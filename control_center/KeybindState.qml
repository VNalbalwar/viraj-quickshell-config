pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Keybind cheatsheet data: `hyprctl binds -j`, keeping only binds that carry a
// `desc` in binds.lua. Cached after the first load, refreshed on every open.
Singleton {
    id: root

    property var all: []
    property string filter: ""
    readonly property var shown: {
        var q = root.filter.trim().toLowerCase()
        return root.all.filter(function(b) {
            return q === "" || b.desc.toLowerCase().indexOf(q) !== -1 || b.chips.join(" ").toLowerCase().indexOf(q) !== -1
        })
    }

    function load() {
        bindsProcess.running = false
        bindsProcess.running = true
    }

    function keyName(key) {
        if (key === "mouse:272") return "LMB"
        if (key === "mouse:273") return "RMB"
        if (key === "mouse_down") return "Scroll ↓"
        if (key === "mouse_up") return "Scroll ↑"
        var names = { left: "←", right: "→", up: "↑", down: "↓", Print: "PrtSc", Return: "Enter" }
        if (names[key]) return names[key]
        return key.indexOf("XF86") === 0 ? key.replace("XF86", "") : key
    }

    function chipsFor(b) {
        var chips = []
        if (b.modmask & 64) chips.push("Super")
        if (b.modmask & 4) chips.push("Ctrl")
        if (b.modmask & 8) chips.push("Alt")
        if (b.modmask & 1) chips.push("Shift")
        chips.push(root.keyName(b.key))
        return chips
    }

    Process {
        id: bindsProcess
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var binds = JSON.parse(text)
                    root.all = binds.filter(function(b) { return b.description && b.description !== "" })
                        .map(function(b) { return { chips: root.chipsFor(b), desc: b.description } })
                } catch (e) {
                    console.log("Failed to parse hyprctl binds:", e)
                }
            }
        }
    }
}
