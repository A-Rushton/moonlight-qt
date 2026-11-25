#include "microphone.h"
#include "micpermission.h"
#include "sdlaudiosubsystem.h"

#include <Limelight.h>

#include <chrono>
#include <optional>
#include <system_error>

namespace {

constexpr size_t kRingSamples = MicEncoder::SampleRate / 5;
constexpr int kInitialEchoDelayMs = 60;
constexpr Uint32 kEchoStatsIntervalMs = 5000;

// Windows reports a privacy-blocked microphone as a device that only
// delivers digital silence
#ifdef Q_OS_WIN32
constexpr bool kDetectBlockedCapture = true;
#else
constexpr bool kDetectBlockedCapture = false;
#endif
constexpr uint64_t kBlockedCaptureSamples = 3 * MicEncoder::SampleRate;

template <typename T>
const char* formatOptional(char (&buf)[16], const std::optional<T>& value, const char* format)
{
    if (!value) {
        return "n/a";
    }
    SDL_snprintf(buf, sizeof(buf), format, *value);
    return buf;
}

bool captureDeviceExists(const QString& name)
{
    int count = SDL_GetNumAudioDevices(1);
    for (int i = 0; i < count; i++) {
        const char* deviceName = SDL_GetAudioDeviceName(i, 1);
        if (deviceName != nullptr && name == QString::fromUtf8(deviceName)) {
            return true;
        }
    }
    return false;
}

}

const char* micStatusOverlayText(MicStatus status)
{
    switch (status) {
    case MicStatus::Live:
        return "Mic: live";
    case MicStatus::NotSupported:
        return "Mic: not supported by host";
    case MicStatus::Unavailable:
        return "Mic: unavailable";
    case MicStatus::Off:
        break;
    }
    return nullptr;
}

MicrophoneStream::MicrophoneStream(QString preferredDevice)
    : m_PreferredDevice(std::move(preferredDevice)),
      m_Status(MicStatus::Unavailable),
      m_UsingFallback(false),
      m_Ring(kRingSamples),
      m_EchoCancelActive(false),
      m_EchoCancelInitialised(false),
      m_Stopping(false),
      m_Device(0),
      m_Started(false),
      m_Stopped(false),
      m_AudioAcquired(false),
      m_PermissionGuard(std::make_shared<PermissionGuard>())
{
    m_PermissionGuard->owner = this;
}

MicrophoneStream::~MicrophoneStream()
{
    stop();
}

void MicrophoneStream::setMessageHandler(MessageHandler handler)
{
    m_MessageHandler = std::move(handler);
}

MicStatus MicrophoneStream::status() const
{
    return m_Status.load(std::memory_order_acquire);
}

bool MicrophoneStream::usingFallbackDevice() const
{
    return m_UsingFallback.load(std::memory_order_acquire);
}

bool MicrophoneStream::wantsFarEnd() const
{
    return m_EchoCancelActive.load(std::memory_order_acquire);
}

void MicrophoneStream::pushFarEnd(const float* mono, size_t samples)
{
    if (mono != nullptr && wantsFarEnd()) {
        m_FarEnd.push(mono, samples);
    }
}

void MicrophoneStream::initEchoCancellerLocked()
{
    if (m_EchoCancelInitialised) {
        return;
    }
    m_EchoCancelInitialised = true;

    // The encoder thread only touches the canceller once m_EchoCancelActive
    // publishes it
    if (m_EchoCanceller.init()) {
        // A hint AEC3 may ignore; its own delay estimator tracks the real delay
        m_EchoCanceller.setStreamDelayMs(kInitialEchoDelayMs);
        m_EchoCancelActive.store(true, std::memory_order_release);
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Microphone echo canceller initialised");
    }
    else {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Microphone echo cancellation unavailable");
        notify(tr("Echo cancellation unavailable. Use headphones to avoid echo."), true);
    }
}

bool MicrophoneStream::start()
{
    std::unique_lock<std::mutex> lock(m_StateLock);

    if (m_Started || m_Stopped) {
        return false;
    }
    m_Started = true;

    if (!(LiGetHostFeatureFlags() & LI_FF_MICROPHONE)) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Host does not support microphone streaming");
        m_Status = MicStatus::NotSupported;
        notify(tr("The host does not support microphone streaming. The stream will continue without your microphone."), true);
        return false;
    }

    if (!LiIsMicrophoneStreamActive()) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Host did not start the microphone stream");
        return false;
    }

    if (!m_Encoder.init()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Failed to create microphone Opus encoder");
        return false;
    }

    if (!SdlAudioSubsystem::acquire()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_InitSubSystem(SDL_INIT_AUDIO) failed for microphone: %s",
                     SDL_GetError());
        return false;
    }
    m_AudioAcquired = true;

    try {
        m_EncoderThread = std::thread(&MicrophoneStream::encoderThreadMain, this);
    } catch (const std::system_error& e) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Failed to start microphone encoder thread: %s",
                     e.what());
        return false;
    }

    switch (micPermissionStatus()) {
    case MicPermission::Granted:
        break;

    case MicPermission::Denied:
        reportPermissionDenied();
        return false;

    case MicPermission::Undetermined: {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Requesting microphone permission");
        std::shared_ptr<PermissionGuard> guard = m_PermissionGuard;
        lock.unlock();
        requestMicPermission([guard](bool granted) {
            std::lock_guard<std::mutex> guardLock(guard->lock);
            if (guard->owner != nullptr) {
                guard->owner->onPermissionResult(granted);
            }
        });
        return true;
    }
    }

    return openPreferredDeviceLocked();
}

