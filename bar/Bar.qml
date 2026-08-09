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

    mask: Region {
        item: island
    }

    // ─────────────────────────────────────────────────────────────
    // Spotify / MPRIS
    // ─────────────────────────────────────────────────────────────

    readonly property var mediaPlayer: {
        for (var i = 0; i < Mpris.players.values.length; i++) {
            var p = Mpris.players.values[i]

            if (p.desktopEntry === "spotify" ||
                p.identity.toLowerCase().indexOf("spotify") !== -1)
                return p
        }

        return null
    }

    readonly property bool hasMedia: mediaPlayer !== null
    readonly property bool mediaPlaying: hasMedia && mediaPlayer.isPlaying

    // ─────────────────────────────────────────────────────────────
    // Main island
    // ─────────────────────────────────────────────────────────────

    Rectangle {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8

        clip: true

        property bool expanded: hover.hovered

        // Collapsed = your original pill
        // Expanded = media card
        implicitWidth: expanded ? 420 : 150
        implicitHeight: expanded ? 150 : 34

        radius: Math.min(height / 2, 26)
        color: Colors.bg1

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

        HoverHandler {
            id: hover
        }

        // ─────────────────────────────────────────────────────────
        // Clock
        // ─────────────────────────────────────────────────────────

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Text {
            anchors.centerIn: parent

            opacity: island.expanded ? 0 : 1

            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Colors.fg

            font {
                pixelSize: 14
                weight: 600
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        // ─────────────────────────────────────────────────────────
        // Expanded media card
        // ─────────────────────────────────────────────────────────

        Item {
            anchors.fill: parent

            opacity: island.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }

            // Album artwork
            Rectangle {
                id: artworkContainer

                width: 94
                height: 94

                anchors {
                    left: parent.left
                    leftMargin: 18
                    top: parent.top
                    topMargin: 18
                }

                radius: 16

                color: Colors.bg1

                clip: true

                Image {
                    anchors.fill: parent

                    source: mediaPlayer && mediaPlayer.trackArtUrl
                            ? mediaPlayer.trackArtUrl
                            : ""

                    fillMode: Image.PreserveAspectCrop

                    asynchronous: true
                    cache: true

                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent

                    visible: !mediaPlayer ||
                             !mediaPlayer.trackArtUrl

                    text: "♫"

                    color: Colors.fg
                    opacity: 0.35

                    font {
                        pixelSize: 32
                        weight: Font.DemiBold
                    }
                }
            }

            // Song information
            Column {
                anchors {
                    left: artworkContainer.right
                    leftMargin: 14
                    right: parent.right
                    rightMargin: 18
                    top: artworkContainer.top
                }

                spacing: 5

                Text {
                    width: parent.width

                    text: mediaPlayer
                          ? (mediaPlayer.trackTitle || "Unknown Title")
                          : "Nothing playing"

                    color: Colors.fg

                    elide: Text.ElideRight

                    font {
                        pixelSize: 17
                        weight: Font.DemiBold
                    }
                }

                Text {
                    width: parent.width

                    text: mediaPlayer
                          ? (mediaPlayer.trackArtist || "Unknown Artist")
                          : "Spotify"

                    color: Colors.grey2

                    elide: Text.ElideRight

                    font.pixelSize: 13
                }
            }

            // ─────────────────────────────────────────────────────
            // Playback controls
            // ─────────────────────────────────────────────────────

        Row {
            anchors {
                bottom: parent.bottom
                bottomMargin: 14
                horizontalCenter: parent.horizontalCenter
            }

            spacing: 10

            // Previous
            Rectangle {
                width: 42
                height: 42
                radius: 21

                color: previousHover.hovered
                    ? Colors.alpha(Colors.colFg, 0.14)
                    : Colors.alpha(Colors.colFg, 0.06)

                scale: previousHover.hovered ? 1.08 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: "󰒮"
                    color: Colors.fg

                    font {
                        pixelSize: 21
                        weight: Font.Medium
                    }
                }

                HoverHandler {
                    id: previousHover
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        if (mediaPlayer && mediaPlayer.canGoPrevious)
                            mediaPlayer.previous()
                    }
                }
            }

            // Play / Pause
            Rectangle {
                width: 48
                height: 48
                radius: 24

                color: playHover.hovered
                    ? Colors.alpha(Colors.colBlue, 0.28)
                    : Colors.alpha(Colors.colBlue, 0.18)

                scale: playHover.hovered ? 1.08 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: mediaPlaying ? "󰏤" : "󰐊"

                    color: Colors.fg

                    font {
                        pixelSize: 23
                        weight: Font.DemiBold
                    }
                }

                HoverHandler {
                    id: playHover
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        if (mediaPlayer && mediaPlayer.canTogglePlaying)
                            mediaPlayer.togglePlaying()
                    }
                }
            }

            // Next
            Rectangle {
                width: 42
                height: 42
                radius: 21

                color: nextHover.hovered
                    ? Colors.alpha(Colors.colFg, 0.14)
                    : Colors.alpha(Colors.colFg, 0.06)

                scale: nextHover.hovered ? 1.08 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: "󰒭"
                    color: Colors.fg

                    font {
                        pixelSize: 21
                        weight: Font.Medium
                    }
                }

                HoverHandler {
                    id: nextHover
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        if (mediaPlayer && mediaPlayer.canGoNext)
                            mediaPlayer.next()
                    }
                }
            }
        }

            // Spotify indicator
            Text {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 18
                    bottomMargin: 18
                }

                text: mediaPlayer ? "Spotify" : ""

                color: Colors.grey2
                opacity: 0.5

                font.pixelSize: 9
            }
        }
    }
}