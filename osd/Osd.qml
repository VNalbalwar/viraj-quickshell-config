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
        id: osdContent

        anchors.centerIn: parent
        spacing: 12

        Text {
            text: OsdState.mode === "audio-output"
                ? OsdState.audioOutputIcon
                : OsdState.mode === "performance"
                    ? "⚡"
                    : OsdState.mode === "fan"
                        ? "󰈐"
                        : OsdState.mode === "wifi"
                            ? OsdState.wifiIcon
                            : OsdState.mode === "bluetooth"
                                ? OsdState.bluetoothIcon
                                : OsdState.mode === "lock"
                                    ? (OsdState.lockType === "caps" ? "⇪" : "󰎤")
                                    : OsdState.mode === "mic"
                                        ? "󰍬"
                                        : OsdState.mode === "battery"
                                            ? (
                                                OsdState.batteryState === "charging"
                                                    ? (OsdState.battery >= 90 ? "󰂋"
                                                        : OsdState.battery >= 80 ? "󰂊"
                                                        : OsdState.battery >= 60 ? "󰂉"
                                                        : OsdState.battery >= 40 ? "󰂈"
                                                        : OsdState.battery >= 30 ? "󰂇"
                                                        : OsdState.battery >= 20 ? "󰂆"
                                                        : "󰂄")
                                                    : OsdState.battery >= 90 ? "󰂂"
                                                        : OsdState.battery >= 80 ? "󰂁"
                                                        : OsdState.battery >= 70 ? "󰂀"
                                                        : OsdState.battery >= 60 ? "󰁿"
                                                        : OsdState.battery >= 50 ? "󰁾"
                                                        : OsdState.battery >= 40 ? "󰁽"
                                                        : OsdState.battery >= 30 ? "󰁼"
                                                        : OsdState.battery >= 20 ? "󰁻"
                                                        : OsdState.battery >= 10 ? "󰁺"
                                                        : "󰂎"
                                            )
                                            : OsdState.mode === "volume"
                                                ? (OsdState.muted ? "󰖁" : "󰕾")
                                                : "󰃠"
            color: Colors.fg
            font {
                pixelSize: 20
                family: "JetBrainsMono Nerd Font"
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            visible: OsdState.mode !== "mic" &&
                     OsdState.mode !== "lock" &&
                     OsdState.mode !== "audio-output" &&
                     OsdState.mode !== "performance" &&
                     OsdState.mode !== "fan" &&
                     OsdState.mode !== "wifi" &&
                     OsdState.mode !== "bluetooth"
            width: 340
            height: 6
            radius: 3
            color: Colors.alpha(Colors.colFg, 0.16)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: parent.width * (
                    (OsdState.mode === "volume"
                        ? OsdState.volume
                        : OsdState.mode === "battery"
                            ? OsdState.battery
                            : OsdState.brightness) / 100
                )
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
            text: OsdState.mode === "audio-output"
                ? OsdState.audioOutputName
                : OsdState.mode === "performance"
                    ? OsdState.performanceLabel
                    : OsdState.mode === "fan"
                        ? OsdState.fanMode
                        : OsdState.mode === "wifi"
                            ? (!OsdState.wifiEnabled
                                ? "Wi-Fi Off"
                                : (OsdState.wifiConnected ? OsdState.wifiName : "Wi-Fi Disconnected"))
                            : OsdState.mode === "bluetooth"
                                ? (OsdState.bluetoothConnected
                                    ? OsdState.bluetoothName
                                    : (OsdState.bluetoothPowered ? "Bluetooth On" : "Bluetooth Off"))
                                : OsdState.mode === "lock"
                                    ? (OsdState.lockType === "caps"
                                        ? (OsdState.capsLock ? "Caps Lock On" : "Caps Lock Off")
                                        : (OsdState.numLock ? "Num Lock On" : "Num Lock Off"))
                                    : OsdState.mode === "mic"
                                        ? (OsdState.micMuted ? "Microphone Muted" : "Microphone On")
                                        : OsdState.mode === "battery"
                                            ? (OsdState.batteryState === "fully-charged"
                                                ? "Fully Charged"
                                                : OsdState.battery + "%")
                                            : ((OsdState.mode === "volume"
                                                ? OsdState.volume
                                                : OsdState.brightness) + "%")
            color: Colors.fg
            font {
                pixelSize: 13
                weight: Font.DemiBold
            }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
