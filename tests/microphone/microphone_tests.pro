QT += testlib
QT -= gui
CONFIG += console testcase c++17
CONFIG -= app_bundle
TEMPLATE = app
TARGET = tst_microphone

APP_DIR = $$PWD/../../app

SOURCES += \
    tst_microphone.cpp \
    $$APP_DIR/streaming/audio/micencoder.cpp

HEADERS += \
    $$APP_DIR/streaming/audio/micring.h \
    $$APP_DIR/streaming/audio/micencoder.h

INCLUDEPATH += $$APP_DIR/streaming/audio

macx {
    LIBS_DIR = $$PWD/../../libs/mac
    INCLUDEPATH += $$LIBS_DIR/include
    LIBS += $$LIBS_DIR/lib/libopus.0.dylib
    QMAKE_RPATHDIR += $$LIBS_DIR/lib
}
else {
    CONFIG += link_pkgconfig
    PKGCONFIG += opus
}
