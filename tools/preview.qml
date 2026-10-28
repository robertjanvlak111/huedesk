/*
 * preview.qml - scene wrapper used by tools/render.py to render the widget
 * offscreen. Not shipped in the plasmoid package.
 */

import QtQuick
import "../package/contents/ui"
import "../settings-app/ui"

Item {
    id: scene

    // Overridden from render.py before loading.
    property string themeMode: "dark"
    property string density: "cosy"
    property int fontScale: 100
    property int cornerRadius: 14
    property string fontFamily: ""
    property var openRooms: []
    property bool supportPrompt: false

    width: 420
    height: 640

    Theme {
        id: previewTheme
        mode: scene.themeMode
        density: scene.density
        fontScale: scene.fontScale
        radius: scene.cornerRadius
        fontFamilyOverride: scene.fontFamily
    }

    MockBridge { id: mock }

    FullRepresentation {
        id: viewUnderTest
        anchors.fill: parent
        hue: mock
        theme: previewTheme
        showSupportPrompt: scene.supportPrompt
        Component.onCompleted: expandedIds = scene.openRooms
    }
}
