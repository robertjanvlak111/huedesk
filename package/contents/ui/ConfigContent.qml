import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_showHeader: headerCheck.checked
    property alias cfg_showLights: lightsCheck.checked
    property alias cfg_showScenes: scenesCheck.checked
    property alias cfg_showZones: zonesCheck.checked
    property alias cfg_accentTint: tintCheck.checked

    QQC2.CheckBox {
        id: headerCheck
        Kirigami.FormData.label: "Show:"
        text: "Header with master switch"
    }

    QQC2.CheckBox {
        id: lightsCheck
        text: "Individual lights when a room is expanded"
    }

    QQC2.CheckBox {
        id: scenesCheck
        text: "Scenes"
    }

    QQC2.CheckBox {
        id: zonesCheck
        text: "Zones as well as rooms"
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: tintCheck
        Kirigami.FormData.label: "Colour:"
        text: "Tint cards with the light colour"
    }

    QQC2.Label {
        text: "When off, cards use the accent colour instead."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
