import QtQuick 2.14
import QtQuick.Window 2.14

import DeskTheme 1.0

Image {
    property string name
    property color color: Theme.mutedStrong
    property int size: 18

    width: size
    height: size
    sourceSize.width: Math.ceil(size * Screen.devicePixelRatio)
    sourceSize.height: Math.ceil(size * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectFit
    source: name ? "image://deskicon/" + name + "/" + color.toString().slice(-6) : ""
}
