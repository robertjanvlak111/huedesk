/*
 * CompactRepresentation.qml - panel form: a bulb that takes on the colour of
 * whatever is lit. Click opens the full view, middle-click toggles everything.
 */

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: compact

    property var hue: null
    property var theme: null
    property var plasmoidItem: null

    readonly property color tint: {
        if (!hue || !hue.anyOn) {
            return theme ? theme.onSurfaceMuted : Kirigami.Theme.disabledTextColor
        }
        var lit = hue.lights.filter(l => l.on && !l.isPlug)
        return lit.length > 0 ? lit[0].hex : (theme ? theme.accent : Kirigami.Theme.highlightColor)
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        source: Qt.resolvedUrl("../icons/bulb.svg")
        isMask: true
        color: compact.tint
        opacity: hue && hue.anyOn ? 1.0 : 0.6

        Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
    }

    Rectangle {
        visible: hue && hue.status === "error"
        width: Kirigami.Units.gridUnit * 0.45
        height: width
        radius: width / 2
        color: theme ? theme.danger : "red"
        anchors { right: parent.right; bottom: parent.bottom }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton && hue) {
                hue.setAll(!hue.anyOn)
            } else {
                plasmoidItem.expanded = !plasmoidItem.expanded
            }
        }
    }
}
