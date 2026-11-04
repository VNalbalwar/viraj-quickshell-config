pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history backed by cliphist (a `wl-paste --watch cliphist store`
// watcher is started from Hyprland's autostart). The list model is diff-synced
// like the wifi / bluetooth lists, so entries animate in and out live.
Singleton {
    id: root

    readonly property alias model: listModel
    property string filter: ""
    property var entries: []          // everything cliphist returned (newest first)

    ListModel { id: listModel }

    function refresh() {
        listProcess.running = false
        listProcess.running = true
    }

    function setFilter(text) {
        root.filter = text
        root.apply()
    }

    function apply() {
        var q = root.filter.trim().toLowerCase()
        var list = root.entries.filter(function(e) {
            return q === "" || e.preview.toLowerCase().indexOf(q) !== -1
        }).slice(0, 60)
        ControlState.syncModel(listModel, "id", list)
    }

    // put an entry back on the clipboard
    function copy(id) {
        copyProcess.command = ["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", String(id)]
        copyProcess.running = false
        copyProcess.running = true
    }

    function remove(id) {
        removeProcess.command = ["sh", "-c", "cliphist list | awk -F'\\t' -v id=\"$1\" '$1 == id' | cliphist delete", "sh", String(id)]
        removeProcess.running = false
        removeProcess.running = true
    }

    function wipe() {
        removeProcess.command = ["cliphist", "wipe"]
        removeProcess.running = false
        removeProcess.running = true
    }

    Process {
        id: listProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.length > 0 ? text.split("\n") : []
                for (var i = 0; i < lines.length && out.length < 200; i++) {
                    var tab = lines[i].indexOf("\t")
                    if (tab <= 0) continue
                    var preview = lines[i].substring(tab + 1).replace(/\s+/g, " ").trim()
                    out.push({
                        id: lines[i].substring(0, tab),
                        preview: preview,
                        image: preview.indexOf("[[ binary data") === 0
                    })
                }
                root.entries = out
                root.apply()
            }
        }
    }

    Process { id: copyProcess }

    Process {
        id: removeProcess
        onExited: root.refresh()
    }

    // live: new copies show up while the page is open
    Timer {
        interval: 1500
        repeat: true
        running: ControlState.visible && ControlState.page === "clipboard"
        onTriggered: root.refresh()
    }
}
