/*
 * FullRepresentation.qml - the desktop face: a header, then one card per room
 * and zone. Draws its own background so that a forced light/dark theme stays
 * consistent regardless of the desktop's own colours.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var hue: null
    property var theme: null

    // Content toggles. Supplied by main.qml from the applet config; kept as
    // plain properties so this view has no dependency on the Plasmoid API and
    // can be rendered and tested on its own.
    property bool showScenes: true
    property bool showLights: true
    property bool showZones: true
    property bool accentTint: true
    property bool showHeader: true

    // Each poll replaces the model arrays, destroying every delegate, so
    // expansion state has to live above them.
    property var expandedIds: []

    function isExpanded(id) {
        return expandedIds.indexOf(id) !== -1
    }

    function toggleExpanded(id) {
        var next = expandedIds.slice()
        var at = next.indexOf(id)
        if (at === -1) {
            next.push(id)
        } else {
            next.splice(at, 1)
        }
        expandedIds = next
    }

    readonly property var visibleGroups: {
        if (!hue) {
            return []
        }
        return showZones ? hue.groups : hue.groups.filter(g => g.kind === "room")
    }

    Rectangle {
        anchors.fill: parent
        radius: theme.radius + 4
        color: theme.background
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme.pad
        spacing: theme.gap

        // -- header --------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Math.round(theme.gap / 2)
            visible: root.showHeader
            spacing: theme.gap

            ColumnLayout {
                spacing: 0

                PlasmaComponents.Label {
                    text: "Lights"
                    font: theme.titleFont
                    color: theme.onSurface
                }

                PlasmaComponents.Label {
                    visible: hue && hue.paired
                    text: {
                        if (!hue) {
                            return ""
                        }
                        if (hue.status === "error") {
                            return "Offline"
                        }
                        var on = hue.lights.filter(l => l.on).length
                        return on === 0 ? "All off" : on + " of " + hue.lights.length + " on"
                    }
                    font: theme.captionFont
                    color: hue && hue.status === "error" ? theme.danger : theme.onSurfaceMuted
                }
            }

            Item { Layout.fillWidth: true }

            Item {
                visible: hue && hue.paired
                Layout.preferredWidth: Math.round(theme.unit * 1.7)
                Layout.preferredHeight: Math.round(theme.unit * 1.7)

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(theme.unit * 0.95)
                    height: width
                    source: Qt.resolvedUrl("../icons/refresh.svg")
                    isMask: true
                    color: theme.onSurfaceMuted
                    opacity: hue && hue.refreshing ? 0.4
                             : (refreshArea.containsMouse ? 1.0 : 0.75)
                }

                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hue.refresh()
                }
            }

            // Master power, styled like the per-room button.
            Rectangle {
                visible: hue && hue.paired
                Layout.preferredWidth: Math.round(theme.unit * 1.9)
                Layout.preferredHeight: Math.round(theme.unit * 1.9)
                radius: width / 2
                color: hue && hue.anyOn ? theme.accent : "transparent"
                border.width: hue && hue.anyOn ? 0 : 1
                border.color: theme.outline

                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(theme.unit)
                    height: width
                    source: Qt.resolvedUrl("../icons/power.svg")
                    isMask: true
                    color: hue && hue.anyOn ? "#241a06" : theme.onSurfaceMuted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hue.setAll(!hue.anyOn)
                }
            }
        }

        // -- error banner --------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            visible: hue && hue.status === "error" && hue.lastError !== ""
            implicitHeight: errorText.implicitHeight + theme.pad
            radius: Math.round(theme.radius * 0.7)
            color: Qt.rgba(theme.danger.r, theme.danger.g, theme.danger.b, 0.12)

            PlasmaComponents.Label {
                id: errorText
                anchors.fill: parent
                anchors.margins: Math.round(theme.pad / 2)
                text: hue ? hue.lastError : ""
                font: theme.captionFont
                color: theme.danger
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }

        // -- pairing -------------------------------------------------------
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: hue && !hue.paired
            visible: active
            sourceComponent: PairingPanel {
                hue: root.hue
                theme: root.theme
            }
        }

        // -- rooms ---------------------------------------------------------
        PlasmaComponents.ScrollView {
            id: roomScroll
            visible: hue && hue.paired
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
                width: roomScroll.availableWidth
                spacing: theme.gap

                Repeater {
                    model: root.visibleGroups
                    delegate: RoomCard {
                        required property var modelData
                        group: modelData
                        hue: root.hue
                        view: root
                        theme: root.theme
                        Layout.fillWidth: true
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.topMargin: theme.unit
                    visible: hue && hue.paired && root.visibleGroups.length === 0
                             && hue.status === "ok"
                    text: "No rooms found.\nAssign your lights to a room in the Hue app."
                    font: theme.bodyFont
                    color: theme.onSurfaceMuted
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
