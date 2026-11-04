pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../notifications"

// ─────────────────────────────────────────────────────────────────────────────
//  ChromeTabs — which Chrome tabs are making sound, straight from Chrome.
//
//  Chrome mixes all tabs into one audio stream and reports one media session, so the audio layer
//  can't tell tabs apart. The "Notch tab bridge" extension (extras/chrome-tabs) can, and reports
//  them through a small native helper that keeps $XDG_RUNTIME_DIR/qs-chrome/tabs.json up to date.
//  Without the extension this is simply empty and the media list behaves as before.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property var tabs: []                 // audible tabs (+ tabs paused from here)
    property string browser: ""
    property string rawKey: ""

    readonly property string stateFile: "/run/user/1000/qs-chrome/tabs.json"
    readonly property string ctl: "/home/viraj/.config/quickshell/extras/chrome-tabs/qs-chrome-ctl"

    function hostOf(url) { return (url || "").replace(/^[a-z]+:\/\/([^\/]+).*$/i, "$1") }

    function setMuted(tabId, muted) { run(["mute", String(tabId), muted ? "true" : "false"]) }

    function togglePause(row) { run([row.playing ? "pause" : "play", String(row.tabId)]) }

    // take me to that tab (Chrome selects it; Hyprland brings the Chrome window forward)
    function focusTab(row) {
        run(["focus", String(row.tabId)])
        NotificationState.focusSource("", "google-chrome")
    }

    function run(args) {
        ctlProcess.command = [root.ctl].concat(args)
        ctlProcess.running = false
        ctlProcess.running = true
    }

    function refresh() {
        readProcess.running = false
        readProcess.running = true
    }

    Process {
        id: ctlProcess
        onExited: quickRefresh.restart()
    }

    Timer { id: quickRefresh; interval: 450; onTriggered: root.refresh() }     // pick up the result of a click

    Process {
        id: readProcess
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "sh", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                var key = text.trim()
                if (key === root.rawKey) return            // unchanged: don't touch anything
                root.rawKey = key
                try {
                    var data = key === "" ? { tabs: [], browser: "" } : JSON.parse(key)
                    root.browser = data.browser || ""
                    root.tabs = data.tabs || []
                } catch (e) {
                    root.tabs = []
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
