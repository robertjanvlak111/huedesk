/*
 * LightRow.qml - one bulb, drawn as a smaller echo of RoomCard so the two read
 * as the same family. Smart plugs report no dimming, so they lose the fill and
 * keep only the power button.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: row
    objectName: "lightRow"

    property var light: null
    property var hue: null
    property var theme: null

    readonly property bool isOn: light ? light.on : false
    readonly property bool dimmable: light ? light.dimmable : false

    // Held locally while dragging; writing to the model would rebuild this
    // row and drop the mouse grab. -1 means "not dragging".
    property int dragLevel: -1
    readonly property int level: dragLevel >= 0
                                 ? dragLevel : (light ? light.bri : 0)
    readonly property real fraction: Math.max(0, Math.min(1, level / 100))

    implicitHeight: theme.rowHeight

    // -- colour -----------------------------------------------------------
    readonly property real fillAlpha: (theme.isDark ? 0.35 : 0.28) * 0.7
    readonly property color tintColor: light && !light.isPlug
                                       ? Qt.color(light.hex) : theme.accent
    readonly property color surfaceColor: theme.blend(theme.background,
                                                      theme.surfaceRaised, 1.0)
    readonly property real fillWidth: Math.max(track.height, track.width * fraction)
    readonly property real probeX: theme.pad * 0.7 + theme.unit * 0.55
                                   + theme.gap + theme.unit * 1.0

    readonly property color labelBackdrop: {
        if (!isOn || !dimmable || probeX > fillWidth) {
            return surfaceColor
        }
        return theme.blend(surfaceColor, tintColor, fillAlpha)
    }

    readonly property color ink: theme.inkFor(labelBackdrop)
    readonly property color mutedInk: theme.mutedInkFor(labelBackdrop)

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
            width: row.fillWidth
            radius: parent.radius
            opacity: 0.7
            color: Qt.rgba(row.tintColor.r, row.tintColor.g, row.tintColor.b,
                           theme.isDark ? 0.35 : 0.28)

            Behavior on width {
                enabled: !slide.scrubbing
                NumberAnimation { duration: Kirigami.Units.longDuration
                                  easing.type: Easing.OutCubic }
            }
        }

        // Same gesture handling as RoomCard: resolve direction first so the
        // list can still be scrolled, click to set, drag to scrub, and never
        // write to the model while the gesture is running.
        MouseArea {
            id: slide
            anchors.fill: parent
            enabled: row.dimmable
            cursorShape: row.dimmable ? Qt.SizeHorCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton

            property bool scrubbing: false
            property bool decided: false
            property real pressX: 0
            property real pressY: 0
            readonly property int slop: 4

            function levelAt(x) {
                return Math.max(1, Math.min(100, Math.round((x / width) * 100)))
            }

            onPressed: (mouse) => {
                pressX = mouse.x
                pressY = mouse.y
                decided = false
                scrubbing = false
            }

            onPositionChanged: (mouse) => {
                if (!decided) {
                    var dx = Math.abs(mouse.x - pressX)
                    var dy = Math.abs(mouse.y - pressY)
                    if (dx < slop && dy < slop) {
                        return
                    }
                    decided = true
                    if (dy > dx) {
                        preventStealing = false
                        return
                    }
                    scrubbing = true
                    preventStealing = true
                    hue.suspended = true
                    throttle.restart()
                }
                if (scrubbing) {
                    row.dragLevel = levelAt(mouse.x)
                }
            }

            onReleased: (mouse) => {
                if (scrubbing) {
                    finish()
                    return
                }
                var wasDecided = decided
                decided = false
                preventStealing = false
                if (!wasDecided) {
                    hue.setLightBrightness(row.light.id, levelAt(mouse.x))
                }
            }

            onCanceled: {
                if (scrubbing) {
                    finish()
                    return
                }
                decided = false
                preventStealing = false
            }

            function finish() {
                scrubbing = false
                decided = false
                preventStealing = false
                throttle.stop()
                hue.suspended = false

                var level = row.dragLevel
                var lightId = row.light.id
                row.dragLevel = -1
                if (level >= 0) {
                    // Rebuilds this delegate, so nothing may follow it.
                    hue.setLightBrightness(lightId, level)
                }
            }

            onWheel: (wheel) => {
                if (!(wheel.modifiers & Qt.ControlModifier)) {
                    wheel.accepted = false
                    return
                }
                var step = wheel.angleDelta.y > 0 ? 5 : -5
                hue.setLightBrightness(row.light.id,
                                       Math.max(1, Math.min(100, row.level + step)))
                wheel.accepted = true
            }

            // Individual lights tolerate about ten commands a second.
            Timer {
                id: throttle
                interval: 300
                repeat: true
                onTriggered: {
                    if (!slide.scrubbing) {
                        stop()
                        return
                    }
                    if (row.dragLevel >= 0) {
                        hue.setLightBrightnessLive(row.light.id, row.dragLevel)
                    }
                }
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
                color: row.isOn ? row.ink : row.mutedInk
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: row.isOn && row.dimmable
                text: light ? row.level + "%" : ""
                font: theme.captionFont
                color: row.mutedInk
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
                    color: row.isOn ? theme.inkFor(theme.accent) : row.mutedInk
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
