/*
 * SceneStrip.qml - a horizontally scrolling row of scene chips, like the Hue
 * app's scene carousel. A room can hold twenty or more scenes, so this scrolls
 * rather than wrapping into a wall of buttons.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: strip

    property var scenes: []
    property var hue: null
    property var theme: null

    implicitHeight: Math.round(theme.unit * 1.6)

    ListView {
        id: list
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: Math.round(theme.gap / 2)
        clip: true
        model: strip.scenes
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            required property var modelData
            height: list.height
            width: label.implicitWidth + theme.pad * 2
            radius: height / 2
            color: modelData.active ? theme.accent : theme.surfaceRaised
            border.width: modelData.active ? 0 : 1
            border.color: theme.outline

            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

            PlasmaComponents.Label {
                id: label
                anchors.centerIn: parent
                text: modelData.name
                font: theme.captionFont
                color: modelData.active ? "#241a06" : theme.onSurfaceMuted
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: hue.recallScene(modelData.id)
            }
        }
    }

    // Soft fade at the right edge, hinting that the strip scrolls.
    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: theme.unit
        visible: !list.atXEnd
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: theme.background }
        }
    }
}
