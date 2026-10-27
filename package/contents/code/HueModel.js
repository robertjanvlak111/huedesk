.pragma library

/*
 * HueModel.js - turns raw CLIP v2 resource lists into the flat view model the
 * UI binds to. Kept free of QML types so the test suite can run it directly.
 *
 * The join is not obvious: a room lists its members as *device* ids, while a
 * light points back at its device through owner.rid. Zones, by contrast, list
 * light ids directly. Both paths are handled here.
 */

function _lightEntry(l, colors) {
    var state = {
        hasColor: !!l.color,
        x: l.color && l.color.xy ? l.color.xy.x : undefined,
        y: l.color && l.color.xy ? l.color.xy.y : undefined,
        mirek: l.color_temperature ? l.color_temperature.mirek : 0,
        bri: l.dimming ? l.dimming.brightness : 100
    };
    return {
        id: l.id,
        name: l.metadata ? l.metadata.name : "Light",
        on: l.on ? l.on.on : false,
        bri: l.dimming ? Math.round(l.dimming.brightness) : 100,
        hasColor: !!l.color,
        hasTemp: !!l.color_temperature,
        dimmable: !!l.dimming,
        archetype: l.metadata ? (l.metadata.archetype || "") : "",
        isPlug: !!(l.metadata && l.metadata.archetype === "plug"),
        hex: colors.stateToHex(state),
        deviceId: l.owner ? l.owner.rid : ""
    };
}

function _buildGroup(src, kind, ctx) {
    var services = (src.services || []).filter(function (s) {
        return s.rtype === "grouped_light";
    });
    if (services.length === 0) {
        return null;
    }

    var groupId = services[0].rid;
    var state = ctx.groupState[groupId] || {};
    var members = [];
    var children = src.children || [];

    for (var i = 0; i < children.length; i++) {
        var child = children[i];
        var viaDevice = ctx.byDevice[child.rid];
        if (viaDevice) {
            members.push(viaDevice.id);
            continue;
        }
        // Zones reference lights directly instead of going through a device.
        for (var j = 0; j < ctx.lights.length; j++) {
            if (ctx.lights[j].id === child.rid) {
                members.push(ctx.lights[j].id);
            }
        }
    }

    if (members.length === 0) {
        return null;
    }

    // Tint from the first member that is lit, so a card reads at a glance.
    var tint = "";
    var litCount = 0;
    var dimmable = false;
    for (var m = 0; m < members.length; m++) {
        var light = ctx.byId[members[m]];
        if (!light) {
            continue;
        }
        if (light.dimmable) {
            dimmable = true;
        }
        if (light.on) {
            litCount++;
            if (!tint && !light.isPlug) {
                tint = light.hex;
            }
        }
    }

    return {
        id: src.id,
        kind: kind,
        name: src.metadata ? src.metadata.name : kind,
        archetype: src.metadata ? (src.metadata.archetype || "") : "",
        groupId: groupId,
        on: state.on ? state.on.on : false,
        bri: state.dimming ? Math.round(state.dimming.brightness) : 100,
        lightIds: members,
        litCount: litCount,
        totalCount: members.length,
        // A room of nothing but smart plugs has no brightness to offer.
        dimmable: dimmable,
        hex: tint || "#ffd9a0"
    };
}

/*
 * rooms/zones/groupedLights/rawLights/rawScenes are the `data` arrays from the
 * matching CLIP v2 endpoints. `colors` is the HueColors module.
 */
function buildModel(rooms, zones, groupedLights, rawLights, rawScenes, colors) {
    rooms = rooms || [];
    zones = zones || [];
    groupedLights = groupedLights || [];
    rawLights = rawLights || [];
    rawScenes = rawScenes || [];

    var lights = [];
    var byDevice = {};
    var byId = {};

    for (var i = 0; i < rawLights.length; i++) {
        var entry = _lightEntry(rawLights[i], colors);
        lights.push(entry);
        byId[entry.id] = entry;
        if (entry.deviceId) {
            byDevice[entry.deviceId] = entry;
        }
    }

    var groupState = {};
    for (var g = 0; g < groupedLights.length; g++) {
        groupState[groupedLights[g].id] = groupedLights[g];
    }

    var ctx = { byDevice: byDevice, byId: byId, lights: lights, groupState: groupState };
    var groups = [];

    for (var r = 0; r < rooms.length; r++) {
        var room = _buildGroup(rooms[r], "room", ctx);
        if (room) {
            groups.push(room);
        }
    }
    for (var z = 0; z < zones.length; z++) {
        var zone = _buildGroup(zones[z], "zone", ctx);
        if (zone) {
            groups.push(zone);
        }
    }

    groups.sort(function (a, b) {
        if (a.kind !== b.kind) {
            return a.kind === "room" ? -1 : 1;
        }
        return a.name.localeCompare(b.name);
    });

    var scenes = [];
    for (var s = 0; s < rawScenes.length; s++) {
        var scene = rawScenes[s];
        scenes.push({
            id: scene.id,
            name: scene.metadata ? scene.metadata.name : "Scene",
            groupId: scene.group ? scene.group.rid : "",
            active: !!(scene.status && scene.status.active
                       && scene.status.active !== "inactive")
        });
    }

    var anyOn = false;
    for (var k = 0; k < lights.length; k++) {
        if (lights[k].on) {
            anyOn = true;
            break;
        }
    }

    return { groups: groups, lights: lights, scenes: scenes, anyOn: anyOn };
}

// Splits the batched curl response (see HueBridge.qml) into resource arrays.
function splitBatch(text, separator) {
    var parts = String(text).split(separator || "__HSPLIT__");
    var out = [];
    for (var i = 0; i < parts.length; i++) {
        var chunk = parts[i].trim();
        if (!chunk) {
            out.push(null);
            continue;
        }
        try {
            var parsed = JSON.parse(chunk);
            out.push(parsed && parsed.data ? parsed.data : null);
        } catch (e) {
            out.push(null);
        }
    }
    return out;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { buildModel, splitBatch };
}
