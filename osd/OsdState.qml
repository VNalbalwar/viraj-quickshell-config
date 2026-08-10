pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool visible: false
    property int brightness: 0

    property int volume: 0
    property bool muted: false
    property string mode: "brightness"

    property bool micMuted: false

    function readBrightness() {
        brightnessProcess.running = true
    }

    function readVolume() {
        volumeProcess.running = true
    }

    function readMicMute() {
        micMuteProcess.running = true
    }

    function showVolume() {
        root.mode = "volume"
        readVolume()
        root.visible = true
        hideTimer.restart()
    }

    function showMic() {
        root.mode = "mic"
        readMicMute()
        root.visible = true
        hideTimer.restart()
    }

    function show() {
        readBrightness()
        root.visible = true
        hideTimer.restart()
    }

    function hide() {
        hideTimer.stop()
        root.visible = false
    }

    function showBrightness() {
        root.mode = "brightness"
        readBrightness()
        root.visible = true
        hideTimer.restart()
    }

    function toggle() {
        if (root.visible)
            hide()
        else
            show()
    }

    Component.onCompleted: readBrightness()

    Process {
        id: brightnessProcess

        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(",")

                if (parts.length >= 4) {
                    var value = parseInt(parts[3].replace("%", ""))

                    if (!isNaN(value))
                        root.brightness = value
                }
            }
        }
    }

    Process {
        id: volumeProcess

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: SplitParser {
            onRead: data => {
                var output = data.trim()

                var match = output.match(/Volume:\s*([0-9.]+)/)

                if (match) {
                    var value = parseFloat(match[1])

                    if (!isNaN(value))
                        root.volume = Math.round(value * 100)
                }

                root.muted = output.indexOf("[MUTED]") !== -1
            }
        }
    }

    Process {
        id: micMuteProcess

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]

        stdout: SplitParser {
            onRead: data => {
                var output = data.trim()
                root.micMuted = output.indexOf("[MUTED]") !== -1
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: root.visible = false
    }

    IpcHandler {
        target: "osd"

        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function showBrightness(): void { root.showBrightness() }
        function hide(): void { root.hide() }
        function showVolume(): void { root.showVolume() }
        function showMic(): void { root.showMic() }
    }
}
