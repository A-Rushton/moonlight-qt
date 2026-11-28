import QtQuick 2.14

import DeskTheme 1.0

Rectangle {
    implicitWidth: label.implicitWidth + 16
    implicitHeight: 20
    radius: 10
    color: Theme.accent

    Text {
        id: label
        anchors.centerIn: parent
        text: qsTr("Running")
        font.pixelSize: Theme.fontSection
        font.weight: Font.DemiBold
        color: Theme.accentText
    }
}
