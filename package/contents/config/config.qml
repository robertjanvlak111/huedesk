import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "Bridge"
        icon: "network-server"
        source: "ConfigBridge.qml"
    }
    ConfigCategory {
        name: "Appearance"
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
    ConfigCategory {
        name: "Content"
        icon: "view-list-details"
        source: "ConfigContent.qml"
    }
    ConfigCategory {
        name: "Support"
        icon: "help-donate"
        source: "ConfigSupport.qml"
    }
}
