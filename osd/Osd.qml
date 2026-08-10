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
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Row {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 22
            rightMargin: 22
        }

        spacing: 12

        Text {
            text: "󰃠"
            color: Colors.fg
            font {
                pixelSize: 20
                family: "JetBrainsMono Nerd Font"
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 340
            height: 6
            radius: 3
            color: Colors.alpha(Colors.colFg, 0.16)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: parent.width * (OsdState.brightness / 100)
                height: parent.height
                radius: parent.radius
                color: Colors.fg

                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            text: OsdState.brightness + "%"
            color: Colors.fg
            font {
                pixelSize: 13
                weight: Font.DemiBold
            }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
