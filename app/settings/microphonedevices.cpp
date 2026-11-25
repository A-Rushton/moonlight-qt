#include "microphonedevices.h"

#include "SDL_compat.h"
#include "streaming/audio/sdlaudiosubsystem.h"

#include <QtDebug>

MicrophoneDevices::MicrophoneDevices(QObject* parent)
    : QObject(parent)
{
}

QStringList MicrophoneDevices::captureDevices()
{
    QStringList devices;

    if (!SdlAudioSubsystem::acquire()) {
        qWarning() << "Failed to initialize SDL audio:" << SDL_GetError();
        return devices;
    }

    int count = SDL_GetNumAudioDevices(SDL_TRUE);
    for (int i = 0; i < count; i++) {
        const char* name = SDL_GetAudioDeviceName(i, SDL_TRUE);
        if (name == nullptr) {
            continue;
        }

        QString deviceName = QString::fromUtf8(name);
        if (!devices.contains(deviceName)) {
            devices.append(deviceName);
        }
    }

    SdlAudioSubsystem::release();

    return devices;
}
