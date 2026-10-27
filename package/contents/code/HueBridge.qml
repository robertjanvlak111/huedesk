/*
 * HueBridge.qml - Philips Hue CLIP v2 client.
 *
 * The bridge serves the v2 API over HTTPS with a self-signed certificate,
 * which QML's XMLHttpRequest refuses outright. So every call shells out to
 * curl through Plasma's executable data engine instead. Pairing is the one
 * exception: it uses the old v1 endpoint over plain HTTP, which is the only
 * way to obtain an application key.
 */

import QtQuick
import QtQml
import org.kde.plasma.plasma5support as P5Support

import "HueColors.js" as HueColors
import "HueModel.js" as HueModel

QtObject {
    id: bridge

    property string ip: ""
    property string appKey: ""

    readonly property bool paired: ip !== "" && appKey !== ""
    property string status: "idle"          // idle | ok | error | pairing | discovering
    property string lastError: ""
    property bool refreshing: false

    // Raised while a brightness control is under the pointer: a poll mid-drag
    // would rebuild the models and tear the delegate out from under the user.
    //
    // It is a single flag shared by every card, so a press that is lost (the
    // pointer leaving the window, a delegate going away mid-gesture) could
    // otherwise leave it raised and freeze polling for good. The watchdog
    // makes that state self-correcting.
    property bool suspended: false

    onSuspendedChanged: {
        if (suspended) {
            suspendGuard.restart()
        } else {
            suspendGuard.stop()
        }
    }

    property QtObject suspendGuard: Timer {
        interval: 8000
        onTriggered: {
            // No gesture lasts this long; the press was lost somewhere.
            bridge.suspended = false
            bridge.refresh()
        }
    }

    // Rooms and zones, merged. Each: id, name, kind, groupId, on, bri, lightIds, hex
    property var groups: []
    property var lights: []                 // id, name, on, bri, hex, hasColor, hasTemp, deviceId
    property var scenes: []                 // id, name, groupId
    property bool anyOn: false

    signal refreshed()
    signal pairSucceeded(string key)
    signal pairFailed(string message)
    signal bridgeFound(string address)

    // -- plumbing ----------------------------------------------------------

    property var _pending: ({})
    property int _nonce: 0

    property QtObject _runner: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            var cb = bridge._pending[source]
            delete bridge._pending[source]
            if (cb) {
                cb(data["stdout"] || "", data["stderr"] || "", data["exit code"])
            }
        }
    }

    function _run(cmd, callback) {
        // The engine keys sources by command string, so identical concurrent
        // calls would collide. A throwaway variable keeps each one distinct.
        var unique = "HUEREQ=" + (++_nonce) + " " + cmd
        _pending[unique] = callback
        _runner.connectSource(unique)
    }

    function _hdr() {
        return "-H 'hue-application-key: " + appKey + "'"
    }

    function _url(path) {
        return "'https://" + ip + "/clip/v2/resource/" + path + "'"
    }

    function _parse(text) {
        try {
            var j = JSON.parse(text)
            return (j && j.data) ? j.data : []
        } catch (e) {
            return null
        }
    }

    // -- discovery and pairing --------------------------------------------

    function discover() {
        status = "discovering"
        _run("curl -s -m 10 https://discovery.meethue.com/", (out) => {
            try {
                var list = JSON.parse(out)
                if (list && list.length > 0 && list[0].internalipaddress) {
                    ip = list[0].internalipaddress
                    status = "idle"
                    bridgeFound(ip)
                    return
                }
                lastError = "No bridge found on this network."
            } catch (e) {
                lastError = "Discovery failed: " + e
            }
            status = "error"
        })
    }

    function pair() {
        if (!ip) {
            pairFailed("Set the bridge address first.")
            return
        }
        status = "pairing"
        var body = "'{\"devicetype\":\"huedesk#plasma\",\"generateclientkey\":true}'"
        _run("curl -s -m 10 -X POST -d " + body + " http://" + ip + "/api", (out) => {
            try {
                var r = JSON.parse(out)
                if (r && r[0] && r[0].success && r[0].success.username) {
                    appKey = r[0].success.username
                    status = "idle"
                    pairSucceeded(appKey)
                    refresh()
                    return
                }
                if (r && r[0] && r[0].error) {
                    pairFailed(r[0].error.description === "link button not pressed"
                        ? "Press the round button on your bridge, then try again."
                        : r[0].error.description)
                    status = "error"
                    return
                }
                pairFailed("Unexpected reply from the bridge.")
            } catch (e) {
                pairFailed("Could not reach the bridge at " + ip + ".")
            }
            status = "error"
        })
    }

    // -- state ------------------------------------------------------------

    function refresh() {
        if (!paired || refreshing || suspended) {
            return
        }
        refreshing = true

        var cmd = "curl -sk -m 8 " + _hdr() + " -w '\\n__HSPLIT__\\n' "
            + _url("room") + " " + _url("zone") + " "
            + _url("grouped_light") + " " + _url("light") + " " + _url("scene")

        _run(cmd, (out, err, code) => {
            refreshing = false
            if (code !== 0 && !out) {
                status = "error"
                lastError = "Cannot reach the bridge at " + ip + "."
                return
            }

            var parts = HueModel.splitBatch(out, "__HSPLIT__")
            if (parts[0] === null) {
                status = "error"
                lastError = "The bridge rejected the request. Re-pair Hue Desk."
                return
            }

            var model = HueModel.buildModel(parts[0], parts[1], parts[2],
                                            parts[3], parts[4], HueColors)
            groups = model.groups
            lights = model.lights
            scenes = model.scenes
            anyOn = model.anyOn

            status = "ok"
            lastError = ""
            refreshed()
        })
    }

    // -- commands ---------------------------------------------------------

    function _put(path, payload, optimistic) {
        if (!paired) {
            return
        }
        if (optimistic) {
            optimistic()
        }
        var cmd = "curl -sk -m 8 -X PUT " + _hdr()
            + " -H 'Content-Type: application/json' -d '" + JSON.stringify(payload) + "' "
            + _url(path)
        _run(cmd, (out, err, code) => {
            if (code !== 0) {
                lastError = "Command failed to reach the bridge."
                status = "error"
            }
            settle.restart()
        })
    }

    // Local state is updated immediately so controls feel responsive, then
    // reconciled against the bridge a moment later.
    property QtObject settle: Timer {
        interval: 900
        onTriggered: bridge.refresh()
    }

    function _patchGroup(groupId, fields) {
        var g = groups.slice()
        for (var i = 0; i < g.length; i++) {
            if (g[i].groupId === groupId) {
                g[i] = Object.assign({}, g[i], fields)
            }
        }
        groups = g
    }

    function _patchLight(lightId, fields) {
        var l = lights.slice()
        for (var i = 0; i < l.length; i++) {
            if (l[i].id === lightId) {
                l[i] = Object.assign({}, l[i], fields)
            }
        }
        lights = l
    }

    function setGroupOn(groupId, on) {
        _put("grouped_light/" + groupId, { on: { on: on } },
             () => _patchGroup(groupId, { on: on }))
    }

    function setGroupBrightness(groupId, bri) {
        var v = Math.max(1, Math.min(100, Math.round(bri)))
        _put("grouped_light/" + groupId, { dimming: { brightness: v }, on: { on: true } },
             () => _patchGroup(groupId, { bri: v, on: true }))
    }

    // Sends without touching the view model.
    //
    // Patching the model replaces the `groups` array, which makes the Repeater
    // destroy and rebuild every delegate - including the card currently under
    // the pointer, which loses its mouse grab. During a drag the card renders
    // its own value instead, and this pushes the level to the bridge.
    function setGroupBrightnessLive(groupId, bri) {
        var v = Math.max(1, Math.min(100, Math.round(bri)))
        _put("grouped_light/" + groupId, { dimming: { brightness: v }, on: { on: true } })
    }

    function setLightOn(lightId, on) {
        _put("light/" + lightId, { on: { on: on } },
             () => _patchLight(lightId, { on: on }))
    }

    function setLightBrightness(lightId, bri) {
        var v = Math.max(1, Math.min(100, Math.round(bri)))
        _put("light/" + lightId, { dimming: { brightness: v }, on: { on: true } },
             () => _patchLight(lightId, { bri: v, on: true }))
    }

    // As setGroupBrightnessLive: no model patch, so the row keeps its grab.
    function setLightBrightnessLive(lightId, bri) {
        var v = Math.max(1, Math.min(100, Math.round(bri)))
        _put("light/" + lightId, { dimming: { brightness: v }, on: { on: true } })
    }

    function setLightColor(lightId, hex) {
        var xy = HueColors.hexToXy(hex)
        _put("light/" + lightId, { color: { xy: { x: xy.x, y: xy.y } }, on: { on: true } },
             () => _patchLight(lightId, { hex: hex, on: true }))
    }

    function setLightTemp(lightId, mirek) {
        var v = Math.max(153, Math.min(500, Math.round(mirek)))
        _put("light/" + lightId, { color_temperature: { mirek: v }, on: { on: true } },
             () => _patchLight(lightId, { on: true }))
    }

    function recallScene(sceneId) {
        _put("scene/" + sceneId, { recall: { action: "active" } })
    }

    function setAll(on) {
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].kind === "room") {
                setGroupOn(groups[i].groupId, on)
            }
        }
        anyOn = on
    }
}
