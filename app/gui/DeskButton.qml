import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

Button {
    property string variant: "secondary"
    property string iconName

    readonly property color foregroundColor: variant === "primary" ? Theme.accentText
                                           : variant === "danger" ? Theme.danger
                                           : variant === "ghost" && !hovered ? Theme.mutedStrong
                                           : Theme.text

    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: 38
    leftPadding: variant === "primary" ? 18 : 16
    rightPadding: leftPadding
    topPadding: 0
    bottomPadding: 0

    font.pixelSize: Theme.fontBase
    font.weight: variant === "primary" ? Font.DemiBold : Font.Medium

    opacity: enabled ? 1.0 : Theme.disabledOpacity

    contentItem: Item {
        implicitWidth: contentRow.width
        implicitHeight: contentRow.height

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8

            DeskIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.iconName !== ""
                name: control.iconName
                color: control.foregroundColor
                size: 16
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: control.text
                font: control.font
                color: control.foregroundColor
            }
        }
    }

    background: Rectangle {
        implicitWidth: 64
        implicitHeight: 38
        radius: Theme.radiusControl
        color: {
            if (control.variant === "primary") {
                return control.down ? Qt.darker(Theme.accent, 1.12)
                                    : control.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
            }
            if (control.variant === "ghost") {
                return control.down ? Theme.selected : control.hovered ? Theme.raised : "transparent"
            }
            return control.down ? Theme.borderStrong : control.hovered ? Theme.selected : Theme.raised
        }
        border.width: control.variant === "secondary" || control.variant === "danger" ? 1 : 0
        border.color: Theme.borderStrong

        DeskFocusRing {
            target: control
        }
    }
}
