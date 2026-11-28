#pragma once

#include <QQuickImageProvider>

class DeskIconProvider : public QQuickImageProvider
{
public:
    DeskIconProvider();

    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;
};
