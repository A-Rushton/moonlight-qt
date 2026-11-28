import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

Switch {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding,
                             implicitIndicatorHeight + topPadding + bottomPadding)
    padding: 0
    spacing: 16
    rightPadding: mirrored ? 0 : indicator.width + (text !== "" ? spacing : 0)
    leftPadding: mirrored ? indicator.width + (text !== "" ? spacing : 0) : 0

    font.pixelSize: Theme.fontBase

    opacity: enabled ? 1.0 : 0.45

    indicator: Rectangle {
        implicitWidth: 40
        implicitHeight: 24
        x: control.mirrored ? 0 : control.width - width
        y: (control.height - height) / 2
        radius: height / 2
        color: control.checked ? Theme.accent : "#3A3C42"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            x: 3 + control.visualPosition * (parent.width - width - 6)
            y: 3
            width: 18
            height: 18
            radius: 9
            color: "#FFFFFF"

            Behavior on x {
                enabled: !control.down
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        DeskFocusRing {
            target: control
            targetRadius: parent.radius
        }
    }

    contentItem: Text {
        text: control.text
        font: control.font
        color: Theme.text
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignLeft
    }
}
