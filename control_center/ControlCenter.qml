import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import QtQuick
import "../theme"
import "../osd"

// ─────────────────────────────────────────────────────────────────────────────
//  ControlCenter — lives INSIDE the notch (Bar.qml hosts it, like the power
//  menu / launcher). Same language as the rest of the notch: black island,
//  translucent colFg cards, colBlue for "on", hover pop, springy resize.
//
//  Keys   arrows move · Enter toggles · Space/Tab opens a tile's detail page
//         Esc goes back / closes
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: cc

    signal powerRequested()

    readonly property bool active: ControlState.visible
    readonly property string page: ControlState.page
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    visible: active
    opacity: active ? 1 : 0
    focus: active

    property int selectedTile: 0
    property int listIndex: 0

    Behavior on opacity { NumberAnimation { duration: 180 } }

    onActiveChanged: {
        if (active) {
            selectedTile = 0
            listIndex = 0
            forceActiveFocus()
        }
    }

    onPageChanged: listIndex = 0

    // ── derived state ────────────────────────────────────────────────────────
    readonly property int btConnectedCount: {
        var n = 0
        var devs = Bluetooth.devices.values
        for (var i = 0; i < devs.length; i++)
            if (devs[i].connected) n++
        return n
    }

    readonly property var btDevices: {
        var list = Bluetooth.devices.values.slice().filter(function(d) {
            return (d.name || d.deviceName) && (d.paired || d.connected || ControlState.bluetoothAdapter && ControlState.bluetoothAdapter.discovering)
        })
        list.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            return (a.name || a.deviceName).localeCompare(b.name || b.deviceName)
        })
        return list
    }

    function wifiIconFor(signal) {
        return signal >= 75 ? "󰤨" : signal >= 50 ? "󰤥" : signal >= 25 ? "󰤢" : "󰤟"
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
            on: ControlState.powerProfile !== "balanced",
            detail: "",
            trigger: function() { ControlState.cycleProfile() }
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
        }
    ]

    function moveTile(dx, dy) {
        var count = tiles.length
        var col = selectedTile % 4
        var row = Math.floor(selectedTile / 4)
        col = (col + dx + 4) % 4
        row = (row + dy + 2) % 2
        selectedTile = row * 4 + col
    }

    function moveList(delta, count) {
        if (count <= 0) return
        listIndex = (listIndex + delta + count) % count
    }

    function activateListItem() {
        if (page === "wifi") {
            var n = ControlState.wifiNetworks[listIndex]
            if (n && !n.active) ControlState.connectWifi(n.ssid)
        } else if (page === "bluetooth") {
            ControlState.activateBluetoothDevice(btDevices[listIndex])
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            ControlState.back()
            event.accepted = true
            return
        }

        if (page === "main") {
            if (event.key === Qt.Key_Left) moveTile(-1, 0)
            else if (event.key === Qt.Key_Right) moveTile(1, 0)
            else if (event.key === Qt.Key_Up) moveTile(0, -1)
            else if (event.key === Qt.Key_Down) moveTile(0, 1)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) tiles[selectedTile].trigger()
            else if (event.key === Qt.Key_Space || event.key === Qt.Key_Tab) {
                if (tiles[selectedTile].detail !== "") ControlState.openPage(tiles[selectedTile].detail)
            } else return
        } else {
            var count = page === "wifi" ? ControlState.wifiNetworks.length : btDevices.length
            if (event.key === Qt.Key_Up) moveList(-1, count)
            else if (event.key === Qt.Key_Down) moveList(1, count)
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) ControlState.back()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) activateListItem()
            else return
        }
        event.accepted = true
    }

    // ── building blocks ──────────────────────────────────────────────────────
    component Tile: Rectangle {
        id: tile

        property string icon
        property string label
        property string sub
        property bool on: false
        property bool picked: false
        property bool hasDetail: false

        signal triggered()
        signal detailRequested()
        signal entered()

        width: 88
        height: 88
        radius: 22
        color: on
            ? Colors.alpha(Colors.colBlue, tileHover.hovered ? 0.44 : 0.34)
            : Colors.alpha(Colors.colFg, tileHover.hovered ? 0.10 : 0.055)
        scale: tileHover.hovered ? 1.045 : 1.0
        border.width: picked ? 2 : 0
        border.color: Colors.alpha(Colors.colFg, 0.45)
        antialiasing: true

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: tileHover
            onHoveredChanged: if (hovered) tile.entered()
        }

        Text {
            anchors { left: parent.left; top: parent.top; leftMargin: 13; topMargin: 12 }
            text: tile.icon
            color: Colors.fg
            font { family: cc.iconFont; pixelSize: 22 }
        }

        Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 13; rightMargin: 8; bottomMargin: 10 }
            spacing: 1

            Text {
                width: parent.width
                text: tile.label
                color: Colors.fg
                elide: Text.ElideRight
                font { pixelSize: 11; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                text: tile.sub
                color: Colors.fg
                opacity: 0.55
                elide: Text.ElideRight
                font { pixelSize: 10 }
            }
        }

        Rectangle {
            visible: tile.hasDetail
            anchors { right: parent.right; top: parent.top; rightMargin: 9; topMargin: 9 }
            width: 24
            height: 24
            radius: 12
            color: chevHover.hovered ? Colors.alpha(Colors.colFg, 0.22) : Colors.alpha(Colors.colFg, 0.10)
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: Colors.fg
                font { family: cc.iconFont; pixelSize: 14 }
            }
            HoverHandler { id: chevHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.detailRequested()
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton && tile.hasDetail) tile.detailRequested()
                else tile.triggered()
            }
        }
    }

    component VSlider: ClippingRectangle {
        id: slider

        property int value: 0
        property string icon
        property bool dim: false

        signal moved(int percent)
        signal iconClicked()

        width: 72
        height: 184
        radius: 22
        color: Colors.alpha(Colors.colFg, sliderHover.hovered ? 0.085 : 0.055)
        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler { id: sliderHover }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * Math.max(0, Math.min(100, slider.value)) / 100
            color: Colors.alpha(Colors.colBlue, slider.dim ? 0.16 : 0.42)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
            text: slider.value + "%"
            color: Colors.fg
            opacity: 0.7
            font { pixelSize: 11; weight: Font.DemiBold }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
            text: slider.icon
            color: Colors.fg
            font { family: cc.iconFont; pixelSize: 22 }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            function pick(y) {
                var v = (1 - y / slider.height) * 100
                slider.moved(Math.max(0, Math.min(100, Math.round(v))))
            }

            onPressed: function(mouse) { ControlState.adjusting = true; pick(mouse.y) }
            onPositionChanged: function(mouse) { if (pressed) pick(mouse.y) }
            onReleased: ControlState.adjusting = false
            onCanceled: ControlState.adjusting = false
            onWheel: function(wheel) {
                slider.moved(Math.max(0, Math.min(100, slider.value + (wheel.angleDelta.y > 0 ? 5 : -5))))
            }
        }

        MouseArea {
            id: iconZone
            z: 1
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 52
            cursorShape: Qt.PointingHandCursor
            onClicked: slider.iconClicked()
        }
    }

    component Pill: Rectangle {
        id: pill

        property bool on: false
        signal toggled()

        width: 46
        height: 26
        radius: 13
        color: on ? Colors.alpha(Colors.colBlue, 0.55) : Colors.alpha(Colors.colFg, 0.12)
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            width: 20
            height: 20
            radius: 10
            y: 3
            x: pill.on ? parent.width - width - 3 : 3
            color: Colors.fg
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.toggled()
        }
    }

    component ListRow: Rectangle {
        id: row

        property string icon
        property string title
        property string subtitle
        property string tag
        property bool on: false
        property bool picked: false

        signal clicked()
        signal entered()

        height: 46
        radius: 14
        color: on
            ? Colors.alpha(Colors.colBlue, rowHover.hovered ? 0.40 : 0.30)
            : Colors.alpha(Colors.colFg, rowHover.hovered ? 0.10 : 0.055)
        border.width: picked ? 2 : 0
        border.color: Colors.alpha(Colors.colFg, 0.45)
        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler {
            id: rowHover
            onHoveredChanged: if (hovered) row.entered()
        }

        Text {
            id: rowIcon
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: row.icon
            color: Colors.fg
            font { family: cc.iconFont; pixelSize: 20 }
        }

        Column {
            anchors { left: rowIcon.right; leftMargin: 14; right: rowTag.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 0

            Text {
                width: parent.width
                text: row.title
                color: Colors.fg
                elide: Text.ElideRight
                font { pixelSize: 13; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                text: row.subtitle
                color: Colors.fg
                opacity: 0.5
                elide: Text.ElideRight
                font { pixelSize: 10 }
            }
        }

        Text {
            id: rowTag
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            text: row.tag
            color: Colors.fg
            opacity: 0.7
            font { pixelSize: 11; weight: Font.DemiBold }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    component RoundButton: Rectangle {
        id: btn

        property string icon
        signal clicked()

        width: 34
        height: 34
        radius: 17
        color: btnHover.hovered ? Colors.alpha(Colors.colFg, 0.13) : Colors.alpha(Colors.colFg, 0.05)
        scale: btnHover.hovered ? 1.08 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            color: Colors.fg
            font { family: cc.iconFont; pixelSize: 17 }
        }
        HoverHandler { id: btnHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // ── header ───────────────────────────────────────────────────────────────
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 24; rightMargin: 24; topMargin: 14 }
        height: 34

        RoundButton {
            id: backButton
            visible: cc.page !== "main"
            icon: "󰁍"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: ControlState.back()
        }

        Text {
            anchors { left: cc.page === "main" ? parent.left : backButton.right; leftMargin: cc.page === "main" ? 0 : 12; verticalCenter: parent.verticalCenter }
            text: cc.page === "wifi" ? "Wi-Fi" : cc.page === "bluetooth" ? "Bluetooth" : "Control Center"
            color: Colors.fg
            font { pixelSize: 16; weight: Font.DemiBold }
        }

        // main: battery + power
        Row {
            visible: cc.page === "main"
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 12

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    text: OsdState.batteryState === "charging" ? "󰂄" : "󰁹"
                    color: Colors.fg
                    anchors.verticalCenter: parent.verticalCenter
                    font { family: cc.iconFont; pixelSize: 17 }
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

        // detail pages: rescan + enable switch
        Row {
            visible: cc.page !== "main"
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 12

            RoundButton {
                icon: "󰑐"
                onClicked: cc.page === "wifi" ? ControlState.scanWifi() : ControlState.setBluetoothScan(true)
            }

            Pill {
                anchors.verticalCenter: parent.verticalCenter
                on: cc.page === "wifi" ? OsdState.wifiEnabled : ControlState.bluetoothEnabled
                onToggled: cc.page === "wifi" ? ControlState.toggleWifi() : ControlState.toggleBluetooth()
            }
        }
    }

    // ── main page: tile grid + vertical sliders ──────────────────────────────
    Row {
        id: mainBody
        visible: cc.page === "main"
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 62 }
        spacing: 14

        Grid {
            columns: 4
            spacing: 8

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
            spacing: 8

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

    // ── wifi page ────────────────────────────────────────────────────────────
    ListView {
        id: wifiList
        visible: cc.page === "wifi"
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 24; rightMargin: 24; topMargin: 62; bottomMargin: 20 }
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: ControlState.wifiNetworks
        currentIndex: cc.listIndex
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: ListRow {
            required property var modelData
            required property int index

            width: wifiList.width
            icon: cc.wifiIconFor(modelData.signal)
            title: modelData.ssid
            subtitle: modelData.active ? "Connected" : (modelData.secure ? "Secured" : "Open")
            tag: ControlState.wifiConnecting === modelData.ssid ? "Connecting…" : (modelData.secure ? "󰌾" : "")
            on: modelData.active
            picked: index === cc.listIndex

            onEntered: cc.listIndex = index
            onClicked: if (!modelData.active) ControlState.connectWifi(modelData.ssid)
        }

        Text {
            anchors.centerIn: parent
            visible: wifiList.count === 0
            text: !OsdState.wifiEnabled ? "Wi-Fi is off" : (ControlState.wifiScanning ? "Scanning…" : "No networks found")
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 13
        }
    }

    // ── bluetooth page ───────────────────────────────────────────────────────
    ListView {
        id: btList
        visible: cc.page === "bluetooth"
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 24; rightMargin: 24; topMargin: 62; bottomMargin: 20 }
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: cc.btDevices
        currentIndex: cc.listIndex
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: ListRow {
            required property var modelData
            required property int index

            width: btList.width
            icon: modelData.connected ? "󰂱" : "󰂯"
            title: modelData.name || modelData.deviceName
            subtitle: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
            tag: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
            on: modelData.connected
            picked: index === cc.listIndex

            onEntered: cc.listIndex = index
            onClicked: ControlState.activateBluetoothDevice(modelData)
        }

        Text {
            anchors.centerIn: parent
            visible: btList.count === 0
            text: !ControlState.bluetoothEnabled ? "Bluetooth is off" : "Searching for devices…"
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 13
        }
    }
}
