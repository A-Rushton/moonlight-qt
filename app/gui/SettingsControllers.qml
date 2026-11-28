import QtQuick 2.14
import QtQuick.Controls 2.14

import StreamingPreferences 1.0
import SystemProperties 1.0

Column {
    id: section

    spacing: 20

    DeskPanel {
        width: parent.width
        height: gamepadColumn.height

        Column {
            id: gamepadColumn
            width: parent.width

            SettingsRow {
                title: qsTr("Swap A/B and X/Y gamepad buttons")
                hint: qsTr("This switches gamepads into a Nintendo-style button layout")
                control: DeskSwitch {
                    id: swapFaceButtonsCheck
                    checked: StreamingPreferences.swapFaceButtons
                    onCheckedChanged: {
                        StreamingPreferences.swapFaceButtons = checked
                    }
                }
            }

            SettingsRow {
                title: qsTr("Force gamepad #1 always connected")
                hint: qsTr("Forces a single gamepad to always stay connected to the host, even if no gamepads are actually connected to this PC.") + " " +
                      qsTr("Only enable this option when streaming a game that doesn't support gamepads being connected after startup.")
                control: DeskSwitch {
                    id: singleControllerCheck
                    checked: !StreamingPreferences.multiController
                    onCheckedChanged: {
                        StreamingPreferences.multiController = !checked
                    }
                }
            }

            SettingsRow {
                title: qsTr("Enable mouse control with gamepads by holding the 'Start' button")
                control: DeskSwitch {
                    id: gamepadMouseCheck
                    checked: StreamingPreferences.gamepadMouse
                    onCheckedChanged: {
                        StreamingPreferences.gamepadMouse = checked
                    }
                }
            }

            SettingsRow {
                visible: SystemProperties.hasDesktopEnvironment
                title: qsTr("Process gamepad input when Moonlight is in the background")
                hint: qsTr("Allows Moonlight to capture gamepad inputs even if it's not the current window in focus")
                control: DeskSwitch {
                    id: backgroundGamepadCheck
                    checked: StreamingPreferences.backgroundGamepad
                    onCheckedChanged: {
                        StreamingPreferences.backgroundGamepad = checked
                    }
                }
            }
        }
    }
}
