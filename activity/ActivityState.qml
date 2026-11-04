pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
//  ActivityState — data behind the notch's "live activities" (the little pill
//  the idle notch grows into): a countdown timer and screen-recording detection.
//  (Media playback comes straight from MPRIS in Bar.qml.)
//
//    qs ipc call activity timer 25m        (also 90s, 1h30m, 1:30, bare number = minutes)
//    qs ipc call activity timer stop
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    // ── countdown timer ──────────────────────────────────────────────────────
    property real timerEnd: 0            // ms since epoch, 0 = not running
    property real timerTotal: 0          // ms
    property real timerRemaining: 0      // ms
    property string timerLabel: ""
    property bool timerFinished: false   // "Done!" flash after it elapses

    readonly property bool timerActive: timerEnd > 0
    readonly property real timerFraction: timerTotal > 0 ? Math.max(0, Math.min(1, timerRemaining / timerTotal)) : 0

    // "25m" | "90s" | "1h30m" | "1:30" (min:sec) | "10" (minutes) -> ms, or 0 if unparseable
    function parseDuration(spec) {
        spec = (spec || "").trim().toLowerCase()
        if (spec === "") return 0
        var colon = spec.match(/^(\d+):(\d{1,2})$/)
        if (colon) return (parseInt(colon[1]) * 60 + parseInt(colon[2])) * 1000
        if (/^\d+(\.\d+)?$/.test(spec)) return Math.round(parseFloat(spec) * 60000)
        var re = /(\d+(?:\.\d+)?)\s*(h|m|s)/g
        var ms = 0, m, any = false
        while ((m = re.exec(spec)) !== null) {
            any = true
            ms += parseFloat(m[1]) * ({ h: 3600000, m: 60000, s: 1000 })[m[2]]
        }
        return any ? Math.round(ms) : 0
    }

    function startTimer(ms, label) {
        if (ms <= 0) return false
        root.timerFinished = false
        finishedFlash.stop()
        root.timerTotal = ms
        root.timerEnd = Date.now() + ms
        root.timerRemaining = ms
        root.timerLabel = label || ""
        return true
    }

    function stopTimer() {
        root.timerEnd = 0
        root.timerRemaining = 0
        root.timerFinished = false
        finishedFlash.stop()
    }

    function format(ms) {
        var s = Math.max(0, Math.ceil(ms / 1000))
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        function two(n) { return (n < 10 ? "0" : "") + n }
        return h > 0 ? h + ":" + two(m) + ":" + two(sec) : two(m) + ":" + two(sec)
    }

    Timer {
        interval: 250
        repeat: true
        running: root.timerActive
        onTriggered: {
            root.timerRemaining = Math.max(0, root.timerEnd - Date.now())
            if (root.timerRemaining <= 0) {
                root.timerEnd = 0
                root.timerFinished = true
                finishedFlash.restart()
                Quickshell.execDetached(["notify-send", "-a", "Timer", "Timer finished",
                    root.timerLabel !== "" ? root.timerLabel : root.format(root.timerTotal) + " elapsed"])
                Quickshell.execDetached(["sh", "-c",
                    "paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true"])
            }
        }
    }

    Timer {
        id: finishedFlash
        interval: 8000
        onTriggered: root.timerFinished = false
    }

    // ── screen recording ─────────────────────────────────────────────────────
    // Detects a running recorder; shows elapsed time and a stop button.
    readonly property var recorders: ["wf-recorder", "wl-screenrec", "gpu-screen-recorder", "obs"]
    property bool recording: false
    property string recorder: ""
    property int recordSecs: 0

    function stopRecording() {
        if (root.recorder !== "")
            Quickshell.execDetached(["pkill", "-INT", "-x", root.recorder])
    }

    Process {
        id: recordPoll
        command: ["sh", "-c",
            "for p in " + root.recorders.join(" ") + "; do pid=$(pgrep -x \"$p\" | head -1); " +
            "if [ -n \"$pid\" ]; then echo \"$p $(ps -o etimes= -p \"$pid\" | tr -d ' ')\"; exit 0; fi; done; echo none"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(" ")
                if (parts[0] === "none" || parts[0] === "") {
                    root.recording = false
                    root.recorder = ""
                } else {
                    root.recording = true
                    root.recorder = parts[0]
                    root.recordSecs = parseInt(parts[1]) || 0
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: recordPoll.running = true
    }

    // smooth the elapsed counter between polls
    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.recordSecs++
    }

    IpcHandler {
        target: "activity"

        function timer(spec: string): void {
            if (spec === "stop" || spec === "cancel") root.stopTimer()
            else if (!root.startTimer(root.parseDuration(spec), ""))
                Quickshell.execDetached(["notify-send", "-a", "Timer", "Couldn't start timer", "Use e.g. 25m, 90s, 1h30m or 1:30"])
        }
    }
}
