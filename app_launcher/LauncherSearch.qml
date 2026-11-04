pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../activity"
import "../control_center"

// ─────────────────────────────────────────────────────────────────────────────
//  LauncherSearch — turns what you type in the notch launcher into result cards.
//
//    2+2*8, = 15%4      calculator   (Enter copies the result)
//    timer 25m          start a countdown (live activity in the notch)
//    github.com, https://…   open the address
//    clip / cb          open clipboard history
//    <text>             matching apps, then open windows (Enter focuses),
//                       then power actions (lock / log out / reboot / power off),
//                       then "search the web"
//
//  Every result is { kind, name, sub, icon, glyph, run() }.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property var windows: []

    function refresh() {
        windowsProcess.running = false
        windowsProcess.running = true
    }

    Process {
        id: windowsProcess
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text)
                        .filter(function(w) { return w.mapped && w.title !== "" })
                } catch (e) {
                    root.windows = []
                }
            }
        }
    }

    // ── helpers ──────────────────────────────────────────────────────────────
    // Whitelisted arithmetic only (digits, operators, parens, dots) -> never arbitrary code.
    function calc(q) {
        var expr = q.trim().replace(/^=/, "").trim()
        if (expr === "" || !/^[0-9+\-*\/().,%^ \t]+$/.test(expr)) return null
        if (!/[+\-*\/%^]/.test(expr.replace(/^\s*-/, ""))) return null      // needs an operator
        expr = expr.replace(/,/g, ".").replace(/\^/g, "**")
        try {
            var v = (new Function('"use strict"; return (' + expr + ')'))()
            if (typeof v !== "number" || !isFinite(v)) return null
            return Math.round(v * 1e10) / 1e10
        } catch (e) {
            return null
        }
    }

    // an icon name only if the theme really has it (otherwise Quickshell draws a checkerboard)
    function iconFor(cls) {
        var names = [cls, cls.toLowerCase(), cls.split(".").pop().toLowerCase()]
        for (var i = 0; i < names.length; i++)
            if (names[i] !== "" && Quickshell.iconPath(names[i], true) !== "") return names[i]
        return ""
    }

    function open(url) { Quickshell.execDetached(["xdg-open", url]) }

    function matches(text, q) { return text && text.toLowerCase().indexOf(q) !== -1 }

    // ── main entry ───────────────────────────────────────────────────────────
    function build(query) {
        var raw = query.trim()
        var q = raw.toLowerCase()
        var apps = DesktopEntries.applications.values
        var out = []

        if (q === "") {
            return apps.map(root.appResult)
        }

        // 1. instant answers
        var value = root.calc(raw)
        if (value !== null) {
            out.push({ kind: "calc", name: "= " + value, sub: "Calculator · Enter to copy", icon: "", glyph: "󰃬",
                run: function() { Quickshell.execDetached(["wl-copy", String(value)]) } })
        }

        var t = raw.match(/^(?:timer|t)\s+(.+)$/i)
        if (t) {
            var ms = ActivityState.parseDuration(t[1])
            if (ms > 0) {
                out.push({ kind: "timer", name: "Timer · " + ActivityState.format(ms), sub: "Start a countdown in the notch", icon: "", glyph: "󱎫",
                    run: function() { ActivityState.startTimer(ms, "") } })
            }
        }

        if (/^(clip|cb|clipboard)(\s|$)/i.test(raw)) {
            out.push({ kind: "clipboard", name: "Clipboard history", sub: "Open in the control center", icon: "", glyph: "󰅌",
                run: function() { ControlState.showPage("clipboard") } })
        }

        if (/^(https?:\/\/)?[\w-]+(\.[\w-]+)+(:\d+)?(\/\S*)?$/i.test(raw)) {
            var url = /^https?:\/\//i.test(raw) ? raw : "https://" + raw
            out.push({ kind: "url", name: "Open " + raw, sub: "In your browser", icon: "", glyph: "󰖟",
                run: function() { root.open(url) } })
        }

        // 2. apps
        var appHits = apps.filter(function(app) {
            if (root.matches(app.name, q) || root.matches(app.genericName, q)) return true
            if (app.keywords)
                for (var i = 0; i < app.keywords.length; i++)
                    if (root.matches(app.keywords[i], q)) return true
            return false
        }).sort(function(a, b) {
            // names that START with the query first, then alphabetical
            var sa = a.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
            var sb = b.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
            return sa !== sb ? sa - sb : a.name.localeCompare(b.name)
        })
        out = out.concat(appHits.map(root.appResult))

        // 3. open windows
        var wins = root.windows.filter(function(w) {
            return root.matches(w.title, q) || root.matches(w.class, q)
        }).slice(0, 6)
        out = out.concat(wins.map(function(w) {
            return { kind: "window", name: w.title, sub: "Window · " + w.class + " · workspace " + w.workspace.id, icon: root.iconFor(w.class), glyph: "󰣇",
                run: function() {
                    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + w.address + "' })"])
                } }
        }))

        // 4. power actions (3+ letters so they don't drown real apps)
        if (q.length >= 3) {
            var actions = [
                { key: "lock", name: "Lock", glyph: "󰌾", cmd: ["qs", "ipc", "call", "lock", "lock"] },
                { key: "log out", name: "Log Out", glyph: "󰐥", cmd: ["uwsm", "stop"] },
                { key: "logout", name: "Log Out", glyph: "󰐥", cmd: ["uwsm", "stop"] },
                { key: "reboot", name: "Reboot", glyph: "󰐥", cmd: ["systemctl", "reboot"] },
                { key: "restart", name: "Reboot", glyph: "󰐥", cmd: ["systemctl", "reboot"] },
                { key: "shutdown", name: "Power Off", glyph: "󰐥", cmd: ["systemctl", "poweroff"] },
                { key: "power off", name: "Power Off", glyph: "󰐥", cmd: ["systemctl", "poweroff"] },
                { key: "poweroff", name: "Power Off", glyph: "󰐥", cmd: ["systemctl", "poweroff"] }
            ]
            var seen = {}
            actions.forEach(function(a) {
                if (a.key.indexOf(q) === 0 && !seen[a.name]) {
                    seen[a.name] = true
                    out.push({ kind: "system", name: a.name, sub: "System", icon: "", glyph: a.glyph,
                        run: function() { Quickshell.execDetached(a.cmd) } })
                }
            })
        }

        // 5. always last: search the web
        out.push({ kind: "web", name: "Search “" + raw + "”", sub: "Web · DuckDuckGo", icon: "", glyph: "󰖟",
            run: function() { root.open("https://duckduckgo.com/?q=" + encodeURIComponent(raw)) } })

        return out
    }

    function appResult(app) {
        return { kind: "app", name: app.name, sub: "", icon: app.icon, glyph: "",
            run: function() {
                app.execute()
                AppLauncherState.recordLaunch(app.id)
            } }
    }
}
