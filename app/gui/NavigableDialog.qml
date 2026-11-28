import QtQuick 2.14
import QtQuick.Controls 2.14

DeskDialog {
    id: dialog

    // Whatever had focus when the dialog opened, so closing it can hand focus back
    property Item focusBeforeOpen: null
    property bool focusWasVisual: false
    // Set by the opener when a keyboard or gamepad action opened the dialog
    property bool openedFromKeyboard: false
    // Whether the dialog's own focused control last showed the focus ring. Escape is handled
    // by the popup before the buttons see it, so this is how a keyboard dismissal is noticed.
    property bool ringShownInside: false

    readonly property Item windowFocusItem: window.activeFocusItem
    readonly property bool focusInside: opened && windowFocusItem !== null && isWithin(windowFocusItem, contentItem.parent)
    readonly property bool focusInsideVisual: focusInside && dialog.isKeyboardFocus(windowFocusItem)

    onFocusInsideVisualChanged: {
        // Losing focus also clears visualFocus, so only follow changes while the item keeps focus
        if (focusInside && windowFocusItem.activeFocus) {
            ringShownInside = focusInsideVisual
        }
    }

    onAboutToShow: {
        var item = window.activeFocusItem
        focusBeforeOpen = item
        focusWasVisual = item !== null && isKeyboardFocus(item)
        ringShownInside = false
    }

    onClosed: {
        // Focus must go back to the page or gamepad and keyboard
        // navigation break after a dialog appears
        var target = focusBeforeOpen
        var reason = focusWasVisual || openedFromKeyboard || closedByKeyboard || ringShownInside
                ? Qt.TabFocusReason : Qt.OtherFocusReason
        focusBeforeOpen = null
        openedFromKeyboard = false

        Qt.callLater(function() {
            var current = window.activeFocusItem
            if (dialog.visible || (current && Overlay.overlay && dialog.isWithin(current, Overlay.overlay))) {
                // Reopened, or another popup took focus
                return
            }

            var page = stackView.currentItem
            if (target && target.visible && target.enabled && page && dialog.isWithin(target, page)) {
                if (target.activeFocus && target.focusReason !== undefined) {
                    // Closing the popup may already have handed focus back without a visible reason
                    target.focusReason = reason
                }
                else {
                    target.forceActiveFocus(reason)
                }
            }
            else if (page && typeof page.restoreFocus === "function") {
                page.restoreFocus(reason)
            }
            else if (page) {
                page.forceActiveFocus(reason)
            }
            else {
                stackView.forceActiveFocus(reason)
            }
        })
    }

    // Text fields have no visualFocus, so fall back to how they got focus
    function isKeyboardFocus(item) {
        if (item.visualFocus !== undefined) {
            return item.visualFocus === true
        }
        return item.focusReason === Qt.TabFocusReason || item.focusReason === Qt.BacktabFocusReason
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
}
