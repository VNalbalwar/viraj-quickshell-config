import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Quickshell.Widgets
import "../wallpaper_switcher"
import "../app_launcher"
import "../osd"
import "../theme"
import "../lockscreen"
import "../control_center"
import "../notifications"
import "../activity"
import "../workspaces"

PanelWindow {
    property var screen
    property bool barVisible: true
    property bool wallpaperMode: WallpaperState.visible
    property bool launcherMode: AppLauncherState.launcherVisible
    property bool powerMode: PowerState.visible
    property bool controlMode: ControlState.visible
    property bool notifMode: NotificationState.banner !== null && !powerMode && !wallpaperMode && !launcherMode && !controlMode
    property bool wallpaperClosing: false
    readonly property bool panelMode: powerMode || wallpaperMode || launcherMode || controlMode || notifMode || wsMode
    // brief popup when you switch workspace / layout; yields to notifications, OSD and panels
    property bool wsMode: WorkspaceState.popup && !powerMode && !wallpaperMode && !launcherMode && !controlMode && !notifMode && !osdMode
    property bool osdMode: OsdState.visible && !wallpaperMode && !launcherMode && !powerMode && !controlMode && !notifMode

    // Hide the notch entirely while the lockscreen is up (Stage 1 test overlay).
    visible: !LockState.demoActive

    anchors {
        top: true
        left: true
        right: true
    }

    focusable: true
    WlrLayershell.keyboardFocus: panelMode
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barVisible ? 50 : 0
    color: "transparent"
    implicitHeight: controlMode ? Ui.height : (notifMode ? Math.max(160, notifView.wantedHeight) : (wallpaperMode ? 180 : (launcherMode ? 240 : (osdMode ? 44 : 160))))

    onControlModeChanged: {
        if (controlMode) {
            if (wallpaperMode)
                WallpaperState.hide()

            if (launcherMode)
                AppLauncherState.hide()

            if (powerMode)
                PowerState.hide()

            barVisible = true
            wallpaperClosing = false

            Qt.callLater(function() {
                controlView.forceActiveFocus()
            })
        }
    }

    onWallpaperModeChanged: {
        if (wallpaperMode) {
            if (launcherMode)
                AppLauncherState.hide()

            if (powerMode)
                PowerState.hide()

            if (controlMode)
                ControlState.hide()

            Qt.callLater(function() {
                wallpaperView.forceActiveFocus()
            })
        }
    }

    onLauncherModeChanged: {
        if (launcherMode) {
            if (wallpaperMode)
                WallpaperState.hide()

            if (powerMode)
                PowerState.hide()

            if (controlMode)
                ControlState.hide()

            barVisible = true
            wallpaperClosing = false

            Qt.callLater(function() {
                launcherView.forceActiveFocus()
            })
        }
    }

    onPowerModeChanged: {
        if (powerMode) {
            if (wallpaperMode)
                WallpaperState.hide()

            if (launcherMode)
                AppLauncherState.hide()

            if (controlMode)
                ControlState.hide()

            barVisible = true
            wallpaperClosing = false

            Qt.callLater(function() {
                powerView.forceActiveFocus()
            })
        }
    }

    Connections {
        target: OsdState

        function onVisibleChanged() {
            if (OsdState.visible)
                barVisible = true
        }
    }

    Timer {
        id: wallpaperHideTimer
        interval: 520
        repeat: false
        onTriggered: {
            if (wallpaperClosing && !WallpaperState.visible) {
                wallpaperClosing = false
                barVisible = false
            }
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            if (!barVisible) {
                barVisible = true
                wallpaperClosing = false
                return
            }

            if (wallpaperMode) {
                wallpaperClosing = true
                WallpaperState.hide()
                wallpaperHideTimer.restart()
                return
            }

            if (launcherMode) {
                AppLauncherState.hide()
                return
            }

            if (powerMode) {
                PowerState.hide()
                return
            }

            if (controlMode) {
                ControlState.hide()
                return
            }

            barVisible = false
        }

        function show(): void {
            wallpaperHideTimer.stop()
            wallpaperClosing = false
            barVisible = true
        }

        function hide(): void {
            wallpaperHideTimer.stop()
            wallpaperClosing = false
            barVisible = false
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (wallpaperMode) {
                WallpaperState.hide()
            }
            AppLauncherState.toggle()
        }

        function show(): void {
            if (wallpaperMode) {
                WallpaperState.hide()
            }
            AppLauncherState.show()
        }

        function hide(): void {
            AppLauncherState.hide()
        }
    }

    mask: Region {
        item: island
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: panelMode ? 34 : (osdMode ? 16 : (island.expanded ? 34 : 16))
        bottomRightRadius: panelMode ? 34 : (osdMode ? 16 : (island.expanded ? 34 : 16))
    }

    // Any MPRIS player (Spotify, every browser tab with media, mpv, VLC...).
    //   - the notch FOLLOWS whichever player started playing most recently
    //   - you can pick one yourself (pager dots, scroll wheel, label); that holds
    //     until another player starts playing
    //   - otherwise: any playing one, then one with a track loaded, then the first
    property var selectedPlayer: null     // picked by the user
    property var lastActivePlayer: null   // most recent player that started playing
    property var hoverPlayer: null        // previewed while hovering a pager dot

    readonly property var mediaPlayer: {
        var players = Mpris.players.values
        if (selectedPlayer && players.indexOf(selectedPlayer) !== -1)
            return selectedPlayer
        if (lastActivePlayer && players.indexOf(lastActivePlayer) !== -1 && lastActivePlayer.isPlaying)
            return lastActivePlayer
        for (var i = 0; i < players.length; i++)
            if (players[i].isPlaying) return players[i]
        for (var j = 0; j < players.length; j++)
            if (players[j].trackTitle) return players[j]
        return players.length > 0 ? players[0] : null
    }

    // what the song info shows: the previewed player while hovering a dot, else the active one
    readonly property var shownPlayer: hoverPlayer !== null && Mpris.players.values.indexOf(hoverPlayer) !== -1 ? hoverPlayer : mediaPlayer
    readonly property int playerCount: Mpris.players.values.length
    readonly property int playerIndex: Mpris.players.values.indexOf(mediaPlayer)

    readonly property bool mediaIsSpotify: mediaPlayer !== null
        && (mediaPlayer.desktopEntry === "spotify" || mediaPlayer.identity.toLowerCase().indexOf("spotify") !== -1)

    // what the idle notch is "doing": recording > timer > media
    readonly property string activityKind:
        ActivityState.recording ? "recording"
        : (ActivityState.timerActive || ActivityState.timerFinished) ? "timer"
        : mediaPlaying ? "media" : ""
    readonly property int activityWidth: activityKind === "media" ? 290 : 310

    function stepPlayer(delta) {
        var players = Mpris.players.values
        if (players.length < 2) return
        var i = players.indexOf(mediaPlayer)
        selectedPlayer = players[((i < 0 ? 0 : i) + delta + players.length) % players.length]
    }

    function nextPlayer() { stepPlayer(1) }

    readonly property bool hasMedia: mediaPlayer !== null
    readonly property bool mediaPlaying: hasMedia && mediaPlayer.isPlaying
    readonly property var weekDays: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property int todayIndex: new Date(clock.date).getDay()

    readonly property var weekDates: {
        var today = new Date(clock.date)
        var day = today.getDay()
        var sunday = new Date(today)
        sunday.setDate(today.getDate() - day)
        var result = []
        for (var i = 0; i < 7; i++) {
            var d = new Date(sunday)
            d.setDate(sunday.getDate() + i)
            result.push(d.getDate())
        }
        return result
    }

    Rectangle {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 0
        clip: true
        antialiasing: true

        property bool expanded:
            powerMode
            || controlMode
            || notifMode
            || wsMode
            || wallpaperMode
            || launcherMode
            || osdMode
            || (hover.hovered && !wallpaperClosing)
        visible: true
        opacity: barVisible ? 1 : 0
        scale: barVisible ? 1 : 0.96
        transformOrigin: Item.Top

        implicitWidth:
            powerMode ? 550 :
            controlMode ? Ui.width :
            notifMode ? notifView.wantedWidth :
            wsMode ? wsView.wantedWidth :
            wallpaperMode ? 1080 :
            launcherMode ? 1000 :
            osdMode ? 500 :
            (expanded ? 680 : (activityKind !== "" ? activityWidth : 200))

        implicitHeight:
            powerMode ? 124 :
            controlMode ? Ui.height :
            notifMode ? notifView.wantedHeight :
            wsMode ? wsView.wantedHeight :
            wallpaperMode ? 180 :
            launcherMode ? 240 :
            osdMode ? 44 :
            (expanded ? 130 : 44)

        radius: panelMode ? 34 : (osdMode ? 16 : (expanded ? 34 : 16))
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: panelMode ? 34 : (osdMode ? 16 : (expanded ? 34 : 16))
        bottomRightRadius: panelMode ? 34 : (osdMode ? 16 : (expanded ? 34 : 16))

        color: "#000000"

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }
        Behavior on implicitWidth {
            NumberAnimation {
                duration: 500
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
            }
        }
        Behavior on implicitHeight {
            NumberAnimation {
                duration: 500
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
            }
        }

        HoverHandler { id: hover }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Text {
            anchors.centerIn: parent
            opacity: (island.expanded || activityKind === "timer" || activityKind === "recording") ? 0 : 1
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Colors.fg
            font { pixelSize: 16; weight: 600 }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // The OSD only owns the notch when no other panel is open; otherwise it
        // used to draw its icons right on top of the control center / menus.
        LiveActivity {
            anchors.fill: parent
            kind: activityKind
            shown: !island.expanded
            player: mediaPlayer
            playing: mediaPlaying
        }

        Osd {
            anchors.fill: parent
            allowed: !panelMode
        }

        WorkspacePopup {
            id: wsView
            anchors.fill: parent
            active: wsMode
        }

        // one dot per workspace in the collapsed notch (the activity pill uses that spot)
        WorkspaceDots {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            shown: !island.expanded && activityKind === ""
        }

        NotificationBanner {
            id: notifView
            anchors.fill: parent
            active: notifMode
        }

        ControlCenter {
            id: controlView
            anchors.fill: parent
            onPowerRequested: PowerState.show()
        }

        Item {
            id: powerView

            anchors.fill: parent
            visible: powerMode
            opacity: powerMode ? 1 : 0
            focus: powerMode

            property int selectedIndex: 0

            readonly property var powerActions: [
                { label: "Lock",      icon: "󰌾", trigger: function() { PowerState.lock() } },
                { label: "Log Out",   icon: "󰍃", trigger: function() { PowerState.logout() } },
                { label: "Reboot",    icon: "󰜉", trigger: function() { PowerState.reboot() } },
                { label: "Power Off", icon: "󰐥", trigger: function() { PowerState.powerOff() } }
            ]

            function navigate(delta) {
                var count = powerActions.length
                if (count === 0)
                    return
                selectedIndex = (selectedIndex + delta + count) % count
            }

            function activateSelected() {
                if (selectedIndex >= 0 && selectedIndex < powerActions.length)
                    powerActions[selectedIndex].trigger()
            }

            onVisibleChanged: {
                if (visible) {
                    selectedIndex = 0
                    forceActiveFocus()
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    navigate(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    navigate(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    activateSelected()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    PowerState.hide()
                    event.accepted = true
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: powerView.powerActions

                    delegate: Rectangle {
                        id: powerCard

                        readonly property bool selected: index === powerView.selectedIndex

                        width: 116
                        height: 92
                        radius: 22
                        color: selected
                            ? Colors.alpha(Colors.colBlue, 0.34)
                            : Colors.alpha(Colors.colFg, 0.055)
                        scale: selected ? 1.045 : 1.0

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 170
                                easing.type: Easing.OutCubic
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 7

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: powerCard.selected ? Colors.fg : Colors.alpha(Colors.fg, 0.92)
                                font {
                                    family: "JetBrainsMono Nerd Font"
                                    pixelSize: 23
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Colors.fg
                                opacity: powerCard.selected ? 0.95 : 0.72
                                font {
                                    pixelSize: 12
                                    weight: Font.DemiBold
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: powerView.selectedIndex = index
                            onClicked: modelData.trigger()
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            opacity: island.expanded
                && !powerMode
                && !controlMode
                && !notifMode
                && !wsMode
                && !wallpaperMode
                && !launcherMode
                && !osdMode ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 220 } }

            // auto-follow: whichever player starts playing becomes the active one
            Repeater {
                model: Mpris.players

                delegate: Item {
                    required property var modelData

                    // a browser tab registers its player when its video starts, i.e. it
                    // shows up already playing - that counts as "just started" too
                    Component.onCompleted: if (modelData.isPlaying) lastActivePlayer = modelData

                    Connections {
                        target: modelData
                        function onIsPlayingChanged() {
                            if (modelData.isPlaying) {
                                lastActivePlayer = modelData
                                selectedPlayer = null
                            }
                        }
                    }
                }
            }

            // scroll over the panel to flip through players (doesn't swallow clicks)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) { stepPlayer(wheel.angleDelta.y > 0 ? -1 : 1) }
            }

            Rectangle {
                id: artworkContainer
                width: 100
                height: 80
                anchors { left: parent.left; leftMargin: 16; top: parent.top; topMargin: 18 }
                radius: 10
                color: Colors.alpha(Colors.colFg, 0.06)

                ClippingRectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    Image {
                        anchors.fill: parent
                        source: shownPlayer && shownPlayer.trackArtUrl ? shownPlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !shownPlayer || !shownPlayer.trackArtUrl
                    text: !mediaPlayer || mediaIsSpotify ? "󰓇" : "󰎆"
                    color: !mediaPlayer || mediaIsSpotify ? "#1ED760" : Colors.colBlue
                    opacity: 1.0
                    font {
                        pixelSize: 38
                        family: "JetBrainsMono Nerd Font"
                    }
                }
            }

            // pager: one dot per player (playing ones tinted) - click to pick, hover to preview
            Row {
                anchors { horizontalCenter: artworkContainer.horizontalCenter; top: artworkContainer.bottom; topMargin: 9 }
                spacing: 5
                visible: playerCount > 1

                Repeater {
                    model: Mpris.players

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: modelData === mediaPlayer

                        width: current ? 16 : 7
                        height: 7
                        radius: 3.5
                        color: current ? Colors.fg
                            : (modelData.isPlaying ? Colors.alpha(Colors.colBrightBlue, 0.85) : Colors.alpha(Colors.colFg, 0.3))
                        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                        Behavior on color { ColorAnimation { duration: 160 } }

                        MouseArea {
                            anchors { fill: parent; margins: -4 }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: hoverPlayer = modelData
                            onExited: if (hoverPlayer === modelData) hoverPlayer = null
                            onClicked: selectedPlayer = modelData
                        }
                    }
                }
            }

            Column {
                id: songInfo
                anchors { left: artworkContainer.right; leftMargin: 16; top: artworkContainer.top; right: calendar.left; rightMargin: 16 }
                spacing: 3
                Text {
                    width: parent.width
                    text: shownPlayer ? (shownPlayer.trackTitle || "Unknown Title") : "Nothing !"
                    color: Colors.fg
                    elide: Text.ElideRight
                    font { pixelSize: 17; weight: Font.DemiBold }
                }
                Text {
                    width: parent.width
                    text: shownPlayer ? (shownPlayer.trackArtist || "Unknown Artist") : "Play something"
                    color: Colors.grey2
                    elide: Text.ElideRight
                    font { pixelSize: 13 }
                }
            }

            Row {
                anchors { left: songInfo.left; bottom: parent.bottom; bottomMargin: 25 }
                spacing: 7
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: previousHover.hovered ? Colors.alpha(Colors.colFg, 0.13) : Colors.alpha(Colors.colFg, 0.05)
                    scale: previousHover.hovered ? 1.08 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Text { anchors.centerIn: parent; text: "󰒮"; color: Colors.fg; font { pixelSize: 18; weight: Font.Medium } }
                    HoverHandler { id: previousHover }
                    MouseArea { anchors.fill: parent; onClicked: if (mediaPlayer && mediaPlayer.canGoPrevious) mediaPlayer.previous() }
                }
                Rectangle {
                    width: 34; height: 34; radius: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: playHover.hovered ? Colors.alpha(Colors.colBlue, 0.32) : Colors.alpha(Colors.colBlue, 0.20)
                    scale: playHover.hovered ? 1.08 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Text {
                        anchors.centerIn: parent
                        text: mediaPlaying ? "󰏤" : "󰐊"
                        color: Colors.fg
                        font { pixelSize: 20; weight: Font.DemiBold }
                    }
                    HoverHandler { id: playHover }
                    MouseArea { anchors.fill: parent; onClicked: if (mediaPlayer && mediaPlayer.canTogglePlaying) mediaPlayer.togglePlaying() }
                }
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: nextHover.hovered ? Colors.alpha(Colors.colFg, 0.13) : Colors.alpha(Colors.colFg, 0.05)
                    scale: nextHover.hovered ? 1.08 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Text { anchors.centerIn: parent; text: "󰒭"; color: Colors.fg; font { pixelSize: 18; weight: Font.Medium } }
                    HoverHandler { id: nextHover }
                    MouseArea { anchors.fill: parent; onClicked: if (mediaPlayer && mediaPlayer.canGoNext) mediaPlayer.next() }
                }
            }

            Column {
                id: calendar
                anchors { right: parent.right; rightMargin: 22; top: parent.top; topMargin: 22 }
                spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Colors.fg
                    font { pixelSize: 27; weight: Font.DemiBold }
                }
                Row {
                    spacing: 18
                    Repeater {
                        model: 7
                        delegate: Column {
                            width: 20
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: weekDays[index]
                                color: Colors.fg
                                opacity: 0.40
                                font { pixelSize: 14; weight: Font.Medium }
                            }
                            Rectangle {
                                width: 20; height: 20; radius: 9
                                color: index === todayIndex ? "#7DCFFF" : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: weekDates[index]
                                    color: index === todayIndex ? "#000000" : Colors.fg
                                    opacity: index === todayIndex ? 1.0 : 0.28
                                    font { pixelSize: 11; weight: Font.Medium }
                                }
                            }
                        }
                    }
                }
            }

            // which player is shown; tap to cycle when several are running
            Text {
                id: playerLabel
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 17; bottomMargin: 10 }
                text: mediaPlayer ? mediaPlayer.identity + (playerCount > 1 ? "  ·  " + (playerIndex + 1) + "/" + playerCount + "  ›" : "") : ""
                color: Colors.grey2
                opacity: labelHover.hovered ? 0.9 : 0.45
                font { pixelSize: 9 }
                Behavior on opacity { NumberAnimation { duration: 120 } }

                HoverHandler { id: labelHover }
                MouseArea {
                    anchors { fill: parent; margins: -6 }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nextPlayer()
                }
            }
        }

        Item {
            id: launcherView
            anchors.fill: parent
            visible: launcherMode
            opacity: launcherMode ? 1 : 0
            focus: launcherMode

            property string searchQuery: ""
            property int selectedIndex: 0

            // apps + calculator / timer / url / windows / power / web (see LauncherSearch.qml)
            property var results: LauncherSearch.build(searchQuery)

            function navigate(delta) {
                if (results.length === 0)
                    return

                var oldIndex = selectedIndex

                selectedIndex =
                    (selectedIndex + delta + results.length)
                    % results.length

                var oldPage = Math.floor(oldIndex / launcherList.pageSize)
                var newPage = Math.floor(selectedIndex / launcherList.pageSize)

                if (oldPage !== newPage) {
                    var pageOffset =
                        newPage *
                        launcherList.pageSize *
                        (launcherList.itemWidth + launcherList.spacing)

                    launcherPageSlideAnimation.from = launcherList.contentX
                    launcherPageSlideAnimation.to = pageOffset
                    launcherPageSlideAnimation.start()
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            onVisibleChanged: {
                if (visible) {
                    launcherSearch.text = ""
                    searchQuery = ""
                    selectedIndex = 0
                    LauncherSearch.refresh()

                    forceActiveFocus()

                    Qt.callLater(function() {
                        launcherSearch.forceActiveFocus()
                    })
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 18
                    leftMargin: 24
                    rightMargin: 24
                }

                height: 46
                radius: 14
                color: Colors.alpha(Colors.colFg, 0.06)

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 16
                        verticalCenter: parent.verticalCenter
                    }

                    text: "⌕"
                    color: Colors.fg
                    opacity: 0.5
                    font.pixelSize: 20
                }

                TextInput {
                    id: launcherSearch

                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 46
                        rightMargin: 16
                        verticalCenter: parent.verticalCenter
                    }

                    color: Colors.fg
                    font.pixelSize: 13
                    focus: launcherMode

                    selectByMouse: true
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        text: "Search apps..."
                        color: Colors.fg
                        opacity: 0.35
                        visible: launcherSearch.text.length === 0
                        font.pixelSize: 13
                    }

                    onTextChanged: {
                        launcherView.searchQuery = text
                        launcherView.selectedIndex = 0
                        launcherList.contentX = 0
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            AppLauncherState.hide()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left ||
                            event.key === Qt.Key_Up) {
                            launcherView.navigate(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right ||
                                   event.key === Qt.Key_Down) {
                            launcherView.navigate(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return ||
                                   event.key === Qt.Key_Enter) {
                            if (launcherView.results.length > 0) {
                                launcherView.results[launcherView.selectedIndex].run()
                                AppLauncherState.hide()
                            }
                            event.accepted = true
                        }
                    }
                }
            }

            ListView {
                id: launcherList

                anchors {
                    left: parent.left
                    right: parent.right
                    top: launcherSearch.parent.bottom
                    bottom: parent.bottom
                    leftMargin: 24
                    rightMargin: 24
                    topMargin: 14
                    bottomMargin: 18
                }

                orientation: ListView.Horizontal
                spacing: 12
                clip: true

                model: launcherView.results

                property int pageSize: 6
                property real itemWidth: (width - (5 * spacing)) / 6
                property real pageWidth: 6 * (itemWidth + spacing)

                NumberAnimation {
                    id: launcherPageSlideAnimation
                    target: launcherList
                    property: "contentX"
                    duration: 500
                    easing.type: Easing.InOutCubic
                }

                delegate: Rectangle {
                    id: appCard

                    width: launcherList.itemWidth
                    height: 105
                    radius: 16

                    color: index === launcherView.selectedIndex ? Colors.alpha(Colors.colBlue, 0.38) : Colors.alpha(Colors.colFg, 0.06)

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    HoverHandler { id: appHover }

                    scale: appHover.hovered ? 1.045 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 42
                            height: 42

                            Image {
                                id: cardIcon
                                anchors.fill: parent
                                source: modelData.icon !== "" ? "image://icon/" + modelData.icon : ""
                                smooth: true
                                mipmap: true
                                visible: modelData.icon !== "" && status === Image.Ready
                            }

                            // calculator / timer / web / window ... results (and icons that fail to load)
                            Text {
                                anchors.centerIn: parent
                                visible: !cardIcon.visible
                                text: modelData.glyph !== "" ? modelData.glyph : "󰣇"
                                color: Colors.colBrightBlue
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 30 }
                            }
                        }

                        Text {
                            width: 110
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.name
                            color: Colors.fg
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font { pixelSize: modelData.kind === "calc" ? 15 : 12; weight: modelData.kind === "calc" ? Font.DemiBold : Font.Medium }
                        }

                        Text {
                            width: 110
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: text !== ""
                            text: modelData.sub
                            color: Colors.fg
                            opacity: 0.5
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: 9
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modelData.run()
                            AppLauncherState.hide()
                        }
                    }
                }
            }
        }

        Item {
            id: wallpaperView

            anchors.fill: parent
            visible: wallpaperMode
            opacity: wallpaperMode ? 1 : 0
            focus: wallpaperMode

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            onVisibleChanged: {
                if (visible)
                    forceActiveFocus()
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    WallpaperState.hide()
                    event.accepted = true
                    return
                }

                if (!wallpaperMode || wallpaperList.count === 0)
                    return

                var oldIndex = WallpaperState.selectedIndex
                var nextIndex = oldIndex

                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    nextIndex = (oldIndex - 1 + wallpaperList.count) % wallpaperList.count
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    nextIndex = (oldIndex + 1) % wallpaperList.count
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    WallpaperState.selectAndApply()
                    event.accepted = true
                    return
                } else {
                    return
                }

                WallpaperState.selectedIndex = nextIndex

                var oldPage = Math.floor(oldIndex / wallpaperList.pageSize)
                var newPage = Math.floor(nextIndex / wallpaperList.pageSize)

                if (oldPage !== newPage) {
                    pageSlideAnimation.from = wallpaperList.contentX

                    var pageOffset =
                        newPage * wallpaperList.pageSize *
                        (wallpaperList.itemWidth + wallpaperList.spacing)

                    pageSlideAnimation.to = pageOffset
                    pageSlideAnimation.start()
                }

                event.accepted = true
            }

            Text {
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 24
                    topMargin: 18
                }

                text: "Wallpaper"
                color: Colors.fg
                font { pixelSize: 16; weight: Font.DemiBold }
            }

            ListView {
                id: wallpaperList

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 18
                    leftMargin: 24
                    rightMargin: 24
                }

                boundsBehavior: Flickable.StopAtBounds
                height: 105
                orientation: ListView.Horizontal
                spacing: 12
                model: WallpaperState.wallpapers

                property int pageSize: 5
                property real itemWidth: (width - (4 * spacing)) / 5
                property real pageWidth: 5 * (itemWidth + spacing)

                NumberAnimation {
                    id: pageSlideAnimation
                    target: wallpaperList
                    property: "contentX"
                    duration: 500
                    easing.type: Easing.InOutCubic
                }

                delegate: Rectangle {
                    id: wallpaperCard
                    width: wallpaperList.itemWidth
                    height: 100
                    radius: 14
                    clip: true
                    antialiasing: true
                    color: Colors.alpha(Colors.colFg, 0.06)

                    HoverHandler { id: wallpaperHover }

                    scale: wallpaperHover.hovered ? 1.045 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: wallpaperCard.radius

                        Image {
                            anchors.fill: parent
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: index === WallpaperState.selectedIndex ? 3 : (wallpaperHover.hovered ? 2 : 0)
                        border.color: index === WallpaperState.selectedIndex ? Colors.colBlue : Colors.alpha(Colors.colFg, 0.55)
                        radius: wallpaperCard.radius
                        antialiasing: true
                        Behavior on border.width { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            WallpaperState.selectedIndex = index
                            wallpaperView.forceActiveFocus()
                            WallpaperState.selectAndApply()
                        }
                    }
                }
            }
        }
    }
}
