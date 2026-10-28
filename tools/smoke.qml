/*
 * smoke.qml - instantiates every UI component once.
 *
 * The renderer only draws FullRepresentation, so a broken binding in a
 * component it does not reach (the panel's compact view, the pairing panel,
 * the support message) would ship unnoticed. This touches all of them, and
 * QML reports any bad property on creation.
 */

import QtQuick
import "../package/contents/ui"
import "../settings-app/ui"

Item {
    id: scene
    width: 400
    height: 700

    property var problems: []
    property bool done: false

    Theme { id: t }
    MockBridge { id: mock }

    // Stand-in for PlasmoidItem, which only exists inside plasmashell.
    QtObject {
        id: fakePlasmoidItem
        property bool expanded: false
    }

    function make(name, props) {
        var comp = Qt.createComponent(Qt.resolvedUrl(
            "../package/contents/ui/" + name + ".qml"))
        if (comp.status === Component.Error) {
            problems.push(name + ": " + comp.errorString().trim())
            return null
        }
        var obj = comp.createObject(scene, props)
        if (obj === null) {
            problems.push(name + ": createObject returned null")
        }
        return obj
    }

    Component.onCompleted: {
        make("FullRepresentation", { hue: mock, theme: t, width: 380, height: 560 })
        make("CompactRepresentation", { hue: mock, theme: t,
                                        plasmoidItem: fakePlasmoidItem,
                                        width: 32, height: 32 })
        make("PairingPanel", { hue: mock, theme: t, width: 380 })
        make("SupportPrompt", { theme: t, width: 380, height: 400 })
        make("SceneStrip", { hue: mock, theme: t, width: 380,
                             scenes: mock.scenes })
        make("TintedIcon", { name: "bulb", width: 24, height: 24 })
        done = true
    }
}
