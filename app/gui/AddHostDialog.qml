import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0
import ComputerManager 1.0

NavigableDialog {
    id: dialog

    readonly property string address: addressField.text.trim()

    titleText: qsTr("Add host")
    implicitWidth: maximumWidth
    standardButtons: Dialog.Ok | Dialog.Cancel
    navigableButtons: true

    onAboutToShow: {
        var addButton = standardButton(Dialog.Ok)
        if (addButton) {
            addButton.text = qsTr("Add host")
            addButton.enabled = Qt.binding(function() { return dialog.address !== "" })
        }
    }

    onOpened: addressField.forceActiveFocus(Qt.TabFocusReason)
    onClosed: addressField.clear()

    onAccepted: {
        if (address !== "") {
            ComputerManager.addNewHostManually(address)
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 18

        Text {
            Layout.fillWidth: true
            text: qsTr("Enter the IP address or hostname of the computer running Sunshine.")
            font.pixelSize: Theme.fontBase
            lineHeight: 1.3
            color: Theme.mutedStrong
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: qsTr("Address")
                font.pixelSize: Theme.fontSmall
                font.weight: Font.Medium
                color: Theme.text
            }

            DeskTextField {
                id: addressField
                Layout.fillWidth: true
                focus: true
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly

                Keys.onReturnPressed: {
                    if (dialog.address !== "") {
                        dialog.closedByKeyboard = true
                        dialog.accept()
                    }
                }
                Keys.onEnterPressed: {
                    if (dialog.address !== "") {
                        dialog.closedByKeyboard = true
                        dialog.accept()
                    }
                }
                Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Add :port if Sunshine uses a custom port.")
                font.pixelSize: 12
                color: Theme.muted
                wrapMode: Text.Wrap
            }
        }
    }
}
