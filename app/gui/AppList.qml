import QtQuick 2.14
import QtQuick.Controls 2.14

import DeskTheme 1.0

Item {
    id: list

    property var model: null
    // Model row shown elsewhere (the Desktop panel), or -1
    property int skipIndex: -1
    // Colour behind the list, used to round the frame's corners
    property color backdrop: Theme.bg

    readonly property int firstIndex: skipIndex === 0 ? 1 : 0

    signal launchRequested(int index)
    signal menuRequested(int index, Item anchor, bool viaKeyboard)

    implicitHeight: column.implicitHeight + 2

    function focusFirst(reason) {
        var item = repeater.itemAt(firstIndex)
        if (item) {
            item.forceActiveFocus(reason)
            return true
        }
        return false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
        color: Theme.panel
    }

    Column {
        id: column
        x: 1
        y: 1
        width: parent.width - 2

        Repeater {
            id: repeater
            model: list.model

            delegate: DeskListRow {
                id: row
                width: column.width
                visible: index !== list.skipIndex
                opacity: model.hidden ? 0.4 : 1.0
                title: model.name
                subtitle: {
                    var parts = []
                    if (model.running) {
                        parts.push(qsTr("Running"))
                    }
                    if (model.hidden) {
                        parts.push(qsTr("Hidden"))
                    }
                    return parts.join(" · ")
                }
                thumbnail: model.boxart ? model.boxart : "qrc:/res/no_app_image.png"
                trailing: DeskIcon {
                    name: "chevron-right"
                    color: Theme.muted
                    size: 16
                }

                onClicked: list.launchRequested(index)
                onPressAndHold: list.menuRequested(index, row, false)
                Keys.onMenuPressed: list.menuRequested(index, row, true)

                Rectangle {
                    visible: index > list.firstIndex
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: Theme.border
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: list.menuRequested(index, row, false)
                }
            }
        }
    }

    // Paints the backdrop over the square row corners, then the frame border
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: Theme.radiusPanel + 6
        color: "transparent"
        border.width: 6
        border.color: list.backdrop
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
        color: "transparent"
        border.width: 1
        border.color: Theme.border
    }
}
