import QtQuick 2.14
import QtQuick.Controls 2.14

import SystemProperties 1.0

NavigableMessageDialog {
    standardButtons: Dialog.Ok | (SystemProperties.hasBrowser ? Dialog.Help : 0)
}
