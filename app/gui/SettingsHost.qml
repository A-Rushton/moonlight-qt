import QtQuick 2.14
import QtQuick.Controls 2.14

import StreamingPreferences 1.0

Column {
    id: section

    spacing: 20

    DeskPanel {
        width: parent.width
        height: hostColumn.height

        Column {
            id: hostColumn
            width: parent.width

            SettingsRow {
                title: qsTr("Optimize game settings for streaming")
                control: DeskSwitch {
                    id: optimizeGameSettingsCheck
                    checked: StreamingPreferences.gameOptimizations
                    onCheckedChanged: {
                        StreamingPreferences.gameOptimizations = checked
                    }
                }
            }

            SettingsRow {
                title: qsTr("Quit app on host PC after ending stream")
                hint: qsTr("This will close the app or game you are streaming when you end your stream. You will lose any unsaved progress!")
                control: DeskSwitch {
                    id: quitAppAfter
                    checked: StreamingPreferences.quitAppAfter
                    onCheckedChanged: {
                        StreamingPreferences.quitAppAfter = checked
                    }
                }
            }
        }
    }
}
