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
    $$APP_DIR/streaming/audio/micechocanceller.cpp \
    $$APP_DIR/settings/miclevelmonitor.cpp

HEADERS += \
    $$APP_DIR/streaming/audio/micring.h \
    $$APP_DIR/streaming/audio/micdownmix.h \
    $$APP_DIR/streaming/audio/micfarend.h \
    $$APP_DIR/streaming/audio/micencoder.h \
    $$APP_DIR/streaming/audio/micechocanceller.h \
    $$APP_DIR/streaming/audio/miclevel.h \
    $$APP_DIR/streaming/audio/micpermission.h \
    $$APP_DIR/streaming/audio/sdlaudiosubsystem.h \
    $$APP_DIR/settings/miclevelmonitor.h

INCLUDEPATH += $$APP_DIR $$APP_DIR/streaming/audio

macx {
    LIBS_DIR = $$PWD/../../libs/mac
    INCLUDEPATH += $$LIBS_DIR/include
    INCLUDEPATH += $$LIBS_DIR/include/SDL2
    LIBS += $$LIBS_DIR/lib/libopus.0.dylib $$LIBS_DIR/lib/libSDL2.dylib

    APM_DIR = $$PWD/../../libs/webrtc-apm/mac
    !exists($$APM_DIR/lib/libwebrtc-apm.a) {
        error("libs/webrtc-apm/mac is missing; run scripts/build-webrtc-apm.sh")
    }
    DEFINES += HAVE_WEBRTC_APM HAVE_WEBRTC_AEC3_FACTORY WEBRTC_POSIX WEBRTC_MAC
    INCLUDEPATH += $$APM_DIR/include
    LIBS += $$APM_DIR/lib/libwebrtc-apm.a -framework CoreFoundation

    OBJECTIVE_SOURCES += $$APP_DIR/streaming/audio/micpermission_mac.mm
    LIBS += -framework AVFoundation
    QMAKE_RPATHDIR += $$LIBS_DIR/lib
}
else {
    CONFIG += link_pkgconfig
    PKGCONFIG += opus sdl2
    packagesExist(webrtc-audio-processing-2) {
        PKGCONFIG += webrtc-audio-processing-2
        DEFINES += HAVE_WEBRTC_APM
    }
}
