import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0

FocusScope {
    id: emptyHosts

    signal addHostRequested()
    signal setupHelpRequested()
    signal sidebarFocusRequested()

    function focusFirst(reason) {
        addButton.forceActiveFocus(reason)
    }

    Keys.onLeftPressed: {
        if (helpButton.activeFocus) {
            addButton.forceActiveFocus(Qt.BacktabFocusReason)
        }
        else {
            sidebarFocusRequested()
        }
    }
    Keys.onRightPressed: {
        if (addButton.activeFocus && helpButton.visible) {
            helpButton.forceActiveFocus(Qt.TabFocusReason)
        }
    }
    Keys.onEscapePressed: sidebarFocusRequested()
    Keys.onBackPressed: sidebarFocusRequested()
    Keys.onReturnPressed: activateFocused()
    Keys.onEnterPressed: activateFocused()

    function activateFocused() {
        if (addButton.activeFocus) {
            addButton.clicked()
        }
        else if (helpButton.activeFocus) {
            helpButton.clicked()
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: Math.max(height, column.implicitHeight + 96)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            width: Math.min(440, parent.width - 64)
            spacing: 16

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 64
                implicitHeight: 64
                radius: 16
                color: Theme.raised
                border.width: 1
                border.color: Theme.border

                DeskIcon {
                    anchors.centerIn: parent
                    name: "wifi"
                    color: Theme.accent
                    size: 30
                }
            }

            Text {
                Layout.fillWidth: true
                text: StreamingPreferences.enableMdns ? qsTr("Looking for hosts on your network")
                                                      : qsTr("No hosts yet")
                font.pixelSize: 20
                font.weight: Font.DemiBold
                color: Theme.text
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                text: StreamingPreferences.enableMdns
                      ? qsTr("Computers running Sunshine on this network appear here automatically. If yours doesn't show up, add it by address.")
                      : qsTr("Automatic PC discovery is disabled. Add your PC manually.")
                font.pixelSize: Theme.fontBase
                lineHeight: 1.4
                color: Theme.mutedStrong
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                spacing: 10

                DeskButton {
                    id: addButton
                    focus: true
                    variant: "primary"
                    text: qsTr("Add host by address")
                    implicitHeight: 42
                    leftPadding: 20
                    rightPadding: 20
                    onClicked: emptyHosts.addHostRequested()
                }

                DeskButton {
                    id: helpButton
                    visible: SystemProperties.hasBrowser
                    text: qsTr("Setting up a host")
                    implicitHeight: 42
                    leftPadding: 18
                    rightPadding: 18
                    onClicked: emptyHosts.setupHelpRequested()
                }
            }
        }
    }
}
