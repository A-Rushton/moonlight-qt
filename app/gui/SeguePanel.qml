import QtQuick 2.14

import DeskTheme 1.0

// Centred status card shown while a stream, quit or pairing operation runs
DeskPanel {
    id: panel

    property alias text: statusLabel.text
    property bool busy: true

    anchors.centerIn: parent
    width: Math.min(440, parent.width - 32)
    height: content.height + 56

    Column {
        id: content
        x: 28
        y: 28
        width: parent.width - 56
        spacing: 20

        Row {
            spacing: 10

            DeskIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "moon"
                color: Theme.accent
                size: 20
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Moonlight"
                font.pixelSize: Theme.fontBase
                font.weight: Font.Bold
                color: Theme.text
            }
        }

        Text {
            id: statusLabel
            width: parent.width
            font.pixelSize: 17
            font.weight: Font.DemiBold
            lineHeight: 1.2
            color: Theme.text
            wrapMode: Text.Wrap
        }

        DeskProgressBar {
            width: parent.width
            visible: panel.busy
        }
    }
}
