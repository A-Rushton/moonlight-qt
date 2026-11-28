import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0
import ComputerManager 1.0
import StreamingPreferences 1.0

FocusScope {
    id: appsPane

    // Snapshot of the host's ComputerModel row
    property var computer: null
    // Whether the host is online and paired, so its apps can be listed
    property bool active: false
    property bool showHiddenGames: false
    property color backdrop: Theme.bg

    property var appModel: null
    property string modelKey
    property int desktopIndex: -1
    property var desktopRow: null

    readonly property string wantedModelKey: active && computer ? computer.uuid + (showHiddenGames ? "/all" : "") : ""
    readonly property int otherCount: appRows.count - (desktopIndex >= 0 ? 1 : 0)
    readonly property bool gridMode: StreamingPreferences.appListMode === StreamingPreferences.ALM_GRID
    // Apps should be listed but no model could be built, e.g. the host dropped out mid-refresh
    readonly property bool loadFailed: wantedModelKey !== "" && appModel === null

    signal showHiddenGamesRequested()
    signal sidebarFocusRequested()

    implicitHeight: layout.implicitHeight

    onWantedModelKeyChanged: Qt.callLater(syncModel)
    // Each host refresh retries a model that failed to build
    onComputerChanged: {
        if (loadFailed) {
            Qt.callLater(syncModel)
        }
    }
    Component.onCompleted: syncModel()
    Component.onDestruction: dropModel()

    function syncModel() {
        if (modelKey !== wantedModelKey) {
            var hadFocus = appsPane.activeFocus
            releaseModel()
            createModel()
            // The focused row or button may have gone with the old model
            if (hadFocus) {
                Qt.callLater(focusFirst, Qt.TabFocusReason)
            }
        }
    }

    function createModel() {
        if (wantedModelKey === "") {
            return
        }

        var model = Qt.createQmlObject('import AppModel 1.0; AppModel {}', appsPane, '')
        if (!model.initializeForUuid(ComputerManager, computer.uuid, showHiddenGames)) {
            model.destroy()
            return
        }

        model.computerLost.connect(computerLost)
        model.modelReset.connect(structureChanged)
        model.rowsInserted.connect(structureChanged)
        model.rowsRemoved.connect(structureChanged)
        model.dataChanged.connect(scheduleDesktopUpdate)
        modelKey = wantedModelKey
        appModel = model
        updateDesktop()
    }

    // Drops the model, e.g. before its host is deleted. A different host or state builds a new one.
    function releaseModel() {
        appMenu.close()
        quitAppDialog.close()
        dropModel()
    }

    function dropModel() {
        var model = appModel
        desktopRow = null
        desktopIndex = -1
        appModel = null
        modelKey = ""

        if (model) {
            model.computerLost.disconnect(computerLost)
            model.modelReset.disconnect(structureChanged)
            model.rowsInserted.disconnect(structureChanged)
            model.rowsRemoved.disconnect(structureChanged)
            model.dataChanged.disconnect(scheduleDesktopUpdate)
            model.destroy()
        }
    }

    function computerLost() {
        // The host went offline or was unpaired; the pane switches state once the host list catches up
        releaseModel()
    }

    function structureChanged() {
        // Row indexes may have moved under the open menu
        appMenu.close()
        scheduleDesktopUpdate()
    }

    function scheduleDesktopUpdate() {
        Qt.callLater(updateDesktop)
    }

    function updateDesktop() {
        for (var i = 0; i < appRows.count; i++) {
            var item = appRows.itemAt(i)
            if (item && item.row.isDesktop) {
                desktopIndex = i
                desktopRow = item.row
                return
            }
        }
        desktopRow = null
        desktopIndex = -1
    }

    function rowAt(index) {
        var item = appRows.itemAt(index)
        return item ? item.row : null
    }

    function launch(index, quitExistingApp) {
        var row = rowAt(index)
        if (!appModel || !row) {
            return
        }

        var runningId = appModel.getRunningAppId()
        if (runningId !== 0 && runningId !== row.appid) {
            if (quitExistingApp) {
                quitAppDialog.appName = appModel.getRunningAppName()
                quitAppDialog.segueToStream = true
                quitAppDialog.nextAppName = row.name
                quitAppDialog.nextAppIndex = index
                quitAppDialog.open()
            }
            return
        }

        var component = Qt.createComponent("StreamSegue.qml")
        var segue = component.createObject(stackView, {
                                               "appName": row.name,
                                               "session": appModel.createSessionForApp(index),
                                               "isResume": runningId === row.appid
                                           })
        stackView.push(segue)
    }

    function quitRunningApp() {
        if (!appModel) {
            return
        }

        quitAppDialog.appName = appModel.getRunningAppName()
        quitAppDialog.segueToStream = false
        quitAppDialog.open()
    }

    // Starts the host's direct launch app, unless another app is running or every app was asked for
    function launchDirectApp() {
        syncModel()
        if (!appModel || showHiddenGames) {
            return false
        }

        var index = appModel.getDirectLaunchAppIndex()
        if (index < 0) {
            return false
        }

        launch(index, false)
        return true
    }

    function openMenu(index, anchor, viaKeyboard) {
        var row = rowAt(index)
        if (row && anchor) {
            appMenu.openFor(index, row, anchor, viaKeyboard)
        }
    }

    function focusFirst(reason) {
        if (retryButton.visible) {
            retryButton.forceActiveFocus(reason)
            return true
        }
        if (desktopPanel.visible) {
            return desktopPanel.focusPrimary(reason)
        }
        if (appsSection.visible && appsLoader.item) {
            return appsLoader.item.focusFirst(reason)
        }
        if (viewAllButton.visible) {
            viewAllButton.forceActiveFocus(reason)
            return true
        }
        return false
    }

    function setListMode(mode) {
        if (StreamingPreferences.appListMode !== mode) {
            StreamingPreferences.appListMode = mode
            StreamingPreferences.save()
        }
    }

    function isWithin(item, ancestor) {
        while (item) {
            if (item === ancestor) {
                return true
            }
            item = item.parent
        }
        return false
    }

    // Row objects for every app, used to find the Desktop app and read rows by index
    Item {
        visible: false

        Repeater {
            id: appRows
            model: appsPane.appModel

            delegate: Item {
                readonly property var row: model
            }

            onItemAdded: appsPane.scheduleDesktopUpdate()
            onItemRemoved: {
                // Don't leave the Desktop panel bound to a row that is going away
                if (item.row === appsPane.desktopRow) {
                    appsPane.desktopRow = null
                    appsPane.desktopIndex = -1
                }
                appsPane.scheduleDesktopUpdate()
            }
        }
    }

    ColumnLayout {
        id: layout
        width: parent.width
        spacing: 28

        DesktopPanel {
            id: desktopPanel
            Layout.fillWidth: true
            visible: appsPane.desktopRow !== null
            row: appsPane.desktopRow

            onLaunchRequested: appsPane.launch(appsPane.desktopIndex, true)
            onQuitRequested: appsPane.quitRunningApp()
            onMenuRequested: appsPane.openMenu(appsPane.desktopIndex, anchor, viaKeyboard)
        }

        ColumnLayout {
            id: appsSection
            Layout.fillWidth: true
            visible: appsPane.otherCount > 0
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    leftPadding: 4
                    text: qsTr("Apps (%1)").arg(appsPane.otherCount).toUpperCase()
                    font.pixelSize: Theme.fontSection
                    font.weight: Font.DemiBold
                    font.letterSpacing: Theme.fontSection * 0.08
                    color: Theme.muted
                    elide: Text.ElideRight
                }

                DeskIconButton {
                    id: listButton
                    implicitWidth: 32
                    implicitHeight: 32
                    iconName: "list"
                    toolTipText: qsTr("List")
                    highlighted: !appsPane.gridMode
                    onClicked: appsPane.setListMode(StreamingPreferences.ALM_LIST)
                    Keys.onRightPressed: gridButton.forceActiveFocus(Qt.TabFocusReason)
                }

                DeskIconButton {
                    id: gridButton
                    implicitWidth: 32
                    implicitHeight: 32
                    iconName: "grid"
                    toolTipText: qsTr("Grid")
                    highlighted: appsPane.gridMode
                    onClicked: appsPane.setListMode(StreamingPreferences.ALM_GRID)
                    Keys.onLeftPressed: listButton.forceActiveFocus(Qt.BacktabFocusReason)
                }
            }

            Loader {
                id: appsLoader
                Layout.fillWidth: true
                sourceComponent: appsPane.gridMode ? gridComponent : listComponent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: appsPane.appModel !== null && appRows.count === 0
            spacing: 16

            Text {
                Layout.fillWidth: true
                text: qsTr("This computer doesn't seem to have any applications or some applications are hidden")
                font.pixelSize: Theme.fontBase
                lineHeight: 1.3
                color: Theme.mutedStrong
                wrapMode: Text.Wrap
            }

            DeskButton {
                id: viewAllButton
                visible: !appsPane.showHiddenGames
                iconName: "eye-off"
                text: qsTr("View all apps")
                onClicked: appsPane.showHiddenGamesRequested()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: appsPane.loadFailed
            spacing: 16

            Text {
                Layout.fillWidth: true
                text: qsTr("Couldn't load the app list for this host.")
                font.pixelSize: Theme.fontBase
                lineHeight: 1.3
                color: Theme.mutedStrong
                wrapMode: Text.Wrap
            }

            DeskButton {
                id: retryButton
                visible: appsPane.loadFailed
                text: qsTr("Retry")
                onClicked: appsPane.syncModel()
            }
        }
    }

    Component {
        id: listComponent

        AppList {
            model: appsPane.appModel
            skipIndex: appsPane.desktopIndex
            backdrop: appsPane.backdrop
            onLaunchRequested: appsPane.launch(index, true)
            onMenuRequested: appsPane.openMenu(index, anchor, viaKeyboard)
        }
    }

    Component {
        id: gridComponent

        AppGrid {
            model: appsPane.appModel
            skipIndex: appsPane.desktopIndex
            backdrop: appsPane.backdrop
            onLaunchRequested: appsPane.launch(index, true)
            onMenuRequested: appsPane.openMenu(index, anchor, viaKeyboard)
            onExitUp: gridButton.forceActiveFocus(Qt.BacktabFocusReason)
            onExitLeft: appsPane.sidebarFocusRequested()
        }
    }

    AppMenu {
        id: appMenu
        appModel: appsPane.appModel

        onLaunchRequested: appsPane.launch(index, true)
        onQuitRequested: appsPane.quitRunningApp()
        onRestoreFocusRequested: {
            if (target && target.visible && !quitAppDialog.visible && stackView.currentItem &&
                    appsPane.isWithin(target, stackView.currentItem)) {
                target.forceActiveFocus(reason)
            }
        }
    }

    NavigableMessageDialog {
        id: quitAppDialog

        property string appName
        property bool segueToStream
        property string nextAppName
        property int nextAppIndex

        text: qsTr("Are you sure you want to quit %1? Any unsaved progress will be lost.").arg(appName)
        standardButtons: Dialog.Yes | Dialog.No

        function quitApp() {
            if (!appsPane.appModel) {
                return
            }

            var model = appsPane.appModel
            var component = Qt.createComponent("QuitSegue.qml")
            var params = {"appName": appName, "quitRunningAppFn": function() { model.quitRunningApp() }}
            if (segueToStream) {
                // Stream the next app once the running one has quit
                params.nextAppName = nextAppName
                params.nextSession = model.createSessionForApp(nextAppIndex)
            }
            else {
                params.nextAppName = null
                params.nextSession = null
            }

            stackView.push(component.createObject(stackView, params))
        }

        onAccepted: quitApp()
    }
}
