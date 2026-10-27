/*
 * RoomCard.qml - a room or zone, drawn the way the Hue app draws one: the card
 * itself is the brightness control. Its fill tracks brightness and takes the
 * colour of the lights in the room; dragging across the card dims it.
 *
 * Power and expand are explicit buttons so that a plain click is never
 * ambiguous, and dragging only takes effect past a small threshold.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: card

    property var group: null
    property var hue: null
    property var view: null
    property var theme: null

    readonly property bool expanded: view && group ? view.isExpanded(group.id) : false
    readonly property bool isOn: group ? group.on : false
    readonly property bool dimmable: group ? group.dimmable : false
    // A plug-only room is simply on or off, so its fill is all-or-nothing.
    readonly property real fraction: {
        if (!group) {
            return 0
        }
        return dimmable ? Math.max(0, Math.min(1, group.bri / 100)) : 1
    }

    readonly property var memberLights: {
        if (!hue || !group) {
            return []
        }
        return hue.lights.filter(l => group.lightIds.indexOf(l.id) !== -1)
    }
    readonly property var groupScenes: {
        if (!hue || !group || !view.showScenes) {
            return []
        }
        return hue.scenes.filter(s => s.groupId === group.id)
    }

    implicitHeight: bar.height + (expanded ? extra.implicitHeight + theme.gap : 0)

    // Hue's room archetypes mapped onto the icons bundled with this widget.
    // Shipping our own avoids depending on whatever icon theme the user has.
    function roomIcon(archetype) {
        switch (archetype) {
        case "living_room":
        case "lounge":
        case "tv":              return "sofa"
        case "bedroom":
        case "kids_bedroom":
        case "nursery":         return "bed"
        case "kitchen":
        case "dining":          return "kitchen"
        case "office":
        case "computer":
        case "studio":          return "desk"
        case "bathroom":
        case "toilet":          return "bath"
        case "garden":
        case "terrace":
        case "balcony":
        case "driveway":
        case "carport":         return "outdoor"
        case "hallway":
        case "staircase":       return "stairs"
        default:                return "bulb"
        }
    }

    // -- the bar ----------------------------------------------------------
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: theme.cardHeight
        radius: theme.radius
        color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b,
                       theme.cardAlpha / 100)
        border.width: 1
        border.color: theme.outline

        // Brightness fill. Rounded at both ends so a partial fill reads as a
        // pill rather than a clipped rectangle.
        Rectangle {
            id: fill
            visible: card.isOn
            height: parent.height
            width: Math.max(parent.height, parent.width * card.fraction)
            radius: parent.radius
            opacity: 0.85

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: {
                        var base = view && view.accentTint && card.group
                                 ? theme.litFill(card.group.hex) : theme.accent
                        return Qt.rgba(base.r, base.g, base.b, 0.55)
                    }
                }
                GradientStop {
                    position: 1.0
                    color: {
                        var base = view && view.accentTint && card.group
                                 ? theme.litFill(card.group.hex) : theme.accent
                        return Qt.rgba(base.r, base.g, base.b, 0.22)
                    }
                }
            }

            Behavior on width {
                enabled: !drag.active
                NumberAnimation { duration: Kirigami.Units.longDuration
                                  easing.type: Easing.OutCubic }
            }
        }

        // Drag anywhere on the bar to dim. Buttons sit above this and so win
        // the press, which keeps a click on them unambiguous.
        MouseArea {
            id: drag
            anchors.fill: parent
            enabled: card.dimmable
            property bool active: false
            property real startX: 0
            readonly property int threshold: Kirigami.Units.gridUnit / 2

            onPressed: (mouse) => {
                startX = mouse.x
                active = false
            }
            onPositionChanged: (mouse) => {
                if (!active && Math.abs(mouse.x - startX) < threshold) {
                    return
                }
                if (!active) {
                    active = true
                    hue.suspended = true
                }
                var f = Math.max(0.01, Math.min(1, mouse.x / width))
                hue.setGroupBrightness(card.group.groupId, Math.round(f * 100), true)
                commit.restart()
            }
            onReleased: {
                if (active) {
                    active = false
                    hue.suspended = false
                    commit.stop()
                    hue.setGroupBrightness(card.group.groupId, card.group.bri)
                }
            }

            Timer {
                id: commit
                interval: 180
                onTriggered: hue.setGroupBrightness(card.group.groupId, card.group.bri)
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: theme.pad
            anchors.rightMargin: Math.round(theme.pad / 2)
            spacing: theme.gap

            Kirigami.Icon {
                source: Qt.resolvedUrl("../icons/"
                        + card.roomIcon(card.group ? card.group.archetype : "") + ".svg")
                isMask: true
                color: card.isOn ? theme.onSurface : theme.onSurfaceMuted
                opacity: card.isOn ? 1.0 : 0.65
                Layout.preferredWidth: Math.round(theme.unit * 1.15)
                Layout.preferredHeight: Layout.preferredWidth
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents.Label {
                    text: card.group ? card.group.name : ""
                    font: theme.labelFont
                    color: theme.onSurface
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: {
                        if (!card.group) {
                            return ""
                        }
                        var total = card.group.totalCount
                        var noun = total === 1 ? "light" : "lights"
                        if (!card.isOn) {
                            return "Off  ·  " + total + " " + noun
                        }
                        var lit = card.group.litCount + " of " + total + " on"
                        return card.dimmable ? card.group.bri + "%  ·  " + lit : lit
                    }
                    font: theme.captionFont
                    color: theme.onSurfaceMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Power. A filled pill when on, outline when off.
            Rectangle {
                id: power
                Layout.preferredWidth: Math.round(theme.unit * 1.7)
                Layout.preferredHeight: Math.round(theme.unit * 1.7)
                radius: width / 2
                color: card.isOn ? theme.accent : "transparent"
                border.width: card.isOn ? 0 : 1
                border.color: theme.outline

                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(theme.unit * 0.85)
                    height: width
                    source: Qt.resolvedUrl("../icons/power.svg")
                    isMask: true
                    color: card.isOn ? "#241a06" : theme.onSurfaceMuted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hue.setGroupOn(card.group.groupId, !card.isOn)
                }
            }

            // Expand / collapse. Uses a bundled glyph so it looks the same
            // whatever icon theme the user happens to have.
            Item {
                id: chevron
                visible: view.showLights
                         && (card.memberLights.length > 0 || card.groupScenes.length > 0)
                Layout.preferredWidth: Math.round(theme.unit * 1.5)
                Layout.preferredHeight: Math.round(theme.unit * 1.5)

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(theme.unit * 0.8)
                    height: width
                    source: Qt.resolvedUrl(card.expanded ? "../icons/chevron-up.svg"
                                                         : "../icons/chevron-down.svg")
                    isMask: true
                    color: theme.onSurfaceMuted
                    opacity: chevronArea.containsMouse ? 1.0 : 0.75
                }

                MouseArea {
                    id: chevronArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.toggleExpanded(card.group.id)
                }
            }
        }
    }

    // -- expanded detail ---------------------------------------------------
    ColumnLayout {
        id: extra
        visible: card.expanded
        anchors {
            left: parent.left
            right: parent.right
            top: bar.bottom
            topMargin: theme.gap
            leftMargin: theme.pad
            rightMargin: Math.round(theme.pad / 2)
        }
        spacing: Math.round(theme.gap / 2)

        SceneStrip {
            visible: card.groupScenes.length > 0
            scenes: card.groupScenes
            hue: card.hue
            theme: card.theme
            Layout.fillWidth: true
        }

        Repeater {
            model: card.expanded ? card.memberLights : []
            delegate: LightRow {
                required property var modelData
                light: modelData
                hue: card.hue
                theme: card.theme
                Layout.fillWidth: true
            }
        }
    }
}
