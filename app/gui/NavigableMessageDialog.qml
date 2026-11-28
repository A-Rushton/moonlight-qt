import QtQuick 2.0
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.2

import DeskTheme 1.0

NavigableDialog {
    id: dialog

    property alias text: dialogLabel.dialogText
    property alias showSpinner: dialogSpinner.visible
    property alias imageSrc: dialogImage.source

    property string helpText
    property string helpUrl : "https://github.com/moonlight-stream/moonlight-docs/wiki/Troubleshooting"
    property string helpTextSeparator : " "

    readonly property int iconSize: 32

    navigableButtons: true

    onOpened: {
        // Force keyboard focus on the label so keyboard navigation works
        if (footer.count > 0) {
            footer.itemAt(footer.count - 1).forceActiveFocus(Qt.TabFocus)
        }
    }

    onHelpRequested: {
        Qt.openUrlExternally(helpUrl)
        close()
    }

    RowLayout {
        spacing: 14

        BusyIndicator {
            id: dialogSpinner
            visible: false
            running: visible
            Layout.preferredWidth: dialog.iconSize
            Layout.preferredHeight: dialog.iconSize
            Layout.alignment: Qt.AlignTop
        }

        Image {
            id: dialogImage
            source: (standardButtons & Dialog.Yes) ?
                        "qrc:/res/baseline-help_outline-24px.svg" :
                        "qrc:/res/baseline-error_outline-24px.svg"
            sourceSize {
                // The icon should be square so use the height as the width too
                width: dialog.iconSize
                height: dialog.iconSize
            }
            visible: !showSpinner
            Layout.alignment: Qt.AlignTop
        }

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
                                 dialog.iconSize - parent.spacing
            Layout.maximumHeight: 400
        }
    }
}
