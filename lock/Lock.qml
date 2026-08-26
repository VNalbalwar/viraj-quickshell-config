import Quickshell
import Quickshell.Wayland
import QtQuick
import "../theme"

PanelWindow {
    id: root

    visible: LockState.visible

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    Rectangle {
        anchors.fill: parent

        color: Colors.bg1
    }

    Text {
        anchors.centerIn: parent

        text: "LOCK SCREEN"
        color: Colors.fg

        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 32
            weight: Font.DemiBold
        }
    }
}