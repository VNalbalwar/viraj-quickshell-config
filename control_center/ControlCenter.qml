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
//  Feel    press = squish + ripple, toggles pop their icon, pages slide, list
//          entries (wifi / bluetooth) animate in/out/reorder as they appear.
//  Keys    arrows move · Enter toggles · Space/Tab opens a tile's detail page
//          Esc goes back / closes
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: cc

    signal powerRequested()

    readonly property bool active: ControlState.visible
    readonly property string page: ControlState.page
    readonly property bool onMain: page === "main"
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    // layout
    readonly property int sideMargin: 38
    readonly property int bodyTop: 68
    readonly property int tileW: 104
    readonly property int tileH: 96
    readonly property int gap: 10

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

    function wifiIconFor(strength) {
        return strength >= 75 ? "󰤨" : strength >= 50 ? "󰤥" : strength >= 25 ? "󰤢" : "󰤟"
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
            if (listIndex < ControlState.wifiModel.count) {
                var n = ControlState.wifiModel.get(listIndex)
                if (!n.active) ControlState.connectWifi(n.ssid)
            }
        } else if (page === "bluetooth") {
            if (listIndex < ControlState.btModel.count)
                ControlState.activateBluetoothDevice(ControlState.btByAddress[ControlState.btModel.get(listIndex).address])
        }
    }

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
        } else {
            var count = page === "wifi" ? ControlState.wifiModel.count : ControlState.btModel.count
            if (event.key === Qt.Key_Up) moveList(-1, count)
            else if (event.key === Qt.Key_Down) moveList(1, count)
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) ControlState.back()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) activateListItem()
            else return
        }
        event.accepted = true
    }

    // ── building blocks ──────────────────────────────────────────────────────
    component Tile: ClippingRectangle {
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

        width: cc.tileW
        height: cc.tileH
        radius: 24
        color: on
            ? Colors.alpha(Colors.colBlue, tileHover.hovered ? 0.44 : 0.34)
            : Colors.alpha(Colors.colFg, tileHover.hovered ? 0.10 : 0.055)
        scale: tileMouse.pressed ? 0.93 : (tileHover.hovered ? 1.045 : 1.0)
        border.width: picked ? 2 : 0
        border.color: Colors.alpha(Colors.colFg, 0.45)

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        HoverHandler {
            id: tileHover
            onHoveredChanged: if (hovered) tile.entered()
        }

        Ripple { id: tileRipple }

        SequentialAnimation {
            id: iconPop
            NumberAnimation { target: tileIcon; property: "scale"; to: 1.35; duration: 100; easing.type: Easing.OutCubic }
            NumberAnimation { target: tileIcon; property: "scale"; to: 1.0; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 3 }
        }

        Text {
            id: tileIcon
            anchors { left: parent.left; top: parent.top; leftMargin: 15; topMargin: 14 }
            text: tile.icon
            color: Colors.fg
            font { family: cc.iconFont; pixelSize: 24 }
        }

        Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 15; rightMargin: 10; bottomMargin: 12 }
            spacing: 1

            Text {
                width: parent.width
                text: tile.label
                color: Colors.fg
                elide: Text.ElideRight
                font { pixelSize: 12; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                text: tile.sub
                color: Colors.fg
                opacity: 0.55
                elide: Text.ElideRight
                font { pixelSize: 11 }
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) { tileRipple.start(mouse.x, mouse.y) }
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton && tile.hasDetail) {
                    tile.detailRequested()
                } else {
                    iconPop.restart()
                    tile.triggered()
                }
            }
        }

        // chevron chip: opens the detail page (above the tile's own mouse area)
        Rectangle {
            visible: tile.hasDetail
            anchors { right: parent.right; top: parent.top; rightMargin: 10; topMargin: 10 }
            width: 26
            height: 26
            radius: 13
            color: chevHover.hovered ? Colors.alpha(Colors.colFg, 0.24) : Colors.alpha(Colors.colFg, 0.10)
            scale: chevMouse.pressed ? 0.85 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: Colors.fg
                font { family: cc.iconFont; pixelSize: 15 }
            }
            HoverHandler { id: chevHover }
            MouseArea {
                id: chevMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.detailRequested()
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

        width: 86
        height: cc.tileH * 2 + cc.gap
        radius: 24
        color: Colors.alpha(Colors.colFg, sliderHover.hovered ? 0.085 : 0.055)
        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler { id: sliderHover }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * Math.max(0, Math.min(100, slider.value)) / 100
            color: Colors.alpha(Colors.colBlue, slider.dim ? 0.16 : 0.42)
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on height { enabled: !dragArea.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 14 }
            text: slider.value + "%"
            color: Colors.fg
            opacity: 0.7
            font { pixelSize: 12; weight: Font.DemiBold }
        }

        Text {
            id: sliderIcon
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
            text: slider.icon
            color: Colors.fg
            scale: iconZone.pressed ? 0.8 : 1.0
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
            font { family: cc.iconFont; pixelSize: 24 }
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
            height: 56
            cursorShape: Qt.PointingHandCursor
            onClicked: slider.iconClicked()
        }
    }

    component Pill: Rectangle {
        id: pill

        property bool on: false
        signal toggled()

        width: 48
        height: 28
        radius: 14
        color: on ? Colors.alpha(Colors.colBlue, 0.55) : Colors.alpha(Colors.colFg, 0.12)
        Behavior on color { ColorAnimation { duration: 160 } }

        Rectangle {
            width: pillMouse.pressed ? 26 : 22
            height: 22
            radius: 11
            y: 3
            x: pill.on ? parent.width - width - 3 : 3
            color: Colors.fg
            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            Behavior on width { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.toggled()
        }
    }

    component ListRow: ClippingRectangle {
        id: row

        property string icon
        property string title
        property string subtitle
        property string tag
        property bool on: false
        property bool picked: false

        signal clicked()
        signal entered()

        height: 48
        radius: 16
        color: on
            ? Colors.alpha(Colors.colBlue, rowHover.hovered ? 0.40 : 0.30)
            : Colors.alpha(Colors.colFg, rowHover.hovered ? 0.10 : 0.055)
        scale: rowMouse.pressed ? 0.975 : 1.0
        border.width: picked ? 2 : 0
        border.color: Colors.alpha(Colors.colFg, 0.45)
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 2 } }

        HoverHandler {
            id: rowHover
            onHoveredChanged: if (hovered) row.entered()
        }

        Ripple { id: rowRipple }

        Text {
            id: rowIcon
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            text: row.icon
            color: Colors.fg
            font { family: cc.iconFont; pixelSize: 21 }
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
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            text: row.tag
            color: Colors.fg
            opacity: 0.7
            font { family: cc.iconFont; pixelSize: 12; weight: Font.DemiBold }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) { rowRipple.start(mouse.x, mouse.y) }
            onClicked: row.clicked()
        }
    }

    component RoundButton: Rectangle {
        id: btn

        property string icon
        property bool spinOnClick: false
        signal clicked()

        width: 34
        height: 34
        radius: 17
        color: btnHover.hovered ? Colors.alpha(Colors.colFg, 0.13) : Colors.alpha(Colors.colFg, 0.05)
        scale: btnMouse.pressed ? 0.88 : (btnHover.hovered ? 1.08 : 1.0)
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        NumberAnimation {
            id: spin
            target: btnIcon
            property: "rotation"
            from: 0
            to: 360
            duration: 520
            easing.type: Easing.OutCubic
        }

        Text {
            id: btnIcon
            anchors.centerIn: parent
            text: btn.icon
            color: Colors.fg
            font { family: cc.iconFont; pixelSize: 17 }
        }
        HoverHandler { id: btnHover }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (btn.spinOnClick) spin.restart()
                btn.clicked()
            }
        }
    }

    // ── header (cross-fades between main and detail pages) ───────────────────
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: cc.sideMargin; rightMargin: cc.sideMargin; topMargin: 16 }
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
                text: cc.page === "wifi" ? "Wi-Fi" : "Bluetooth"
                color: Colors.fg
                font { pixelSize: 16; weight: Font.DemiBold }
            }
        }

        // main: battery + power
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 12
            opacity: cc.onMain ? 1 : 0
            x: cc.onMain ? 0 : 16
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200 } }

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
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 12
            opacity: cc.onMain ? 0 : 1
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
    Item {
        id: mainPage
        width: parent.width
        height: parent.height
        opacity: cc.onMain ? 1 : 0
        x: cc.onMain ? 0 : -56
        visible: opacity > 0.01
        enabled: cc.onMain
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: cc.bodyTop }
            spacing: 18

            Grid {
                columns: 4
                spacing: cc.gap

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
                spacing: cc.gap

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

    // shared list animations: new entries pop in (staggered on first open),
    // removed ones shrink away, the rest glide to their new spot.
    readonly property Transition listAdd: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.82; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }

    readonly property Transition listPopulate: Transition {
        SequentialAnimation {
            PauseAnimation { duration: ViewTransition.index * 45 }
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: ViewTransition.destination.y + 14; to: ViewTransition.destination.y; duration: 340; easing.type: Easing.OutCubic }
            }
        }
    }

    readonly property Transition listRemove: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; to: 0.85; duration: 200; easing.type: Easing.InCubic }
        }
    }

    readonly property Transition listDisplaced: Transition {
        NumberAnimation { properties: "x,y"; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { property: "opacity"; to: 1; duration: 1 }
        NumberAnimation { property: "scale"; to: 1; duration: 1 }
    }

    // ── wifi page ────────────────────────────────────────────────────────────
    Item {
        id: wifiPage
        readonly property bool shown: cc.page === "wifi"
        width: parent.width
        height: parent.height
        opacity: shown ? 1 : 0
        x: shown ? 0 : 56
        visible: opacity > 0.01
        enabled: shown
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

        ListView {
            id: wifiList
            anchors { fill: parent; leftMargin: cc.sideMargin; rightMargin: cc.sideMargin; topMargin: cc.bodyTop; bottomMargin: 22 }
            spacing: 7
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ControlState.wifiModel
            currentIndex: cc.listIndex
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            add: cc.listAdd
            populate: cc.listPopulate
            remove: cc.listRemove
            displaced: cc.listDisplaced

            delegate: ListRow {
                required property string ssid
                required property bool active
                required property int strength
                required property bool secure
                required property int index

                width: wifiList.width
                icon: cc.wifiIconFor(strength)
                title: ssid
                subtitle: active ? "Connected" : (secure ? "Secured" : "Open")
                tag: ControlState.wifiConnecting === ssid ? "Connecting…" : (secure ? "󰌾" : "")
                on: active
                picked: index === cc.listIndex

                onEntered: cc.listIndex = index
                onClicked: if (!active) ControlState.connectWifi(ssid)
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
    }

    // ── bluetooth page ───────────────────────────────────────────────────────
    Item {
        id: btPage
        readonly property bool shown: cc.page === "bluetooth"
        width: parent.width
        height: parent.height
        opacity: shown ? 1 : 0
        x: shown ? 0 : 56
        visible: opacity > 0.01
        enabled: shown
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

        ListView {
            id: btList
            anchors { fill: parent; leftMargin: cc.sideMargin; rightMargin: cc.sideMargin; topMargin: cc.bodyTop; bottomMargin: 22 }
            spacing: 7
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ControlState.btModel
            currentIndex: cc.listIndex
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            add: cc.listAdd
            populate: cc.listPopulate
            remove: cc.listRemove
            displaced: cc.listDisplaced

            delegate: ListRow {
                id: btRow

                required property string address
                required property int index

                readonly property var dev: ControlState.btByAddress[address]

                width: btList.width
                icon: dev && dev.connected ? "󰂱" : "󰂯"
                title: dev ? (dev.name || dev.deviceName) : ""
                subtitle: dev ? (dev.connected ? "Connected" : (dev.paired ? "Paired" : "Available")) : ""
                tag: dev && dev.batteryAvailable ? Math.round(dev.battery * 100) + "%" : ""
                on: dev ? dev.connected : false
                picked: index === cc.listIndex

                onEntered: cc.listIndex = index
                onClicked: ControlState.activateBluetoothDevice(dev)
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
}
