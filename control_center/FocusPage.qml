import QtQuick
import "../theme"
import "../activity"

// Pomodoro on top of the notch's own timer: it shows live in the notch while it runs.
Page {
    id: page
    name: "focus"

    readonly property bool running: ActivityState.timerEnd > Date.now()
    readonly property real remaining: ActivityState.timerRemaining
    function mmss(ms) {
        var s = Math.max(0, Math.round(ms / 1000))
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
    }

    Column {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Ui.bodyTop + 4 }
        spacing: 18

        // big readout + progress
        Item {
            width: 300
            height: 118
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.running ? page.mmss(page.remaining) : "25:00"
                color: page.running ? Colors.fg : Colors.alpha(Colors.fg, 0.4)
                font { family: Ui.iconFont; pixelSize: 78; weight: Font.Light }
            }
            Text {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: bar.top; bottomMargin: 8 }
                text: page.running ? (ActivityState.timerLabel || "Timer") : "Ready"
                color: Colors.grey2
                font { pixelSize: 12; weight: Font.Medium; letterSpacing: 1 }
            }
            Rectangle {
                id: bar
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 4
                radius: 2
                color: Colors.alpha(Colors.colFg, 0.10)
                Rectangle {
                    height: parent.height
                    radius: 2
                    color: Colors.colBlue
                    width: page.running && ActivityState.timerTotal > 0 ? parent.width * (1 - page.remaining / ActivityState.timerTotal) : 0
                    Behavior on width { NumberAnimation { duration: 900 } }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Ui.gap
            Repeater {
                model: [
                    { icon: "󱎫", label: "Focus", sub: "25 min", ms: 25 * 60000, name: "Focus" },
                    { icon: "󰅶", label: "Break", sub: "5 min", ms: 5 * 60000, name: "Break" },
                    { icon: "󰒲", label: "Long break", sub: "15 min", ms: 15 * 60000, name: "Long break" },
                    { icon: "󰓛", label: "Stop", sub: "Clear timer", ms: 0, name: "" }
                ]
                delegate: Tile {
                    icon: modelData.icon
                    label: modelData.label
                    sub: modelData.sub
                    on: page.running && modelData.ms > 0 && ActivityState.timerLabel === modelData.name
                    onTriggered: {
                        if (modelData.ms > 0) ActivityState.startTimer(modelData.ms, modelData.name)
                        else ActivityState.stopTimer()
                    }
                }
            }
        }
    }
}
