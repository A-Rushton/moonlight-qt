import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

// Placeholder until a gamepad mapper exists; the sidebar entry that opens it is hidden
FocusScope {
    id: page
    objectName: qsTr("Gamepad Mapping")

    StackView.onActivated: backButton.forceActiveFocus(Qt.TabFocusReason)

    function restoreFocus(reason) {
        backButton.forceActiveFocus(reason)
    }

    Column {
        x: 32
        y: 24
        width: parent.width - 64
        spacing: 24

        DeskButton {
            id: backButton
            focus: true
            variant: "ghost"
            iconName: "chevron-left"
            text: qsTr("Back to library")
            leftPadding: 10
            onClicked: window.goBack()

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
        }

        Text {
            width: parent.width
            text: page.objectName
            font.pixelSize: Theme.fontTitle
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideRight
        }
    }
}
