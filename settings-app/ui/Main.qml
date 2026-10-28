/*
 * Main.qml - the Hue Desk Settings window.
 *
 * Left: the settings. Right: a live preview built from the installed
 * plasmoid's own QML, so what you see is the real widget, not a mock-up of it.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: win

    width: 1000
    height: 700
    minimumWidth: 720
    minimumHeight: 560
    visible: true
    title: "Hue Desk Settings"

    readonly property var cfg: backend.settings

    // The backend loads its settings before this window exists, so the first
    // settingsChanged is missed. Ask again once the controls are up.
    Component.onCompleted: backend.reload()

    // Guards against the controls writing back while they are being populated.
    property bool loading: false

    function apply(key, value) {
        if (!loading) {
            backend.setValue(key, value)
        }
    }

    Connections {
        target: backend
        function onSettingsChanged() {
            win.loading = true
            themeBox.currentIndex = themeBox.indexOfValue(cfg.themeMode)
            densityBox.currentIndex = densityBox.indexOfValue(cfg.density)
            fontBox.currentIndex = Math.max(0, fontBox.model.indexOf(
                cfg.fontFamily === "" ? backend.defaultFontLabel() : cfg.fontFamily))
            scaleSlider.value = cfg.fontScale
            radiusSlider.value = cfg.cornerRadius
            opacitySlider.value = cfg.cardOpacity
            headerCheck.checked = cfg.showHeader
            lightsCheck.checked = cfg.showLights
            scenesCheck.checked = cfg.showScenes
            zonesCheck.checked = cfg.showZones
            tintCheck.checked = cfg.accentTint
            ipField.text = cfg.bridgeIp
            pollSpin.value = cfg.pollInterval
            win.loading = false
            preview.rebuild()
        }
        function onWidgetsChanged() {
            var g = backend.geometry
            xSpin.value = Math.round(g.x)
            ySpin.value = Math.round(g.y)
            wSpin.value = Math.max(wSpin.from, Math.round(g.width))
            hSpin.value = Math.max(hSpin.from, Math.round(g.height))
        }
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            Label {
                text: "Hue Desk"
                font.bold: true
                font.pixelSize: 16
            }

            Label {
                text: backend.widgets.length === 0
                      ? "not on your desktop"
                      : backend.widgets.length + " on your desktop"
                opacity: 0.6
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Add to desktop"
                visible: backend.widgets.length === 0
                onClicked: backend.addToDesktop()
            }

            ToolButton {
                text: "Reload"
                onClicked: backend.reload()
            }
        }
    }

    footer: ToolBar {
        visible: backend.status !== ""
        Label {
            anchors.fill: parent
            anchors.margins: 8
            text: backend.status
            elide: Text.ElideRight
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // -- settings ------------------------------------------------------
        ScrollView {
            id: settingsScroll
            Layout.preferredWidth: 480
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: settingsScroll.availableWidth
                spacing: 18

                // Appearance ------------------------------------------------
                GroupBox {
                    title: "Appearance"
                    Layout.fillWidth: true
                    Layout.margins: 14

                    GridLayout {
                        anchors.fill: parent
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 10

                        Label { text: "Theme" }
                        ComboBox {
                            id: themeBox
                            Layout.fillWidth: true
                            textRole: "label"
                            valueRole: "value"
                            model: [
                                { label: "Follow desktop", value: "auto" },
                                { label: "Light", value: "light" },
                                { label: "Dark", value: "dark" }
                            ]
                            onActivated: win.apply("themeMode", currentValue)
                        }

                        Label { text: "Font" }
                        ComboBox {
                            id: fontBox
                            Layout.fillWidth: true
                            model: backend.fontFamilies()
                            onActivated: win.apply("fontFamily",
                                currentIndex === 0 ? "" : currentText)
                        }

                        Label { text: "Text size" }
                        RowLayout {
                            Layout.fillWidth: true
                            Slider {
                                id: scaleSlider
                                Layout.fillWidth: true
                                from: 75; to: 150; stepSize: 5; snapMode: Slider.SnapAlways
                                onMoved: win.apply("fontScale", value)
                            }
                            Label { text: Math.round(scaleSlider.value) + "%" }
                        }

                        Label { text: "Density" }
                        ComboBox {
                            id: densityBox
                            Layout.fillWidth: true
                            textRole: "label"
                            valueRole: "value"
                            model: [
                                { label: "Compact", value: "compact" },
                                { label: "Cosy", value: "cosy" },
                                { label: "Comfortable", value: "comfortable" }
                            ]
                            onActivated: win.apply("density", currentValue)
                        }

                        Label { text: "Corner rounding" }
                        RowLayout {
                            Layout.fillWidth: true
                            Slider {
                                id: radiusSlider
                                Layout.fillWidth: true
                                from: 0; to: 28; stepSize: 1; snapMode: Slider.SnapAlways
                                onMoved: win.apply("cornerRadius", value)
                            }
                            Label { text: Math.round(radiusSlider.value) + " px" }
                        }

                        Label { text: "Card opacity" }
                        RowLayout {
                            Layout.fillWidth: true
                            Slider {
                                id: opacitySlider
                                Layout.fillWidth: true
                                from: 30; to: 100; stepSize: 5; snapMode: Slider.SnapAlways
                                onMoved: win.apply("cardOpacity", value)
                            }
                            Label { text: Math.round(opacitySlider.value) + "%" }
                        }
                    }
                }

                // Content ---------------------------------------------------
                GroupBox {
                    title: "Content"
                    Layout.fillWidth: true
                    Layout.margins: 14

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        CheckBox {
                            id: headerCheck
                            text: "Header with master switch"
                            onToggled: win.apply("showHeader", checked)
                        }
                        CheckBox {
                            id: lightsCheck
                            text: "Individual lights when a room is expanded"
                            onToggled: win.apply("showLights", checked)
                        }
                        CheckBox {
                            id: scenesCheck
                            text: "Scenes"
                            onToggled: win.apply("showScenes", checked)
                        }
                        CheckBox {
                            id: zonesCheck
                            text: "Zones as well as rooms"
                            onToggled: win.apply("showZones", checked)
                        }
                        CheckBox {
                            id: tintCheck
                            text: "Tint cards with the light colour"
                            onToggled: win.apply("accentTint", checked)
                        }
                    }
                }

                // Position --------------------------------------------------
                GroupBox {
                    title: "Position and size"
                    Layout.fillWidth: true
                    Layout.margins: 14

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        GridLayout {
                            columns: 4
                            columnSpacing: 10
                            rowSpacing: 8

                            Label { text: "X" }
                            SpinBox { id: xSpin; from: 0; to: 10000; editable: true }
                            Label { text: "Y" }
                            SpinBox { id: ySpin; from: 0; to: 10000; editable: true }
                            Label { text: "Width" }
                            SpinBox { id: wSpin; from: 220; to: 2000; editable: true }
                            Label { text: "Height" }
                            SpinBox { id: hSpin; from: 180; to: 2000; editable: true }
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            opacity: 0.7
                            text: "Plasma only reads widget geometry when it starts, "
                                + "so applying a position restarts the desktop shell. "
                                + "Your windows are not affected. You can also just "
                                + "drag the widget on the desktop."
                        }

                        Button {
                            text: "Apply position"
                            enabled: backend.widgets.length > 0
                            onClicked: confirmMove.open()
                        }
                    }
                }

                // Bridge ----------------------------------------------------
                GroupBox {
                    title: "Bridge"
                    Layout.fillWidth: true
                    Layout.margins: 14

                    GridLayout {
                        anchors.fill: parent
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 10

                        Label { text: "Address" }
                        TextField {
                            id: ipField
                            Layout.fillWidth: true
                            placeholderText: "192.168.1.x"
                            onEditingFinished: win.apply("bridgeIp", text)
                        }

                        Label { text: "Refresh every" }
                        RowLayout {
                            Layout.fillWidth: true
                            SpinBox {
                                id: pollSpin
                                from: 5; to: 300; stepSize: 5; editable: true
                                onValueModified: win.apply("pollInterval", value)
                            }
                            Label { text: "seconds" }
                        }

                        Label { text: "Pairing" }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            opacity: 0.7
                            text: "Pair from the widget itself: press the round "
                                + "button on your bridge, then choose Pair."
                        }
                    }
                }

                // About -----------------------------------------------------
                GroupBox {
                    title: "About"
                    Layout.fillWidth: true
                    Layout.margins: 14

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Hue Desk is free and open source, and always "
                                + "will be. If it has been useful, you can buy "
                                + "me a coffee."
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Button {
                                text: "Buy me a coffee"
                                onClicked: Qt.openUrlExternally(
                                    "https://ko-fi.com/robertjanvlak")
                            }
                            Button {
                                text: "Project page"
                                onClicked: Qt.openUrlExternally(
                                    "https://github.com/robertjanvlak111/huedesk")
                            }
                            Button {
                                text: "Report a problem"
                                onClicked: Qt.openUrlExternally(
                                    "https://github.com/robertjanvlak111/huedesk/issues")
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            opacity: 0.7
                            font.pixelSize: 11
                            text: "The widget mentions this once, after about "
                                + "three months of use, and never again. "
                                + "Nothing is sent anywhere."
                        }
                    }
                }

                Item { Layout.preferredHeight: 8 }
            }
        }

        ToolSeparator { Layout.fillHeight: true }

        // -- live preview ----------------------------------------------------
        Item {
            id: previewPane
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.5, 0.5, 0.55, 0.12)
            }

            Label {
                anchors.centerIn: parent
                visible: !backend.installed
                width: parent.width - 60
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: "The Hue Desk widget is not installed yet, so there is "
                    + "nothing to preview. Run install.sh first."
            }

            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: backend.installed

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Live preview"
                    opacity: 0.6
                }

                Item {
                    id: preview
                    width: 360
                    height: 540

                    property var themeObject: null
                    property var mockObject: null
                    property var viewObject: null

                    // The preview is the real widget: its QML is loaded from
                    // the installed plasmoid rather than reimplemented here.
                    function rebuild() {
                        if (!backend.installed) {
                            return
                        }
                        if (viewObject) { viewObject.destroy(); viewObject = null }
                        if (themeObject) { themeObject.destroy(); themeObject = null }
                        if (mockObject) { mockObject.destroy(); mockObject = null }

                        var themeComp = Qt.createComponent(backend.uiPath + "/Theme.qml")
                        var mockComp = Qt.createComponent(Qt.resolvedUrl("MockBridge.qml"))
                        var viewComp = Qt.createComponent(backend.uiPath
                                                          + "/FullRepresentation.qml")
                        for (var comp of [themeComp, mockComp, viewComp]) {
                            if (comp.status === Component.Error) {
                                console.warn("preview:", comp.errorString())
                                return
                            }
                        }

                        themeObject = themeComp.createObject(preview, {
                            mode: win.cfg.themeMode,
                            fontFamilyOverride: win.cfg.fontFamily,
                            fontScale: win.cfg.fontScale,
                            density: win.cfg.density,
                            radius: win.cfg.cornerRadius,
                            cardAlpha: win.cfg.cardOpacity
                        })
                        mockObject = mockComp.createObject(preview)
                        viewObject = viewComp.createObject(preview, {
                            width: preview.width,
                            height: preview.height,
                            hue: mockObject,
                            theme: themeObject,
                            showHeader: win.cfg.showHeader,
                            showLights: win.cfg.showLights,
                            showScenes: win.cfg.showScenes,
                            showZones: win.cfg.showZones,
                            accentTint: win.cfg.accentTint
                        })
                        if (viewObject) {
                            viewObject.expandedIds = ["r1"]
                        }
                    }

                    Component.onCompleted: rebuild()
                }
            }
        }
    }

    MessageDialog {
        id: confirmMove
        title: "Restart the desktop shell?"
        text: "Applying a new position restarts plasmashell. Your panel will "
            + "blink; open windows are not affected."
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: backend.applyGeometry(xSpin.value, ySpin.value,
                                          wSpin.value, hSpin.value)
    }
}
