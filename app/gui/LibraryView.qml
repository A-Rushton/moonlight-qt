import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14

import DeskTheme 1.0
import ComputerModel 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0

FocusScope {
    id: library

    property ComputerModel computerModel: createModel()
    property string selectedUuid
    property int selectedIndex: -1
    property var selectedComputer: null
    // "View all apps" for the selected host
    property bool showAllApps: false

    // Pairing runs in the background, so remember which host it is for and its PIN
    property string pairingUuid
    property string pairingPin

    // Which side keyboard focus should return to after the focused item disappears
    property string focusArea: "sidebar"

    objectName: qsTr("Hosts")

    onSelectedUuidChanged: showAllApps = false

    // Note: Any initialization done here that is critical for streaming must
    // also be done in CliStartStreamSegue.qml, since this code does not run
    // for command-line initiated streams.
    StackView.onActivated: {
        ComputerManager.computerAddCompleted.connect(hostDialogs.addComplete)
        Qt.callLater(ensureFocus)
    }

    StackView.onDeactivating: {
        ComputerManager.computerAddCompleted.disconnect(hostDialogs.addComplete)
    }

    function createModel() {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', library, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(hostDialogs.connectionTestComplete)
        model.modelReset.connect(scheduleSync)
        model.rowsInserted.connect(scheduleSync)
        model.rowsAboutToBeRemoved.connect(hostAboutToBeRemoved)
        model.rowsRemoved.connect(scheduleSync)
        model.dataChanged.connect(scheduleSync)
        return model
    }

    Component.onCompleted: scheduleSync()

    function openAddHost() {
        addHostDialog.open()
    }

    function openSettings() {
        window.openSettings()
    }

    function openHelp() {
        window.openHelp()
    }

    function scheduleSync() {
        Qt.callLater(syncSelection)
    }

    function hostAboutToBeRemoved(parent, first, last) {
        var index = selectedUuid !== "" ? computerModel.indexOfUuid(selectedUuid) : -1
        if (index >= first && index <= last) {
            hostPane.releaseApps()
        }
    }

    function snapshot(row, index) {
        return {
            index: index,
            uuid: row.uuid,
            name: row.name,
            online: row.online,
            paired: row.paired,
            busy: row.busy,
            wakeable: row.wakeable,
            statusUnknown: row.statusUnknown,
            serverSupported: row.serverSupported,
            details: row.details,
            address: row.address,
            macAddress: row.macAddress,
            appCount: row.appCount
        }
    }

    function sameSnapshot(a, b) {
        if (!a || !b) {
            return a === b
        }
        for (var key in a) {
            if (a[key] !== b[key]) {
                return false
            }
        }
        return true
    }

    function syncSelection() {
        var index = selectedUuid !== "" ? computerModel.indexOfUuid(selectedUuid) : -1
        if (index < 0 && hostRows.count > 0) {
            index = 0
        }

        var rowItem = index >= 0 && index < hostRows.count ? hostRows.itemAt(index) : null
        if (rowItem) {
            var computer = snapshot(rowItem.row, index)
            if (!sameSnapshot(computer, selectedComputer)) {
                selectedComputer = computer
            }
            selectedIndex = index
            selectedUuid = computer.uuid
        }
        else {
            selectedComputer = null
            selectedIndex = -1
        }

        if (pairingUuid !== "" && computerModel.indexOfUuid(pairingUuid) < 0) {
            pairingUuid = ""
            pairingPin = ""
        }

        Qt.callLater(ensureFocus)
    }

    function selectHost(index) {
        var rowItem = hostRows.itemAt(index)
        if (rowItem) {
            selectedUuid = rowItem.row.uuid
            syncSelection()
        }
    }

    // Clicking or pressing Enter on a host starts its direct launch app; moving focus with the arrows does not
    function activateHost(index) {
        selectHost(index)

        var computer = selectedComputer
        if (computer && computer.index === index) {
            hostPane.launchDirectApp()
        }
    }

    function startPairing() {
        var computer = selectedComputer
        var index = computer ? computerModel.indexOfUuid(computer.uuid) : -1
        if (index < 0 || pairingUuid !== "") {
            return
        }

        var pin = computerModel.generatePinString()
        pairingUuid = computer.uuid
        pairingPin = pin
        computerModel.pairComputer(index, pin)
    }

    function cancelPairing() {
        // Pairing can't be interrupted; this only dismisses the PIN
        pairingUuid = ""
        pairingPin = ""
    }

    function pairingComplete(error) {
        pairingUuid = ""
        pairingPin = ""

        if (error !== undefined) {
            hostDialogs.showError(error, "")
        }
    }

    function focusReason() {
        return SdlGamepadKeyNavigation.getConnectedGamepads() > 0 ? Qt.TabFocusReason : Qt.OtherFocusReason
    }

    function focusSidebar(reason) {
        sidebar.focusHost(selectedIndex, reason)
    }

    function focusContent(reason) {
        if (hostRows.count === 0) {
            emptyHosts.focusFirst(reason)
        }
        else if (selectedComputer) {
            hostPane.focusFirst(reason)
        }
    }

    function hasUsableFocus() {
        var item = Window.activeFocusItem
        return item !== null && item.activeFocusOnTab === true && item.visible
    }

    function restoreFocus(reason) {
        if (reason === undefined) {
            reason = focusReason()
        }
        if (focusArea === "content" && (hostRows.count === 0 || selectedComputer)) {
            focusContent(reason)
        }
        else {
            focusSidebar(reason)
        }
    }

    // Moves focus somewhere sensible when the focused item went away, e.g. a deleted host
    function ensureFocus() {
        if (library.StackView.status !== StackView.Active || hostDialogs.anyOpen || addHostDialog.visible) {
            return
        }
        if (!hasUsableFocus() && (library.activeFocus || Window.activeFocusItem === null ||
                                  Window.activeFocusItem === Window.contentItem)) {
            restoreFocus()
        }
    }

    // Row objects for every host, used to snapshot the selected host's data
    Item {
        visible: false

        Repeater {
            id: hostRows
            model: library.computerModel

            delegate: Item {
                readonly property var row: model
            }
        }
    }

    HostSidebar {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 240
        focus: true
        computerModel: library.computerModel
        selectedUuid: library.selectedUuid
        updateToolTip: window.updateVersion !== ""
                       ? qsTr("Update available for Moonlight: Version %1").arg(window.updateVersion) : ""
        addHostShortcutText: newHostShortcut.nativeText
        helpShortcutText: helpShortcut.nativeText
        settingsShortcutText: settingsShortcut.nativeText

        onActiveFocusChanged: {
            if (activeFocus) {
                library.focusArea = "sidebar"
            }
        }

        onHostActivated: library.activateHost(index)
        onHostMenuRequested: {
            library.selectHost(index)
            hostDialogs.openMenu(library.selectedComputer, anchor, viaKeyboard)
        }
        onHostDeleteRequested: {
            var rowItem = hostRows.itemAt(index)
            if (rowItem) {
                hostDialogs.confirmDelete(library.snapshot(rowItem.row, index), true)
            }
        }
        onAddHostRequested: library.openAddHost()
        onHelpRequested: library.openHelp()
        onUpdateRequested: window.openUpdate()
        onDiscordRequested: window.openDiscord()
        onControllersRequested: window.openControllers()
        onSettingsRequested: library.openSettings()
        onContentFocusRequested: library.focusContent(Qt.TabFocusReason)
    }

    FocusScope {
        id: content
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        onActiveFocusChanged: {
            if (activeFocus) {
                library.focusArea = "content"
            }
        }

        HostPane {
            id: hostPane
            anchors.fill: parent
            visible: library.selectedComputer !== null
            focus: visible
            computer: library.selectedComputer
            showAllApps: library.showAllApps
            pairingPin: library.selectedComputer && library.pairingUuid === library.selectedComputer.uuid
                        ? library.pairingPin : ""
            otherPairingActive: library.pairingUuid !== "" && pairingPin === ""

            onMenuRequested: hostDialogs.openMenu(library.selectedComputer, anchor, viaKeyboard)
            onSidebarFocusRequested: library.focusSidebar(Qt.TabFocusReason)
            onWakeRequested: hostDialogs.wake(library.selectedComputer)
            onWakeHelpRequested: library.openHelp()
            onPairRequested: library.startPairing()
            onCancelPairingRequested: library.cancelPairing()
            onViewAllAppsRequested: library.showAllApps = true
        }

        EmptyHosts {
            id: emptyHosts
            anchors.fill: parent
            visible: hostRows.count === 0
            focus: visible

            onAddHostRequested: library.openAddHost()
            onSetupHelpRequested: library.openHelp()
            onSidebarFocusRequested: library.focusSidebar(Qt.TabFocusReason)
        }
    }

    HostDialogs {
        id: hostDialogs
        computerModel: library.computerModel
        pageActive: library.StackView.status === StackView.Active
        showingAllApps: library.showAllApps

        onViewAllAppsToggled: library.showAllApps = !library.showAllApps
    }

    AddHostDialog {
        id: addHostDialog
    }
}
