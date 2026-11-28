import QtQuick 2.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.3

import DeskTheme 1.0

ToolButton {
    property string iconSource

    id: control

    activeFocusOnTab: true

    icon.source: iconSource
    // Size the icon from the button's height, never its width, so the
    // button's implicit width can't feed back into itself.
    icon.width: height / 2
    icon.height: height / 2
    icon.color: hovered || visualFocus ? Theme.text : Theme.mutedStrong

    // Fill the toolbar height for large, TV-readable icons, with a square background.
    Layout.preferredHeight: parent.height
    topInset: Math.max(0, (height - width) / 2)
    bottomInset: topInset

    background: Rectangle {
        implicitWidth: 40
        implicitHeight: 40
        radius: Theme.radiusControl
        color: control.down ? Theme.selected : control.hovered ? Theme.raised : "transparent"

        DeskFocusRing {
            target: control
        }
    }

    Keys.onReturnPressed: {
        clicked()
    }

    Keys.onEnterPressed: {
        clicked()
    }

    Keys.onRightPressed: {
        nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
    }

    Keys.onLeftPressed: {
        nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
    }
}
