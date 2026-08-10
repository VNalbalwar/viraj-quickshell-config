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
    implicitHeight: 44

    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        id: osdPill

        width: 500
        height: 44
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // Exact same geometry as the normal notch.
        radius: 0
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 16
        bottomRightRadius: 16
        color: "#000000"
        antialiasing: true

        opacity: OsdState.visible ? 1 : 0
        scale: OsdState.visible ? 1 : 0.96
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 320
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
