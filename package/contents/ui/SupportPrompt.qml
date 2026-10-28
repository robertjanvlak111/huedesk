/*
 * SupportPrompt.qml - the one-time support message.
 *
 * Deliberately contained: it overlays the widget rather than opening a system
 * window, so it cannot steal focus from whatever you are doing. It is shown
 * once, ever, and says so.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: prompt

    property var theme: null
    readonly property string kofiUrl: "https://ko-fi.com/robertjanvlak"

    signal dismissed()

    // Catches clicks so nothing behind the message reacts while it is up.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {}
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(theme.background.r, theme.background.g,
                       theme.background.b, 0.88)
    }

    Rectangle {
        id: cardBody
        anchors.centerIn: parent
        width: Math.min(parent.width - theme.pad * 2, theme.unit * 17)
        height: content.implicitHeight + theme.pad * 2
        radius: theme.radius
        color: theme.surface
        border.width: 1
        border.color: theme.outline

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: theme.pad
            spacing: Math.round(theme.gap * 0.8)

            TintedIcon {
                name: "heart"
                tint: theme.accent
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.round(theme.unit * 2)
                Layout.preferredHeight: Layout.preferredWidth
            }

            PlasmaComponents.Label {
                text: "Enjoying Hue Desk?"
                font: theme.titleFont
                color: theme.onSurface
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: "You have been using it for about three months. "
                    + "It is free and always will be, but if it has been "
                    + "useful you can buy me a coffee."
                font: theme.bodyFont
                color: theme.onSurfaceMuted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: "This message appears only once — you will not be asked again."
                font: theme.captionFont
                color: theme.onSurfaceMuted
                opacity: 0.8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.topMargin: Math.round(theme.gap * 0.3)
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(theme.gap * 0.5)
                spacing: theme.gap

                PlasmaComponents.Button {
                    text: "No thanks"
                    flat: true
                    font: theme.bodyFont
                    onClicked: prompt.dismissed()
                }

                PlasmaComponents.Button {
                    text: "Buy me a coffee"
                    font: theme.bodyFont
                    onClicked: {
                        Qt.openUrlExternally(prompt.kofiUrl)
                        prompt.dismissed()
                    }
                }
            }
        }
    }
}