bool MicrophoneStream::openPreferredDeviceLocked()
{
    const char* name = nullptr;
    QByteArray preferredName = m_PreferredDevice.toUtf8();
    if (!m_PreferredDevice.isEmpty()) {
        if (captureDeviceExists(m_PreferredDevice)) {
            name = preferredName.constData();
        }
        else {
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "Microphone '%s' not found; using the default device",
                        preferredName.constData());
            notify(tr("Microphone \"%1\" was not found. Using the system default microphone instead.").arg(m_PreferredDevice), true);
        }
    }

    if (!openDeviceLocked(name)) {
        return false;
    }

    m_UsingFallback = name == nullptr && !m_PreferredDevice.isEmpty();
    initEchoCancellerLocked();
    return true;
}

void MicrophoneStream::onPermissionResult(bool granted)
{
    std::lock_guard<std::mutex> lock(m_StateLock);

    if (m_Stopped) {
        return;
    }

    if (!granted) {
        reportPermissionDenied();
        return;
    }

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Microphone permission granted");
    openPreferredDeviceLocked();
}

void MicrophoneStream::reportPermissionDenied()
{
    SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                "Microphone permission denied");
    m_Status = MicStatus::Unavailable;
    notify(tr(u8"Microphone access is denied. Allow Moonlight in System Settings \u2192 Privacy & Security \u2192 Microphone."), true);
}

bool MicrophoneStream::openDeviceLocked(const char* name)
{
    SDL_AudioSpec want, have;
    SDL_zero(want);
    SDL_zero(have);
    want.freq = MicEncoder::SampleRate;
    want.format = AUDIO_F32SYS;
    want.channels = 1;
    want.samples = MicEncoder::FrameSamples;
    want.callback = captureCallback;
    want.userdata = this;

    // No allowed changes: SDL converts whatever the device delivers
    SDL_AudioDeviceID device = SDL_OpenAudioDevice(name, 1, &want, &have, 0);
    if (device == 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Failed to open microphone '%s': %s",
                     name != nullptr ? name : "(default)",
                     SDL_GetError());
        m_Status = MicStatus::Unavailable;
        return false;
    }

    m_Device = device;

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Microphone '%s' opened: %d Hz, %d channel(s), %u sample buffer",
                name != nullptr ? name : "(default)",
                have.freq,
                have.channels,
                have.samples);

    SDL_PauseAudioDevice(device, 0);
    m_Status = MicStatus::Live;
    return true;
}

void MicrophoneStream::closeDeviceLocked()
{
    if (m_Device != 0) {
        // Waits for any in-flight capture callback to return
        SDL_CloseAudioDevice(m_Device);
        m_Device = 0;
    }
}

void MicrophoneStream::handleDeviceRemoved(SDL_AudioDeviceID id)
{
    std::lock_guard<std::mutex> lock(m_StateLock);

    if (m_Stopped || m_Device == 0 || id != m_Device) {
        return;
    }

    SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                "Microphone device removed");
    closeDeviceLocked();

    if (openDeviceLocked(nullptr)) {
        m_UsingFallback = !m_PreferredDevice.isEmpty();
        notify(tr("Microphone disconnected. Switched to the system default microphone."), false);
    }
    else {
        m_EchoCancelActive = false;
        notify(tr("Microphone unavailable"), false);
    }
}

void MicrophoneStream::stop()
{
    {
        // Waits for an in-flight permission callback and disarms later ones
        std::lock_guard<std::mutex> guardLock(m_PermissionGuard->lock);
        m_PermissionGuard->owner = nullptr;
    }

    std::lock_guard<std::mutex> lock(m_StateLock);

    if (m_Stopped) {
        return;
    }
    m_Stopped = true;

    m_Stopping = true;
    m_EchoCancelActive = false;
    closeDeviceLocked();

    {
        std::lock_guard<std::mutex> wakeLock(m_WakeLock);
    }
    m_Wake.notify_all();

    if (m_EncoderThread.joinable()) {
        m_EncoderThread.join();
    }

    if (m_AudioAcquired) {
        SdlAudioSubsystem::release();
        m_AudioAcquired = false;
    }
}

