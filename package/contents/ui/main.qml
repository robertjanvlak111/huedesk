/*
 * main.qml - entry point. Owns the bridge client, the theme and the poll
 * timer, and renders inline on the desktop rather than behind a tray icon.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import "../code" as HueCode
import "../code/Support.js" as Support

PlasmoidItem {
    id: root

    readonly property HueCode.HueBridge hue: hueBridge
    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar

    // The widget paints its own themed surface, so Plasma's panel background
    // would only fight it.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 12

    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    Layout.minimumHeight: Kirigami.Units.gridUnit * 10
    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredHeight: Kirigami.Units.gridUnit * 26

    toolTipMainText: "Hue Desk"
    toolTipSubText: {
        if (!hueBridge.paired) {
            return "Not paired with a bridge"
        }
        if (hueBridge.status === "error") {
            return hueBridge.lastError
        }
        var on = hueBridge.lights.filter(l => l.on).length
        return on + " of " + hueBridge.lights.length + " lights on"
    }

    // The support message is shown at most once, ever. The flag is written
    // the moment it is displayed rather than when it is dismissed, so a crash
    // or a restart cannot bring it back.
    property bool supportPromptVisible: false

    Component.onCompleted: {
        if (Plasmoid.configuration.firstRunDate === "") {
            Plasmoid.configuration.firstRunDate = Support.todayIso()
        }
        if (Support.shouldPrompt(Plasmoid.configuration.firstRunDate,
                                 Plasmoid.configuration.supportPromptShown,
                                 Support.todayIso())) {
            Plasmoid.configuration.supportPromptShown = true
            supportPromptVisible = true
        }
    }

    Theme {
        id: appTheme
        mode: Plasmoid.configuration.themeMode
        fontFamilyOverride: Plasmoid.configuration.fontFamily
        fontScale: Plasmoid.configuration.fontScale
        density: Plasmoid.configuration.density
        radius: Plasmoid.configuration.cornerRadius
        cardAlpha: Plasmoid.configuration.cardOpacity
    }

    HueCode.HueBridge {
        id: hueBridge
        ip: Plasmoid.configuration.bridgeIp
        appKey: Plasmoid.configuration.appKey

        onPairSucceeded: (key) => {
            Plasmoid.configuration.appKey = key
            Plasmoid.configuration.bridgeIp = hueBridge.ip
        }
        onBridgeFound: (addr) => {
            Plasmoid.configuration.bridgeIp = addr
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "All lights on"
            icon.name: "dialog-ok"
            enabled: hueBridge.paired
            onTriggered: hueBridge.setAll(true)
        },
        PlasmaCore.Action {
            text: "All lights off"
            icon.name: "dialog-cancel"
            enabled: hueBridge.paired
            onTriggered: hueBridge.setAll(false)
        },
        PlasmaCore.Action {
            text: "Refresh now"
            icon.name: "view-refresh"
            enabled: hueBridge.paired
            onTriggered: hueBridge.refresh()
        }
    ]

    Timer {
        interval: Math.max(5, Plasmoid.configuration.pollInterval) * 1000
        repeat: true
        running: hueBridge.paired
        triggeredOnStart: true
        onTriggered: hueBridge.refresh()
    }

    compactRepresentation: CompactRepresentation {
        hue: hueBridge
        theme: appTheme
        plasmoidItem: root
    }

    fullRepresentation: FullRepresentation {
        hue: hueBridge
        theme: appTheme
        showScenes: Plasmoid.configuration.showScenes
        showLights: Plasmoid.configuration.showLights
        showZones: Plasmoid.configuration.showZones
        accentTint: Plasmoid.configuration.accentTint
        showHeader: Plasmoid.configuration.showHeader
        showSupportPrompt: root.supportPromptVisible
        onSupportPromptDismissed: root.supportPromptVisible = false
    }
}
