import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0

NavigableDialog {
    id: dialog

    property alias text: dialogLabel.dialogText
    property bool showSpinner: false
    property string iconName: (standardButtons & Dialog.Yes) ? "help" : "alert"
    property color iconColor: iconName === "alert" ? Theme.danger
                            : iconName === "check" ? Theme.accent
                            : Theme.mutedStrong

    property string helpText
    property string helpUrl : "https://github.com/moonlight-stream/moonlight-docs/wiki/Troubleshooting"
    property string helpTextSeparator : " "

    readonly property int iconSize: 24

    navigableButtons: true

    onOpened: {
        // Force keyboard focus on the label so keyboard navigation works
        if (footer.count > 0) {
            var button = footer.itemAt(footer.count - 1)
            if (button.activeFocus) {
                // The popup may have focused it already, without a visible reason
                button.focusReason = Qt.TabFocusReason
            }
            else {
                button.forceActiveFocus(Qt.TabFocusReason)
            }
        }
    }

    onHelpRequested: {
        Qt.openUrlExternally(helpUrl)
        close()
    }

    RowLayout {
        spacing: 14

        DeskIcon {
            visible: !dialog.showSpinner
            name: dialog.iconName
            color: dialog.iconColor
            size: dialog.iconSize
            Layout.preferredWidth: dialog.iconSize
            Layout.preferredHeight: dialog.iconSize
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            spacing: 16
            Layout.alignment: Qt.AlignTop

            Label {
                property string dialogText

                id: dialogLabel
                text: dialogText + ((helpText && (standardButtons & Dialog.Help)) ? (helpTextSeparator + helpText) : "")
                wrapMode: Text.Wrap
                elide: Label.ElideRight
                font.pixelSize: Theme.fontBase
                lineHeight: 1.3
                color: Theme.text

                // Cap the width so the dialog doesn't grow horizontally forever. This
                // will cause word wrap to kick in.
                Layout.maximumWidth: dialog.maximumWidth - dialog.leftPadding - dialog.rightPadding -
                                     (dialog.showSpinner ? 0 : dialog.iconSize + 14)
                Layout.maximumHeight: 400
            }

            DeskProgressBar {
                visible: dialog.showSpinner
                Layout.fillWidth: true
            }
        }
    }
}
