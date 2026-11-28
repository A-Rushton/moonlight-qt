import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14

import DeskTheme 1.0
import StreamingPreferences 1.0
import SdlGamepadKeyNavigation 1.0
import SystemProperties 1.0

FocusScope {
    id: settingsPage
    objectName: qsTr("Settings")

    property int currentSection: 0
    readonly property var sectionTitles: [qsTr("Video"), qsTr("Audio"), qsTr("Microphone"), qsTr("Input"),
                                          qsTr("Controllers"), qsTr("Host"), qsTr("Interface"), qsTr("Advanced")]
    readonly property int maximumBitrateKbps: StreamingPreferences.unlockBitrate ? 500000 : 150000

    // Which side has keyboard focus, so leaving the content always lands on its section button
    property string focusArea: "nav"

    signal languageChanged()

    StackView.onActivated: {
        // Gamepad D-pad up/down sends Tab/Backtab while settings are shown,
        // which moves focus between the controls of a section
        SdlGamepadKeyNavigation.setUiNavMode(true)

        // Highlight the current section if a gamepad is connected
        focusNav(SdlGamepadKeyNavigation.getConnectedGamepads() > 0 ? Qt.TabFocusReason : Qt.OtherFocusReason)
    }

    StackView.onDeactivating: {
        SdlGamepadKeyNavigation.setUiNavMode(false)

        // Save the prefs so the Session can observe the changes
        StreamingPreferences.save()
    }

    Component.onDestruction: {
        // Also save preferences on destruction, since we won't get a
        // deactivating callback if the user just closes Moonlight
        StreamingPreferences.save()
    }

    onCurrentSectionChanged: scroller.contentY = 0

    function isWithin(item, ancestor) {
        while (item) {
            if (item === ancestor) {
                return true
            }
            item = item.parent
        }
        return false
    }

    function currentSectionItem() {
        return sections.children[currentSection]
    }

    function focusNav(reason) {
        focusArea = "nav"
        sectionButtons.itemAt(currentSection).forceActiveFocus(reason)
    }

    function selectSection(index, reason) {
        currentSection = index
        focusNav(reason)
    }

    function moveNav(delta, enterAtEnd) {
        var focused = Window.activeFocusItem
        var reason = delta > 0 ? Qt.TabFocusReason : Qt.BacktabFocusReason
        if (focused === backItem) {
            if (delta > 0) {
                selectSection(0, reason)
            }
            return
        }

        for (var i = 0; i < sectionButtons.count; i++) {
            if (sectionButtons.itemAt(i) === focused) {
                var target = i + delta
                if (target < 0) {
                    backItem.forceActiveFocus(reason)
                }
                else if (target < sectionButtons.count) {
                    selectSection(target, reason)
                }
                else if (enterAtEnd) {
                    enterSection()
                }
                return
            }
        }
    }

    function focusedSectionIndex() {
        for (var i = 0; i < sectionButtons.count; i++) {
            if (sectionButtons.itemAt(i).activeFocus) {
                return i
            }
        }
        return -1
    }

    function enterSection() {
        var focused = focusedSectionIndex()
        if (focused >= 0) {
            currentSection = focused
        }

        var item = contentGate.nextItemInFocusChain(true)
        if (item && isWithin(item, currentSectionItem())) {
            focusArea = "content"
            item.forceActiveFocus(Qt.TabFocusReason)
        }
    }

    function activateNav() {
        if (backItem.activeFocus) {
            window.goBack()
        }
        else {
            enterSection()
        }
    }

    function moveContent(forward) {
        var current = Window.activeFocusItem
        var next = current ? current.nextItemInFocusChain(forward) : null
        if (next && next !== current && isWithin(next, currentSectionItem())) {
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
        }
        else if (!forward) {
            focusNav(Qt.BacktabFocusReason)
        }
    }

    function ensureVisible(item) {
        if (!item || !isWithin(item, contentScope)) {
            return
        }

        var top = item.mapToItem(scroller.contentItem, 0, 0).y
        var margin = scroller.height > 200 ? 48 : 0
        if (top - margin < scroller.contentY) {
            scroller.contentY = Math.max(0, top - margin)
        }
        else if (top + item.height + margin > scroller.contentY + scroller.height) {
            scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height,
                                                     top + item.height + margin - scroller.height))
        }
    }

    Window.onActiveFocusItemChanged: ensureVisible(Window.activeFocusItem)

    Rectangle {
        id: nav
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 240
        color: Theme.panel

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Theme.border
        }

        FocusScope {
            id: navScope
            anchors.fill: parent
            focus: true

            onActiveFocusChanged: {
                if (activeFocus) {
                    settingsPage.focusArea = "nav"
                }
            }

            Keys.onUpPressed: settingsPage.moveNav(-1, false)
            Keys.onDownPressed: settingsPage.moveNav(1, false)
            Keys.onRightPressed: settingsPage.enterSection()
            Keys.onReturnPressed: settingsPage.activateNav()
            Keys.onEnterPressed: settingsPage.activateNav()

            Column {
                x: 12
                y: 18
                width: parent.width - 24
                spacing: 2

                DeskSidebarItem {
                    id: backItem
                    width: parent.width
                    height: 36
                    iconName: "chevron-left"
                    text: qsTr("Back to library")
                    font.weight: Font.Normal

                    onClicked: window.goBack()

                    Keys.onTabPressed: settingsPage.moveNav(1, true)
                }

                Item {
                    width: parent.width
                    height: 12
                }

                Text {
                    width: parent.width
                    leftPadding: 10
                    topPadding: 6
                    bottomPadding: 6
                    text: qsTr("Settings")
                    font.pixelSize: Theme.fontSection
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.9
                    font.capitalization: Font.AllUppercase
                    color: Theme.muted
                }

                Repeater {
                    id: sectionButtons
                    model: settingsPage.sectionTitles

                    DeskSidebarItem {
                        width: parent.width
                        height: 36
                        text: modelData
                        selected: index === settingsPage.currentSection

                        onClicked: settingsPage.currentSection = index

                        Keys.onTabPressed: settingsPage.moveNav(1, true)
                        Keys.onBacktabPressed: settingsPage.moveNav(-1, true)
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.bottomMargin: 18
                text: qsTr("Version %1").arg(SystemProperties.versionString)
                font.pixelSize: Theme.fontSmall
                color: Theme.muted
                elide: Text.ElideRight
            }
        }
    }

    // Sits between the nav and the content in the Tab chain, so moving backwards
    // out of a section returns to its button and moving forwards enters it
    Item {
        id: contentGate
        activeFocusOnTab: true

        onActiveFocusChanged: {
            if (!activeFocus) {
                return
            }
            if (settingsPage.focusArea === "content") {
                settingsPage.focusNav(Qt.BacktabFocusReason)
            }
            else {
                settingsPage.enterSection()
            }
        }
    }

    Flickable {
        id: scroller
        anchors.left: nav.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        contentHeight: contentScope.y + contentScope.height + 48
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ScrollBar { }

        FocusScope {
            id: contentScope
            x: 40
            y: 32
            width: Math.max(0, Math.min(720, scroller.width - 80))
            height: contentColumn.height

            onActiveFocusChanged: {
                if (activeFocus) {
                    settingsPage.focusArea = "content"
                }
            }

            Keys.onUpPressed: settingsPage.moveContent(false)
            Keys.onDownPressed: settingsPage.moveContent(true)
            Keys.onLeftPressed: settingsPage.focusNav(Qt.BacktabFocusReason)
            Keys.onEscapePressed: settingsPage.focusNav(Qt.BacktabFocusReason)
            Keys.onBackPressed: settingsPage.focusNav(Qt.BacktabFocusReason)

            Column {
                id: contentColumn
                width: parent.width
                spacing: 24

                Text {
                    width: parent.width
                    text: settingsPage.sectionTitles[settingsPage.currentSection]
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                    color: Theme.text
                    elide: Text.ElideRight
                }

                StackLayout {
                    id: sections
                    width: parent.width
                    height: settingsPage.currentSectionItem() ? settingsPage.currentSectionItem().implicitHeight : 0
                    currentIndex: settingsPage.currentSection

                    SettingsVideo {
                        id: videoSection
                        maximumBitrateKbps: settingsPage.maximumBitrateKbps
                    }

                    SettingsAudio { }

                    SettingsMicrophone { }

                    SettingsInput { }

                    SettingsControllers { }

                    SettingsHost { }

                    SettingsInterface {
                        onLanguageChanged: {
                            videoSection.languageChanged()
                            settingsPage.languageChanged()
                        }
                    }

                    SettingsAdvanced {
                        maximumBitrateKbps: settingsPage.maximumBitrateKbps
                    }
                }
            }
        }
    }
}
