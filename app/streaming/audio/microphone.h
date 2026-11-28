#pragma once

#include "micechocanceller.h"
#include "micencoder.h"
#include "micfarend.h"
#include "micring.h"

#include "SDL_compat.h"

#include <QCoreApplication>
#include <QString>

#include <atomic>
#include <condition_variable>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>

enum class MicStatus { Off, NotSupported, Live, Unavailable };

const char* micStatusOverlayText(MicStatus status);

class MicrophoneStream
{
    Q_DECLARE_TR_FUNCTIONS(MicrophoneStream)

public:
    // Called from any thread. launchWarning distinguishes configuration
    // warnings from transient status changes.
    using MessageHandler = std::function<void(const QString& text, bool launchWarning)>;

    MicrophoneStream(QString preferredDevice, MicEchoCanceller::Options options);
    ~MicrophoneStream();

    MicrophoneStream(const MicrophoneStream&) = delete;
    MicrophoneStream& operator=(const MicrophoneStream&) = delete;

    // Must be set before start()
    void setMessageHandler(MessageHandler handler);

    // Call once after LiStartConnection() succeeds. Returns false if the
    // microphone will not be streamed; the stream itself is never affected.
    bool start();

    // Stops capture and joins the encoder thread. Must be called before
    // LiStopConnection(). Idempotent.
    void stop();

    MicStatus status() const;
    void handleDeviceRemoved(SDL_AudioDeviceID id);
    bool usingFallbackDevice() const;

    // Decoded host audio as played, mono 48 kHz. Called from the audio
    // decode thread; never blocks.
    void pushFarEnd(const float* mono, size_t samples);
    bool wantsFarEnd() const;

private:
    struct PermissionGuard
    {
        std::mutex lock;
        MicrophoneStream* owner;
    };

    static void SDLCALL captureCallback(void* userdata, Uint8* stream, int len);

    void encoderThreadMain();
    void logEchoStats();
    void onPermissionResult(bool granted);
    void reportPermissionDenied();
    bool openPreferredDeviceLocked();
    bool openDeviceLocked(const char* name);
    void closeDeviceLocked();
    void initEchoCancellerLocked();
    void notify(const QString& text, bool launchWarning);

    const QString m_PreferredDevice;
    const MicEchoCanceller::Options m_EchoOptions;
    MessageHandler m_MessageHandler;

    std::atomic<MicStatus> m_Status;
    std::atomic<bool> m_UsingFallback;

    MicRing m_Ring;
    MicEncoder m_Encoder;

    MicEchoCanceller m_EchoCanceller;
    MicFarEndFeeder m_FarEnd;
    std::atomic<bool> m_EchoCancelActive;
    bool m_EchoCancelInitialised;

    std::thread m_EncoderThread;
    std::mutex m_WakeLock;
    std::condition_variable m_Wake;
    std::atomic<bool> m_Stopping;

    // Guards the device and lifecycle flags against concurrent start(),
    // stop(), device removal and the permission callback
    std::mutex m_StateLock;
    SDL_AudioDeviceID m_Device;
    bool m_Started;
    bool m_Stopped;
    bool m_AudioAcquired;

    std::shared_ptr<PermissionGuard> m_PermissionGuard;
};
