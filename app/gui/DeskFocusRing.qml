import QtQuick 2.14

import DeskTheme 1.0

// Drawn around its parent, which should be the target or the target's background.
Rectangle {
    property Item target
    property bool shown: target ? target.visualFocus === true : false
    property real targetRadius: target && target.background && target.background.radius !== undefined
                                ? target.background.radius : Theme.radiusControl
    property int gap: 3
    anchors.fill: parent
    anchors.margins: -gap
    radius: targetRadius + gap
    color: "transparent"
    border.color: Theme.accent
    border.width: 2
    visible: shown
}
