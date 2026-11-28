import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

MenuItem {
    id: control

    readonly property real trailingSpace: (checkable ? indicator.width + spacing : 0) +
                                          (subMenu ? arrow.width + spacing : 0)

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: 36
    topPadding: 0
    bottomPadding: 0
    leftPadding: mirrored ? 12 + trailingSpace : 12
    rightPadding: mirrored ? 12 : 12 + trailingSpace
    spacing: 8

    font.pixelSize: Theme.fontBase

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? Theme.text : Theme.muted
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    indicator: DeskIcon {
        readonly property real arrowSpace: control.subMenu ? control.arrow.width + control.spacing : 0
        x: control.mirrored ? 12 + arrowSpace : control.width - width - 12 - arrowSpace
        y: (control.height - height) / 2
        visible: control.checkable && control.checked
        name: "check"
        color: Theme.accent
        size: 16
    }

    arrow: DeskIcon {
        x: control.mirrored ? 12 : control.width - width - 12
        y: (control.height - height) / 2
        visible: control.subMenu !== null
        mirror: control.mirrored
        name: "chevron-right"
        color: Theme.muted
        size: 16
    }

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 36
        radius: Theme.radiusControl - 2
        color: control.down ? Theme.borderStrong : control.highlighted ? Theme.selected : "transparent"

        DeskFocusRing {
            target: control
            gap: 0
        }
    }
}
