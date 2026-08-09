import Quickshell
import Quickshell.Services.Mpris
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
    color: "transparent"
    implicitHeight: 160

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

        property bool expanded: hover.hovered
        implicitWidth: expanded ? 680 : 180
        implicitHeight: expanded ? 120 : 40

        // iPhone-style notch: completely flat at the screen edge,
        // with no rounding on the top corners. The lower corners
        // sweep into a deep, smooth rounded U-shape.
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: expanded ? 60 : 20
        bottomRightRadius: expanded ? 60 : 20
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
            font { pixelSize: 14; weight: 600 }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Item {
            anchors.fill: parent
            opacity: island.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            Rectangle {
                id: artworkContainer
                width: 100
                height: 80
                anchors { left: parent.left; leftMargin: 16; top: parent.top; topMargin: 18 }
                radius: 14
                color: Colors.alpha(Colors.colFg, 0.06)
                clip: true
                Image {
                    anchors.fill: parent
                    source: mediaPlayer && mediaPlayer.trackArtUrl ? mediaPlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !mediaPlayer || !mediaPlayer.trackArtUrl
                    text: "♫"
                    color: Colors.fg
                    opacity: 0.35
                    font { pixelSize: 28; weight: Font.DemiBold }
                }
            }

            Column {
                id: songInfo
                anchors { left: artworkContainer.right; leftMargin: 14; top: artworkContainer.top; right: calendar.left; rightMargin: 16 }
                spacing: 3
                Text {
                    width: parent.width
                    text: mediaPlayer ? (mediaPlayer.trackTitle || "Unknown Title") : "Nothing playing"
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
                anchors { left: songInfo.left; bottom: parent.bottom; bottomMargin: 13 }
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
                    width: 40; height: 40; radius: 20
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
                anchors { right: parent.right; rightMargin: 22; top: parent.top; topMargin: 17 }
                spacing: 5
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Colors.fg
                    font { pixelSize: 20; weight: Font.DemiBold }
                }
                Row {
                    spacing: 5
                    Repeater {
                        model: 7
                        delegate: Column {
                            width: 15
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: weekDays[index]
                                color: Colors.fg
                                opacity: 0.40
                                font { pixelSize: 9; weight: Font.Medium }
                            }
                            Rectangle {
                                width: 15; height: 15; radius: 7.5
                                color: index === todayIndex ? Colors.colBlue : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: weekDates[index]
                                    color: index === todayIndex ? "#000000" : Colors.fg
                                    opacity: index === todayIndex ? 1.0 : 0.28
                                    font { pixelSize: 8; weight: Font.Medium }
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
