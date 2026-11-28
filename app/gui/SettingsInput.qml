import QtQuick 2.14
import QtQuick.Controls 2.14

import StreamingPreferences 1.0
import SystemProperties 1.0

Column {
    id: section

    spacing: 20

    DeskPanel {
        width: parent.width
        height: inputColumn.height

        Column {
            id: inputColumn
            width: parent.width

            SettingsRow {
                title: qsTr("Optimize mouse for remote desktop instead of games")
                hint: qsTr("This enables seamless mouse control without capturing the client's mouse cursor. It is ideal for remote desktop usage but will not work in most games.") + " " +
                      qsTr("You can toggle this while streaming using Ctrl+Alt+Shift+M.") + "\n\n" +
                      qsTr("NOTE: Due to a bug in GeForce Experience, this option may not work properly if your host PC has multiple monitors.")
                control: DeskSwitch {
                    id: absoluteMouseCheck
                    checked: StreamingPreferences.absoluteMouseMode
                    onCheckedChanged: {
                        StreamingPreferences.absoluteMouseMode = checked
                    }
                }
            }

            SettingsRow {
                title: qsTr("Capture system keyboard shortcuts")
                hint: qsTr("This enables the capture of system-wide keyboard shortcuts like Alt+Tab that would normally be handled by the client OS while streaming.") + "\n\n" +
                      qsTr("NOTE: Certain keyboard shortcuts like Ctrl+Alt+Del on Windows cannot be intercepted by any application, including Moonlight.")
                control: Row {
                    spacing: 16
                    enabled: SystemProperties.hasDesktopEnvironment

                    AutoResizingComboBox {
                        // ignore setting the index at first, and actually set it when the component is loaded
                        Component.onCompleted: {
                            var saved_syskeysmode = StreamingPreferences.captureSysKeysMode
                            currentIndex = 0
                            for (var i = 0; i < captureSysKeysModeListModel.count; i++) {
                                var el_syskeysmode = captureSysKeysModeListModel.get(i).val;
                                if (saved_syskeysmode === el_syskeysmode) {
                                    currentIndex = i
                                    break
                                }
                            }

                            activated(currentIndex)
                        }

                        id: captureSysKeysModeComboBox
                        anchors.verticalCenter: parent.verticalCenter
                        maximumWidth: 240
                        enabled: captureSysKeysCheck.checked && captureSysKeysCheck.enabled
                        textRole: "text"
                        model: ListModel {
                            id: captureSysKeysModeListModel
                            ListElement {
                                text: qsTr("in fullscreen")
                                val: StreamingPreferences.CSK_FULLSCREEN
                            }
                            ListElement {
                                text: qsTr("always")
                                val: StreamingPreferences.CSK_ALWAYS
                            }
                        }

                        function updatePref() {
                            if (!enabled) {
                                StreamingPreferences.captureSysKeysMode = StreamingPreferences.CSK_OFF
                            }
                            else {
                                StreamingPreferences.captureSysKeysMode = captureSysKeysModeListModel.get(currentIndex).val
                            }
                        }

                        // ::onActivated must be used, as it only listens for when the index is changed by a human
                        onActivated: {
                            updatePref()
                        }

                        // This handles transition of the switch state
                        onEnabledChanged: {
                            updatePref()
                        }
                    }

                    DeskSwitch {
                        id: captureSysKeysCheck
                        anchors.verticalCenter: parent.verticalCenter
                        checked: StreamingPreferences.captureSysKeysMode !== StreamingPreferences.CSK_OFF || !SystemProperties.hasDesktopEnvironment
                    }
                }
            }

            SettingsRow {
                title: qsTr("Use touchscreen as a virtual trackpad")
                hint: qsTr("When checked, the touchscreen acts like a trackpad. When unchecked, the touchscreen will directly control the mouse pointer.")
                control: DeskSwitch {
                    id: absoluteTouchCheck
                    checked: !StreamingPreferences.absoluteTouchMode
                    onCheckedChanged: {
                        StreamingPreferences.absoluteTouchMode = !checked
                    }
                }
            }

            SettingsRow {
                title: qsTr("Swap left and right mouse buttons")
                control: DeskSwitch {
                    id: swapMouseButtonsCheck
                    checked: StreamingPreferences.swapMouseButtons
                    onCheckedChanged: {
                        StreamingPreferences.swapMouseButtons = checked
                    }
                }
            }

            SettingsRow {
                title: qsTr("Reverse mouse scrolling direction")
                control: DeskSwitch {
                    id: reverseScrollButtonsCheck
                    checked: StreamingPreferences.reverseScrollDirection
                    onCheckedChanged: {
                        StreamingPreferences.reverseScrollDirection = checked
                    }
                }
            }
        }
    }
}
