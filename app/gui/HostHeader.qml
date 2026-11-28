import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0

Item {
    id: header

    property var computer

    readonly property alias menuButton: menuButton

    signal menuRequested(Item anchor, bool viaKeyboard)

    implicitHeight: layout.implicitHeight + 44

    function statusText() {
        if (!computer) {
            return ""
        }
        if (computer.statusUnknown) {
            return qsTr("Connecting…")
        }

        var parts = []
        if (computer.online) {
            parts.push(qsTr("Online"))
            parts.push(computer.paired ? qsTr("Paired") : qsTr("Not paired"))
        }
        else {
            parts.push(qsTr("Offline"))
        }
        if (computer.address) {
            parts.push(computer.address)
        }
        return parts.join(" · ")
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: header.computer ? header.computer.name : ""
                font.pixelSize: 20
                font.weight: Font.DemiBold
                color: Theme.text
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    visible: header.computer ? !header.computer.statusUnknown : false
                    implicitWidth: 7
                    implicitHeight: 7
                    radius: 3.5
                    color: header.computer && header.computer.online ? Theme.accent : Theme.offline
                }

                Text {
                    Layout.fillWidth: true
                    text: header.statusText()
                    font.pixelSize: Theme.fontSmall
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }
        }

        DeskIconButton {
            id: menuButton
            iconName: "more"
            toolTipText: qsTr("Host options")
            onClicked: header.menuRequested(menuButton, visualFocus)
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.border
    }
}
