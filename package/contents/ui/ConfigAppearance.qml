import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property string cfg_themeMode: "auto"
    property string cfg_fontFamily: ""
    property alias cfg_fontScale: scaleSlider.value
    property string cfg_density: "cosy"
    property alias cfg_cornerRadius: radiusSlider.value
    property alias cfg_cardOpacity: opacitySlider.value

    QQC2.ComboBox {
        Kirigami.FormData.label: "Theme:"
        model: [
            { label: "Follow desktop", value: "auto" },
            { label: "Light", value: "light" },
            { label: "Dark", value: "dark" }
        ]
        textRole: "label"
        valueRole: "value"
        currentIndex: Math.max(0, indexOfValue(page.cfg_themeMode))
        onActivated: page.cfg_themeMode = currentValue
    }

    QQC2.ComboBox {
        id: fontBox
        Kirigami.FormData.label: "Font:"
        editable: false
        readonly property string defaultLabel: "Hue Desk default (Archivo SemiExpanded)"
        model: [defaultLabel].concat(Qt.fontFamilies())
        currentIndex: {
            if (page.cfg_fontFamily === "") {
                return 0
            }
            var i = model.indexOf(page.cfg_fontFamily)
            return i === -1 ? 0 : i
        }
        onActivated: page.cfg_fontFamily = (currentIndex === 0 ? "" : currentText)
    }

    RowLayout {
        Kirigami.FormData.label: "Text size:"
        QQC2.Slider {
            id: scaleSlider
            from: 75
            to: 150
            stepSize: 5
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label { text: scaleSlider.value + "%" }
    }

    QQC2.ComboBox {
        Kirigami.FormData.label: "Density:"
        model: [
            { label: "Compact", value: "compact" },
            { label: "Cosy", value: "cosy" },
            { label: "Comfortable", value: "comfortable" }
        ]
        textRole: "label"
        valueRole: "value"
        currentIndex: Math.max(0, indexOfValue(page.cfg_density))
        onActivated: page.cfg_density = currentValue
    }

    RowLayout {
        Kirigami.FormData.label: "Corner rounding:"
        QQC2.Slider {
            id: radiusSlider
            from: 0
            to: 28
            stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label { text: radiusSlider.value + " px" }
    }

    RowLayout {
        Kirigami.FormData.label: "Card opacity:"
        QQC2.Slider {
            id: opacitySlider
            from: 30
            to: 100
            stepSize: 5
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        }
        QQC2.Label { text: opacitySlider.value + "%" }
    }
}
