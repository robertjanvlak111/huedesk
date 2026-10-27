.pragma library

// Hue reports colour as CIE xy plus a separate brightness percentage, and
// colour temperature in mired. Both need converting before we can tint anything.

function _gamma(c) {
    c = Math.max(0, Math.min(1, c));
    return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
}

function _hex(r, g, b) {
    function h(v) {
        var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16);
        return s.length === 1 ? "0" + s : s;
    }
    return "#" + h(r) + h(g) + h(b);
}

// xy chromaticity (Hue's wide gamut) + brightness 0..100 -> "#rrggbb"
function xyToHex(x, y, briPercent) {
    if (!y || y <= 0) {
        return "#ffffff";
    }
    var Y = Math.max(0.05, (briPercent === undefined ? 100 : briPercent) / 100);
    var X = (Y / y) * x;
    var Z = (Y / y) * (1 - x - y);

    var r = X * 1.656492 - Y * 0.354851 - Z * 0.255038;
    var g = -X * 0.707196 + Y * 1.655397 + Z * 0.036152;
    var b = X * 0.051713 - Y * 0.121364 + Z * 1.011530;

    // Desaturate rather than clip, so out-of-gamut values keep their hue.
    var m = Math.max(r, g, b);
    if (m > 1) {
        r /= m; g /= m; b /= m;
    }
    return _hex(_gamma(r), _gamma(g), _gamma(b));
}

// Mired (Hue's "mirek") -> "#rrggbb", via the usual blackbody approximation.
function mirekToHex(mirek, briPercent) {
    if (!mirek || mirek <= 0) {
        return "#ffffff";
    }
    var k = 1000000 / mirek;
    var t = k / 100;
    var r, g, b;

    if (t <= 66) {
        r = 255;
        g = 99.4708025861 * Math.log(t) - 161.1195681661;
    } else {
        r = 329.698727446 * Math.pow(t - 60, -0.1332047592);
        g = 288.1221695283 * Math.pow(t - 60, -0.0755148492);
    }
    if (t >= 66) {
        b = 255;
    } else if (t <= 19) {
        b = 0;
    } else {
        b = 138.5177312231 * Math.log(t - 10) - 305.0447927307;
    }

    // Brightness only dims the tint a little; a dim bulb should still read warm.
    var scale = 0.55 + 0.45 * ((briPercent === undefined ? 100 : briPercent) / 100);
    return _hex((r / 255) * scale, (g / 255) * scale, (b / 255) * scale);
}

// Pick whichever representation the light actually reports.
function stateToHex(st) {
    if (!st) {
        return "#ffffff";
    }
    if (st.hasColor && st.x !== undefined) {
        return xyToHex(st.x, st.y, st.bri);
    }
    if (st.mirek) {
        return mirekToHex(st.mirek, st.bri);
    }
    return "#ffe9c4";
}

// Approximate inverse of xyToHex, for the colour picker.
function hexToXy(hex) {
    var c = hex.replace("#", "");
    var r = parseInt(c.substr(0, 2), 16) / 255;
    var g = parseInt(c.substr(2, 2), 16) / 255;
    var b = parseInt(c.substr(4, 2), 16) / 255;

    function lin(v) {
        return v > 0.04045 ? Math.pow((v + 0.055) / 1.055, 2.4) : v / 12.92;
    }
    r = lin(r); g = lin(g); b = lin(b);

    var X = r * 0.649926 + g * 0.103455 + b * 0.197109;
    var Y = r * 0.234327 + g * 0.743075 + b * 0.022598;
    var Z = r * 0.000000 + g * 0.053077 + b * 1.035763;

    var sum = X + Y + Z;
    if (sum === 0) {
        return { x: 0.3127, y: 0.3290 };
    }
    return { x: X / sum, y: Y / sum };
}

// QML's engine has no `module`, so this tail is inert there and only takes
// effect under Node, letting the test suite exercise this exact file.
if (typeof module !== "undefined" && module.exports) {
    module.exports = { xyToHex, mirekToHex, stateToHex, hexToXy };
}
