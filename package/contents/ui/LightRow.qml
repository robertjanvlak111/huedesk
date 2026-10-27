/*
 * LightRow.qml - one bulb, drawn as a smaller echo of RoomCard so the two
 * read as the same family. Smart plugs report no dimming, so they lose the
 * fill and keep only the power button.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: row

    property var light: null
    property var hue: null
    property var theme: null

    readonly property bool isOn: light ? light.on : false
    readonly property bool dimmable: light ? light.dimmable : false
    readonly property real fraction: light ? Math.max(0, Math.min(1, light.bri / 100)) : 0

    implicitHeight: theme.rowHeight

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Math.round(theme.radius * 0.7)
        color: theme.surfaceRaised
        border.width: 1
        border.color: theme.outline

        Rectangle {
            visible: row.isOn && row.dimmable
            height: parent.height
            width: Math.max(parent.height, parent.width * row.fraction)
            radius: parent.radius
            opacity: 0.7
            color: {
                var base = light && !light.isPlug ? Qt.color(light.hex) : theme.accent
                return Qt.rgba(base.r, base.g, base.b, theme.isDark ? 0.35 : 0.28)
            }

            Behavior on width {
                enabled: !slide.active
                NumberAnimation { duration: Kirigami.Units.longDuration
                                  easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: slide
            anchors.fill: parent
            enabled: row.dimmable && row.isOn
            property bool active: false
            property real startX: 0
            readonly property int threshold: Kirigami.Units.gridUnit / 2

            onPressed: (mouse) => { startX = mouse.x; active = false }
            onPositionChanged: (mouse) => {
                if (!active && Math.abs(mouse.x - startX) < threshold) {
                    return
                }
                if (!active) {
                    active = true
                    hue.suspended = true
                }
                var f = Math.max(0.01, Math.min(1, mouse.x / width))
                hue.setLightBrightness(row.light.id, Math.round(f * 100), true)
                commit.restart()
            }
            onReleased: {
                if (active) {
                    active = false
                    hue.suspended = false
                    commit.stop()
                    hue.setLightBrightness(row.light.id, row.light.bri)
                }
            }

            Timer {
                id: commit
                interval: 180
                onTriggered: hue.setLightBrightness(row.light.id, row.light.bri)
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(theme.pad * 0.7)
            anchors.rightMargin: Math.round(theme.pad * 0.35)
            spacing: theme.gap

            // A bulb shows its colour; a plug has none, so it gets a square.
            Rectangle {
                Layout.preferredWidth: Math.round(theme.unit * 0.55)
                Layout.preferredHeight: Layout.preferredWidth
                radius: light && light.isPlug ? width * 0.28 : width / 2
                color: {
                    if (!row.isOn) {
                        return "transparent"
                    }
                    return light.isPlug ? theme.accent : light.hex
                }
                border.width: 1
                border.color: row.isOn ? Qt.rgba(0, 0, 0, 0.18) : theme.outline

                Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
            }

            PlasmaComponents.Label {
                text: light ? light.name : ""
                font: theme.captionFont
                color: row.isOn ? theme.onSurface : theme.onSurfaceMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: row.isOn && row.dimmable
                text: light ? light.bri + "%" : ""
                font: theme.captionFont
                color: theme.onSurfaceMuted
            }

            Rectangle {
                Layout.preferredWidth: Math.round(theme.unit * 1.1)
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: row.isOn ? theme.accent : "transparent"
                border.width: row.isOn ? 0 : 1
                border.color: theme.outline

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(theme.unit * 0.6)
                    height: width
                    source: Qt.resolvedUrl("../icons/power.svg")
                    isMask: true
                    color: row.isOn ? "#241a06" : theme.onSurfaceMuted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hue.setLightOn(row.light.id, !row.isOn)
                }
            }
        }
    }
}
