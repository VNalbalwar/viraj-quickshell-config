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
    property string lastFile: ""

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
            page.lastFile = out
            // Hardware (Intel VA-API) encoding when the driver is there: the screen is copied and encoded on the GPU, so
            // your 240 Hz desktop stays smooth. Without it wf-recorder copies every frame through the CPU (~4 cores busy).
            // slurp gets </dev/null: with an open stdin pipe it waits for a list of regions instead of letting you drag one.
            var sel = region ? 'g=$(slurp </dev/null) || exit 0; ' : ''
            var geo = region ? '-g "$g" ' : ''
            recorder.command = ["sh", "-c",
                sel + 'dev=$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-render); ' +
                'if [ -e /usr/lib/dri/iHD_drv_video.so ] && [ -e "$dev" ]; then enc="-c h264_vaapi -d $dev -r 60 -p b=16000000 -p level=52"; else enc="-p preset=ultrafast -p crf=28"; fi; ' +
                // sound: whatever is playing through your speakers / headphones (the default output's monitor)
                'aud="-a$(pactl get-default-sink).monitor"; ' +
                // -r 60: a steady 60 fps. Capture tops out around 80 fps on this machine, so asking for 90 or 120 made
                // the file play back FAST and jerky (an 8 s recording came out 5 s long). Level 5.2 + 16 Mbit/s keeps
                // 2560x1600 at 60 fps within what players' decoders accept, and sharp.
                'exec wf-recorder $enc $aud ' + geo + '-f "$1"', "sh", out]
            recorder.running = true
        }
    }
    Process {
        id: recorder
        onExited: {
            page.recording = false
            page.seconds = 0
            // tell you where it went; clicking the notification opens the folder with the file selected
            if (page.lastFile !== "")
                Quickshell.execDetached(["sh", "-c",
                    "[ -s \"$1\" ] && notify-send -a Capture -i video-x-generic -t 6000 'Recording saved' \"Saved in <i>$1</i>\"", "sh", page.lastFile])
        }
    }
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
        Tile { icon: "󰉋"; label: "Folder"; sub: "Pictures"; onTriggered: { ControlState.hide(); Quickshell.execDetached(["sh", "-c", "nautilus \"$1\" || thunar \"$1\" || xdg-open \"$1\"", "sh", Quickshell.env("HOME") + "/Pictures"]) } }
    }
}
