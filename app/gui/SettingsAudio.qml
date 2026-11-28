import QtQuick 2.14
import QtQuick.Controls 2.14

import StreamingPreferences 1.0
import SystemProperties 1.0

Column {
    id: section

    spacing: 20

    DeskPanel {
        width: parent.width
        height: audioColumn.height

        Column {
            id: audioColumn
            width: parent.width

            SettingsRow {
                title: qsTr("Audio configuration")
                control: AutoResizingComboBox {
                    // ignore setting the index at first, and actually set it when the component is loaded
                    Component.onCompleted: {
                        var saved_audio = StreamingPreferences.audioConfig
                        currentIndex = 0
                        for (var i = 0; i < audioListModel.count; i++) {
                            var el_audio = audioListModel.get(i).val;
                            if (saved_audio === el_audio) {
                                currentIndex = i
                                break
                            }
                        }
                        activated(currentIndex)
                    }

                    id: audioComboBox
                    textRole: "text"
                    model: ListModel {
                        id: audioListModel
                        ListElement {
                            text: qsTr("Stereo")
                            val: StreamingPreferences.AC_STEREO
                        }
                        ListElement {
                            text: qsTr("5.1 surround sound")
                            val: StreamingPreferences.AC_51_SURROUND
                        }
                        ListElement {
                            text: qsTr("7.1 surround sound")
                            val: StreamingPreferences.AC_71_SURROUND
                        }
                    }
                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated : {
                        StreamingPreferences.audioConfig = audioListModel.get(currentIndex).val
                    }
                }
            }

            SettingsRow {
                title: qsTr("Mute host PC speakers while streaming")
                hint: qsTr("You must restart any game currently in progress for this setting to take effect")
                control: DeskSwitch {
                    id: audioPcCheck
                    checked: !StreamingPreferences.playAudioOnHost
                    onCheckedChanged: {
                        StreamingPreferences.playAudioOnHost = !checked
                    }
                }
            }

            SettingsRow {
                visible: SystemProperties.hasDesktopEnvironment
                title: qsTr("Mute audio stream when Moonlight is not the active window")
                hint: qsTr("Mutes Moonlight's audio when you Alt+Tab out of the stream or click on a different window.")
                control: DeskSwitch {
                    id: muteOnFocusLossCheck
                    checked: StreamingPreferences.muteOnFocusLoss
                    onCheckedChanged: {
                        StreamingPreferences.muteOnFocusLoss = checked
                    }
                }
            }
        }
    }
}
