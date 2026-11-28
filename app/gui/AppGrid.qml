import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14

import DeskTheme 1.0

Item {
    id: grid

    property var model: null
    // Model row shown elsewhere (the Desktop panel), or -1
    property int skipIndex: -1
    // Colour behind the grid, used to round the poster corners
    property color backdrop: Theme.bg

    readonly property int minCardWidth: 140
    readonly property int columnSpacing: 16
    readonly property int columns: Math.max(1, Math.floor((width + columnSpacing) / (minCardWidth + columnSpacing)))
    readonly property real cardWidth: Math.floor((width - columnSpacing * (columns - 1)) / columns)
    readonly property int visualCount: repeater.count - (skipIndex >= 0 && skipIndex < repeater.count ? 1 : 0)

    signal launchRequested(int index)
    signal menuRequested(int index, Item anchor, bool viaKeyboard)
    signal quitRequested()
    // Up was pressed on the first row, or Left on the first column
    signal exitUp()
    signal exitLeft()

    implicitHeight: positioner.implicitHeight

    function visualIndex(index) {
        return skipIndex >= 0 && index > skipIndex ? index - 1 : index
    }

    function modelIndex(visual) {
        return skipIndex >= 0 && visual >= skipIndex ? visual + 1 : visual
    }

    function focusVisual(visual, reason) {
        var item = repeater.itemAt(modelIndex(visual))
        if (item) {
            item.forceActiveFocus(reason)
            return true
        }
        return false
    }

    function focusFirst(reason) {
        return focusVisual(0, reason)
    }

    Grid {
        id: positioner
        width: parent.width
        columns: grid.columns
        columnSpacing: grid.columnSpacing
        rowSpacing: 20

        Repeater {
            id: repeater
            model: grid.model

            delegate: AbstractButton {
                id: card

                readonly property int visual: grid.visualIndex(index)

                width: grid.cardWidth
                implicitHeight: poster.height + 8 + nameText.implicitHeight
                visible: index !== grid.skipIndex
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                padding: 0
                background: null
                contentItem: null

                ToolTip.text: model.name
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: (hovered || visualFocus) && nameText.truncated

                onClicked: grid.launchRequested(index)
                onPressAndHold: grid.menuRequested(index, card, false)

                Keys.onMenuPressed: grid.menuRequested(index, card, true)
                Keys.onLeftPressed: {
                    if (visual % grid.columns > 0) {
                        grid.focusVisual(visual - 1, Qt.BacktabFocusReason)
                    }
                    else {
                        grid.exitLeft()
                    }
                }
                function focusNextCard() {
                    if (visual % grid.columns < grid.columns - 1 && visual + 1 < grid.visualCount) {
                        grid.focusVisual(visual + 1, Qt.TabFocusReason)
                    }
                }

                Keys.onRightPressed: {
                    if (model.running) {
                        quitButton.forceActiveFocus(Qt.TabFocusReason)
                    }
                    else {
                        focusNextCard()
                    }
                }
                Keys.onUpPressed: {
                    if (visual >= grid.columns) {
                        grid.focusVisual(visual - grid.columns, Qt.BacktabFocusReason)
                    }
                    else {
                        grid.exitUp()
                    }
                }
                Keys.onDownPressed: {
                    var lastRow = Math.floor((grid.visualCount - 1) / grid.columns)
                    if (Math.floor(visual / grid.columns) < lastRow) {
                        grid.focusVisual(Math.min(visual + grid.columns, grid.visualCount - 1), Qt.TabFocusReason)
                    }
                }

                Rectangle {
                    id: poster
                    width: parent.width
                    height: Math.round(width * 1.5)
                    radius: Theme.radiusControl
                    color: Theme.raised

                    Image {
                        anchors.fill: parent
                        // Dimmed here rather than on the card, so the corner masking stays opaque
                        opacity: model.hidden ? 0.4 : 1.0
                        source: model.boxart ? model.boxart : "qrc:/res/no_app_image.png"
                        sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    // Rounds the image corners by painting the backdrop over them
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: parent.radius + 4
                        color: "transparent"
                        border.width: 4
                        border.color: grid.backdrop
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: card.down ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
                        border.width: 1
                        border.color: card.hovered ? Theme.offline : Theme.borderStrong
                    }

                    RunningBadge {
                        x: 8
                        y: 8
                        visible: model.running
                    }

                    DeskFocusRing {
                        target: card
                        targetRadius: Theme.radiusControl
                    }
                }

                Text {
                    id: nameText
                    anchors.top: poster.bottom
                    anchors.topMargin: 8
                    width: parent.width
                    text: model.name
                    opacity: model.hidden ? 0.4 : 1.0
                    font.pixelSize: Theme.fontBase
                    font.weight: Font.Medium
                    color: Theme.text
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: grid.menuRequested(index, card, false)
                }

                DeskIconButton {
                    id: quitButton
                    x: poster.width - width - 8
                    y: 8
                    visible: model.running
                    implicitWidth: 32
                    implicitHeight: 32
                    // Reached with Right from the card, so Tab and Up/Down keep stepping card to card
                    activeFocusOnTab: false
                    iconName: "stop"
                    toolTipText: qsTr("Quit")
                    onClicked: grid.quitRequested()
                    Keys.onLeftPressed: card.forceActiveFocus(Qt.BacktabFocusReason)
                    Keys.onRightPressed: card.focusNextCard()
                }
            }
        }
    }
}
