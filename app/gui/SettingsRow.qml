import QtQuick 2.14

import DeskTheme 1.0

// One setting inside a DeskPanel: title and hint on the left, control on the right
// (or below at full width when stacked). Rows after the first visible one get a divider.
Item {
    id: row

    property string title
    property string hint
    property Item control: null
    property bool stacked: false

    readonly property bool firstVisible: {
        var siblings = parent ? parent.children : []
        for (var i = 0; i < siblings.length; i++) {
            if (siblings[i] === row) {
                return true
            }
            if (siblings[i].visible) {
                return false
            }
        }
        return true
    }

    readonly property int horizontalPadding: 18
    readonly property int verticalPadding: 14

    width: parent ? parent.width : implicitWidth
    implicitHeight: stacked ? slot.y + slot.height + verticalPadding
                            : Math.max(textColumn.height, slot.height) + 2 * verticalPadding

    function attachControl() {
        if (!control) {
            return
        }
        control.parent = slot
        control.anchors.fill = slot
        if (control.maximumWidth !== undefined) {
            control.maximumWidth = Qt.binding(function() {
                // Combos can take up to 60% of the row, leaving the rest for the title and hint
                return Math.max(160, Math.floor(row.width * 0.6))
            })
        }
    }

    onControlChanged: attachControl()
    Component.onCompleted: attachControl()

    Rectangle {
        visible: !row.firstVisible
        width: parent.width
        height: 1
        color: Theme.border
    }

    Column {
        id: textColumn
        x: row.horizontalPadding
        y: row.stacked ? row.verticalPadding : (row.height - height) / 2
        width: row.stacked || slot.width === 0
               ? row.width - 2 * row.horizontalPadding
               : row.width - 2 * row.horizontalPadding - slot.width - 16
        spacing: 3
        visible: row.title !== "" || row.hint !== ""
        opacity: row.control && !row.control.enabled ? Theme.disabledOpacity : 1.0

        Text {
            width: parent.width
            visible: text !== ""
            text: row.title
            font.pixelSize: Theme.fontBase
            font.weight: Font.Medium
            color: Theme.text
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: row.hint
            font.pixelSize: Theme.fontSmall
            color: Theme.muted
            wrapMode: Text.Wrap
            lineHeight: 1.1
        }
    }

    Item {
        id: slot
        x: row.stacked ? row.horizontalPadding : row.width - row.horizontalPadding - width
        y: row.stacked ? (textColumn.visible ? textColumn.y + textColumn.height + 12 : row.verticalPadding)
                       : (row.height - height) / 2
        width: !row.control ? 0 : row.stacked ? row.width - 2 * row.horizontalPadding : row.control.implicitWidth
        height: row.control ? row.control.implicitHeight : 0
    }
}
