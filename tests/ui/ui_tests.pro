QT += testlib gui svg quick
CONFIG += console testcase c++17
CONFIG -= app_bundle
TEMPLATE = app
TARGET = tst_ui

APP_DIR = $$PWD/../../app

SOURCES += \
    tst_ui.cpp \
    $$APP_DIR/gui/deskiconprovider.cpp

HEADERS += \
    $$APP_DIR/gui/deskiconprovider.h

INCLUDEPATH += $$APP_DIR/gui

RESOURCES += ui_tests.qrc
