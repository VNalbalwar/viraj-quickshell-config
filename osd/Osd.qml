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

        Row {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 24
                rightMargin: 24
            }

            spacing: 14

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
                id: brightnessBar

                width: 360
                height: 6
                radius: 3
                color: Colors.alpha(Colors.colFg, 0.15)

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
}
