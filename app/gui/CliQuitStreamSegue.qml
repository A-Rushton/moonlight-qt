import QtQuick 2.14
import QtQuick.Controls 2.14

import ComputerManager 1.0
import Session 1.0

Item {
    function onSearchingComputer() {
        stagePanel.text = qsTr("Establishing connection to PC...")
    }

    function onQuittingApp() {
        stagePanel.text = qsTr("Quitting app...")
    }

    function onFailure(message) {
        errorDialog.text = message
        errorDialog.open()
    }

    StackView.onActivated: {
        if (!launcher.isExecuted()) {
            launcher.searchingComputer.connect(onSearchingComputer)
            launcher.quittingApp.connect(onQuittingApp)
            launcher.failed.connect(onFailure)
            launcher.execute(ComputerManager)
        }
    }

    SeguePanel {
        id: stagePanel
    }

    ErrorMessageDialog {
        id: errorDialog

        onClosed: {
            Qt.quit()
        }
    }
}
