import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

Dialog {
    property string titleText
    property int maximumWidth: 440
    // Lets Return/Enter activate footer buttons and Left/Right move between them
    property bool navigableButtons: false

    id: control

    modal: true
    anchors.centerIn: Overlay.overlay

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding,
                            implicitHeaderWidth,
                            implicitFooterWidth)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding
                             + (implicitHeaderHeight > 0 ? implicitHeaderHeight + spacing : 0)
                             + (implicitFooterHeight > 0 ? implicitFooterHeight + spacing : 0))
    width: Math.min(implicitWidth, maximumWidth, Overlay.overlay ? Overlay.overlay.width - 32 : maximumWidth)

    padding: 24
    topPadding: implicitHeaderHeight > 0 ? 0 : 24
    bottomPadding: implicitFooterHeight > 0 ? 0 : 24
    spacing: 18

    font.pixelSize: Theme.fontBase

    Overlay.modal: Rectangle {
        color: Qt.rgba(5 / 255, 6 / 255, 8 / 255, 0.66)
    }

    Overlay.modeless: Rectangle {
        color: Qt.rgba(5 / 255, 6 / 255, 8 / 255, 0.2)
    }

    background: Rectangle {
        radius: Theme.radiusDialog
        color: "#1A1B1F"
        border.width: 1
        border.color: Theme.borderStrong
    }

    header: Item {
        visible: control.titleText !== ""
        implicitWidth: titleLabel.implicitWidth
        implicitHeight: visible ? titleLabel.implicitHeight : 0

        Label {
            id: titleLabel
            width: parent.width
            text: control.titleText
            leftPadding: 24
            rightPadding: 24
            topPadding: 24
            font.pixelSize: 17
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Label.ElideRight
        }
    }

    footer: DialogButtonBox {
        id: buttonBox

        visible: count > 0
        implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: count > 0 ? Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                             implicitContentHeight + topPadding + bottomPadding) : 0
        alignment: Qt.AlignRight
        spacing: 8
        padding: 24
        topPadding: 0

        delegate: DeskButton {
            variant: DialogButtonBox.buttonRole === DialogButtonBox.AcceptRole ||
                     DialogButtonBox.buttonRole === DialogButtonBox.YesRole ? "primary" : "secondary"

            Keys.enabled: control.navigableButtons
            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
            Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
            Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        }

        contentItem: ListView {
            implicitWidth: contentWidth
            implicitHeight: 38
            model: buttonBox.contentModel
            spacing: buttonBox.spacing
            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapToItem
        }

        background: Item { }
    }
}
