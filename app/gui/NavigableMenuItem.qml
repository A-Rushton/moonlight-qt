import QtQuick 2.14
import QtQuick.Controls 2.14

DeskMenuItem {
    // True while triggered() runs for Return/Enter, so handlers can tell keyboard use from a click
    property bool triggeredByKeyboard: false

    // Ensure focus can't be given to an invisible item
    enabled: visible
    height: visible ? implicitHeight : 0
    focusPolicy: visible ? Qt.TabFocus : Qt.NoFocus

    onTriggered: {
        // We must close the context menu first or
        // it can steal focus from any dialogs that
        // onTriggered may spawn.
        menu.close()
    }

    function triggerFromKeyboard() {
        triggeredByKeyboard = true
        triggered()
        triggeredByKeyboard = false
    }

    Keys.onReturnPressed: triggerFromKeyboard()
    Keys.onEnterPressed: triggerFromKeyboard()

    Keys.onEscapePressed: {
        menu.close()
    }
}
