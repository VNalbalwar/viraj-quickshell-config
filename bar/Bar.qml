import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import "../theme"

PanelWindow {
    property var screen
    property bool barVisible: true
    property bool wallpaperMode: WallpaperState.visible

    anchors {
        top: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barVisible ? 50 : 0
    color: "transparent"
    implicitHeight: 160

    IpcHandler {
        target: "bar"

        function toggle(): void {
            barVisible = !barVisible
        }

        function show(): void {
            barVisible = true
        }

        function hide(): void {
            barVisible = false
        }
    }

    mask: Region { item: island }

    readonly property var mediaPlayer: {
        for (var i = 0; i < Mpris.players.values.length; i++) {
            var p = Mpris.players.values[i]
            if (p.desktopEntry === "spotify" || p.identity.toLowerCase().indexOf("spotify") !== -1)
                return p
        }
        return null
    }

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

        property bool expanded: hover.hovered || wallpaperMode
        visible: barVisible

        implicitWidth: wallpaperMode ? 1080 : (expanded ? 680 : 200)
        implicitHeight: wallpaperMode ? 180 : (expanded ? 130 : 44)

        // iPhone-style notch: flat at the screen edge with a restrained,
        // smooth curve only along the bottom edge.
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: expanded ? 34 : 16
        bottomRightRadius: expanded ? 34 : 16
        color: "#000000"

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
            opacity: island.expanded ? 0 : 1
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Colors.fg
            font { pixelSize: 16; weight: 600 }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Item {
            anchors.fill: parent
            opacity: island.expanded && !wallpaperMode ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            Rectangle {
                id: artworkContainer
                width: 100
                height: 80
                anchors { left: parent.left; leftMargin: 16; top: parent.top; topMargin: 18 }
                radius: 10
                color: Colors.alpha(Colors.colFg, 0.06)

                // Using the official Quickshell widget to strictly clip the image inside the radius
                ClippingRectangle {
                    anchors.fill: parent
                    radius: parent.radius

                    Image {
                        anchors.fill: parent
                        source: mediaPlayer && mediaPlayer.trackArtUrl ? mediaPlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !mediaPlayer || !mediaPlayer.trackArtUrl
                    text: "󰓇"
                    color: "#1ED760"
                    opacity: 1.0
                    font {
                        pixelSize: 38
                        family: "JetBrainsMono Nerd Font"
                    }
                }
            }


            Column {
                id: songInfo
                anchors { left: artworkContainer.right; leftMargin: 16; top: artworkContainer.top; right: calendar.left; rightMargin: 16 }
                spacing: 3
                Text {
                    width: parent.width
                    text: mediaPlayer ? (mediaPlayer.trackTitle || "Unknown Title") : "Nothing !"
                    color: Colors.fg
                    elide: Text.ElideRight
                    font { pixelSize: 17; weight: Font.DemiBold }
                }
                Text {
                    width: parent.width
                    text: mediaPlayer ? (mediaPlayer.trackArtist || "Unknown Artist") : "Spotify"
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

            Text {
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 17; bottomMargin: 10 }
                text: mediaPlayer ? "Spotify" : ""
                color: Colors.grey2
                opacity: 0.45
                font { pixelSize: 8 }
            }
        }
    }
}