void MicrophoneStream::notify(const QString& text, bool launchWarning)
{
    if (!m_Stopping && m_MessageHandler) {
        m_MessageHandler(text, launchWarning);
    }
}

void SDLCALL MicrophoneStream::captureCallback(void* userdata, Uint8* stream, int len)
{
    auto self = static_cast<MicrophoneStream*>(userdata);

    if (len > 0) {
        self->m_Ring.push(reinterpret_cast<const float*>(stream), static_cast<size_t>(len) / sizeof(float));
        self->m_Wake.notify_one();
    }
}

void MicrophoneStream::logEchoStats()
{
    MicEchoCanceller::Stats stats;
    m_EchoCanceller.statistics(stats);
    MicFarEndFeeder::Counters counters = m_FarEnd.takeCounters();

    char delay[16], erl[16], erle[16], divergent[16], residual[16];
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Mic AEC: delay=%s ms ERL=%s ERLE=%s divergent=%s residual=%s starved=%llu/%llu trims=%llu (%llu samples) farDepth=%llu",
                formatOptional(delay, stats.delayMs, "%d"),
                formatOptional(erl, stats.erl, "%.1f"),
                formatOptional(erle, stats.erle, "%.1f"),
                formatOptional(divergent, stats.divergentFraction, "%.2f"),
                formatOptional(residual, stats.residualEchoMax, "%.2f"),
                static_cast<unsigned long long>(counters.starved),
                static_cast<unsigned long long>(counters.frames),
                static_cast<unsigned long long>(counters.trims),
                static_cast<unsigned long long>(counters.trimmedSamples),
                static_cast<unsigned long long>(m_FarEnd.depth()));
}

void MicrophoneStream::encoderThreadMain()
{
    float frame[MicEncoder::FrameSamples];
    float farFrame[MicEncoder::FrameSamples];
    unsigned char packet[MIC_MAX_OPUS_FRAME_BYTES];

    bool checkBlockedCapture = kDetectBlockedCapture;
    uint64_t silentSamples = 0;

    unsigned int failedFrames = 0;
    int lastEncodeError = 0;
    int lastSendError = 0;
    Uint32 lastFailureLog = 0;

    bool echoStatsStarted = false;
    Uint32 lastEchoStatsLog = 0;

    while (!m_Stopping) {
        {
            std::unique_lock<std::mutex> wakeLock(m_WakeLock);
            m_Wake.wait_for(wakeLock, std::chrono::milliseconds(5), [this] {
                return m_Stopping || m_Ring.available() >= MicEncoder::FrameSamples;
            });
        }

        while (!m_Stopping && m_Ring.popFrame(frame, MicEncoder::FrameSamples)) {
            if (checkBlockedCapture) {
                bool silent = true;
                for (float sample : frame) {
                    if (sample != 0.0f) {
                        silent = false;
                        break;
                    }
                }

                if (!silent) {
                    checkBlockedCapture = false;
                }
                else if ((silentSamples += MicEncoder::FrameSamples) >= kBlockedCaptureSamples) {
                    checkBlockedCapture = false;
                    SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                                "Microphone delivered only silence for 3 seconds");
                    notify(tr(u8"No audio from your microphone. It may be muted or blocked in Windows Settings \u2192 Privacy & security \u2192 Microphone."), true);
                }
            }

            if (m_EchoCancelActive.load(std::memory_order_acquire)) {
                m_FarEnd.popFrame(farFrame);
                m_EchoCanceller.processReverse(farFrame);
                m_EchoCanceller.processCapture(frame);

                if (!echoStatsStarted) {
                    echoStatsStarted = true;
                    lastEchoStatsLog = SDL_GetTicks();
                }
                else if (SDL_TICKS_PASSED(SDL_GetTicks(), lastEchoStatsLog + kEchoStatsIntervalMs)) {
                    logEchoStats();
                    lastEchoStatsLog = SDL_GetTicks();
                }
            }

            int len = m_Encoder.encode(frame, packet, sizeof(packet));
            if (len > 0) {
                int err = LiSendMicrophoneOpusFrame(packet, len);
                if (err == -1) {
                    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                                "Microphone stream is no longer active");
                    if (!m_Stopping) {
                        m_Status = MicStatus::Unavailable;
                    }
                    m_EchoCancelActive = false;
                    return;
                }
                else if (err != 0) {
                    failedFrames++;
                    lastSendError = err;
                }
            }
            else {
                failedFrames++;
                lastEncodeError = len;
            }

            if (failedFrames != 0 && SDL_TICKS_PASSED(SDL_GetTicks(), lastFailureLog + 1000)) {
                SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                            "Dropped %u microphone frame(s) (last encode error: %d, last send error: %d)",
                            failedFrames,
                            lastEncodeError,
                            lastSendError);
                failedFrames = 0;
                lastFailureLog = SDL_GetTicks();
            }
        }
    }
}
