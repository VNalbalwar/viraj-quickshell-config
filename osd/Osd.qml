import Quickshell
import QtQuick
import "../theme"

Item {
    anchors.fill: parent
    visible: OsdState.visible
    opacity: OsdState.visible ? 1 : 0
    z: 100

    Behavior on opacity {
        NumberAnimation {
            duration: 220
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
