import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14

import DeskTheme 1.0
import SystemProperties 1.0

FocusScope {
    id: sidebar

    property var computerModel
    property string selectedUuid
    property string updateToolTip
    // Native text of the window's keyboard shortcuts, shown in tooltips
    property string addHostShortcutText
    property string helpShortcutText
    property string settingsShortcutText

    signal hostActivated(int index)
    signal hostMenuRequested(int index, Item anchor, bool viaKeyboard)
    signal hostDeleteRequested(int index)
    signal addHostRequested()
    signal helpRequested()
    signal updateRequested()
    signal discordRequested()
    signal controllersRequested()
    signal settingsRequested()
    signal contentFocusRequested()

    implicitWidth: 240

    Keys.onUpPressed: moveFocus(Window.activeFocusItem, -1)
    Keys.onDownPressed: moveFocus(Window.activeFocusItem, 1)
    Keys.onRightPressed: contentFocusRequested()
    Keys.onReturnPressed: activateFocused()
    Keys.onEnterPressed: activateFocused()

    function activateFocused() {
        var item = Window.activeFocusItem
        if (item && typeof item.clicked === "function") {
            item.clicked()
        }
    }

    function navigationItems() {
        var items = []
        for (var i = 0; i < hostList.count; i++) {
            var host = hostList.itemAtIndex(i)
            if (host) {
                items.push(host)
            }
        }
        items.push(addHostItem)
        for (var j = 0; j < bottomColumn.children.length; j++) {
            var child = bottomColumn.children[j]
            if (child.visible && child.activeFocusOnTab) {
                items.push(child)
            }
        }
        return items
    }

    function withShortcut(text, shortcut) {
        return shortcut ? text + " (" + shortcut + ")" : text
    }

    function moveFocus(from, delta) {
        var items = navigationItems()
        var target = items.indexOf(from) + delta
        if (target >= 0 && target < items.length) {
            items[target].forceActiveFocus(delta > 0 ? Qt.TabFocusReason : Qt.BacktabFocusReason)
        }
    }

    function focusHost(index, reason) {
        var host = index >= 0 ? hostList.itemAtIndex(index) : null
        if (host) {
            host.forceActiveFocus(reason)
        }
        else {
            addHostItem.forceActiveFocus(reason)
        }
    }

    function hostItem(index) {
        return hostList.itemAtIndex(index)
    }

    function ensureVisible(item) {
        var top = item.mapToItem(hostsFlick.contentItem, 0, 0).y
        if (top < hostsFlick.contentY) {
            hostsFlick.contentY = top
        }
        else if (top + item.height > hostsFlick.contentY + hostsFlick.height) {
            hostsFlick.contentY = top + item.height - hostsFlick.height
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panel

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Theme.border
        }
    }

    Column {
        id: topColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 13
        anchors.topMargin: 18

        Row {
            leftPadding: 10
            topPadding: 4
            bottomPadding: 18
            spacing: 10

            DeskIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "moon"
                color: Theme.accent
                size: 22
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Moonlight"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: Theme.text
            }
        }

        Text {
            width: parent.width
            leftPadding: 10
            topPadding: 6
            bottomPadding: 6
            text: qsTr("Hosts").toUpperCase()
            font.pixelSize: Theme.fontSection
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.fontSection * 0.08
            color: Theme.muted
            elide: Text.ElideRight
        }
    }

    Flickable {
        id: hostsFlick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topColumn.bottom
        anchors.bottom: bottomColumn.top
        anchors.leftMargin: 12
        anchors.rightMargin: 13
        anchors.topMargin: 4
        anchors.bottomMargin: 8
        contentHeight: hostsColumn.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: hostsFlick.contentHeight > hostsFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        // Leave room for the focus ring of the first and last rows
        Column {
            id: hostsColumn
            width: parent.width
            topPadding: 2
            bottomPadding: 2
            spacing: 4

            ListView {
                id: hostList
                width: parent.width
                height: contentHeight
                visible: count > 0
                interactive: false
                keyNavigationEnabled: false
                spacing: 4
                model: sidebar.computerModel

                delegate: DeskSidebarItem {
                    id: hostDelegate

                    width: hostList.width
                    text: model.name
                    iconName: "monitor"
                    dotColor: model.statusUnknown ? "transparent" : model.online ? Theme.accent : Theme.offline
                    selected: model.uuid === sidebar.selectedUuid

                    ToolTip.text: model.name
                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered && contentItem.implicitWidth > contentItem.width

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            sidebar.ensureVisible(hostDelegate)
                        }
                    }

                    onClicked: sidebar.hostActivated(index)
                    onPressAndHold: sidebar.hostMenuRequested(index, hostDelegate, false)

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: sidebar.hostMenuRequested(index, hostDelegate, false)
                    }

                    Keys.onMenuPressed: sidebar.hostMenuRequested(index, hostDelegate, true)
                    Keys.onDeletePressed: sidebar.hostDeleteRequested(index)
                }
            }

            Text {
                width: parent.width
                visible: hostList.count === 0
                leftPadding: 10
                topPadding: 8
                bottomPadding: 8
                text: qsTr("None yet")
                font.pixelSize: Theme.fontSmall
                color: Theme.muted
            }

            DeskSidebarItem {
                id: addHostItem
                width: parent.width
                text: qsTr("Add host")
                iconName: "plus"

                ToolTip.text: sidebar.withShortcut(qsTr("Add PC manually"), sidebar.addHostShortcutText)
                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered

                onClicked: sidebar.addHostRequested()
                onActiveFocusChanged: {
                    if (activeFocus) {
                        sidebar.ensureVisible(addHostItem)
                    }
                }
            }
        }
    }

    Column {
        id: bottomColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 13
        anchors.bottomMargin: 18
        spacing: 4

        DeskSidebarItem {
            width: parent.width
            visible: SystemProperties.hasBrowser
            text: qsTr("Help")
            iconName: "help"

            ToolTip.text: sidebar.withShortcut(qsTr("Help"), sidebar.helpShortcutText)
            ToolTip.delay: 1000
            ToolTip.timeout: 3000
            ToolTip.visible: hovered && sidebar.helpShortcutText !== ""

            onClicked: sidebar.helpRequested()
        }

        DeskSidebarItem {
            width: parent.width
            visible: sidebar.updateToolTip !== ""
            text: qsTr("Update available")
            iconName: "update"
            dotColor: Theme.accent

            ToolTip.text: sidebar.updateToolTip
            ToolTip.delay: 1000
            ToolTip.timeout: 3000
            ToolTip.visible: hovered

            onClicked: sidebar.updateRequested()
        }

        DeskSidebarItem {
            width: parent.width
            visible: SystemProperties.hasBrowser
            text: qsTr("Discord")
            iconName: "discord"

            ToolTip.text: qsTr("Join our community on Discord")
            ToolTip.delay: 1000
            ToolTip.timeout: 3000
            ToolTip.visible: hovered

            onClicked: sidebar.discordRequested()
        }

        // Hidden until the gamepad mapper exists; GamepadMapper.qml is still a stub
        DeskSidebarItem {
            width: parent.width
            visible: false
            text: qsTr("Controllers")
            iconName: "gamepad"
            onClicked: sidebar.controllersRequested()
        }

        DeskSidebarItem {
            width: parent.width
            text: qsTr("Settings")
            iconName: "sliders"

            ToolTip.text: sidebar.withShortcut(qsTr("Settings"), sidebar.settingsShortcutText)
            ToolTip.delay: 1000
            ToolTip.timeout: 3000
            ToolTip.visible: hovered && sidebar.settingsShortcutText !== ""

            onClicked: sidebar.settingsRequested()
        }
    }
}
