/*
 * ConfigSupport.qml - the "Support" page of the widget's settings.
 *
 * Plasma adds its own About page, generated from metadata.json, which cannot
 * be extended. This sits beside it rather than competing with it, and is
 * where the project links live.
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    spacing: Kirigami.Units.largeSpacing

    readonly property string version: {
        try {
            return Plasmoid.metaData.version || ""
        } catch (e) {
            return ""
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Image {
            source: Qt.resolvedUrl("../icons/bulb.svg")
            sourceSize.width: Kirigami.Units.iconSizes.huge
            sourceSize.height: Kirigami.Units.iconSizes.huge
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            fillMode: Image.PreserveAspectFit
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            QQC2.Label {
                text: page.version !== "" ? "Hue Desk " + page.version : "Hue Desk"
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            }

            QQC2.Label {
                text: "Control your Philips Hue lights from your desktop."
                opacity: 0.75
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    Kirigami.Separator { Layout.fillWidth: true }

    QQC2.Label {
        text: "Hue Desk is free and open source, and always will be. "
            + "If it has been useful, you can buy me a coffee."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        QQC2.Button {
            text: "Buy me a coffee"
            onClicked: Qt.openUrlExternally("https://ko-fi.com/robertjanvlak")
        }

        QQC2.Button {
            text: "Project page"
            onClicked: Qt.openUrlExternally("https://github.com/robertjanvlak111/huedesk")
        }

        QQC2.Button {
            text: "Report a problem"
            onClicked: Qt.openUrlExternally("https://github.com/robertjanvlak111/huedesk/issues")
        }

        Item { Layout.fillWidth: true }
    }

    QQC2.Label {
        text: "The widget mentions this once, after about three months of use, "
            + "and never again. Nothing is sent anywhere: the date of first "
            + "use is stored in this widget's own settings and the check "
            + "happens on your machine."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Item { Layout.fillHeight: true }
}
