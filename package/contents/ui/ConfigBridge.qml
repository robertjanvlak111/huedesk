import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_bridgeIp: ipField.text
    property alias cfg_appKey: keyField.text
    property alias cfg_pollInterval: pollSpin.value

    QQC2.TextField {
        id: ipField
        Kirigami.FormData.label: "Bridge address:"
        placeholderText: "192.168.1.x"
    }

    QQC2.TextField {
        id: keyField
        Kirigami.FormData.label: "Application key:"
        echoMode: TextInput.Password
    }

    QQC2.Label {
        text: "Clear the key and reopen the widget to pair again."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.SpinBox {
        id: pollSpin
        Kirigami.FormData.label: "Refresh every:"
        from: 5
        to: 300
        stepSize: 5
        textFromValue: (value) => value + " s"
        valueFromText: (text) => parseInt(text)
    }

    QQC2.Label {
        text: "Lower values react faster to changes made elsewhere,\nat the cost of more requests to the bridge."
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
