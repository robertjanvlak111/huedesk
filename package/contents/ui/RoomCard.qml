/*
 * RoomCard.qml - a room or zone, drawn the way the Hue app draws one: the card
 * itself is the brightness control. Its fill tracks brightness and takes the
 * colour of the lights in the room.
 *
 * Because the fill colour is whatever the bulbs happen to be, the card's
 * background can end up light or dark independently of the theme, so the text
 * colour is derived from the actual composited background rather than fixed.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: card
    objectName: "roomCard"

    property var group: null
    property var hue: null
    property var view: null
    property var theme: null

    readonly property bool expanded: view && group ? view.isExpanded(group.id) : false
    readonly property bool isOn: group ? group.on : false
    readonly property bool dimmable: group ? group.dimmable : false

    // While a drag is in progress the card renders this instead of the model
    // value. Patching the model would replace the groups array and rebuild
    // this very delegate, which would drop the mouse grab mid-gesture.
    // -1 means "not dragging".
    property int dragLevel: -1

    readonly property int level: dragLevel >= 0
                                 ? dragLevel : (group ? group.bri : 0)

    // A plug-only room is simply on or off, so its fill is all-or-nothing.
    readonly property real fraction: {
        if (!group) {
            return 0
        }
        return dimmable ? Math.max(0, Math.min(1, level / 100)) : 1
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

    // -- colour -----------------------------------------------------------
    readonly property real fillAlphaStart: 0.46
    readonly property real fillAlphaEnd: 0.18
    readonly property real fillOpacity: 0.85

    readonly property color tintColor: view && view.accentTint && group
                                       ? theme.litFill(group.hex) : theme.accent

    // The card sits on the widget background and may itself be translucent.
    readonly property color surfaceColor:
        theme.blend(theme.background, theme.surface, theme.cardAlpha / 100)

    readonly property real fillWidth: Math.max(bar.height, bar.width * fraction)

    // Sampled where the room name begins; that is what the ink has to suit.
    readonly property real probeX: theme.pad + theme.unit * 1.15
                                   + theme.gap + theme.unit * 1.2

    readonly property color labelBackdrop: {
        if (!isOn || probeX > fillWidth || fillWidth <= 0) {
            return surfaceColor
        }
        var t = Math.max(0, Math.min(1, probeX / fillWidth))
        var alpha = (fillAlphaStart + (fillAlphaEnd - fillAlphaStart) * t) * fillOpacity
        return theme.blend(surfaceColor, tintColor, alpha)
    }

    readonly property color ink: theme.inkFor(labelBackdrop)
    readonly property color mutedInk: theme.mutedInkFor(labelBackdrop)

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
            width: card.fillWidth
            radius: parent.radius
            opacity: card.fillOpacity

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(card.tintColor.r, card.tintColor.g,
                                   card.tintColor.b, card.fillAlphaStart)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(card.tintColor.r, card.tintColor.g,
                                   card.tintColor.b, card.fillAlphaEnd)
                }
            }

            Behavior on width {
                enabled: !scrub.scrubbing
                NumberAnimation { duration: Kirigami.Units.longDuration
                                  easing.type: Easing.OutCubic }
            }
        }

        // Brightness scrubbing.
        //
        // The card lives inside a vertically scrolling list, so the gesture
        // direction is resolved first: a horizontal drag takes the grab and
        // dims, a vertical one is left to the list. A press that never moves
        // is a click, and sets the level where it landed.
        //
        // Nothing here writes to the view model: that would rebuild this
        // delegate and break the drag. The card shows dragLevel, the bridge
        // is fed through the throttle, and the model is updated once on
        // release.
        MouseArea {
            id: scrub
            anchors.fill: parent
            enabled: card.dimmable
            cursorShape: card.dimmable ? Qt.SizeHorCursor : Qt.ArrowCursor
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
                        // Vertical: hand the gesture back to the list.
                        preventStealing = false
                        return
                    }
                    scrubbing = true
                    preventStealing = true
                    hue.suspended = true
                    throttle.restart()
                }
                if (scrubbing) {
                    card.dragLevel = levelAt(mouse.x)
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
                    hue.setGroupBrightness(card.group.groupId, levelAt(mouse.x))
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

                var level = card.dragLevel
                var groupId = card.group.groupId
                card.dragLevel = -1
                if (level >= 0) {
                    // Rebuilds this delegate, so nothing may follow it.
                    hue.setGroupBrightness(groupId, level)
                }
            }

            // Ctrl+wheel nudges the level; a plain wheel is left alone so the
            // list can still be scrolled with the pointer over a card.
            onWheel: (wheel) => {
                if (!(wheel.modifiers & Qt.ControlModifier)) {
                    wheel.accepted = false
                    return
                }
                var step = wheel.angleDelta.y > 0 ? 5 : -5
                hue.setGroupBrightness(card.group.groupId,
                                       Math.max(1, Math.min(100, card.level + step)))
                wheel.accepted = true
            }

            // Pushes the dragged level to the bridge while the gesture runs.
            // The bridge rate-limits group commands to roughly one a second.
            Timer {
                id: throttle
                interval: 1000
                repeat: true
                onTriggered: {
                    if (!scrub.scrubbing) {
                        stop()
                        return
                    }
                    if (card.dragLevel >= 0) {
                        hue.setGroupBrightnessLive(card.group.groupId, card.dragLevel)
                    }
                }
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
                color: card.isOn ? card.ink : card.mutedInk
                Layout.preferredWidth: Math.round(theme.unit * 1.15)
                Layout.preferredHeight: Layout.preferredWidth
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents.Label {
                    text: card.group ? card.group.name : ""
                    font: theme.labelFont
                    color: card.ink
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
                        return card.dimmable ? card.level + "%  ·  " + lit : lit
                    }
                    font: theme.captionFont
                    color: card.mutedInk
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
                    color: card.isOn ? theme.inkFor(theme.accent) : card.mutedInk
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
                    color: card.mutedInk
                    opacity: chevronArea.containsMouse ? 1.0 : 0.8
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
