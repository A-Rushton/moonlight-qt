import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14

import DeskTheme 1.0

FocusScope {
    id: pane

    property int computerIndex: -1
    // Snapshot of the selected ComputerModel row, refreshed by LibraryView whenever the row changes
    property var computer: null
    property string pairingPin
    property bool otherPairingActive: false

    // Filled by the apps view when the host is online and paired
    readonly property alias appsArea: appsArea

    readonly property string hostState: !computer ? ""
                                       : computer.statusUnknown ? "connecting"
                                       : !computer.online ? "offline"
                                       : !computer.serverSupported ? "unsupported"
                                       : !computer.paired ? "pairing"
                                       : "apps"

    signal menuRequested(Item anchor, bool viaKeyboard)
    signal sidebarFocusRequested()
    signal wakeRequested()
    signal wakeHelpRequested()
    signal pairRequested()
    signal cancelPairingRequested()

    function showApps() {
        if (computerIndex < 0) {
            return
        }

        var component = Qt.createComponent("AppView.qml")
        var appView = component.createObject(stackView, {"computerIndex": computerIndex, "objectName": computer.name})
        stackView.push(appView)
    }

    function focusFirst(reason) {
        if (hostState === "apps") {
            showAppsButton.forceActiveFocus(reason)
        }
        else if (!(stateLoader.item && stateLoader.item.focusPrimary && stateLoader.item.focusPrimary(reason))) {
            header.menuButton.forceActiveFocus(reason)
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

    function moveFocus(forward) {
        var current = Window.activeFocusItem
        if (!current) {
            return
        }

        var next = current.nextItemInFocusChain(forward)
        if (next && next !== current && isWithin(next, pane)) {
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
        }
    }

    function ensureVisible(item) {
        if (!isWithin(item, scroller.contentItem)) {
            return
        }

        var top = item.mapToItem(scroller.contentItem, 0, 0).y
        var margin = 24
        if (top - margin < scroller.contentY) {
            scroller.contentY = Math.max(0, top - margin)
        }
        else if (top + item.height + margin > scroller.contentY + scroller.height) {
            scroller.contentY = Math.min(scroller.contentHeight - scroller.height,
                                         top + item.height + margin - scroller.height)
        }
    }

    Keys.onUpPressed: moveFocus(false)
    Keys.onDownPressed: moveFocus(true)
    Keys.onLeftPressed: sidebarFocusRequested()
    Keys.onEscapePressed: sidebarFocusRequested()
    Keys.onBackPressed: sidebarFocusRequested()
    Keys.onMenuPressed: menuRequested(header.menuButton, true)
    Keys.onReturnPressed: activateFocused()
    Keys.onEnterPressed: activateFocused()

    function activateFocused() {
        var item = Window.activeFocusItem
        if (item && isWithin(item, pane) && typeof item.clicked === "function") {
            item.clicked()
        }
    }

    Window.onActiveFocusItemChanged: ensureVisible(Window.activeFocusItem)

    HostHeader {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        computer: pane.computer
        onMenuRequested: pane.menuRequested(anchor, viaKeyboard)
    }

    Flickable {
        id: scroller
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        contentHeight: content.implicitHeight + 56
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ScrollBar { }

        ColumnLayout {
            id: content
            x: 32
            y: 28
            width: Math.min(880 - 64, scroller.width - 64)
            spacing: 28

            Loader {
                id: stateLoader
                Layout.fillWidth: true
                visible: item !== null
                focus: pane.hostState !== "apps"
                sourceComponent: pane.hostState === "connecting" ? connectingComponent
                               : pane.hostState === "offline" ? offlineComponent
                               : pane.hostState === "pairing" ? pairingComponent
                               : pane.hostState === "unsupported" ? unsupportedComponent
                               : null

                onLoaded: {
                    if (pane.activeFocus) {
                        Qt.callLater(pane.focusFirst, Qt.TabFocusReason)
                    }
                }
            }

            FocusScope {
                id: appsArea
                Layout.fillWidth: true
                implicitHeight: childrenRect.height
                visible: pane.hostState === "apps"
                focus: pane.hostState === "apps"

                DeskButton {
                    id: showAppsButton
                    focus: true
                    variant: "primary"
                    iconName: "grid"
                    text: qsTr("Show apps")
                    onClicked: pane.showApps()
                }
            }
        }
    }

    onHostStateChanged: {
        if (hostState === "apps" && pane.activeFocus) {
            Qt.callLater(pane.focusFirst, Qt.TabFocusReason)
        }
    }

    onPairingPinChanged: {
        if (pane.activeFocus) {
            Qt.callLater(pane.focusFirst, Qt.TabFocusReason)
        }
    }

    Component {
        id: connectingComponent

        DeskPanel {
            implicitHeight: connectingRow.implicitHeight + 48

            RowLayout {
                id: connectingRow
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                BusyIndicator {
                    implicitWidth: 28
                    implicitHeight: 28
                    padding: 0
                    running: visible
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Connecting…")
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Checking whether this host is online.")
                        font.pixelSize: Theme.fontSmall
                        color: Theme.muted
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    Component {
        id: offlineComponent

        OfflinePanel {
            focus: true
            computer: pane.computer
            onWakeRequested: pane.wakeRequested()
            onWakeHelpRequested: pane.wakeHelpRequested()
        }
    }

    Component {
        id: pairingComponent

        PairingPanel {
            focus: true
            computer: pane.computer
            pin: pane.pairingPin
            otherPairingActive: pane.otherPairingActive
            onPairRequested: pane.pairRequested()
            onCancelRequested: pane.cancelPairingRequested()
        }
    }

    Component {
        id: unsupportedComponent

        DeskPanel {
            implicitHeight: unsupportedRow.implicitHeight + 48

            RowLayout {
                id: unsupportedRow
                anchors.fill: parent
                anchors.margins: 24
                spacing: 24

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 56
                    implicitHeight: 56
                    radius: Theme.radiusPanel
                    color: Theme.selected

                    DeskIcon {
                        anchors.centerIn: parent
                        name: "alert"
                        color: Theme.danger
                        size: 28
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("The version of GeForce Experience on %1 is not supported by this build of Moonlight. You must update Moonlight to stream from %1.")
                          .arg(pane.computer ? pane.computer.name : "")
                    font.pixelSize: Theme.fontBase
                    lineHeight: 1.3
                    color: Theme.mutedStrong
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
