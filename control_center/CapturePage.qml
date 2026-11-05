import Quickshell
import Quickshell.Io
import QtQuick
import "../theme"
import "../app_launcher"

// Screenshots (hyprshot) and screen recording (wf-recorder, if installed).
Page {
    id: page
    name: "capture"

    property bool recording: false
    property int seconds: 0
    property bool haveRecorder: false

    onShownChanged: if (shown) { probe.running = false; probe.running = true; LauncherSearch.refresh() }

    Process { id: probe; command: ["sh", "-c", "command -v wf-recorder >/dev/null && echo yes || echo no"]
        stdout: StdioCollector { onStreamFinished: page.haveRecorder = text.trim() === "yes" } }

    function shot(mode) {
        ControlState.hide()
        shotTimer.mode = mode
        shotTimer.start()
    }
    Timer {
        id: shotTimer
        property string mode: "region"
        interval: 380
        onTriggered: Quickshell.execDetached(["hyprshot", "-m", mode])
    }

    function record(region) {
        if (!haveRecorder) { Quickshell.execDetached(["notify-send", "-a", "Capture", "wf-recorder isn't installed", "sudo pacman -S wf-recorder"]); return }
        ControlState.hide()
        recordStart.region = region
        recordStart.start()
    }
    Timer {
        id: recordStart
        property bool region: false
        interval: 380
        onTriggered: {
            var out = Quickshell.env("HOME") + "/Videos/recording-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd-hhmmss") + ".mp4"
            page.seconds = 0
            page.recording = true
            recorder.command = region
                ? ["sh", "-c", "wf-recorder -g \"$(slurp)\" -f \"$1\"", "sh", out]
                : ["wf-recorder", "-f", out]
            recorder.running = true
        }
    }
    Process { id: recorder; onExited: { page.recording = false; page.seconds = 0 } }
    function stopRecording() { Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]) }
    Timer { interval: 1000; repeat: true; running: page.recording; onTriggered: page.seconds++ }

    Grid {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Ui.bodyTop + 6 }
        columns: 4
        spacing: Ui.gap

        Tile { icon: "󰵑"; label: "Region"; sub: "Screenshot"; onTriggered: page.shot("region") }
        Tile { icon: "󰖲"; label: "Window"; sub: "Screenshot"; onTriggered: page.shot("window") }
        Tile { icon: "󰍹"; label: "Screen"; sub: "Screenshot"; onTriggered: page.shot("output") }
        Tile { icon: "󰥶"; label: "Last shot"; sub: LauncherSearch.lastScreenshot !== "" ? "Open it" : "None yet"
               onTriggered: if (LauncherSearch.lastScreenshot !== "") { ControlState.hide(); Quickshell.execDetached(["xdg-open", LauncherSearch.lastScreenshot]) } }

        Tile { icon: "󰑊"; label: "Record area"; sub: page.haveRecorder ? "Video" : "Needs wf-recorder"; onTriggered: page.record(true) }
        Tile { icon: "󰕧"; label: "Record screen"; sub: page.haveRecorder ? "Video" : "Needs wf-recorder"; onTriggered: page.record(false) }
        Tile { icon: "󰓛"; label: page.recording ? "Stop" : "Stopped"; on: page.recording
               sub: page.recording ? Math.floor(page.seconds / 60) + ":" + ("0" + page.seconds % 60).slice(-2) : "Not recording"
               onTriggered: if (page.recording) page.stopRecording() }
        Tile { icon: "󰉋"; label: "Folder"; sub: "Pictures"; onTriggered: { ControlState.hide(); Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/Pictures"]) } }
    }
}
