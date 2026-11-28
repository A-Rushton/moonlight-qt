import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14

import DeskTheme 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0

Column {
    id: section

    property int maximumBitrateKbps: 150000

    signal languageChanged()

    spacing: 20

    DeskPanel {
        width: parent.width
        height: streamColumn.height

        Column {
            id: streamColumn
            width: parent.width

            SettingsRow {
                title: qsTr("Resolution")
                hint: qsTr("Setting values too high for your PC or network connection may cause lag, stuttering, or errors.")
                control: AutoResizingComboBox {
                    property int lastIndexValue

                    function addDetectedResolution(friendlyNamePrefix, rect) {
                        var indexToAdd = 0
                        for (var j = 0; j < resolutionComboBox.count; j++) {
                            var existing_width = parseInt(resolutionListModel.get(j).video_width);
                            var existing_height = parseInt(resolutionListModel.get(j).video_height);

                            if (rect.width === existing_width && rect.height === existing_height) {
                                // Duplicate entry, skip
                                indexToAdd = -1
                                break
                            }
                            else if (rect.width * rect.height > existing_width * existing_height) {
                                // Candidate entrypoint after this entry
                                indexToAdd = j + 1
                            }
                        }

                        // Insert this display's resolution if it's not a duplicate
                        if (indexToAdd >= 0) {
                            resolutionListModel.insert(indexToAdd,
                                                       {
                                                           "text": friendlyNamePrefix+" ("+rect.width+"x"+rect.height+")",
                                                           "video_width": ""+rect.width,
                                                           "video_height": ""+rect.height,
                                                           "is_custom": false
                                                       })
                        }
                    }

                    // ignore setting the index at first, and actually set it when the component is loaded
                    Component.onCompleted: {
                        // Refresh display data before using it to build the list
                        SystemProperties.refreshDisplays()

                        // Add native and safe area resolutions for all attached displays
                        var done = false
                        for (var displayIndex = 0; !done; displayIndex++) {
                            var screenRect = SystemProperties.getNativeResolution(displayIndex);
                            var safeAreaRect = SystemProperties.getSafeAreaResolution(displayIndex);

                            if (screenRect.width === 0) {
                                // Exceeded max count of displays
                                done = true
                                break
                            }

                            addDetectedResolution(qsTr("Native"), screenRect)
                            addDetectedResolution(qsTr("Native (Excluding Notch)"), safeAreaRect)
                        }

                        // Prune resolutions that are over the decoder's maximum
                        var max_pixels = SystemProperties.maximumResolution.width * SystemProperties.maximumResolution.height;
                        if (max_pixels > 0) {
                            for (var j = 0; j < resolutionComboBox.count; j++) {
                                var existing_width = parseInt(resolutionListModel.get(j).video_width);
                                var existing_height = parseInt(resolutionListModel.get(j).video_height);

                                if (existing_width * existing_height > max_pixels) {
                                    resolutionListModel.remove(j)
                                    j--
                                }
                            }
                        }

                        // load the saved width/height, and iterate through the ComboBox until a match is found
                        // and set it to that index.
                        var saved_width = StreamingPreferences.width
                        var saved_height = StreamingPreferences.height
                        var index_set = false
                        for (var i = 0; i < resolutionListModel.count; i++) {
                            var el_width = parseInt(resolutionListModel.get(i).video_width);
                            var el_height = parseInt(resolutionListModel.get(i).video_height);

                            if (saved_width === el_width && saved_height === el_height) {
                                currentIndex = i
                                index_set = true
                                break
                            }
                        }

                        if (!index_set) {
                            // We did not find a match. This must be a custom resolution.
                            resolutionListModel.append({
                                                           "text": qsTr("Custom")+" ("+StreamingPreferences.width+"x"+StreamingPreferences.height+")",
                                                           "video_width": ""+StreamingPreferences.width,
                                                           "video_height": ""+StreamingPreferences.height,
                                                           "is_custom": true
                                                       })
                            currentIndex = resolutionListModel.count - 1
                        }
                        else {
                            resolutionListModel.append({
                                                           "text": qsTr("Custom"),
                                                           "video_width": "",
                                                           "video_height": "",
                                                           "is_custom": true
                                                       })
                        }

                        // Since we don't call activate() here, we need to trigger
                        // width calculation manually
                        recalculateWidth()

                        lastIndexValue = currentIndex
                    }

                    id: resolutionComboBox
                    textRole: "text"
                    model: ListModel {
                        id: resolutionListModel
                        // Other elements may be added at runtime
                        // based on attached display resolution
                        ListElement {
                            text: qsTr("720p")
                            video_width: "1280"
                            video_height: "720"
                            is_custom: false
                        }
                        ListElement {
                            text: qsTr("1080p")
                            video_width: "1920"
                            video_height: "1080"
                            is_custom: false
                        }
                        ListElement {
                            text: qsTr("1440p")
                            video_width: "2560"
                            video_height: "1440"
                            is_custom: false
                        }
                        ListElement {
                            text: qsTr("4K")
                            video_width: "3840"
                            video_height: "2160"
                            is_custom: false
                        }
                    }

                    function updateBitrateForSelection() {
                        var selectedWidth = parseInt(resolutionListModel.get(currentIndex).video_width)
                        var selectedHeight = parseInt(resolutionListModel.get(currentIndex).video_height)

                        // Only modify the bitrate if the values actually changed
                        if (StreamingPreferences.width !== selectedWidth || StreamingPreferences.height !== selectedHeight) {
                            StreamingPreferences.width = selectedWidth
                            StreamingPreferences.height = selectedHeight

                            if (StreamingPreferences.autoAdjustBitrate) {
                                StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                          StreamingPreferences.height,
                                                                                                          StreamingPreferences.fps,
                                                                                                          StreamingPreferences.enableYUV444);
                            }
                        }

                        lastIndexValue = currentIndex
                    }

                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated : {
                        if (resolutionListModel.get(currentIndex).is_custom) {
                            customResolutionDialog.open()
                        }
                        else {
                            updateBitrateForSelection()
                        }
                    }

                    NavigableDialog {
                        id: customResolutionDialog
                        standardButtons: Dialog.Ok | Dialog.Cancel
                        onOpened: {
                            // Force keyboard focus on the textbox so keyboard navigation works
                            widthField.forceActiveFocus()

                            // standardButton() was added in Qt 5.10, so we must check for it first
                            if (customResolutionDialog.standardButton) {
                                customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                            }
                        }

                        onClosed: {
                            widthField.clear()
                            heightField.clear()
                        }

                        onRejected: {
                            resolutionComboBox.currentIndex = resolutionComboBox.lastIndexValue
                        }

                        function isInputValid() {
                            // If we have text in either textbox that isn't valid,
                            // reject the input.
                            if ((!widthField.acceptableInput && widthField.text) ||
                                    (!heightField.acceptableInput && heightField.text)) {
                                return false
                            }

                            // The textboxes need to have text or placeholder text
                            if ((!widthField.text && !widthField.placeholderText) ||
                                    (!heightField.text && !heightField.placeholderText)) {
                                return false
                            }

                            return true
                        }

                        onAccepted: {
                            // Reject if there's invalid input
                            if (!isInputValid()) {
                                reject()
                                return
                            }

                            var width = widthField.text ? widthField.text : widthField.placeholderText
                            var height = heightField.text ? heightField.text : heightField.placeholderText

                            // Find and update the custom entry
                            for (var i = 0; i < resolutionListModel.count; i++) {
                                if (resolutionListModel.get(i).is_custom) {
                                    resolutionListModel.setProperty(i, "video_width", width)
                                    resolutionListModel.setProperty(i, "video_height", height)
                                    resolutionListModel.setProperty(i, "text", "Custom ("+width+"x"+height+")")

                                    // Now update the bitrate using the custom resolution
                                    resolutionComboBox.currentIndex = i
                                    resolutionComboBox.updateBitrateForSelection()

                                    // Update the combobox width too
                                    resolutionComboBox.recalculateWidth()
                                    break
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 12

                            Label {
                                text: qsTr("Custom resolutions are not officially supported by GeForce Experience, so it will not set your host display resolution. You will need to set it manually while in game.") + "\n\n" +
                                      qsTr("Resolutions that are not supported by your client or host PC may cause streaming errors.")
                                wrapMode: Label.WordWrap
                                color: Theme.mutedStrong
                                Layout.maximumWidth: 360
                            }

                            Label {
                                text: qsTr("Enter a custom resolution:")
                                font.bold: true
                                color: Theme.text
                            }

                            RowLayout {
                                spacing: 10

                                DeskTextField {
                                    id: widthField
                                    implicitWidth: 120
                                    maximumLength: 5
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    placeholderText: resolutionListModel.get(resolutionComboBox.currentIndex).video_width
                                    validator: IntValidator{bottom:256; top:8192}
                                    focus: true

                                    onTextChanged: {
                                        // standardButton() was added in Qt 5.10, so we must check for it first
                                        if (customResolutionDialog.standardButton) {
                                            customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                        }
                                    }

                                    Keys.onReturnPressed: {
                                        customResolutionDialog.accept()
                                    }

                                    Keys.onEnterPressed: {
                                        customResolutionDialog.accept()
                                    }
                                }

                                Label {
                                    text: "x"
                                    font.bold: true
                                    color: Theme.text
                                }

                                DeskTextField {
                                    id: heightField
                                    implicitWidth: 120
                                    maximumLength: 5
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    placeholderText: resolutionListModel.get(resolutionComboBox.currentIndex).video_height
                                    validator: IntValidator{bottom:256; top:8192}

                                    onTextChanged: {
                                        // standardButton() was added in Qt 5.10, so we must check for it first
                                        if (customResolutionDialog.standardButton) {
                                            customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                        }
                                    }

                                    Keys.onReturnPressed: {
                                        customResolutionDialog.accept()
                                    }

                                    Keys.onEnterPressed: {
                                        customResolutionDialog.accept()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SettingsRow {
                title: qsTr("Frame rate")
                control: AutoResizingComboBox {
                    property int lastIndexValue

                    function updateBitrateForSelection() {
                        // Only modify the bitrate if the values actually changed
                        var selectedFps = parseInt(model.get(fpsComboBox.currentIndex).video_fps)
                        if (StreamingPreferences.fps !== selectedFps) {
                            StreamingPreferences.fps = selectedFps

                            if (StreamingPreferences.autoAdjustBitrate) {
                                StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                          StreamingPreferences.height,
                                                                                                          StreamingPreferences.fps,
                                                                                                          StreamingPreferences.enableYUV444);
                            }
                        }

                        lastIndexValue = currentIndex
                    }

                    NavigableDialog {
                        function isInputValid() {
                            // If we have text that isn't valid, reject the input.
                            if (!fpsField.acceptableInput && fpsField.text) {
                                return false
                            }

                            // The textbox needs to have text or placeholder text
                            if (!fpsField.text && !fpsField.placeholderText) {
                                return false
                            }

                            return true
                        }

                        id: customFpsDialog
                        standardButtons: Dialog.Ok | Dialog.Cancel
                        onOpened: {
                            // Force keyboard focus on the textbox so keyboard navigation works
                            fpsField.forceActiveFocus()

                            // standardButton() was added in Qt 5.10, so we must check for it first
                            if (customFpsDialog.standardButton) {
                                customFpsDialog.standardButton(Dialog.Ok).enabled = customFpsDialog.isInputValid()
                            }
                        }

                        onClosed: {
                            fpsField.clear()
                        }

                        onRejected: {
                            fpsComboBox.currentIndex = fpsComboBox.lastIndexValue
                        }

                        onAccepted: {
                            // Reject if there's invalid input
                            if (!isInputValid()) {
                                reject()
                                return
                            }

                            var fps = fpsField.text ? fpsField.text : fpsField.placeholderText

                            // Find and update the custom entry
                            for (var i = 0; i < fpsListModel.count; i++) {
                                if (fpsListModel.get(i).is_custom) {
                                    fpsListModel.setProperty(i, "video_fps", fps)
                                    fpsListModel.setProperty(i, "text", qsTr("Custom (%1 FPS)").arg(fps))

                                    // Now update the bitrate using the custom resolution
                                    fpsComboBox.currentIndex = i
                                    fpsComboBox.updateBitrateForSelection()

                                    // Update the combobox width too
                                    fpsComboBox.recalculateWidth()
                                    break
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 12

                            Label {
                                text: qsTr("Enter a custom frame rate:")
                                font.bold: true
                                color: Theme.text
                            }

                            DeskTextField {
                                id: fpsField
                                implicitWidth: 120
                                maximumLength: 4
                                inputMethodHints: Qt.ImhDigitsOnly
                                placeholderText: fpsListModel.get(fpsComboBox.currentIndex).video_fps
                                validator: IntValidator{bottom:10; top:9999}
                                focus: true

                                onTextChanged: {
                                    // standardButton() was added in Qt 5.10, so we must check for it first
                                    if (customFpsDialog.standardButton) {
                                        customFpsDialog.standardButton(Dialog.Ok).enabled = customFpsDialog.isInputValid()
                                    }
                                }

                                Keys.onReturnPressed: {
                                    customFpsDialog.accept()
                                }

                                Keys.onEnterPressed: {
                                    customFpsDialog.accept()
                                }
                            }
                        }
                    }

                    function addRefreshRateOrdered(fpsListModel, refreshRate, description, custom) {
                        var indexToAdd = 0
                        for (var j = 0; j < fpsListModel.count; j++) {
                            var existing_fps = parseInt(fpsListModel.get(j).video_fps);

                            if (refreshRate === existing_fps || (custom && fpsListModel.get(j).is_custom)) {
                                // Duplicate entry, skip
                                indexToAdd = -1
                                break
                            }
                            else if (refreshRate > existing_fps) {
                                // Candidate entrypoint after this entry
                                indexToAdd = j + 1
                            }
                        }

                        // Insert this frame rate if it's not a duplicate
                        if (indexToAdd >= 0) {
                            // Custom values always go at the end of the list
                            if (custom) {
                                indexToAdd = fpsListModel.count
                            }

                            fpsListModel.insert(indexToAdd,
                                                {
                                                    "text": description,
                                                    "video_fps": ""+refreshRate,
                                                    "is_custom": custom
                                                })
                        }

                        return indexToAdd
                    }

                    function reinitialize() {
                        // Add native refresh rate for all attached displays
                        var done = false
                        for (var displayIndex = 0; !done; displayIndex++) {
                            var refreshRate = SystemProperties.getRefreshRate(displayIndex);
                            if (refreshRate === 0) {
                                // Exceeded max count of displays
                                done = true
                                break
                            }

                            addRefreshRateOrdered(fpsListModel, refreshRate, qsTr("%1 FPS").arg(refreshRate), false)
                        }

                        var saved_fps = StreamingPreferences.fps
                        var found = false
                        for (var i = 0; i < model.count; i++) {
                            var el_fps = parseInt(model.get(i).video_fps);

                            // Look for a matching frame rate
                            if (saved_fps === el_fps) {
                                currentIndex = i
                                found = true
                                break
                            }
                        }

                        // If we didn't find one, add a custom frame rate for the current value
                        if (!found) {
                            currentIndex = addRefreshRateOrdered(model, saved_fps, qsTr("Custom (%1 FPS)").arg(saved_fps), true)
                        }
                        else {
                            addRefreshRateOrdered(model, "", qsTr("Custom"), true)
                        }

                        recalculateWidth()

                        lastIndexValue = currentIndex
                    }

                    // ignore setting the index at first, and actually set it when the component is loaded
                    Component.onCompleted: {
                        reinitialize()
                        section.languageChanged.connect(reinitialize)
                    }

                    model: ListModel {
                        id: fpsListModel
                        // Other elements may be added at runtime
                        ListElement {
                            text: qsTr("30 FPS")
                            video_fps: "30"
                            is_custom: false
                        }
                        ListElement {
                            text: qsTr("60 FPS")
                            video_fps: "60"
                            is_custom: false
                        }
                    }

                    id: fpsComboBox
                    textRole: "text"
                    // ::onActivated must be used, as it only listens for when the index is changed by a human
                    onActivated : {
                        if (model.get(currentIndex).is_custom) {
                            customFpsDialog.open()
                        }
                        else {
                            updateBitrateForSelection()
                        }
                    }
                }
            }

            SettingsRow {
                stacked: true
                title: qsTr("Video bitrate: %1 Mbps").arg(slider.value / 1000.0)
                hint: qsTr("Lower the bitrate on slower connections. Raise the bitrate to increase image quality.")
                control: RowLayout {
                    spacing: 16

                    DeskSlider {
                        id: slider
                        Layout.fillWidth: true

                        value: StreamingPreferences.bitrateKbps

                        stepSize: 500
                        from : 500
                        to: section.maximumBitrateKbps

                        snapMode: Slider.SnapOnRelease

                        onValueChanged: {
                            StreamingPreferences.bitrateKbps = value
                        }

                        onMoved: {
                            StreamingPreferences.autoAdjustBitrate = false
                        }
                    }

                    DeskButton {
                        id: resetBitrateButton
                        text: qsTr("Use Default (%1 Mbps)").arg(StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444) / 1000.0)
                        visible: StreamingPreferences.bitrateKbps !== StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444)
                        onClicked: {
                            var defaultBitrate = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width, StreamingPreferences.height, StreamingPreferences.fps, StreamingPreferences.enableYUV444)
                            StreamingPreferences.bitrateKbps = defaultBitrate
                            StreamingPreferences.autoAdjustBitrate = true
                        }
                    }
                }
            }

            SettingsRow {
                visible: SystemProperties.hasDesktopEnvironment
                title: qsTr("Display mode")
                hint: qsTr("Fullscreen generally provides the best performance, but borderless windowed may work better with features like macOS Spaces, Alt+Tab, screenshot tools, on-screen overlays, etc.")
                control: AutoResizingComboBox {
                    function createModel() {
                        var model = Qt.createQmlObject('import QtQuick 2.0; ListModel {}', parent, '')

                        model.append({
                                         text: qsTr("Fullscreen"),
                                         val: StreamingPreferences.WM_FULLSCREEN
                                     })

                        model.append({
                                         text: qsTr("Borderless windowed"),
                                         val: StreamingPreferences.WM_FULLSCREEN_DESKTOP
                                     })

                        model.append({
                                         text: qsTr("Windowed"),
                                         val: StreamingPreferences.WM_WINDOWED
                                     })


                        // Set the recommended option based on the OS
                        for (var i = 0; i < model.count; i++) {
                            var thisWm = model.get(i).val;
                            if (thisWm === StreamingPreferences.recommendedFullScreenMode) {
                                model.get(i).text += " " + qsTr("(Recommended)")
                                model.move(i, 0, 1)
                                break
                            }
                        }

                        return model
                    }

                    // This is used on initialization and upon retranslation
                    function reinitialize() {
                        if (!SystemProperties.hasDesktopEnvironment) {
                            // Do nothing if the control won't even be visible
                            return
                        }

                        model = createModel()
                        currentIndex = 0

                        // Set the current value based on the saved preferences
                        var savedWm = StreamingPreferences.windowMode
                        for (var i = 0; i < model.count; i++) {
                             var thisWm = model.get(i).val;
                             if (savedWm === thisWm) {
                                 currentIndex = i
                                 break
                             }
                        }

                        activated(currentIndex)
                    }

                    Component.onCompleted: {
                        reinitialize()
                        section.languageChanged.connect(reinitialize)
                    }

                    id: windowModeComboBox
                    enabled: !SystemProperties.rendererAlwaysFullScreen
                    textRole: "text"
                    onActivated: {
                        StreamingPreferences.windowMode = model.get(currentIndex).val
                    }
                }
            }
        }
    }

    DeskPanel {
        width: parent.width
        height: renderColumn.height

        Column {
            id: renderColumn
            width: parent.width

            SettingsRow {
                title: qsTr("V-Sync")
                hint: qsTr("Disabling V-Sync allows sub-frame rendering latency, but it can display visible tearing")
                control: DeskSwitch {
                    id: vsyncCheck
                    checked: StreamingPreferences.enableVsync
                    onCheckedChanged: {
                        StreamingPreferences.enableVsync = checked
                    }
                }
            }

            SettingsRow {
                title: qsTr("Frame pacing")
                hint: qsTr("Frame pacing reduces micro-stutter by delaying frames that come in too early")
                control: DeskSwitch {
                    id: framePacingCheck
                    enabled: StreamingPreferences.enableVsync
                    checked: StreamingPreferences.enableVsync && StreamingPreferences.framePacing
                    onCheckedChanged: {
                        StreamingPreferences.framePacing = checked
                    }
                }
            }

            SettingsRow {
                title: qsTr("Enable HDR")
                hint: enableHdr.enabled ?
                          qsTr("The stream will be HDR-capable, but some games may require an HDR monitor on your host PC to enable HDR mode.")
                        :
                          qsTr("HDR streaming is not supported on this PC.")
                control: DeskSwitch {
                    id: enableHdr

                    enabled: SystemProperties.supportsHdr
                    checked: enabled && StreamingPreferences.enableHdr
                    onCheckedChanged: {
                        StreamingPreferences.enableHdr = checked
                    }
                }
            }
        }
    }
}
