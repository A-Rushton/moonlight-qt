import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0

FocusScope {
    id: panel

    property var computer
    // The PIN being entered on this host, or empty when not pairing
    property string pin
    // Another host is pairing; only one pairing can run at a time
    property bool otherPairingActive: false

    readonly property bool pairing: pin !== ""

    signal pairRequested()
    signal cancelRequested()

    implicitHeight: card.implicitHeight

    function focusPrimary(reason) {
        var button = pairing ? cancelButton : pairButton
        if (button.visible && button.enabled) {
            button.forceActiveFocus(reason)
            return true
        }
        return false
    }

    DeskPanel {
        id: card
        width: parent.width
        implicitHeight: layout.implicitHeight + 56

        ColumnLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            spacing: 24

            RowLayout {
                Layout.fillWidth: true
                spacing: 24

                Rectangle {
                    visible: !panel.pairing
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 56
                    implicitHeight: 56
                    radius: Theme.radiusPanel
                    color: Theme.selected

                    DeskIcon {
                        anchors.centerIn: parent
                        name: "lock"
                        color: Theme.accent
                        size: 28
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Pair with this host")
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: Theme.text
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: !panel.pairing
                        text: qsTr("Moonlight needs to pair with %1 before it can show its apps. You only need to do this once.")
                              .arg(panel.computer ? panel.computer.name : "")
                        font.pixelSize: Theme.fontBase
                        lineHeight: 1.3
                        color: Theme.mutedStrong
                        wrapMode: Text.Wrap
                    }
                }

                DeskButton {
                    id: pairButton
                    visible: !panel.pairing
                    enabled: !panel.otherPairingActive
                    focus: !panel.pairing
                    variant: "primary"
                    text: qsTr("Pair")
                    implicitHeight: 44
                    leftPadding: 24
                    rightPadding: 24
                    font.pixelSize: 15
                    onClicked: panel.pairRequested()
                }
            }

            Row {
                visible: panel.pairing
                spacing: 10

                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("PIN %1").arg(panel.pin)

                Repeater {
                    model: panel.pin.split("")

                    delegate: Rectangle {
                        width: 56
                        height: 68
                        radius: 10
                        color: Theme.bg
                        border.width: 1
                        border.color: Theme.borderStrong

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 32
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: panel.pairing
                text: qsTr("Enter %1 on your host PC. This will update when pairing completes.").arg(panel.pin) + "\n\n" +
                      qsTr("If your host PC is running Sunshine, navigate to the Sunshine web UI to enter the PIN.")
                font.pixelSize: Theme.fontBase
                lineHeight: 1.3
                color: Theme.mutedStrong
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: panel.otherPairingActive && !panel.pairing
                text: qsTr("Finish pairing the other host before pairing this one.")
                font.pixelSize: Theme.fontSmall
                color: Theme.muted
                wrapMode: Text.Wrap
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: panel.pairing
                spacing: 18

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    BusyIndicator {
                        implicitWidth: 18
                        implicitHeight: 18
                        padding: 0
                        running: panel.pairing && panel.visible
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Waiting for the host…")
                        font.pixelSize: Theme.fontSmall
                        color: Theme.muted
                        elide: Text.ElideRight
                    }

                    DeskButton {
                        id: cancelButton
                        focus: panel.pairing
                        text: qsTr("Cancel")
                        onClicked: panel.cancelRequested()
                    }
                }
            }
        }
    }
}
