import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

ItemDelegate {
    property string iconName
    property color dotColor: "transparent"
    property bool selected: false

    readonly property color foregroundColor: selected || hovered ? Theme.text : Theme.mutedStrong

    id: control

    implicitHeight: 40
    leftPadding: 10
    rightPadding: 10
    topPadding: 0
    bottomPadding: 0
    spacing: 10

    font.pixelSize: Theme.fontBase
    font.weight: Font.Medium

    opacity: enabled ? 1.0 : Theme.disabledOpacity

    contentItem: Item {
        implicitWidth: (icon.visible ? icon.width + control.spacing : 0) + label.implicitWidth +
                       (dot.visible ? dot.width + control.spacing : 0)
        implicitHeight: Math.max(icon.height, label.implicitHeight)

        DeskIcon {
            id: icon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: control.iconName !== ""
            name: control.iconName
            color: control.foregroundColor
        }

        Text {
            id: label
            anchors.left: icon.visible ? icon.right : parent.left
            anchors.leftMargin: icon.visible ? control.spacing : 0
            anchors.right: dot.visible ? dot.left : parent.right
            anchors.rightMargin: dot.visible ? control.spacing : 0
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            font: control.font
            color: control.foregroundColor
            elide: Text.ElideRight
        }

        Rectangle {
            id: dot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: control.dotColor.a > 0
            width: 7
            height: 7
            radius: 3.5
            color: control.dotColor
        }
    }

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 40
        radius: Theme.radiusControl
        color: control.selected ? Theme.selected : control.down ? Theme.selected : control.hovered ? Theme.raised : "transparent"

        DeskFocusRing {
            target: control
            gap: 0
        }
    }
}
