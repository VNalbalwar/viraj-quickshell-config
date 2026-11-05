pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../activity"
import "../control_center"
import "../notifications"
import "../theme"

// ─────────────────────────────────────────────────────────────────────────────
//  LauncherSearch — turns what you type in the notch launcher into result cards.
//
//    2+2*8, = 15%4      calculator   (Enter copies the result)
//    timer 25m          start a countdown (live activity in the notch)
//    github.com, https://…   open the address
//    clip / cb          open clipboard history
//    <text>             matching apps, then open windows (Enter focuses),
//                       then power actions (lock / log out / reboot / power off),
//                       then "search Google"
//
//  Every result is { kind, name, sub, icon, glyph, run() }.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property var windows: []

    property var recentFiles: []          // [{ path, name, dir }] newest first
    property string lastScreenshot: ""

    function refresh() {
        windowsProcess.running = false
        windowsProcess.running = true
        recentProcess.running = false
        recentProcess.running = true
        ClipboardState.refresh()
    }

    // what you touched lately in the places you actually keep things (no hidden files, no caches)
    Process {
        id: recentProcess
        command: ["sh", "-c",
            "find \"$HOME/Documents\" \"$HOME/Downloads\" \"$HOME/Desktop\" \"$HOME/Pictures\" \"$HOME/Videos\" -maxdepth 3 -type f " +
            "-not -path '*/.*' -not -path '*/node_modules/*' -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -60 | cut -f2"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list = text.trim() === "" ? [] : text.trim().split("\n")
                root.recentFiles = list.map(function(path) {
                    var i = path.lastIndexOf("/")
                    return { path: path, name: path.slice(i + 1), dir: path.slice(0, i).replace(/^\/home\/[^\/]+/, "~") }
                })
                var shots = root.recentFiles.filter(function(f) { return /hyprshot|screenshot|screen[ _-]?shot/i.test(f.name) })
                root.lastScreenshot = shots.length > 0 ? shots[0].path : ""
            }
        }
    }

    function fileResult(f) {
        var ext = (f.name.split(".").pop() || "").toLowerCase()
        var glyph = /^(png|jpe?g|webp|gif|svg|bmp)$/.test(ext) ? "󰋩"
                  : /^(mp4|mkv|webm|mov|avi)$/.test(ext) ? "󰕧"
                  : /^(mp3|flac|wav|ogg|m4a)$/.test(ext) ? "󰎆"
                  : /^(pdf)$/.test(ext) ? "󰈦"
                  : /^(zip|tar|gz|xz|7z|rar)$/.test(ext) ? "󰗄" : "󰈔"
        return { kind: "file", name: f.name, sub: "File · " + f.dir, icon: "", glyph: glyph,
            run: function() { Quickshell.execDetached(["xdg-open", f.path]) } }
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

    // Open an address in the default browser AND go to the browser window. Without the
    // second part a tab opens in a Chrome that may be sitting on another workspace and it
    // looks like nothing happened.
    property string browserEntry: ""

    function open(url) {
        Quickshell.execDetached(["xdg-open", url])
        focusFast.restart()      // the tab usually opens within ~0.5s...
        focusSlow.restart()      // ...a cold-started browser needs longer to create its window
    }

    Timer { id: focusFast; interval: 450;  onTriggered: NotificationState.focusSource("", root.browserEntry) }
    Timer { id: focusSlow; interval: 1700; onTriggered: NotificationState.focusSource("", root.browserEntry) }

    Process {
        command: ["xdg-settings", "get", "default-web-browser"]
        running: true
        stdout: SplitParser { onRead: data => root.browserEntry = data.trim().replace(/\.desktop$/, "") }
    }

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
        // Apps that can have many windows (browsers, terminals, file managers): the app card opens a NEW
        // window, and a second card right after it takes you to the one that is already open.
        appHits.forEach(function(app) {
            out.push(root.appResult(app))
            var open = root.isMultiWindow(app) ? root.openWindowsOf(app) : []
            if (open.length > 0) out.push(root.goToResult(app, open))
        })

        // 3. open windows
        var wins = root.windows.filter(function(w) {
            return root.matches(w.title, q) || root.matches(w.class, q)
        }).slice(0, 6)
        out = out.concat(wins.map(function(w) {
            return { kind: "window", name: w.title, sub: "Window · " + w.class + " · workspace " + w.workspace.id, icon: root.iconFor(w.class), iconSource: Icons.source([w.class, w.class.toLowerCase(), w.initialClass]), glyph: "󰣆",
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

        // quick actions
        var quick = [
            { keys: ["last screenshot", "screenshot", "latest screenshot", "open screenshot"], when: root.lastScreenshot !== "",
              name: "Open last screenshot", sub: root.lastScreenshot.replace(/^.*\//, ""), glyph: "󰋩",
              run: function() { Quickshell.execDetached(["xdg-open", root.lastScreenshot]) } },
            { keys: ["last download", "latest download", "download"], when: true, name: "Open Downloads folder", sub: "~/Downloads", glyph: "󰉍",
              run: function() { Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/Downloads"]) } },
            { keys: ["screenshot area", "take screenshot", "capture"], when: true, name: "Take a screenshot", sub: "Select an area", glyph: "󰹑",
              run: function() { ControlState.screenshot() } }
        ]
        quick.forEach(function(a) {
            if (!a.when) return
            for (var i = 0; i < a.keys.length; i++)
                if (q.length >= 3 && a.keys[i].indexOf(q) === 0) {
                    out.push({ kind: "action", name: a.name, sub: a.sub, icon: "", glyph: a.glyph, run: a.run })
                    return
                }
        })

        // recent files: "recent" / "files" lists the latest, otherwise match by name
        var onlyRecent = /^(recent|recents|recent files|files)$/.test(q)
        var fileHits = root.recentFiles.filter(function(f) {
            return onlyRecent || (q.length >= 2 && root.matches(f.name, q))
        }).slice(0, onlyRecent ? 8 : 4)
        out = out.concat(fileHits.map(root.fileResult))

        // clipboard history: text you copied earlier that matches
        if (q.length >= 3) {
            var clips = ClipboardState.entries.filter(function(e) {
                return e.preview.toLowerCase().indexOf(q) !== -1
            }).slice(0, 3)
            out = out.concat(clips.map(function(c) {
                return { kind: "clip", name: c.preview.length > 60 ? c.preview.slice(0, 60) + "…" : c.preview,
                    sub: "Clipboard · Enter to copy again", icon: "", glyph: "󰅌",
                    run: function() { ClipboardState.copy(c.id) } }
            }))
        }

        // 5. always last: search the web
        out.push({ kind: "web", name: "Google “" + raw + "”", sub: "Search the web", icon: "", glyph: "󰖟",
            run: function() { root.open("https://www.google.com/search?q=" + encodeURIComponent(raw)) } })

        return out
    }

    function isMultiWindow(app) {
        var cats = app.categories || []
        return cats.indexOf("WebBrowser") !== -1 || cats.indexOf("TerminalEmulator") !== -1 || cats.indexOf("FileManager") !== -1
    }

    // the app's windows that are open right now, most recently used first
    function openWindowsOf(app) {
        var keys = NotificationState.keysFor(app.name, app.id, true)
        return root.windows.filter(function(w) {
            if (!w.mapped) return false
            var cls = (w["class"] || "").toLowerCase()
            for (var i = 0; i < keys.length; i++)
                if (cls === keys[i] || (w.initialClass || "").toLowerCase() === keys[i]) return true
            return false
        }).sort(function(a, b) { return a.focusHistoryID - b.focusHistoryID })
    }

    function goToResult(app, open) {
        var w = open[0]
        return { kind: "window", name: app.name, icon: app.icon, iconSource: Icons.forApp(app), glyph: "󰣆",
            sub: "Go to the open window · workspace " + w.workspace.id + (open.length > 1 ? " · " + open.length + " windows" : ""),
            run: function() {
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + w.address + "' })"])
            } }
    }

    function appResult(app) {
        return { kind: "app", name: app.name, sub: "", icon: app.icon, iconSource: Icons.forApp(app), glyph: "",
            run: function() {
                if (root.isMultiWindow(app)) app.execute()            // browsers etc: this card means "a new window"
                else NotificationState.focusOrLaunch(app)             // single-window apps: already open? go to it
                AppLauncherState.recordLaunch(app.id)
            } }
    }
}
