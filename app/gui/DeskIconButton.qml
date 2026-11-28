import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

Button {
    property string iconName
    property string toolTipText

    id: control

    implicitWidth: 36
    implicitHeight: 36
    padding: 0

    opacity: enabled ? 1.0 : Theme.disabledOpacity

    ToolTip.text: toolTipText
    ToolTip.delay: 1000
    ToolTip.timeout: 3000
    ToolTip.visible: toolTipText !== "" && hovered

    contentItem: Item {
        DeskIcon {
            anchors.centerIn: parent
            name: control.iconName
            color: control.highlighted ? Theme.accent
                 : control.hovered || control.visualFocus ? Theme.text : Theme.mutedStrong
        }
    }

    background: Rectangle {
        implicitWidth: 36
        implicitHeight: 36
        radius: Theme.radiusControl
        color: control.down ? Theme.borderStrong : control.hovered || control.highlighted ? Theme.selected : Theme.raised
        border.width: 1
        border.color: Theme.borderStrong

        DeskFocusRing {
            target: control
        }
    }
}
