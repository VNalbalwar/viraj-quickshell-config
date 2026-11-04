import Quickshell.Widgets
import QtQuick
import "../theme"

// What the idle (collapsed) notch shows while something is going on:
//   media      album art on the left, animated equalizer on the right (clock stays)
//   timer      timer glyph, countdown in the middle, progress ring on the right
//   recording  pulsing red dot, elapsed time, stop button
// Bar.qml widens the island for it and hides the plain clock for timer/recording.
Item {
    id: activity

    property string kind: ""         // "" | media | timer | recording
    property bool shown: true        // false while the island is expanded for something else
    property var player: null
    property bool playing: false

    readonly property bool on: kind !== "" && shown
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    opacity: on ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 220 } }

    // ── left slot ────────────────────────────────────────────────────────────
    Item {
        id: leftSlot
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        width: 28
        height: 28

        // media: album art
        ClippingRectangle {
            anchors.fill: parent
            visible: activity.kind === "media"
            radius: 9
            color: Colors.alpha(Colors.colFg, 0.10)

            Image {
                anchors.fill: parent
                source: activity.player && activity.player.trackArtUrl ? activity.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !activity.player || !activity.player.trackArtUrl
                text: "󰎆"
                color: Colors.colBrightBlue
                font { family: activity.iconFont; pixelSize: 16 }
            }
        }

        // timer: glyph (flashes when done)
        Text {
            anchors.centerIn: parent
            visible: activity.kind === "timer"
            text: "󱎫"
            color: ActivityState.timerFinished ? "#ffd166" : Colors.colBrightBlue
            font { family: activity.iconFont; pixelSize: 20 }
            SequentialAnimation on opacity {
                running: activity.kind === "timer" && ActivityState.timerFinished
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 450 }
                NumberAnimation { to: 1.0; duration: 450 }
            }
        }

        // recording: pulsing red dot
        Rectangle {
            id: recDot
            anchors.centerIn: parent
            visible: activity.kind === "recording"
            width: 12
            height: 12
            radius: 6
            color: "#ff4d4d"
            SequentialAnimation on scale {
                running: activity.kind === "recording" && activity.on
                loops: Animation.Infinite
                NumberAnimation { to: 1.35; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.85; duration: 600; easing.type: Easing.InOutSine }
            }
        }
    }

    // ── centre: countdown / elapsed (media keeps the plain clock) ────────────
    Text {
        anchors.centerIn: parent
        visible: activity.kind === "timer" || activity.kind === "recording"
        text: activity.kind === "timer"
            ? (ActivityState.timerFinished ? "Done!" : ActivityState.format(ActivityState.timerRemaining))
            : ActivityState.format(ActivityState.recordSecs * 1000)
        color: activity.kind === "recording" ? "#ff8a8a" : (ActivityState.timerFinished ? "#ffd166" : Colors.fg)
        font { pixelSize: 16; weight: Font.DemiBold; family: "JetBrainsMono Nerd Font" }
    }

    // ── right slot ───────────────────────────────────────────────────────────
    // media: equalizer
    Row {
        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        visible: activity.kind === "media"
        spacing: 3
        height: 20

        Repeater {
            model: 4

            delegate: Rectangle {
                required property int index

                anchors.bottom: parent.bottom
                width: 3
                height: 5
                radius: 1.5
                color: Colors.colBrightBlue

                SequentialAnimation on height {
                    running: activity.kind === "media" && activity.playing && activity.on
                    loops: Animation.Infinite
                    NumberAnimation { to: 18 - index * 2; duration: 260 + index * 90; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 4 + index; duration: 300 + index * 70; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 12 + (index % 2) * 5; duration: 220 + index * 60; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // timer: progress ring
    Canvas {
        id: ring
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        width: 24
        height: 24
        visible: activity.kind === "timer"

        property real fraction: ActivityState.timerFinished ? 1 : ActivityState.timerFraction
        property color track: Colors.alpha(Colors.colFg, 0.16)
        property color arc: ActivityState.timerFinished ? "#ffd166" : Colors.colBrightBlue

        onFractionChanged: requestPaint()
        onArcChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.lineWidth = 3
            ctx.lineCap = "round"
            ctx.strokeStyle = track
            ctx.beginPath()
            ctx.arc(12, 12, 9, 0, 2 * Math.PI)
            ctx.stroke()
            if (fraction > 0) {
                ctx.strokeStyle = arc
                ctx.beginPath()
                ctx.arc(12, 12, 9, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * fraction)
                ctx.stroke()
            }
        }
    }

    // recording: stop button
    Rectangle {
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        visible: activity.kind === "recording"
        width: 26
        height: 26
        radius: 13
        color: stopMouse.containsMouse ? Colors.alpha("#ff4d4d", 0.35) : Colors.alpha("#ff4d4d", 0.2)
        scale: stopMouse.pressed ? 0.88 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.centerIn: parent
            width: 9
            height: 9
            radius: 2
            color: "#ff6b6b"
        }

        MouseArea {
            id: stopMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ActivityState.stopRecording()
        }
    }
}
