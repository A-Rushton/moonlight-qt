import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

ItemDelegate {
    property string title
    property string subtitle
    property Item trailing: null
    property url thumbnail

    id: control

    implicitHeight: 56
    leftPadding: 16
    rightPadding: 16
    topPadding: 0
    bottomPadding: 0
    spacing: 14

    font.pixelSize: Theme.fontBase

    opacity: enabled ? 1.0 : Theme.disabledOpacity

    function attachTrailing() {
        if (trailing) {
            trailing.parent = trailingSlot
            trailing.anchors.verticalCenter = trailingSlot.verticalCenter
        }
    }

    onTrailingChanged: attachTrailing()
    Component.onCompleted: attachTrailing()

    contentItem: Item {
        implicitWidth: (thumbnailFrame.visible ? thumbnailFrame.width + control.spacing : 0) +
                       Math.max(titleText.implicitWidth, subtitleText.implicitWidth) +
                       (trailingSlot.width > 0 ? trailingSlot.width + control.spacing : 0)
        implicitHeight: 40

        Rectangle {
            id: thumbnailFrame
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: control.thumbnail.toString() !== ""
            width: 30
            height: 40
            radius: 4
            color: Theme.selected

            Image {
                anchors.fill: parent
                source: control.thumbnail
                sourceSize.width: 60
                sourceSize.height: 80
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // Rounds the image corners by painting the row background over them
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 3
                border.color: control.background.color
            }
        }

        Column {
            anchors.left: thumbnailFrame.visible ? thumbnailFrame.right : parent.left
            anchors.leftMargin: thumbnailFrame.visible ? control.spacing : 0
            anchors.right: trailingSlot.left
            anchors.rightMargin: trailingSlot.width > 0 ? control.spacing : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                id: titleText
                width: parent.width
                text: control.title !== "" ? control.title : control.text
                font.pixelSize: Theme.fontBase
                font.weight: Font.Medium
                color: Theme.text
                elide: Text.ElideRight
            }

            Text {
                id: subtitleText
                width: parent.width
                visible: text !== ""
                text: control.subtitle
                font.pixelSize: Theme.fontSmall
                color: Theme.muted
                elide: Text.ElideRight
            }
        }

        Item {
            id: trailingSlot
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: control.trailing && control.trailing.visible ? control.trailing.width : 0
        }
    }

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 56
        color: control.down ? Theme.selected : control.highlighted || control.hovered ? Theme.raised : Theme.panel

        DeskFocusRing {
            target: control
            targetRadius: 0
            gap: 0
        }
    }
}
