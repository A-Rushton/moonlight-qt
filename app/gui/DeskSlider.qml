import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

Slider {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitHandleWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitHandleHeight + topPadding + bottomPadding)
    padding: 4

    opacity: enabled ? 1.0 : 0.45

    handle: Rectangle {
        x: control.leftPadding + (control.horizontal ? control.visualPosition * (control.availableWidth - width)
                                                     : (control.availableWidth - width) / 2)
        y: control.topPadding + (control.horizontal ? (control.availableHeight - height) / 2
                                                    : control.visualPosition * (control.availableHeight - height))
        implicitWidth: 16
        implicitHeight: 16
        radius: 8
        color: control.pressed ? Theme.text : "#FFFFFF"

        DeskFocusRing {
            target: control
            targetRadius: parent.radius
        }
    }

    background: Item {
        x: control.leftPadding
        y: control.topPadding
        implicitWidth: control.horizontal ? 200 : 16
        implicitHeight: control.horizontal ? 16 : 200
        width: control.availableWidth
        height: control.availableHeight

        Rectangle {
            id: track
            x: control.horizontal ? 0 : (parent.width - width) / 2
            y: control.horizontal ? (parent.height - height) / 2 : 0
            width: control.horizontal ? parent.width : 4
            height: control.horizontal ? 4 : parent.height
            radius: 2
            color: Theme.borderStrong

            Rectangle {
                x: control.horizontal && control.mirrored ? parent.width - width : 0
                y: control.horizontal ? 0 : control.visualPosition * parent.height
                width: control.horizontal ? control.position * parent.width : parent.width
                height: control.horizontal ? parent.height : (1 - control.visualPosition) * parent.height
                radius: 2
                color: Theme.accent
            }
        }
    }
}
