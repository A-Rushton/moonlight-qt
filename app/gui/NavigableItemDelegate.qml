import QtQuick 2.0
import QtQuick.Controls 2.14

import DeskTheme 1.0

ItemDelegate {
    property GridView grid

    id: control

    highlighted: grid.activeFocus && grid.currentItem === this

    background: Rectangle {
        radius: Theme.radiusPanel
        color: control.down ? Theme.selected : control.hovered ? Theme.raised : "transparent"

        // Grid navigation moves focus without a keyboard focus reason, so key off highlighted
        DeskFocusRing {
            target: control
            shown: control.highlighted
            gap: 0
        }
    }

    Keys.onLeftPressed: {
        grid.moveCurrentIndexLeft()
    }
    Keys.onRightPressed: {
        grid.moveCurrentIndexRight()
    }
    Keys.onDownPressed: {
        grid.moveCurrentIndexDown()
    }
    Keys.onUpPressed: {
        grid.moveCurrentIndexUp()

        // If we've reached the top of the grid, move focus to the toolbar
        if (grid.currentItem === this) {
            nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        }
    }
    Keys.onReturnPressed: {
        clicked()
    }
    Keys.onEnterPressed: {
        clicked()
    }
}
