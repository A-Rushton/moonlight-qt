import QtQuick 2.14
import QtQuick.Controls 2.14

DeskMenu {
    id: appMenu

    property var appModel: null
    property int appIndex: -1
    property bool running
    property bool hidden
    property bool directLaunch
    property Item anchor: null
    property bool viaKeyboard

    signal launchRequested(int index)
    signal quitRequested()
    // Asks the owner to return focus to the item that opened the menu
    signal restoreFocusRequested(Item target, int reason)

    function openFor(index, row, anchorItem, keyboard) {
        appIndex = index
        running = row.running
        hidden = row.hidden
        directLaunch = row.directLaunch
        // Triggering a checkable item breaks its binding, so set the state on every open
        directLaunchItem.checked = directLaunch
        hiddenItem.checked = hidden
        anchor = anchorItem
        viaKeyboard = keyboard

        if (keyboard) {
            var origin = anchorItem.mapToItem(parent, 0, 0)
            x = anchorItem.width < width ? origin.x + anchorItem.width - width : origin.x
            y = origin.y + anchorItem.height + 4
            open()
        }
        else {
            popup()
        }
    }

    onOpened: {
        if (viaKeyboard) {
            for (var i = 0; i < count; i++) {
                var item = itemAt(i)
                if (item.visible && item.enabled) {
                    item.forceActiveFocus(Qt.TabFocusReason)
                    break
                }
            }
        }
    }

    onClosed: {
        var target = anchor
        var reason = viaKeyboard ? Qt.TabFocusReason : Qt.OtherFocusReason
        Qt.callLater(function() {
            appMenu.restoreFocusRequested(target, reason)
        })
    }

    NavigableMenuItem {
        text: appMenu.running ? qsTr("Resume") : qsTr("Launch")
        onTriggered: appMenu.launchRequested(appMenu.appIndex)
    }
    NavigableMenuItem {
        text: qsTr("Quit")
        visible: appMenu.running
        onTriggered: appMenu.quitRequested()
    }
    NavigableMenuItem {
        id: directLaunchItem
        checkable: true
        text: qsTr("Direct launch")
        enabled: !appMenu.hidden
        onTriggered: appMenu.appModel.setAppDirectLaunch(appMenu.appIndex, !appMenu.directLaunch)

        ToolTip.text: qsTr("Launch this app immediately when the host is selected, bypassing the app selection grid.")
        ToolTip.delay: 1000
        ToolTip.timeout: 3000
        ToolTip.visible: hovered
    }
    NavigableMenuItem {
        id: hiddenItem
        checkable: true
        text: qsTr("Hide")
        enabled: appMenu.hidden || (!appMenu.running && !appMenu.directLaunch)
        onTriggered: appMenu.appModel.setAppHidden(appMenu.appIndex, !appMenu.hidden)

        ToolTip.text: qsTr("Hide this game from the app grid. To access hidden games, right-click on the host and choose %1.").arg(qsTr("View all apps"))
        ToolTip.delay: 1000
        ToolTip.timeout: 5000
        ToolTip.visible: hovered
    }
}
