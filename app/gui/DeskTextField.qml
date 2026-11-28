import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

TextField {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: 40
    leftPadding: 12
    rightPadding: 12
    topPadding: 0
    bottomPadding: 0
    verticalAlignment: TextInput.AlignVCenter

    font.pixelSize: Theme.fontBase
    color: Theme.text
    placeholderTextColor: Theme.muted
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentText

    opacity: enabled ? 1.0 : 0.45

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 40
        radius: Theme.radiusControl
        color: Theme.bg
        border.width: 1
        border.color: control.activeFocus ? Theme.accent : Theme.borderStrong

        DeskFocusRing {
            shown: control.activeFocus
            targetRadius: parent.radius
            border.color: Qt.rgba(74 / 255, 222 / 255, 128 / 255, 0.18)
            border.width: 3
        }
    }
}
