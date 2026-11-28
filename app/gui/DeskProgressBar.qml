import QtQuick 2.14

import DeskTheme 1.0

// Thin indeterminate progress bar: an accent segment sweeping across a track
Rectangle {
    id: bar

    property bool running: visible

    implicitWidth: 200
    implicitHeight: 3
    radius: height / 2
    color: Theme.border
    clip: true

    Rectangle {
        id: segment
        width: Math.max(24, bar.width * 0.3)
        height: bar.height
        radius: bar.radius
        color: Theme.accent
        x: -width

        NumberAnimation on x {
            running: bar.running && bar.width > 0
            loops: Animation.Infinite
            from: -segment.width
            to: bar.width
            duration: 1400
            easing.type: Easing.InOutQuad
        }
    }
}
