import QtQuick 2.0
import QtQuick.Controls 2.5

DeskDialog {
    onClosed: {
        // We must force focus back to the last item. If we don't,
        // gamepad and keyboard navigation will break after a
        // dialog appears.
        stackView.forceActiveFocus()
    }
}
