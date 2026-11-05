pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "../workspaces"

// ─────────────────────────────────────────────────────────────────────────────
//  NotificationState — the notch's notification daemon (replaces swaync).
//
//  Implements org.freedesktop.Notifications through Quickshell. Incoming
//  notifications become a banner inside the notch (queued, auto-expiring,
//  paused while hovered) and are also written to a persisted history that the
//  control center shows. Do Not Disturb keeps recording history but only lets
//  critical notifications through as banners.
//
//    notify-send "Title" "Body"                 -> banner
//    qs ipc call notifications dnd toggle|on|off
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property bool dnd: false
    property int unread: 0

    // banner
    property var banner: null            // live Notification being shown
    property bool hovering: false        // pointer is on the banner (pauses expiry)
    property int bannerDuration: 5000
    property real bannerRemaining: 0     // ms left; the time bar draws exactly this, and 0 closes the banner
    property int pausedMs: 0             // how long the pointer has held the banner (capped, see tickTimer)
    property var queue: []               // live Notifications waiting for the banner

    readonly property alias history: historyModel

    readonly property int defaultTimeout: 5000
    readonly property int maxHistory: 100
    readonly property string stateFile: "/home/viraj/.cache/quickshell/notifications.json"

    ListModel { id: historyModel }       // nid, app, summary, body, icon, entry, time, urgency

    // ── server ───────────────────────────────────────────────────────────────
    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: function(n) {
            n.tracked = true
            root.received(n)
        }
    }

    function received(n) {
        // the app (or we) closed it: drop it from the queue / banner
        n.closed.connect(function() {
            root.queue = root.queue.filter(function(q) { return q !== n })
            if (root.banner === n) {
                root.hovering = false
                root.banner = null
                nextTimer.restart()
            }
        })

        historyModel.insert(0, {
            nid: Date.now() + "-" + n.id,
            app: n.appName,
            summary: n.summary,
            body: n.body,
            icon: n.appIcon,
            entry: n.desktopEntry || "",
            time: Date.now(),
            urgency: n.urgency
        })
        while (historyModel.count > root.maxHistory)
            historyModel.remove(historyModel.count - 1)
        root.unread++
        root.save()
        root.noteWorkspace(n.appName, n.desktopEntry)   // red dot on the workspace it came from

        var critical = n.urgency === NotificationUrgency.Critical
        if (root.dnd && !critical) return

        if (root.banner === n) {          // the app updated the notification we're showing
            root.armTimer()
            return
        }
        root.queue = root.queue.concat([n])
        if (root.banner === null) root.nextBanner()
    }

    // ── banner lifecycle ─────────────────────────────────────────────────────
    function nextBanner() {
        if (root.queue.length > 0) {
            var n = root.queue[0]
            root.queue = root.queue.slice(1)
            root.banner = n
            root.armTimer()
            return
        }
        root.banner = null
    }

    function armTimer() {
        var n = root.banner
        if (n === null) return
        if (n.urgency === NotificationUrgency.Critical) {
            root.bannerDuration = 0              // critical stays until dealt with
            root.bannerRemaining = 0
            return
        }
        var secs = n.expireTimeout
        // the daemon reports an app's requested timeout in milliseconds (notify-send -t 3000 -> 3000), but the old code
        // multiplied it by 1000 again: 3000 ms became 50 minutes. That is why some banners never left.
        // (Anything under 100 is taken as seconds.) Capped so no app can park a banner for long.
        var ms = secs >= 100 ? secs : secs * 1000
        root.bannerDuration = secs > 0 ? Math.min(Math.round(ms), 15000) : root.defaultTimeout
        root.bannerRemaining = root.bannerDuration
        root.pausedMs = 0
    }

    function closeBanner(userDismissed) {
        var n = root.banner
        if (n === null) return
        root.hovering = false
        root.banner = null
        if (userDismissed) n.dismiss()
        else n.expire()
        nextTimer.restart()      // short gap so the island can collapse/re-open between banners
    }

    // Click on the banner: run the app's own default action (if it has one) and take
    // you to the window the notification came from - even on another workspace.
    // Screenshots (hyprshot) and recordings (Capture page) say where the file is: icon = the image itself,
    // or "<i>/path/file</i>" in the body. Clicking such a notification reveals that file in the file manager.
    function capturePath(app, body, icon) {
        if (!/^(hyprshot|capture)$/i.test(app || "")) return ""
        if (icon && icon.charAt(0) === "/" && /\.(png|jpe?g|webp|gif|mp4|mkv|webm)$/i.test(icon)) return icon
        var m = (body || "").match(/<i>([^<]+)<\/i>/)
        return m ? m[1] : ""
    }

    function reveal(path) {
        Quickshell.execDetached([Quickshell.shellDir + "/extras/reveal-file", path])
    }

    function activate() {
        var n = root.banner
        if (n === null) return
        var app = n.appName, entry = n.desktopEntry
        var file = root.capturePath(app, n.body, n.appIcon)
        if (file !== "") { closeBanner(true); root.reveal(file); return }
        for (var i = 0; i < n.actions.length; i++)
            if (n.actions[i].identifier === "default") n.actions[i].invoke()
        closeBanner(true)
        root.focusSource(app, entry)
    }

    // ── jump to the window a notification came from ──────────────────────────
    property string pendingApp: ""
    property string pendingEntry: ""

    function focusSource(app, entry) {
        root.pendingApp = app || ""
        root.pendingEntry = entry || ""
        root.pendingLaunch = null
        clientsProcess.running = false
        clientsProcess.running = true
    }

    // Launcher: if the app already has a window, go to it (switching workspace); otherwise start it.
    // Terminal emulators are the exception - opening one again is meant to give a new window.
    property var pendingLaunch: null
    property string pendingClass: ""

    function focusOrLaunch(entry) {
        var cats = entry.categories || []
        if (cats.indexOf("TerminalEmulator") !== -1) { entry.execute(); return }
        root.pendingApp = entry.name || ""
        root.pendingEntry = entry.id || ""
        root.pendingClass = entry.startupClass || ""
        root.pendingLaunch = entry
        clientsProcess.running = false
        clientsProcess.running = true
    }

    // all the ways an app might name itself: desktop entry, app name, "google-chrome" for "Google Chrome"...
    function keysFor(app, entry) {
        var keys = []
        function add(s) {
            s = (s || "").toLowerCase().replace(/\.desktop$/, "").trim()
            if (s.length < 2) return
            [s, s.replace(/\s+/g, "-"), s.split(/[\s.]/)[0]].forEach(function(k) {
                if (k.length >= 2 && keys.indexOf(k) === -1) keys.push(k)
            })
        }
        add(entry)
        add(app)
        add(root.pendingClass)
        return keys
    }

    function bestWindow(clients, keys, classOnly) {
        var best = null, bestScore = 0
        for (var i = 0; i < clients.length; i++) {
            var c = clients[i]
            if (!c.mapped) continue
            var cls = (c["class"] || "").toLowerCase()
            var icls = (c.initialClass || "").toLowerCase()
            var title = (c.title || "").toLowerCase()
            var score = 0
            for (var j = 0; j < keys.length; j++) {
                var k = keys[j]
                if (cls === k || icls === k) score = Math.max(score, 100)
                else if (cls.length && (cls.endsWith("." + k) || cls.indexOf(k) !== -1)) score = Math.max(score, 60)
                else if (icls.indexOf(k) !== -1) score = Math.max(score, 55)
                else if (!classOnly && k.length >= 3 && title.indexOf(k) !== -1) score = Math.max(score, 30)
            }
            if (score === 0) continue
            // prefer the window you used most recently
            score += 10 - Math.min(10, c.focusHistoryID >= 0 ? c.focusHistoryID : 10)
            if (score > bestScore) { bestScore = score; best = c }
        }
        return best
    }

    Process {
        id: clientsProcess
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var launching = root.pendingLaunch
                    var win = root.bestWindow(JSON.parse(text), root.keysFor(root.pendingApp, root.pendingEntry), launching !== null)
                    root.pendingLaunch = null
                    root.pendingClass = ""
                    if (!win && launching) launching.execute()
                    if (win) {
                        // hl.dsp.focus switches to the window's workspace (with the workspace animation)
                        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + win.address + "' })"])
                    }
                } catch (e) {
                    console.log("focusSource failed:", e)
                    if (root.pendingLaunch) { root.pendingLaunch.execute(); root.pendingLaunch = null }
                }
            }
        }
    }

    // ── which workspace did it come from? (drives the red workspace dots) ─────
    property var markQueue: []

    function noteWorkspace(app, entry) {
        root.markQueue = root.markQueue.concat([{ app: app || "", entry: entry || "" }])
        if (!markProcess.running) markProcess.running = true
    }

    Process {
        id: markProcess
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var job = root.markQueue[0]
                root.markQueue = root.markQueue.slice(1)
                try {
                    if (job) {
                        var win = root.bestWindow(JSON.parse(text), root.keysFor(job.app, job.entry))
                        if (win) WorkspaceState.markAlert(win.workspace.id)
                    }
                } catch (e) {}
            }
        }
        onExited: if (root.markQueue.length > 0) markProcess.running = true
    }

    function invokeAction(action) {
        action.invoke()
        closeBanner(true)
    }

    // One clock does both jobs: it counts the banner down (the time bar draws bannerRemaining) and closes it at 0.
    // Holding the pointer on the banner pauses it (after the first 1.5 s), but for at most 2.5 s in total, so a pointer
    // that just happens to be resting where a banner appears can never keep it there.
    Timer {
        id: tickTimer
        interval: 50
        repeat: true
        running: root.banner !== null && root.bannerDuration > 0
        onTriggered: {
            // (hover is ignored for the first 1.5 s: the island growing under a resting pointer makes a fake "move")
            var settled = root.bannerDuration - root.bannerRemaining > 1500
            if (root.hovering && settled && root.pausedMs < 2500) { root.pausedMs += 50; return }
            root.bannerRemaining -= 50
            if (root.bannerRemaining <= 0) root.closeBanner(false)
        }
    }

    Timer {
        id: nextTimer
        interval: 350
        onTriggered: root.nextBanner()
    }


    // ── do not disturb ───────────────────────────────────────────────────────
    function setDnd(on) {
        root.dnd = on
        if (on) {
            root.queue = []
            if (root.banner !== null) root.closeBanner(false)
        }
        root.save()
    }

    function toggleDnd() { setDnd(!root.dnd) }

    // ── history ──────────────────────────────────────────────────────────────
    function removeFromHistory(index) {
        if (index >= 0 && index < historyModel.count) {
            historyModel.remove(index)
            root.save()
        }
    }

    function clearHistory() {
        WorkspaceState.clearAlerts()
        historyModel.clear()
        root.unread = 0
        root.save()
    }

    function markRead() { root.unread = 0 }

    function ago(ms) {
        var s = Math.max(0, Math.round((Date.now() - ms) / 1000))
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + "m"
        if (s < 86400) return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
    }

    // ── persistence ──────────────────────────────────────────────────────────
    function save() { saveTimer.restart() }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            var items = []
            for (var i = 0; i < historyModel.count; i++) {
                var e = historyModel.get(i)
                items.push({ nid: e.nid, app: e.app, summary: e.summary, body: e.body, icon: e.icon, entry: e.entry, time: e.time, urgency: e.urgency })
            }
            saveProcess.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
                "sh", root.stateFile, JSON.stringify({ dnd: root.dnd, history: items })]
            saveProcess.running = false
            saveProcess.running = true
        }
    }

    Process { id: saveProcess }

    FileView {
        id: stateView
        path: root.stateFile
        blockLoading: true

        Component.onCompleted: {
            try {
                var data = JSON.parse(text())
                root.dnd = !!data.dnd
                var items = data.history || []
                for (var i = 0; i < items.length; i++) {
                    items[i].entry = items[i].entry || ""      // history saved before `entry` existed
                    historyModel.append(items[i])
                }
            } catch (e) {
                // first run / empty file
            }
        }
    }

    IpcHandler {
        target: "notifications"

        function dnd(state: string): void {
            if (state === "on") root.setDnd(true)
            else if (state === "off") root.setDnd(false)
            else root.toggleDnd()
        }

        function dismiss(): void { root.closeBanner(true) }

        // same as clicking the banner (handy for testing / binds)
        function open(): void { root.activate() }

        function clear(): void { root.clearHistory() }
    }
}
