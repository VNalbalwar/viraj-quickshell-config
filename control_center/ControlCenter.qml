import Quickshell
import Quickshell.Bluetooth
import QtQuick
import "../theme"
import "../osd"

// ─────────────────────────────────────────────────────────────────────────────
//  ControlCenter — lives INSIDE the notch (Bar.qml hosts it, like the power
//  menu / launcher). Same language as the rest of the notch: black island,
//  translucent colFg cards, colBlue for "on", hover pop, springy resize.
//
//  Pages   main · wifi · bluetooth · audio · clipboard · keys   (see *Page.qml)
//  Keys    arrows move · Enter toggles · Space/Tab opens a tile's detail page
//          Esc goes back / closes
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: cc

    signal powerRequested()

    readonly property bool active: ControlState.visible
    readonly property string page: ControlState.page
    readonly property bool onMain: page === "main"

    visible: active
    opacity: active ? 1 : 0
    focus: active

    property int selectedTile: 0

    Behavior on opacity { NumberAnimation { duration: 180 } }

    onActiveChanged: {
        if (active) {
            selectedTile = 0
            forceActiveFocus()
        }
    }

    // ── derived state ────────────────────────────────────────────────────────
    readonly property int btConnectedCount: {
        var n = 0
        var devs = Bluetooth.devices.values
        for (var i = 0; i < devs.length; i++)
            if (devs[i].connected) n++
        return n
    }

    readonly property var tiles: [
        {
            icon: !OsdState.wifiEnabled ? "󰖪" : (OsdState.wifiConnected ? "󰤨" : "󰤟"),
            label: "Wi-Fi",
            sub: !OsdState.wifiEnabled ? "Off" : (OsdState.wifiConnected ? OsdState.wifiName : "Not connected"),
            on: OsdState.wifiEnabled,
            detail: "wifi",
            trigger: function() { ControlState.toggleWifi() }
        },
        {
            icon: !ControlState.bluetoothEnabled ? "󰂲" : (btConnectedCount > 0 ? "󰂱" : "󰂯"),
            label: "Bluetooth",
            sub: !ControlState.bluetoothEnabled ? "Off" : (btConnectedCount > 0 ? btConnectedCount + " connected" : "On"),
            on: ControlState.bluetoothEnabled,
            detail: "bluetooth",
            trigger: function() { ControlState.toggleBluetooth() }
        },
        {
            icon: "󰀝",
            label: "Airplane",
            sub: ControlState.airplane ? "On" : "Off",
            on: ControlState.airplane,
            detail: "",
            trigger: function() { ControlState.toggleAirplane() }
        },
        {
            icon: ControlState.dnd ? "󰂛" : "󰂚",
            label: "DND",
            sub: ControlState.dnd ? "On" : "Off",
            on: ControlState.dnd,
            detail: "",
            trigger: function() { ControlState.toggleDnd() }
        },
        {
            icon: "󰓅",
            label: "Power",
            sub: ControlState.profileLabel,
            on: ControlState.effectiveProfile !== "balanced",
            detail: "",
            trigger: function() { ControlState.cycleProfile() }
        },
        {
            icon: "󰈐",
            label: "Fan",
            sub: OsdState.fanMode !== "" ? OsdState.fanMode : "N/A",
            on: OsdState.fanMode !== "" && OsdState.fanMode !== "Auto",
            detail: "",
            trigger: function() { ControlState.cycleFan() }
        },
        {
            icon: OsdState.micMuted ? "󰍭" : "󰍬",
            label: "Microphone",
            sub: OsdState.micMuted ? "Muted" : "Live",
            on: !OsdState.micMuted,
            detail: "",
            trigger: function() { ControlState.toggleMic() }
        },
        {
            icon: OsdState.audioOutputIcon,
            label: "Sound",
            sub: OsdState.audioOutputName !== "" ? OsdState.audioOutputName : "Output",
            on: false,
            detail: "",
            trigger: function() { ControlState.openPage("audio") }
        },
        {
            icon: "󰋩",
            label: "Wallpaper",
            sub: "Theme",
            on: false,
            detail: "",
            trigger: function() { ControlState.openWallpapers() }
        },
        {
            icon: "󰹑",
            label: "Capture",
            sub: "Region",
            on: false,
            detail: "",
            trigger: function() { ControlState.screenshot() }
        },
        {
            icon: "󰅌",
            label: "Clipboard",
            sub: "History",
            on: false,
            detail: "",
            trigger: function() { ControlState.openPage("clipboard") }
        }
    ]

    function moveTile(dx, dy) {
        var cols = Ui.columns
        var rows = Math.ceil(tiles.length / cols)
        var col = (selectedTile % cols + dx + cols) % cols
        var row = (Math.floor(selectedTile / cols) + dy + rows) % rows
        selectedTile = Math.min(row * cols + col, tiles.length - 1)
    }

    readonly property var pageItems: ({
        wifi: wifiPage, bluetooth: bluetoothPage, audio: audioPage, clipboard: clipboardPage, keys: keysPage
    })

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            ControlState.back()
            event.accepted = true
            return
        }

        if (onMain) {
            if (event.key === Qt.Key_Left) moveTile(-1, 0)
            else if (event.key === Qt.Key_Right) moveTile(1, 0)
            else if (event.key === Qt.Key_Up) moveTile(0, -1)
            else if (event.key === Qt.Key_Down) moveTile(0, 1)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) tiles[selectedTile].trigger()
            else if (event.key === Qt.Key_Space || event.key === Qt.Key_Tab) {
                if (tiles[selectedTile].detail !== "") ControlState.openPage(tiles[selectedTile].detail)
            } else return
            event.accepted = true
        } else {
            var p = pageItems[page]
            if (p) p.handleKey(event, false)
        }
    }

    // ── header (cross-fades between main and detail pages) ───────────────────
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: 16 }
        height: 34

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Control Center"
            color: Colors.fg
            opacity: cc.onMain ? 1 : 0
            x: cc.onMain ? 0 : -16
            font { pixelSize: 16; weight: Font.DemiBold }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            opacity: cc.onMain ? 0 : 1
            x: cc.onMain ? 16 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

            RoundButton {
                icon: "󰁍"
                onClicked: ControlState.back()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ({ wifi: "Wi-Fi", bluetooth: "Bluetooth", audio: "Sound", clipboard: "Clipboard", keys: "Keybinds" })[cc.page] || ""
                color: Colors.fg
                font { pixelSize: 16; weight: Font.DemiBold }
            }
        }

        // main: keybinds + battery + power
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 12
            opacity: cc.onMain ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RoundButton {
                icon: "󰌌"
                onClicked: ControlState.openPage("keys")
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    text: OsdState.batteryState === "charging" ? "󰂄" : "󰁹"
                    color: Colors.fg
                    anchors.verticalCenter: parent.verticalCenter
                    font { family: Ui.iconFont; pixelSize: 17 }
                }
                Text {
                    text: OsdState.battery + "%"
                    color: Colors.fg
                    opacity: 0.8
                    anchors.verticalCenter: parent.verticalCenter
                    font { pixelSize: 13; weight: Font.DemiBold }
                }
            }

            RoundButton {
                icon: "󰐥"
                onClicked: cc.powerRequested()
            }
        }

        // wifi / bluetooth pages: rescan + enable switch
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 12
            opacity: (cc.page === "wifi" || cc.page === "bluetooth") ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RoundButton {
                icon: "󰑐"
                spinOnClick: true
                onClicked: cc.page === "wifi" ? ControlState.rescanWifi() : ControlState.setBluetoothScan(true)
            }

            Pill {
                anchors.verticalCenter: parent.verticalCenter
                on: cc.page === "wifi" ? OsdState.wifiEnabled : ControlState.bluetoothEnabled
                onToggled: cc.page === "wifi" ? ControlState.toggleWifi() : ControlState.toggleBluetooth()
            }
        }
    }

    // ── main page: tile grid + vertical sliders ──────────────────────────────
    Page {
        id: mainPage
        name: "main"

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Ui.bodyTop }
            spacing: 18

            Grid {
                columns: Ui.columns
                spacing: Ui.gap

                Repeater {
                    model: cc.tiles

                    delegate: Tile {
                        required property var modelData
                        required property int index

                        icon: modelData.icon
                        label: modelData.label
                        sub: modelData.sub
                        on: modelData.on
                        hasDetail: modelData.detail !== ""
                        picked: index === cc.selectedTile

                        onEntered: cc.selectedTile = index
                        onTriggered: modelData.trigger()
                        onDetailRequested: ControlState.openPage(modelData.detail)
                    }
                }
            }

            Row {
                spacing: Ui.gap

                VSlider {
                    value: OsdState.brightness
                    icon: "󰃠"
                    onMoved: function(percent) { ControlState.setBrightness(percent) }
                }

                VSlider {
                    value: OsdState.muted ? 0 : OsdState.volume
                    dim: OsdState.muted
                    icon: OsdState.muted ? "󰖁" : "󰕾"
                    onMoved: function(percent) { ControlState.setVolume(percent) }
                    onIconClicked: ControlState.toggleMute()
                }
            }
        }
    }

    WifiPage { id: wifiPage }
    BluetoothPage { id: bluetoothPage }
    AudioPage { id: audioPage }
    ClipboardPage { id: clipboardPage }
    KeysPage { id: keysPage }
}
