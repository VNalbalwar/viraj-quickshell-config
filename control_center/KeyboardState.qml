pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
//  KeyboardState — four-zone RGB keyboard backlight (linuwu_sense driver).
//
//  Linux support: the out-of-tree linuwu_sense module exposes
//    .../acer-wmi/four_zoned_kb/per_zone_mode   RRGGBB x4 , brightness
//    .../acer-wmi/four_zoned_kb/four_zone_mode  mode,speed,brightness,direction,r,g,b
//  Writing is root-only, so changes go through the whitelisted predator-sense
//  helper (extras/predator/install.sh also patches the driver so PH16-71 gets
//  the four_zoned_kb folder at all).
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    readonly property string base: "/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb"
    readonly property string helperPath: "/usr/local/bin/predator-sense"

    property bool available: false     // the driver exposes four_zoned_kb
    property bool helper: false        // predator-sense is installed
    property var zones: ["4287f5", "4287f5", "4287f5", "4287f5"]
    property int brightness: 100
    property int selectedZone: -1      // -1 = all zones
    property int effect: -1            // -1 = per-zone static colours, 0-7 = hardware effect

    readonly property var effects: [
        { mode: 0, name: "Static" },
        { mode: 1, name: "Breathing" },
        { mode: 2, name: "Neon" },
        { mode: 3, name: "Wave" },
        { mode: 4, name: "Shift" },
        { mode: 5, name: "Zoom" },
        { mode: 6, name: "Meteor" },
        { mode: 7, name: "Twinkle" }
    ]

    readonly property var palette: [
        "ff3b30", "ff9500", "ffcc00", "34c759", "00c7be", "0a84ff", "5e5ce6", "bf5af2", "ff375f", "ffffff"
    ]

    function hex(c) {                  // QML color -> "rrggbb"
        function two(n) { n = Math.round(n * 255); return (n < 16 ? "0" : "") + n.toString(16) }
        return two(c.r) + two(c.g) + two(c.b)
    }

    function refresh() {
        availableProcess.running = true
        helperProcess.running = true
        readProcess.running = true
    }

    function run(args) {
        applyProcess.command = ["pkexec", root.helperPath].concat(args)
        applyProcess.running = false
        applyProcess.running = true
    }

    function notifyMissing() {
        Quickshell.execDetached(["notify-send", "-a", "Keyboard", "Keyboard lighting",
            "Run extras/predator/install.sh once to enable it"])
    }

    // paint the selected zone (or all) with a colour, as static per-zone colours
    function setColor(rrggbb) {
        if (!root.helper) { root.notifyMissing(); return }
        var z = root.zones.slice()
        if (root.selectedZone < 0) z = [rrggbb, rrggbb, rrggbb, rrggbb]
        else z[root.selectedZone] = rrggbb
        root.zones = z
        root.effect = -1
        root.apply()
    }

    function setBrightness(percent) {
        root.brightness = Math.max(0, Math.min(100, Math.round(percent)))
        if (!root.helper) return
        brightnessTimer.restart()
    }

    function apply() {
        root.run(["kb-zones", root.zones.join(",") + "," + root.brightness])
    }

    function setEffect(mode) {
        if (!root.helper) { root.notifyMissing(); return }
        root.effect = mode
        var c = root.zones[Math.max(0, root.selectedZone)]
        var r = parseInt(c.substring(0, 2), 16), g = parseInt(c.substring(2, 4), 16), b = parseInt(c.substring(4, 6), 16)
        // speed 5, direction 1; neon ignores colour/direction on its own
        root.run(["kb-mode", [mode, 5, root.brightness, 1, r, g, b].join(",")])
    }

    Timer {
        id: brightnessTimer
        interval: 150
        onTriggered: {
            if (root.effect >= 0) root.setEffect(root.effect)
            else root.apply()
        }
    }

    Process { id: applyProcess }

    Process {
        id: availableProcess
        command: ["test", "-e", root.base + "/per_zone_mode"]
        onExited: function(code) { root.available = (code === 0) }
    }

    Process {
        id: helperProcess
        command: ["test", "-x", root.helperPath]
        onExited: function(code) { root.helper = (code === 0) }
    }

    // current zone colours: "4287f5,4287f5,4287f5,4287f5,100"
    Process {
        id: readProcess
        command: ["cat", root.base + "/per_zone_mode"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(",")
                if (p.length >= 5 && /^[0-9a-fA-F]{6}$/.test(p[0])) {
                    root.zones = p.slice(0, 4).map(function(s) { return s.toLowerCase() })
                    root.brightness = parseInt(p[4]) || root.brightness
                }
            }
        }
    }
}
