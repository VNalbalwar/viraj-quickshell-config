import Quickshell
import Quickshell.Wayland
import QtQuick
import "../theme"

PanelWindow {
    property var screen

    anchors {
        top: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    implicitHeight: 110

    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        id: osdPill

        width: 260
        height: 58
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        topMargin: 42

        radius: 29
        color: "#000000"
        antialiasing: true

        opacity: OsdState.visible ? 1 : 0
        scale: OsdState.visible ? 1 : 0.88
        y: OsdState.visible ? 0 : -12
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.centerIn: parent
            text: "OSD"
            color: Colors.fg
            font {
                pixelSize: 15
                weight: Font.DemiBold
            }
        }
    }
}
