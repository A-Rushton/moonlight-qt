import QtQuick 2.14
import QtQuick.Controls 2.14

import SdlGamepadKeyNavigation 1.0

// https://stackoverflow.com/questions/45029968/how-do-i-set-the-combobox-width-to-fit-the-largest-item
DeskComboBox {
    id: control

    property int textWidth
    // The indicator's space is included in the padding
    property int desiredWidth : leftPadding + textWidth + rightPadding
    property int maximumWidth : parent.width

    implicitWidth: desiredWidth < maximumWidth ? desiredWidth : maximumWidth

    TextMetrics {
        id: popupMetrics
    }

    TextMetrics {
        id: textMetrics
    }

    function recalculateWidth() {
        textMetrics.font = font
        popupMetrics.font = popup.font
        textWidth = 0
        for (var i = 0; i < count; i++){
            textMetrics.text = textAt(i)
            popupMetrics.text = textAt(i)
            textWidth = Math.max(Math.ceil(textMetrics.advanceWidth), textWidth)
            textWidth = Math.max(Math.ceil(popupMetrics.advanceWidth), textWidth)
        }
    }

    // We call this every time the options change (and init)
    // so we can adjust the combo box width here too
    onActivated: recalculateWidth()

    popup.onAboutToShow: {
        // Switch to normal navigation for combo boxes
        SdlGamepadKeyNavigation.setUiNavMode(false)
    }

    popup.onAboutToHide: {
        SdlGamepadKeyNavigation.setUiNavMode(true)
    }

    // Up/Down move to the neighbouring control like the rest of the page; Left/Right change the value.
    // ComboBox consumes Up/Down itself, so hand them to the page's own navigation when it has one,
    // which keeps focus inside the current settings section.
    function moveFocus(forward) {
        for (var item = parent; item; item = item.parent) {
            if (typeof item.moveContent === "function") {
                item.moveContent(forward)
                return
            }
        }

        var next = nextItemInFocusChain(forward)
        if (next && next !== control) {
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
        }
    }

    Keys.onUpPressed: moveFocus(false)
    Keys.onDownPressed: moveFocus(true)

    Keys.onLeftPressed: {
        decrementCurrentIndex()
    }

    Keys.onRightPressed: {
        incrementCurrentIndex()
    }
}
