/*
 * Theme.qml - every colour, metric and font the widget uses.
 *
 * Plasma widgets normally inherit the desktop theme wholesale. Hue Desk lets
 * the user override that (light / dark / follow desktop, font, scale, density)
 * so the widget can match the Hue app rather than the desktop, which is why
 * the tokens are resolved here instead of read from Kirigami at each use.
 */

import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    id: theme

    property string mode: "auto"          // auto | light | dark
    // Empty means "use the bundled font"; anything else names an installed family.
    property string fontFamilyOverride: ""
    property int fontScale: 100           // percent
    property string density: "cosy"       // compact | cosy | comfortable
    property int radius: 14
    property int cardAlpha: 100           // percent

    // "auto" follows the desktop: decide from the Plasma background luminance.
    readonly property bool isDark: {
        if (mode === "dark") {
            return true
        }
        if (mode === "light") {
            return false
        }
        var c = Kirigami.Theme.backgroundColor
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.5
    }

    // -- palette ----------------------------------------------------------
    readonly property color background: isDark ? "#17171b" : "#f2f2f5"
    readonly property color surface: isDark ? "#242429" : "#ffffff"
    readonly property color surfaceRaised: isDark ? "#2e2e34" : "#f7f7fa"
    readonly property color onSurface: isDark ? "#f6f6f8" : "#1b1b20"
    readonly property color onSurfaceMuted: isDark ? "#9a9aa4" : "#6a6a74"
    readonly property color outline: isDark ? Qt.rgba(1, 1, 1, 0.10)
                                            : Qt.rgba(0, 0, 0, 0.09)
    readonly property color accent: "#ffb648"
    readonly property color danger: isDark ? "#ff6b6b" : "#c92a2a"

    // Colour of a lit bulb's fill, kept readable against the card.
    function litFill(hex) {
        var c = Qt.color(hex)
        return isDark ? Qt.darker(c, 1.25) : Qt.lighter(c, 1.05)
    }

    // -- metrics ----------------------------------------------------------
    readonly property int unit: Kirigami.Units.gridUnit
    readonly property int gap: density === "compact" ? Math.round(unit * 0.25)
                             : density === "comfortable" ? Math.round(unit * 0.6)
                             : Math.round(unit * 0.4)
    readonly property int pad: density === "compact" ? Math.round(unit * 0.4)
                             : density === "comfortable" ? Math.round(unit * 0.85)
                             : Math.round(unit * 0.6)
    readonly property int cardHeight: density === "compact" ? Math.round(unit * 2.6)
                                    : density === "comfortable" ? Math.round(unit * 3.6)
                                    : Math.round(unit * 3.1)
    readonly property int rowHeight: density === "compact" ? Math.round(unit * 1.5)
                                   : density === "comfortable" ? Math.round(unit * 2.1)
                                   : Math.round(unit * 1.8)

    // -- type -------------------------------------------------------------
    //
    // Archivo SemiExpanded ships with the widget (SIL OFL 1.1, see
    // contents/fonts/OFL.txt) so that Hue Desk looks the same on every
    // machine instead of depending on what the user happens to have
    // installed. FontLoader registers it for this process only.
    property FontLoader _fontRegular: FontLoader {
        source: Qt.resolvedUrl("../fonts/ArchivoSemiExpanded-Regular.ttf")
    }
    property FontLoader _fontMedium: FontLoader {
        source: Qt.resolvedUrl("../fonts/ArchivoSemiExpanded-Medium.ttf")
    }
    property FontLoader _fontSemiBold: FontLoader {
        source: Qt.resolvedUrl("../fonts/ArchivoSemiExpanded-SemiBold.ttf")
    }

    // Empty until the file has loaded, or if it failed to load at all.
    readonly property string bundledFamily: _fontRegular.status === FontLoader.Ready
                                            ? _fontRegular.font.family : ""

    readonly property string family: {
        if (fontFamilyOverride !== "") {
            return fontFamilyOverride
        }
        if (bundledFamily !== "") {
            return bundledFamily
        }
        return Kirigami.Theme.defaultFont.family
    }
    readonly property real scale: Math.max(0.7, Math.min(1.8, fontScale / 100))

    readonly property font titleFont: Qt.font({
        family: family,
        pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.15 * scale),
        weight: Font.DemiBold
    })
    readonly property font bodyFont: Qt.font({
        family: family,
        pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * scale),
        weight: Font.Normal
    })
    readonly property font labelFont: Qt.font({
        family: family,
        pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.95 * scale),
        weight: Font.Medium
    })
    readonly property font captionFont: Qt.font({
        family: family,
        pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.82 * scale),
        weight: Font.Normal
    })
}
