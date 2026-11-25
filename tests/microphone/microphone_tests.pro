QT += testlib
QT -= gui
CONFIG += console testcase c++17
CONFIG -= app_bundle
TEMPLATE = app
TARGET = tst_microphone

APP_DIR = $$PWD/../../app

SOURCES += \
    tst_microphone.cpp \
    $$APP_DIR/streaming/audio/micencoder.cpp \
    $$APP_DIR/streaming/audio/micechocanceller.cpp

HEADERS += \
    $$APP_DIR/streaming/audio/micring.h \
    $$APP_DIR/streaming/audio/micencoder.h \
    $$APP_DIR/streaming/audio/micechocanceller.h

INCLUDEPATH += $$APP_DIR/streaming/audio

macx {
    LIBS_DIR = $$PWD/../../libs/mac
    INCLUDEPATH += $$LIBS_DIR/include
    INCLUDEPATH += $$LIBS_DIR/include/SDL2
    LIBS += $$LIBS_DIR/lib/libopus.0.dylib $$LIBS_DIR/lib/libSDL2.dylib

    APM_DIR = $$PWD/../../libs/webrtc-apm/mac
    exists($$APM_DIR/lib/libwebrtc-apm.a) {
        DEFINES += HAVE_WEBRTC_APM WEBRTC_POSIX WEBRTC_MAC
        INCLUDEPATH += $$APM_DIR/include
        LIBS += $$APM_DIR/lib/libwebrtc-apm.a -framework CoreFoundation
    }
    QMAKE_RPATHDIR += $$LIBS_DIR/lib
}
else {
    CONFIG += link_pkgconfig
    PKGCONFIG += opus sdl2
}
