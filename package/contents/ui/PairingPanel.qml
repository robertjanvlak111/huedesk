/*
 * PairingPanel.qml - shown until the widget holds an application key.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: panel

    property var hue: null
    property var theme: null

    spacing: theme.gap

    Item { Layout.fillHeight: true }

    Kirigami.Icon {
        source: Qt.resolvedUrl("../icons/bulb.svg")
        isMask: true
        color: theme.accent
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Math.round(theme.unit * 3)
        Layout.preferredHeight: Layout.preferredWidth
    }

    PlasmaComponents.Label {
        text: "Connect your bridge"
        font: theme.titleFont
        color: theme.onSurface
        Layout.alignment: Qt.AlignHCenter
    }

    PlasmaComponents.Label {
        text: hue && hue.status === "pairing"
              ? "Pairing…"
              : "Press the round button on your Hue bridge, then choose Pair."
        font: theme.captionFont
        color: theme.onSurfaceMuted
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.leftMargin: theme.pad
        Layout.rightMargin: theme.pad
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: theme.gap
        spacing: theme.gap

        PlasmaComponents.TextField {
            id: ipField
            placeholderText: "Bridge address"
            text: hue ? hue.ip : ""
            font: theme.bodyFont
            Layout.preferredWidth: Math.round(theme.unit * 9)
            onTextChanged: if (hue) hue.ip = text
        }

        PlasmaComponents.Button {
            text: "Find"
            icon.name: "search"
            font: theme.bodyFont
            enabled: hue && hue.status !== "discovering"
            onClicked: hue.discover()
        }
    }

    PlasmaComponents.Button {
        text: "Pair"
        icon.name: "network-connect"
        font: theme.bodyFont
        Layout.alignment: Qt.AlignHCenter
        enabled: hue && hue.ip !== "" && hue.status !== "pairing"
        onClicked: hue.pair()
    }

    PlasmaComponents.Label {
        id: pairMessage
        Layout.fillWidth: true
        Layout.leftMargin: theme.pad
        Layout.rightMargin: theme.pad
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font: theme.captionFont
        color: theme.danger
        visible: text !== ""
    }

    Item { Layout.fillHeight: true }

    Connections {
        target: panel.hue
        function onPairFailed(message) { pairMessage.text = message }
        function onPairSucceeded(key) { pairMessage.text = "" }
    }
}
