import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14

import DeskTheme 1.0

ComboBox {
    id: control

    readonly property int indicatorSpace: indicator.width + 20

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: 40
    topPadding: 0
    bottomPadding: 0
    leftPadding: mirrored ? indicatorSpace : 12
    rightPadding: mirrored ? 12 : indicatorSpace

    font.pixelSize: Theme.fontBase

    opacity: enabled ? 1.0 : 0.45

    delegate: ItemDelegate {
        width: ListView.view ? ListView.view.width : implicitWidth
        implicitHeight: 36
        leftPadding: 12
        rightPadding: 12
        text: control.textRole ? (Array.isArray(control.model) ? modelData[control.textRole] : model[control.textRole])
                               : modelData
        font: control.font
        highlighted: control.highlightedIndex === index
        hoverEnabled: control.hoverEnabled

        contentItem: Text {
            text: parent.text
            font: parent.font
            color: control.currentIndex === index ? Theme.accent : Theme.text
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: Theme.radiusControl - 2
            color: parent.highlighted ? Theme.selected : "transparent"
        }
    }

    indicator: DeskIcon {
        x: control.mirrored ? 12 : control.width - width - 12
        y: (control.height - height) / 2
        name: "chevron-down"
        color: Theme.muted
        size: 16
    }

    contentItem: Text {
        text: control.displayText
        font: control.font
        color: Theme.text
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        implicitWidth: 140
        implicitHeight: 40
        radius: Theme.radiusControl
        color: control.pressed || control.popup.visible ? Theme.selected : Theme.raised
        border.width: 1
        border.color: Theme.borderStrong

        DeskFocusRing {
            target: control
        }
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                         control.Window.height - topMargin - bottomMargin)
        topMargin: 8
        bottomMargin: 8
        padding: 4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            highlightMoveDuration: 0

            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            radius: Theme.radiusControl
            color: Theme.raised
            border.width: 1
            border.color: Theme.borderStrong
        }
    }
}
