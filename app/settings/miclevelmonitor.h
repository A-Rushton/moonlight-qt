#pragma once

#include "SDL_compat.h"

#include <QObject>
#include <QString>
#include <QTimer>

#include <atomic>

class MicLevelMonitor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString device READ device WRITE setDevice NOTIFY deviceChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(qreal level READ level NOTIFY levelChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit MicLevelMonitor(QObject* parent = nullptr);
    ~MicLevelMonitor() override;

    QString device() const;
    void setDevice(const QString& device);

    bool active() const;
    void setActive(bool active);

    qreal level() const;
    QString error() const;

signals:
    void deviceChanged();
    void activeChanged();
    void levelChanged();
    void errorChanged();

private:
    static void SDLCALL captureCallback(void* userdata, Uint8* stream, int len);

    void open();
    void openDevice();
    void close();
    void fail(const QString& error);
    void onPermissionResult(quint64 request, bool granted);
    void tick();
    void setLevel(qreal level);
    void setError(const QString& error);

    QString m_Device;
    bool m_Active = false;
    qreal m_Level = 0;
    QString m_Error;

    bool m_SdlAcquired = false;
    SDL_AudioDeviceID m_AudioDevice = 0;
    quint64 m_OpenRequest = 0;
    std::atomic<float> m_PendingLevel {0.0f};
    QTimer m_Timer;
};
