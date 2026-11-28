import QtQuick 2.14
import QtQuick.Controls 2.14

import ComputerManager 1.0

Item {
    function onSearchingComputer() {
        stagePanel.text = qsTr("Establishing connection to PC...")
    }

    function onPairing(pcName, pin) {
        stagePanel.text = qsTr("Pairing... Please enter '%1' on %2.").arg(pin).arg(pcName)
    }

    function onFailed(message) {
        stagePanel.busy = false
        errorDialog.text = message
        errorDialog.open()
    }

    function onSuccess(appName) {
        stagePanel.busy = false
        pairCompleteDialog.open()
    }

    // Allow user to back out of pairing
    Keys.onEscapePressed: {
        Qt.quit()
    }
    Keys.onBackPressed: {
        Qt.quit()
    }
    Keys.onCancelPressed: {
        Qt.quit()
    }

    StackView.onActivated: {
        if (!launcher.isExecuted()) {
            launcher.searchingComputer.connect(onSearchingComputer)
            launcher.pairing.connect(onPairing)
            launcher.failed.connect(onFailed)
            launcher.success.connect(onSuccess)
            launcher.execute(ComputerManager)
        }
    }

    SeguePanel {
        id: stagePanel
    }

    ErrorMessageDialog {
        id: errorDialog

        onClosed: {
            Qt.quit();
        }
    }

    NavigableMessageDialog {
        id: pairCompleteDialog
        closePolicy: Popup.CloseOnEscape

        text:qsTr("Pairing completed successfully")
        standardButtons: Dialog.Ok
        onClosed: {
            Qt.quit()
        }
    }
}
