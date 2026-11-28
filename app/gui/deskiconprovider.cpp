#include "deskiconprovider.h"

#include <QColor>
#include <QFile>
#include <QPainter>
#include <QSvgRenderer>

namespace {

const int kDefaultIconSize = 24;

QSize resolveSize(const QSize& requestedSize)
{
    int width = requestedSize.width();
    int height = requestedSize.height();

    if (width <= 0 && height <= 0) {
        return QSize(kDefaultIconSize, kDefaultIconSize);
    }

    // Icons are square, so a single requested dimension determines both
    if (width <= 0) {
        width = height;
    }
    else if (height <= 0) {
        height = width;
    }

    return QSize(width, height);
}

}

DeskIconProvider::DeskIconProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage DeskIconProvider::requestImage(const QString& id, QSize* size, const QSize& requestedSize)
{
    const QSize targetSize = resolveSize(requestedSize);
    if (size != nullptr) {
        *size = targetSize;
    }

    QImage image(targetSize, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);

    // Expected form: <name>/<RRGGBB>
    const int separator = id.lastIndexOf(QLatin1Char('/'));
    const QString name = separator > 0 ? id.left(separator) : QString();
    const QColor color(QLatin1Char('#') + id.mid(separator + 1));
    if (name.isEmpty() || !color.isValid()) {
        qWarning() << "Malformed icon request:" << id;
        return image;
    }

    const QString path = QStringLiteral(":/res/desk/%1.svg").arg(name);
    if (!QFile::exists(path)) {
        qWarning() << "Unknown icon:" << name;
        return image;
    }

    QSvgRenderer renderer(path);
    if (!renderer.isValid()) {
        qWarning() << "Invalid icon:" << name;
        return image;
    }

    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    renderer.render(&painter, QRectF(QPointF(0, 0), targetSize));
    painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
    painter.fillRect(image.rect(), color);
    painter.end();

    return image;
}
