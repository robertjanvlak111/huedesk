/*
 * TintedIcon.qml - a bundled icon, drawn in a colour of our choosing.
 *
 * Kirigami.Icon ignores its `color` when the source is a plain SVG file, so
 * every bundled icon rendered as the black silhouette in the file - all but
 * invisible on a dark card. This builds the SVG at runtime with the fill
 * baked in instead, which needs no graphical effects and cannot silently
 * fail. Alpha goes into the SVG too, leaving `opacity` free for callers.
 */

import QtQuick
import "../code/Icons.js" as Icons

Image {
    id: icon

    property string name: "bulb"
    property color tint: "#000000"

    readonly property string hexTint: {
        function channel(v) {
            var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)
            return s.length < 2 ? "0" + s : s
        }
        return "#" + channel(tint.r) + channel(tint.g) + channel(tint.b)
    }

    source: Icons.url(name, hexTint, tint.a)

    // Rasterise at the displayed size so the shape stays crisp.
    sourceSize.width: Math.max(1, Math.round(width))
    sourceSize.height: Math.max(1, Math.round(height))
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: false
}
