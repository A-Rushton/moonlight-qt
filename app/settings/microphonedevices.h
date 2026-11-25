#pragma once

#include <QObject>
#include <QStringList>

class MicrophoneDevices : public QObject
{
    Q_OBJECT

public:
    explicit MicrophoneDevices(QObject* parent = nullptr);

    Q_INVOKABLE QStringList captureDevices();
};
