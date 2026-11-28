#include "miclevelmonitor.h"

#include "streaming/audio/miclevel.h"
#include "streaming/audio/micpermission.h"
#include "streaming/audio/sdlaudiosubsystem.h"

#include <QCoreApplication>
#include <QPointer>
#include <QStringList>
#include <QtDebug>

namespace {

constexpr int kSampleRate = 48000;
constexpr Uint16 kBufferSamples = 480;
constexpr int kTickMs = 33;
constexpr qreal kRelease = 0.85;

}

MicLevelMonitor::MicLevelMonitor(QObject* parent)
    : QObject(parent)
{
    m_Timer.setInterval(kTickMs);
    connect(&m_Timer, &QTimer::timeout, this, &MicLevelMonitor::tick);
}

MicLevelMonitor::~MicLevelMonitor()
{
    close();
}

QString MicLevelMonitor::device() const
{
    return m_Device;
}

void MicLevelMonitor::setDevice(const QString& device)
{
    if (device == m_Device) {
        return;
    }

    m_Device = device;
    emit deviceChanged();

    if (m_Active) {
        close();
        open();
    }
}

bool MicLevelMonitor::active() const
{
    return m_Active;
}

void MicLevelMonitor::setActive(bool active)
{
    if (active == m_Active) {
        return;
    }

    m_Active = active;
    emit activeChanged();

    if (m_Active) {
        open();
    }
    else {
        close();
    }
}

qreal MicLevelMonitor::level() const
{
    return m_Level;
}

QString MicLevelMonitor::error() const
{
    return m_Error;
}

void MicLevelMonitor::open()
{
    if (!SdlAudioSubsystem::acquire()) {
        qWarning() << "Failed to initialize SDL audio:" << SDL_GetError();
        setError(tr("Microphone unavailable"));
        return;
    }
    m_SdlAcquired = true;

    QStringList devices;
    int count = SDL_GetNumAudioDevices(SDL_TRUE);
    for (int i = 0; i < count; i++) {
        const char* name = SDL_GetAudioDeviceName(i, SDL_TRUE);
        if (name != nullptr) {
            devices.append(QString::fromUtf8(name));
        }
    }

    if (devices.isEmpty()) {
        fail(tr("No microphone found"));
        return;
    }
    if (!m_Device.isEmpty() && !devices.contains(m_Device)) {
        fail(tr("Microphone unavailable"));
        return;
    }

    switch (micPermissionStatus()) {
    case MicPermission::Granted:
        openDevice();
        break;
    case MicPermission::Denied:
        fail(tr("Microphone unavailable"));
        break;
    case MicPermission::Undetermined: {
        quint64 request = ++m_OpenRequest;
        QPointer<MicLevelMonitor> self(this);
        requestMicPermission([self, request](bool granted) {
            QCoreApplication* app = QCoreApplication::instance();
            if (app == nullptr) {
                return;
            }
            QMetaObject::invokeMethod(app, [self, request, granted] {
                if (self) {
                    self->onPermissionResult(request, granted);
                }
            }, Qt::QueuedConnection);
        });
        break;
    }
    }
}

void MicLevelMonitor::onPermissionResult(quint64 request, bool granted)
{
    if (request != m_OpenRequest || !m_SdlAcquired || m_AudioDevice != 0) {
        return;
    }

    if (granted) {
        openDevice();
    }
    else {
        fail(tr("Microphone unavailable"));
    }
}

void MicLevelMonitor::openDevice()
{
    SDL_AudioSpec want, have;
    SDL_zero(want);
    SDL_zero(have);
    want.freq = kSampleRate;
    want.format = AUDIO_F32SYS;
    want.channels = 1;
    want.samples = kBufferSamples;
    want.callback = captureCallback;
    want.userdata = this;

    QByteArray name = m_Device.toUtf8();
    m_AudioDevice = SDL_OpenAudioDevice(m_Device.isEmpty() ? nullptr : name.constData(),
                                        1, &want, &have, 0);
    if (m_AudioDevice == 0) {
        qWarning() << "Failed to open microphone for level monitoring:" << SDL_GetError();
        fail(tr("Microphone unavailable"));
        return;
    }

    m_PendingLevel.store(0.0f, std::memory_order_relaxed);
    setError(QString());
    SDL_PauseAudioDevice(m_AudioDevice, 0);
    m_Timer.start();
}

void MicLevelMonitor::fail(const QString& error)
{
    close();
    setError(error);
}

void MicLevelMonitor::close()
{
    ++m_OpenRequest;
    m_Timer.stop();

    if (m_AudioDevice != 0) {
        // Waits for any in-flight capture callback to return
        SDL_CloseAudioDevice(m_AudioDevice);
        m_AudioDevice = 0;
    }

    if (m_SdlAcquired) {
        SdlAudioSubsystem::release();
        m_SdlAcquired = false;
    }

    setLevel(0);
}

void SDLCALL MicLevelMonitor::captureCallback(void* userdata, Uint8* stream, int len)
{
    auto* self = static_cast<MicLevelMonitor*>(userdata);
    float level = micLevelFromSamples(reinterpret_cast<const float*>(stream),
                                      len / int(sizeof(float)));

    // Keep the loudest buffer seen since the last tick
    float pending = self->m_PendingLevel.load(std::memory_order_relaxed);
    while (level > pending &&
           !self->m_PendingLevel.compare_exchange_weak(pending, level, std::memory_order_relaxed)) {
    }
}

void MicLevelMonitor::tick()
{
    qreal latest = m_PendingLevel.exchange(0.0f, std::memory_order_relaxed);
    setLevel(qMax(latest, m_Level * kRelease));
}

void MicLevelMonitor::setLevel(qreal level)
{
    if (level < 0.001) {
        level = 0;
    }
    if (qFuzzyCompare(level + 1, m_Level + 1)) {
        return;
    }

    m_Level = level;
    emit levelChanged();
}

void MicLevelMonitor::setError(const QString& error)
{
    if (error == m_Error) {
        return;
    }

    m_Error = error;
    emit errorChanged();
}
