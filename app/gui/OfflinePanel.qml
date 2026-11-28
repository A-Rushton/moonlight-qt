import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0
import SystemProperties 1.0

FocusScope {
    id: panel

    property var computer

    signal wakeRequested()
    signal wakeHelpRequested()

    implicitHeight: layout.implicitHeight

    function focusPrimary(reason) {
        if (wakeButton.visible) {
            wakeButton.forceActiveFocus(reason)
            return true
        }
        if (helpLink.visible) {
            helpLink.forceActiveFocus(reason)
            return true
        }
        return false
    }

    ColumnLayout {
        id: layout
        width: parent.width
        spacing: 28

        DeskPanel {
            Layout.fillWidth: true
            implicitHeight: statusRow.implicitHeight + 48

            RowLayout {
                id: statusRow
                anchors.fill: parent
                anchors.margins: 24
                spacing: 24

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 56
                    implicitHeight: 56
                    radius: Theme.radiusPanel
                    color: Theme.selected

                    DeskIcon {
                        anchors.centerIn: parent
                        name: "power"
                        color: Theme.muted
                        size: 28
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("This host is offline")
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: Theme.text
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: panel.computer && panel.computer.wakeable
                              ? qsTr("It may be asleep or turned off. Moonlight can try to wake it over the network.")
                              : qsTr("It may be asleep or turned off. Moonlight can't wake it because its MAC address isn't known.")
                        font.pixelSize: Theme.fontSmall
                        lineHeight: 1.3
                        color: Theme.muted
                        wrapMode: Text.Wrap
                    }
                }

                DeskButton {
                    id: wakeButton
                    visible: panel.computer ? panel.computer.wakeable : false
                    focus: true
                    variant: "primary"
                    text: qsTr("Wake host")
                    implicitHeight: 44
                    leftPadding: 24
                    rightPadding: 24
                    font.pixelSize: 15
                    onClicked: panel.wakeRequested()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                leftPadding: 4
                text: qsTr("Details").toUpperCase()
                font.pixelSize: Theme.fontSection
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.fontSection * 0.08
                color: Theme.muted
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: detailsColumn.implicitHeight + 2
                radius: Theme.radiusPanel
                color: "transparent"
                border.width: 1
                border.color: Theme.border

                Column {
                    id: detailsColumn
                    x: 1
                    y: 1
                    width: parent.width - 2

                    Repeater {
                        model: panel.computer ? [
                            { label: qsTr("Address"), value: panel.computer.address || qsTr("Unknown") },
                            { label: qsTr("MAC address"), value: panel.computer.macAddress || qsTr("Unknown") },
                            { label: qsTr("Paired"), value: panel.computer.paired ? qsTr("Yes") : qsTr("No") },
                            { label: qsTr("Apps"), value: String(panel.computer.appCount) }
                        ] : []

                        delegate: Item {
                            width: detailsColumn.width
                            implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight) + 24

                            Rectangle {
                                visible: index > 0
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Theme.border
                            }

                            Text {
                                id: labelText
                                x: 16
                                width: 140
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                font.pixelSize: Theme.fontBase
                                color: Theme.muted
                                elide: Text.ElideRight
                            }

                            Text {
                                id: valueText
                                anchors.left: labelText.right
                                anchors.right: parent.right
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.value
                                font.pixelSize: Theme.fontBase
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            RowLayout {
                id: helpRow
                Layout.fillWidth: true
                Layout.leftMargin: 4
                spacing: 4

                Text {
                    Layout.maximumWidth: helpRow.width - (helpLink.visible ? helpLink.implicitWidth + helpRow.spacing : 0)
                    text: qsTr("Wake-on-LAN must be enabled on the host.")
                    font.pixelSize: Theme.fontSmall
                    color: Theme.muted
                    wrapMode: Text.Wrap
                }

                AbstractButton {
                    id: helpLink
                    visible: SystemProperties.hasBrowser
                    padding: 2
                    text: qsTr("How to set it up")

                    contentItem: Text {
                        text: helpLink.text
                        font.pixelSize: Theme.fontSmall
                        font.underline: helpLink.hovered || helpLink.visualFocus
                        color: Theme.link
                    }

                    background: Item {
                        DeskFocusRing {
                            target: helpLink
                            targetRadius: 4
                            gap: 1
                        }
                    }

                    onClicked: panel.wakeHelpRequested()
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }
}
