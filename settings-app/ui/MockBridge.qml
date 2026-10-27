/*
 * MockBridge.qml - deterministic stand-in for HueBridge.
 *
 * Used by tools/render.py and the QML tests. The data is invented so that
 * screenshots and test output never contain anyone's real home layout.
 */

import QtQuick

QtObject {
    property string ip: "192.168.0.10"
    property string appKey: "mock"
    readonly property bool paired: true
    property string status: "ok"
    property string lastError: ""
    property bool refreshing: false
    property bool suspended: false
    property bool anyOn: true

    property var lights: [
        { id: "l1", name: "Ceiling",     on: true,  bri: 82, hex: "#ffd9a0", dimmable: true,  isPlug: false, hasColor: true,  hasTemp: true,  archetype: "ceiling_round", deviceId: "d1" },
        { id: "l2", name: "Floor lamp",  on: true,  bri: 54, hex: "#ffb36b", dimmable: true,  isPlug: false, hasColor: true,  hasTemp: true,  archetype: "floor_shade",  deviceId: "d2" },
        { id: "l3", name: "TV backlight",on: true,  bri: 38, hex: "#7fb4ff", dimmable: true,  isPlug: false, hasColor: true,  hasTemp: false, archetype: "hue_lightstrip", deviceId: "d3" },
        { id: "l4", name: "Bedside",     on: true,  bri: 18, hex: "#ff9470", dimmable: true,  isPlug: false, hasColor: true,  hasTemp: true,  archetype: "table_shade", deviceId: "d4" },
        { id: "l5", name: "Wardrobe",    on: false, bri: 60, hex: "#ffd9a0", dimmable: true,  isPlug: false, hasColor: false, hasTemp: true,  archetype: "spot_bulb",   deviceId: "d5" },
        { id: "l6", name: "Worktop",     on: true,  bri: 100,hex: "#fff2d6", dimmable: true,  isPlug: false, hasColor: false, hasTemp: true,  archetype: "spot_bulb",   deviceId: "d6" },
        { id: "l7", name: "Desk",        on: true,  bri: 70, hex: "#ffe3b8", dimmable: true,  isPlug: false, hasColor: true,  hasTemp: true,  archetype: "desk_lamp",   deviceId: "d7" },
        { id: "l8", name: "Coffee maker",on: false, bri: 100,hex: "#ffd9a0", dimmable: false, isPlug: true,  hasColor: false, hasTemp: false, archetype: "plug",        deviceId: "d8" }
    ]

    property var groups: [
        { id: "r1", kind: "room", name: "Living room", archetype: "living_room", groupId: "g1",
          on: true,  bri: 68, lightIds: ["l1","l2","l3"], litCount: 3, totalCount: 3, dimmable: true,  hex: "#ffd9a0" },
        { id: "r2", kind: "room", name: "Bedroom",     archetype: "bedroom",     groupId: "g2",
          on: true,  bri: 18, lightIds: ["l4","l5"],      litCount: 1, totalCount: 2, dimmable: true,  hex: "#ff9470" },
        { id: "r3", kind: "room", name: "Kitchen",     archetype: "kitchen",     groupId: "g3",
          on: true,  bri: 100,lightIds: ["l6","l8"],      litCount: 1, totalCount: 2, dimmable: true,  hex: "#fff2d6" },
        { id: "r4", kind: "room", name: "Office",      archetype: "office",      groupId: "g4",
          on: false, bri: 70, lightIds: ["l7"],           litCount: 0, totalCount: 1, dimmable: true,  hex: "#ffe3b8" }
    ]

    property var scenes: [
        { id: "s1", name: "Relax",       groupId: "r1", active: true  },
        { id: "s2", name: "Concentrate", groupId: "r1", active: false },
        { id: "s3", name: "Energise",    groupId: "r1", active: false },
        { id: "s4", name: "Nightlight",  groupId: "r1", active: false },
        { id: "s5", name: "Dimmed",      groupId: "r2", active: false },
        { id: "s6", name: "Bright",      groupId: "r3", active: false }
    ]

    signal refreshed()
    signal pairSucceeded(string key)
    signal pairFailed(string message)
    signal bridgeFound(string address)

    // Call log, so tests can assert what the UI asked for.
    property var calls: []
    function _log(name, a, b) {
        var next = calls.slice()
        next.push({ name: name, a: String(a), b: String(b) })
        calls = next
    }

    // Replacing the array is what makes a Repeater rebuild its delegates, so
    // the mock does it exactly as HueBridge does; otherwise the drag test
    // could not reproduce a lost mouse grab.
    function _patchGroup(groupId, bri) {
        var next = groups.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].groupId === groupId) {
                next[i] = Object.assign({}, next[i], { bri: bri, on: true })
            }
        }
        groups = next
    }

    function _patchLight(lightId, bri) {
        var next = lights.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === lightId) {
                next[i] = Object.assign({}, next[i], { bri: bri, on: true })
            }
        }
        lights = next
    }

    function refresh() {}
    function discover() {}
    function pair() {}
    function setGroupOn(g, on) { _log("setGroupOn", g, on) }
    function setGroupBrightness(g, b) {
        _log("setGroupBrightness", g, b)
        _patchGroup(g, b)
    }
    function setGroupBrightnessLive(g, b) { _log("setGroupBrightnessLive", g, b) }
    function setLightOn(l, on) { _log("setLightOn", l, on) }
    function setLightBrightness(l, b) {
        _log("setLightBrightness", l, b)
        _patchLight(l, b)
    }
    function setLightBrightnessLive(l, b) { _log("setLightBrightnessLive", l, b) }
    function setLightColor(l, h) {}
    function setLightTemp(l, m) {}
    function recallScene(s) {}
    function setAll(on) {}
}
