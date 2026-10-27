/*
 * Tests for HueModel.buildModel and splitBatch.
 *
 * Runs inside the test harness, which provides assert helpers, the HueColors
 * and HueModel modules, and FIXTURE (tests/fixtures/clipv2.json).
 */

var F = FIXTURE;

function build() {
    return HueModel.buildModel(F.room, F.zone, F.grouped_light,
                               F.light, F.scene, HueColors);
}

test("every light is converted", function () {
    equal(build().lights.length, 4);
});

test("a room joins its lights through device ids", function () {
    var living = build().groups.filter(function (g) { return g.id === "room-living"; })[0];
    ok(living, "living room present");
    equal(living.lightIds.length, 3);
    ok(living.lightIds.indexOf("light-ceiling") !== -1, "ceiling joined");
    ok(living.lightIds.indexOf("light-plug") !== -1, "plug joined");
});

test("a zone joins its lights by light id", function () {
    var zone = build().groups.filter(function (g) { return g.id === "zone-down"; })[0];
    ok(zone, "zone present");
    equal(zone.kind, "zone");
    equal(zone.lightIds.length, 2);
});

test("a room with no members is dropped", function () {
    var ids = build().groups.map(function (g) { return g.id; });
    ok(ids.indexOf("room-empty") === -1, "empty room omitted");
});

test("a room with no grouped_light service is dropped", function () {
    var ids = build().groups.map(function (g) { return g.id; });
    ok(ids.indexOf("room-noservice") === -1, "room without grouped light omitted");
});

test("rooms sort before zones", function () {
    var kinds = build().groups.map(function (g) { return g.kind; });
    equal(kinds[kinds.length - 1], "zone");
    equal(kinds.indexOf("zone"), kinds.length - 1);
});

test("grouped light state carries through", function () {
    var living = build().groups.filter(function (g) { return g.id === "room-living"; })[0];
    equal(living.on, true);
    equal(living.bri, 64);
});

test("lit members are counted", function () {
    var living = build().groups.filter(function (g) { return g.id === "room-living"; })[0];
    // Ceiling and the plug are on; the floor lamp is off.
    equal(living.litCount, 2);
    equal(living.totalCount, 3);
});

test("a plug is flagged and is not dimmable", function () {
    var plug = build().lights.filter(function (l) { return l.id === "light-plug"; })[0];
    equal(plug.isPlug, true);
    equal(plug.dimmable, false);
});

test("a room is dimmable when any member is", function () {
    var living = build().groups.filter(function (g) { return g.id === "room-living"; })[0];
    equal(living.dimmable, true);
});

test("a room of only plugs is not dimmable", function () {
    var onlyPlug = {
        id: "room-plugs", metadata: { name: "Plugs", archetype: "other" },
        children: [{ rid: "dev-plug", rtype: "device" }],
        services: [{ rid: "gl-living", rtype: "grouped_light" }]
    };
    var model = HueModel.buildModel([onlyPlug], [], F.grouped_light,
                                    F.light, [], HueColors);
    equal(model.groups.length, 1);
    equal(model.groups[0].dimmable, false);
});

test("tint comes from a lit non-plug member", function () {
    var living = build().groups.filter(function (g) { return g.id === "room-living"; })[0];
    var ceiling = build().lights.filter(function (l) { return l.id === "light-ceiling"; })[0];
    equal(living.hex, ceiling.hex);
});

test("scene active state is normalised to a boolean", function () {
    var scenes = build().scenes;
    var relax = scenes.filter(function (s) { return s.id === "scene-relax"; })[0];
    var focus = scenes.filter(function (s) { return s.id === "scene-focus"; })[0];
    var night = scenes.filter(function (s) { return s.id === "scene-night"; })[0];
    equal(relax.active, true);
    equal(focus.active, false);
    equal(night.active, false, "a scene with no status block is inactive");
});

test("scenes keep their owning group", function () {
    var relax = build().scenes.filter(function (s) { return s.id === "scene-relax"; })[0];
    equal(relax.groupId, "room-living");
});

test("anyOn reflects the lights", function () {
    equal(build().anyOn, true);
    var allOff = F.light.map(function (l) {
        var copy = JSON.parse(JSON.stringify(l));
        copy.on = { on: false };
        return copy;
    });
    equal(HueModel.buildModel(F.room, [], F.grouped_light, allOff, [], HueColors).anyOn,
          false);
});

test("missing resource arrays are tolerated", function () {
    var model = HueModel.buildModel(null, null, null, null, null, HueColors);
    equal(model.groups.length, 0);
    equal(model.lights.length, 0);
    equal(model.anyOn, false);
});

test("splitBatch separates and parses each chunk", function () {
    var text = '{"data":[{"id":"a"}]}\n__HSPLIT__\n{"data":[]}\n__HSPLIT__\n';
    var parts = HueModel.splitBatch(text, "__HSPLIT__");
    equal(parts[0].length, 1);
    equal(parts[0][0].id, "a");
    equal(parts[1].length, 0);
    equal(parts[2], null, "trailing empty chunk becomes null");
});

test("splitBatch returns null for a chunk that is not JSON", function () {
    var parts = HueModel.splitBatch('not json\n__HSPLIT__\n{"data":[]}', "__HSPLIT__");
    equal(parts[0], null);
    equal(parts[1].length, 0);
});

test("splitBatch returns null when the bridge sends an error body", function () {
    // An unauthenticated CLIP v2 reply has `errors` but no `data`.
    var parts = HueModel.splitBatch('{"errors":[{"description":"unauthorized"}]}',
                                    "__HSPLIT__");
    equal(parts[0], null);
});
