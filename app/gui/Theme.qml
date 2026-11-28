pragma Singleton
import QtQuick 2.14

QtObject {
    readonly property color bg: "#111214"
    readonly property color panel: "#18191C"
    readonly property color raised: "#1C1D21"
    readonly property color selected: "#25272C"
    readonly property color border: "#232428"
    readonly property color borderStrong: "#2A2B30"
    readonly property color text: "#ECEDEF"
    readonly property color muted: "#8E9198"
    readonly property color mutedStrong: "#A4A7AE"
    readonly property color accent: "#4ADE80"
    readonly property color accentText: "#0E1A12"
    readonly property color offline: "#5B5E66"
    readonly property color link: "#7CC4FF"
    readonly property color danger: "#F87171"
    readonly property color dialog: "#1A1B1F"
    readonly property color switchTrackOff: "#3A3C42"
    readonly property color knob: "#FFFFFF"
    readonly property color focusGlow: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color scrim: Qt.rgba(5 / 255, 6 / 255, 8 / 255, 0.66)

    readonly property real disabledOpacity: 0.45

    readonly property int radiusControl: 8
    readonly property int radiusPanel: 12
    readonly property int radiusDialog: 14

    readonly property int fontBase: 14
    readonly property int fontTitle: 22
    readonly property int fontSection: 11
    readonly property int fontSmall: 13

    readonly property int controlHeight: 40
    readonly property int rowHeight: 40
}
