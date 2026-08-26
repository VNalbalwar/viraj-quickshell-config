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

    Image {
        id: wallpaper

        anchors.fill: parent

        source: "file:///home/viraj/.cache/wallpaper_frame.png"
        fillMode: Image.PreserveAspectCrop

        asynchronous: true
        cache: false
    }

    Rectangle {
        anchors.fill: parent

        color: Colors.bg1
        opacity: 0.55
    }
}