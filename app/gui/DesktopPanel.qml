import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0
import StreamingPreferences 1.0

FocusScope {
    id: panel

    // Model row of the host's Desktop app
    property var row: null

    readonly property bool running: row ? row.running : false

    signal launchRequested()
    signal quitRequested()
    signal menuRequested(Item anchor, bool viaKeyboard)

    implicitHeight: frame.implicitHeight

    function focusPrimary(reason) {
        (running ? resumeButton : connectButton).forceActiveFocus(reason)
        return true
    }

    function resolutionText() {
        var height = StreamingPreferences.height
        if ([720, 1080, 1440, 2160].indexOf(height) >= 0) {
            return height + "p"
        }
        return StreamingPreferences.width + "×" + height
    }

    function bitrateText() {
        var mbps = StreamingPreferences.bitrateKbps / 1000
        return mbps % 1 === 0 ? String(mbps) : mbps.toFixed(1)
    }

    readonly property string summary: [
        resolutionText(),
        qsTr("%1 fps").arg(StreamingPreferences.fps),
        qsTr("%1 Mbps").arg(bitrateText()),
        StreamingPreferences.enableMicrophone ? qsTr("Mic on") : qsTr("Mic off")
    ].join(" · ")

    Keys.onMenuPressed: menuRequested(running ? resumeButton : connectButton, true)

    DeskPanel {
        id: frame
        width: parent.width
        implicitHeight: layout.implicitHeight + 48
        opacity: panel.row && panel.row.hidden ? 0.4 : 1.0

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: panel.menuRequested(frame, false)
        }

        RowLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
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
                    name: "monitor"
                    color: Theme.accent
                    size: 28
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        Layout.fillWidth: !runningBadge.visible
                        text: qsTr("Desktop")
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    RunningBadge {
                        id: runningBadge
                        visible: panel.running
                    }

                    Item {
                        Layout.fillWidth: runningBadge.visible
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: panel.summary
                    font.pixelSize: Theme.fontSmall
                    color: Theme.muted
                    wrapMode: Text.Wrap
                }
            }

            DeskButton {
                id: connectButton
                visible: !panel.running
                focus: !panel.running
                variant: "primary"
                text: qsTr("Connect")
                implicitHeight: 44
                leftPadding: 24
                rightPadding: 24
                font.pixelSize: 15
                onClicked: panel.launchRequested()
                onPressAndHold: panel.menuRequested(connectButton, false)
            }

            RowLayout {
                visible: panel.running
                spacing: 8

                DeskButton {
                    id: resumeButton
                    focus: panel.running
                    variant: "primary"
                    iconName: "play"
                    text: qsTr("Resume")
                    implicitHeight: 44
                    leftPadding: 20
                    rightPadding: 20
                    font.pixelSize: 15
                    onClicked: panel.launchRequested()
                    onPressAndHold: panel.menuRequested(resumeButton, false)
                }

                DeskButton {
                    id: quitButton
                    iconName: "stop"
                    text: qsTr("Quit")
                    implicitHeight: 44
                    font.pixelSize: 15
                    onClicked: panel.quitRequested()
                    onPressAndHold: panel.menuRequested(quitButton, false)
                }
            }
        }
    }
}
