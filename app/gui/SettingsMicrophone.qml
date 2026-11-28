import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14

import DeskTheme 1.0
import StreamingPreferences 1.0
import MicrophoneDevices 1.0
import MicLevelMonitor 1.0

Column {
    id: section

    readonly property int meterSegments: 24

    // Capture only while the meter can be seen; the short delay avoids opening
    // the device when keyboard navigation merely passes through this section
    readonly property bool wantsLevel: visible && StreamingPreferences.enableMicrophone &&
                                       Window.visibility !== Window.Hidden &&
                                       Window.visibility !== Window.Minimized

    spacing: 20

    onWantsLevelChanged: {
        if (wantsLevel) {
            activationTimer.restart()
        }
        else {
            activationTimer.stop()
            levelMonitor.active = false
        }
    }

    Timer {
        id: activationTimer
        interval: 250
        onTriggered: levelMonitor.active = section.wantsLevel
    }

    MicLevelMonitor {
        id: levelMonitor
        device: StreamingPreferences.microphoneDevice
    }

    MicrophoneDevices {
        id: microphoneDevices
    }

    DeskPanel {
        width: parent.width
        height: enableColumn.height

        Column {
            id: enableColumn
            width: parent.width

            SettingsRow {
                title: qsTr("Stream microphone to host")
                hint: qsTr("Apps on the host hear you through the Sunshine virtual microphone")
                control: DeskSwitch {
                    id: enableMicrophoneCheck
                    checked: StreamingPreferences.enableMicrophone
                    onCheckedChanged: {
                        StreamingPreferences.enableMicrophone = checked
                    }
                }
            }
        }
    }

    DeskPanel {
        width: parent.width
        height: deviceColumn.height

        Column {
            id: deviceColumn
            width: parent.width

            SettingsRow {
                title: qsTr("Input device")
                control: AutoResizingComboBox {
                    id: microphoneComboBox
                    enabled: enableMicrophoneCheck.checked
                    model: [qsTr("System default")]

                    function refreshDevices() {
                        var saved = StreamingPreferences.microphoneDevice
                        var devices = microphoneDevices.captureDevices()
                        if (saved !== "" && devices.indexOf(saved) < 0) {
                            devices.push(saved)
                        }
                        devices.unshift(qsTr("System default"))
                        model = devices
                        currentIndex = saved === "" ? 0 : devices.indexOf(saved)
                        recalculateWidth()
                    }

                    Component.onCompleted: refreshDevices()

                    onDownChanged: {
                        if (down) {
                            refreshDevices()
                        }
                    }

                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated: {
                        StreamingPreferences.microphoneDevice = currentIndex === 0 ? "" : model[currentIndex]
                        recalculateWidth()
                    }
                }
            }

            SettingsRow {
                id: meterRow
                stacked: true
                control: Column {
                    enabled: enableMicrophoneCheck.checked
                    opacity: enabled ? 1.0 : 0.45
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 16

                        DeskIcon {
                            id: micIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: "mic"
                            color: Theme.muted
                            size: 16
                        }

                        Row {
                            id: meter
                            readonly property int litSegments: levelMonitor.active
                                                               ? Math.round(Math.max(0, Math.min(1, levelMonitor.level)) * section.meterSegments)
                                                               : 0
                            readonly property real segmentWidth: (width - (section.meterSegments - 1) * spacing) / section.meterSegments

                            anchors.left: micIcon.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Accessible.role: Accessible.ProgressBar
                            Accessible.name: qsTr("Input level")

                            Repeater {
                                model: section.meterSegments

                                Rectangle {
                                    width: meter.segmentWidth
                                    height: 8
                                    radius: 2
                                    color: index < meter.litSegments ? Theme.accent : Theme.borderStrong
                                }
                            }
                        }
                    }

                    Text {
                        readonly property bool failed: levelMonitor.active && levelMonitor.error !== ""

                        width: parent.width
                        text: failed ? levelMonitor.error : qsTr("Speak to check the level.")
                        font.pixelSize: Theme.fontSmall
                        color: failed ? Theme.danger : Theme.muted
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    DeskPanel {
        width: parent.width
        height: processingColumn.height

        Column {
            id: processingColumn
            width: parent.width

            SettingsRow {
                title: qsTr("Echo cancellation")
                hint: qsTr("Removes host audio your mic picks up from speakers")
                control: DeskSwitch {
                    id: echoCancellationCheck
                    enabled: enableMicrophoneCheck.checked
                    checked: StreamingPreferences.micEchoCancellation
                    onCheckedChanged: {
                        StreamingPreferences.micEchoCancellation = checked
                    }
                }
            }

            SettingsRow {
                title: qsTr("Noise suppression")
                hint: qsTr("Reduces steady background noise like fans")
                control: DeskSwitch {
                    id: noiseSuppressionCheck
                    enabled: enableMicrophoneCheck.checked
                    checked: StreamingPreferences.micNoiseSuppression
                    onCheckedChanged: {
                        StreamingPreferences.micNoiseSuppression = checked
                    }
                }
            }
        }
    }
}
