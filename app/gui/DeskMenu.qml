import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.14

import DeskTheme 1.0

Menu {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    margins: 8
    padding: 4
    overlap: 4

    font.pixelSize: Theme.fontBase

    delegate: DeskMenuItem { }

    contentItem: ListView {
        implicitHeight: contentHeight
        model: control.contentModel
        interactive: Window.window ? contentHeight + control.topPadding + control.bottomPadding > control.height : false
        clip: true
        currentIndex: control.currentIndex

        ScrollIndicator.vertical: ScrollIndicator { }
    }

    background: Rectangle {
        implicitWidth: 220
        implicitHeight: 36
        radius: Theme.radiusControl
        color: Theme.raised
        border.width: 1
        border.color: Theme.borderStrong
    }
}
