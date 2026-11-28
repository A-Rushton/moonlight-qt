import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0

// Host actions shared by the sidebar and the host pane: the host menu and every host dialog.
Item {
    id: hostDialogs

    property var computerModel
    // Whether the owning page is the current StackView page
    property bool pageActive: true
    // Whether the selected host currently lists hidden apps too
    property bool showingAllApps: false

    signal viewAllAppsToggled()

    readonly property bool anyOpen: hostMenu.visible || errorDialog.visible || deleteDialog.visible ||
                                    renameDialog.visible || testConnectionDialog.visible || detailsDialog.visible

    function indexOf(computer) {
        return computer ? computerModel.indexOfUuid(computer.uuid) : -1
    }

    function showError(text, helpText) {
        errorDialog.text = text
        errorDialog.helpText = helpText
        errorDialog.open()
    }

    function addComplete(success, detectedPortBlocking) {
        if (!success) {
            var text = qsTr("Unable to connect to the specified PC.")
            var helpText = ""

            if (detectedPortBlocking) {
                text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
            }
            else {
                helpText = qsTr("Click the Help button for possible solutions.")
            }

            showError(text, helpText)
        }
    }

    function openMenu(computer, anchor, viaKeyboard) {
        if (!computer || !anchor) {
            return
        }

        hostMenu.computer = computer
        hostMenu.anchor = anchor
        hostMenu.viaKeyboard = viaKeyboard
        // Triggering a checkable item breaks its binding, so set the state on every open
        viewAllAppsItem.checked = showingAllApps
        // Position from the anchor rather than parenting to it, since a model reset can destroy sidebar rows
        var origin = anchor.mapToItem(hostDialogs, 0, 0)
        hostMenu.x = anchor.width < hostMenu.width ? origin.x + anchor.width - hostMenu.width : origin.x
        hostMenu.y = origin.y + anchor.height + 4
        hostMenu.open()
    }

    function wake(computer) {
        var index = indexOf(computer)
        if (index >= 0) {
            computerModel.wakeComputer(index)
        }
    }

    function testNetwork(computer, viaKeyboard) {
        var index = indexOf(computer)
        if (index >= 0) {
            computerModel.testConnectionForComputer(index)
            testConnectionDialog.openedFromKeyboard = viaKeyboard === true
            testConnectionDialog.open()
        }
    }

    function rename(computer, viaKeyboard) {
        renameDialog.uuid = computer.uuid
        renameDialog.originalName = computer.name
        renameDialog.openedFromKeyboard = viaKeyboard === true
        renameDialog.open()
    }

    function confirmDelete(computer, viaKeyboard) {
        deleteDialog.uuid = computer.uuid
        deleteDialog.pcName = computer.name
        deleteDialog.openedFromKeyboard = viaKeyboard === true
        deleteDialog.open()
    }

    function showDetails(computer, viaKeyboard) {
        detailsDialog.text = computer.details
        detailsDialog.openedFromKeyboard = viaKeyboard === true
        detailsDialog.open()
    }

    function connectionTestComplete(result, blockedPorts) {
        testConnectionDialog.connectionTestComplete(result, blockedPorts)
    }

    DeskMenu {
        id: hostMenu

        property var computer
        property Item anchor
        property bool viaKeyboard

        readonly property bool online: computer ? computer.online : false

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
            // Return keyboard focus to whatever opened the menu, unless an action took it elsewhere
            var target = anchor
            var reason = viaKeyboard ? Qt.TabFocusReason : Qt.OtherFocusReason
            Qt.callLater(function() {
                if (target && hostDialogs.pageActive && !hostDialogs.anyOpen && target.visible) {
                    target.forceActiveFocus(reason)
                }
            })
        }

        NavigableMenuItem {
            id: viewAllAppsItem
            text: qsTr("View all apps")
            checkable: true
            visible: hostMenu.online && hostMenu.computer.paired
            onTriggered: hostDialogs.viewAllAppsToggled()
        }
        NavigableMenuItem {
            text: qsTr("Wake host")
            visible: hostMenu.computer ? !hostMenu.online && hostMenu.computer.wakeable : false
            onTriggered: hostDialogs.wake(hostMenu.computer)
        }
        NavigableMenuItem {
            text: qsTr("Test network")
            onTriggered: hostDialogs.testNetwork(hostMenu.computer, triggeredByKeyboard)
        }
        NavigableMenuItem {
            text: qsTr("Rename")
            onTriggered: hostDialogs.rename(hostMenu.computer, triggeredByKeyboard)
        }
        NavigableMenuItem {
            text: qsTr("Delete")
            onTriggered: hostDialogs.confirmDelete(hostMenu.computer, triggeredByKeyboard)
        }
        NavigableMenuItem {
            text: qsTr("View details")
            onTriggered: hostDialogs.showDetails(hostMenu.computer, triggeredByKeyboard)
        }
    }

    ErrorMessageDialog {
        id: errorDialog

        // Using Setup-Guide here instead of Troubleshooting because it's likely that users
        // will arrive here by forgetting to enable GameStream or not forwarding ports.
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    NavigableMessageDialog {
        id: deleteDialog

        property string uuid
        property string pcName

        titleText: qsTr("Delete host")
        text: qsTr("Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            var index = hostDialogs.computerModel.indexOfUuid(uuid)
            if (index >= 0) {
                hostDialogs.computerModel.deleteComputer(index)
            }
        }
    }

    NavigableMessageDialog {
        id: testConnectionDialog

        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            text = qsTr("Moonlight is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTr("This may take a few seconds…")
            showSpinner = true
        }

        function connectionTestComplete(result, blockedPorts) {
            if (result === -1) {
                text = qsTr("The network test could not be performed because none of Moonlight's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                iconName = "alert"
            }
            else if (result === 0) {
                text = qsTr("This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTr("If you are trying to stream over the Internet, install the Moonlight Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                iconName = "check"
            }
            else {
                text = qsTr("Your PC's current network connection seems to be blocking Moonlight. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTr("The following network ports were blocked:") + "\n"
                text += blockedPorts
                iconName = "alert"
            }

            showSpinner = false
        }
    }

    NavigableDialog {
        id: renameDialog

        property string uuid
        property string originalName

        titleText: qsTr("Rename host")
        implicitWidth: maximumWidth
        standardButtons: Dialog.Ok | Dialog.Cancel
        navigableButtons: true

        onOpened: {
            nameField.text = originalName
            nameField.selectAll()
            nameField.forceActiveFocus(Qt.TabFocusReason)
        }

        onClosed: nameField.clear()

        onAccepted: {
            var name = nameField.text.trim()
            var index = hostDialogs.computerModel.indexOfUuid(uuid)
            if (name !== "" && index >= 0) {
                hostDialogs.computerModel.renameComputer(index, name)
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: 8

            Label {
                text: qsTr("Enter the new name for this PC:")
                font.pixelSize: Theme.fontSmall
                font.weight: Font.Medium
                color: Theme.text
            }

            DeskTextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: renameDialog.originalName
                focus: true

                Keys.onReturnPressed: {
                    renameDialog.closedByKeyboard = true
                    renameDialog.accept()
                }
                Keys.onEnterPressed: {
                    renameDialog.closedByKeyboard = true
                    renameDialog.accept()
                }
                Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
            }
        }
    }

    NavigableMessageDialog {
        id: detailsDialog

        titleText: qsTr("Host details")
        iconName: "help"
        standardButtons: Dialog.Ok
    }
}
