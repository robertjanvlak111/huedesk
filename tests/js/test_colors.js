/*
 * Tests for HueColors, the xy / mirek to RGB conversions.
 */

function isHex(value) {
    return /^#[0-9a-f]{6}$/.test(value);
}

test("xyToHex returns a hex colour", function () {
    ok(isHex(HueColors.xyToHex(0.45, 0.41, 100)), "well formed");
});

test("xyToHex guards against a zero y", function () {
    equal(HueColors.xyToHex(0.3, 0, 100), "#ffffff");
});

test("a redder chromaticity yields more red than green", function () {
    var hex = HueColors.xyToHex(0.64, 0.33, 100);
    var r = parseInt(hex.substr(1, 2), 16);
    var g = parseInt(hex.substr(3, 2), 16);
    ok(r > g, "red channel dominates: " + hex);
});

test("a bluer chromaticity yields more blue than red", function () {
    var hex = HueColors.xyToHex(0.15, 0.06, 100);
    var r = parseInt(hex.substr(1, 2), 16);
    var b = parseInt(hex.substr(5, 2), 16);
    ok(b > r, "blue channel dominates: " + hex);
});

test("lowering brightness darkens the result", function () {
    function sum(hex) {
        return parseInt(hex.substr(1, 2), 16) + parseInt(hex.substr(3, 2), 16)
             + parseInt(hex.substr(5, 2), 16);
    }
    ok(sum(HueColors.xyToHex(0.45, 0.41, 20))
       < sum(HueColors.xyToHex(0.45, 0.41, 100)), "dim is darker");
});

test("mirekToHex gets cooler as mirek falls", function () {
    // Hue's coldest setting is 153 mirek, i.e. ~6536K. That is just under the
    // ~6600K neutral point of the blackbody approximation, so it is still a
    // shade warm in absolute terms. What matters is that it is cooler than a
    // warm setting, so compare the blue/red ratio rather than asserting
    // blue dominance outright.
    function blueOverRed(hex) {
        return parseInt(hex.substr(5, 2), 16) / parseInt(hex.substr(1, 2), 16);
    }
    var warm = HueColors.mirekToHex(500, 100);   // ~2000K
    var cool = HueColors.mirekToHex(153, 100);   // ~6536K
    ok(blueOverRed(warm) < 0.6, "2000K is strongly red: " + warm);
    ok(blueOverRed(cool) > blueOverRed(warm),
       "6536K is cooler than 2000K: " + cool + " vs " + warm);
});

test("mirekToHex guards against zero", function () {
    equal(HueColors.mirekToHex(0, 100), "#ffffff");
});

test("stateToHex prefers xy, then mirek, then a warm default", function () {
    ok(isHex(HueColors.stateToHex({ hasColor: true, x: 0.4, y: 0.4, bri: 90 })));
    equal(HueColors.stateToHex({ hasColor: false, mirek: 300, bri: 90 }),
          HueColors.mirekToHex(300, 90));
    equal(HueColors.stateToHex({ hasColor: false, mirek: 0 }), "#ffe9c4");
    equal(HueColors.stateToHex(null), "#ffffff");
});

test("hexToXy round-trips close to the original chromaticity", function () {
    var xy = HueColors.hexToXy(HueColors.xyToHex(0.45, 0.41, 100));
    ok(Math.abs(xy.x - 0.45) < 0.08, "x within tolerance: " + xy.x);
    ok(Math.abs(xy.y - 0.41) < 0.08, "y within tolerance: " + xy.y);
});

test("hexToXy handles black without dividing by zero", function () {
    var xy = HueColors.hexToXy("#000000");
    ok(isFinite(xy.x) && isFinite(xy.y), "finite values");
});
