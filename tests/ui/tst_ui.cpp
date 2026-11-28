#include <QtTest>
#include <QImage>

#include "deskiconprovider.h"

class TestUi : public QObject
{
    Q_OBJECT

private slots:
    void iconIsTinted();
    void iconHonoursRequestedSize();
    void unknownIconIsTransparent();
};

void TestUi::iconIsTinted()
{
    DeskIconProvider provider;
    QSize size;
    const QImage image = provider.requestImage(QStringLiteral("plus/4ADE80"), &size, QSize(24, 24));
    QCOMPARE(image.size(), QSize(24, 24));

    int opaque = 0;
    for (int y = 0; y < image.height(); y++) {
        for (int x = 0; x < image.width(); x++) {
            const QColor c = image.pixelColor(x, y);
            if (c.alpha() > 200) {
                QVERIFY2(qAbs(c.red() - 0x4A) <= 2 && qAbs(c.green() - 0xDE) <= 2 && qAbs(c.blue() - 0x80) <= 2,
                         qPrintable(QStringLiteral("(%1, %2) is %3").arg(x).arg(y).arg(c.name())));
                opaque++;
            }
        }
    }
    QVERIFY(opaque > 0);
}

void TestUi::iconHonoursRequestedSize()
{
    DeskIconProvider provider;
    QSize size;
    const QImage image = provider.requestImage(QStringLiteral("plus/FFFFFF"), &size, QSize(48, 48));
    QCOMPARE(image.size(), QSize(48, 48));
    QCOMPARE(size, QSize(48, 48));
}

void TestUi::unknownIconIsTransparent()
{
    DeskIconProvider provider;
    QSize size;
    QTest::ignoreMessage(QtWarningMsg, QRegularExpression("Unknown icon.*nope"));
    const QImage image = provider.requestImage(QStringLiteral("nope/FFFFFF"), &size, QSize(24, 24));
    QCOMPARE(image.size(), QSize(24, 24));
    for (int y = 0; y < image.height(); y++) {
        for (int x = 0; x < image.width(); x++) {
            QCOMPARE(qAlpha(image.pixel(x, y)), 0);
        }
    }
}

QTEST_MAIN(TestUi)

#include "tst_ui.moc"
