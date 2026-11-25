#include "microphonedevices.h"

#include "SDL_compat.h"

#include <QtDebug>

MicrophoneDevices::MicrophoneDevices(QObject* parent)
    : QObject(parent)
{
}

QStringList MicrophoneDevices::captureDevices()
{
    QStringList devices;

    if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
        qWarning() << "SDL_InitSubSystem(SDL_INIT_AUDIO) failed:" << SDL_GetError();
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

    SDL_QuitSubSystem(SDL_INIT_AUDIO);

    return devices;
}
