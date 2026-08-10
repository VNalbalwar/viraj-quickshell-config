pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool visible: false
    property int brightness: 0

    function show() {
        brightnessProcess.running = true
        root.visible = true
        hideTimer.restart()
    }

    function hide() {
        hideTimer.stop()
        root.visible = false
    }

    function showBrightness() {
        brightnessProcess.running = true
        root.visible = true
        hideTimer.restart()
    }

    function toggle() {
        if (root.visible)
            hide()
        else
            show()
    }
    
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
        function hide(): void { root.hide() }
    }
}
