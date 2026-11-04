pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
//  WorkspaceState — which Hyprland workspaces exist, which one you're on, and
//  the little popup the notch shows when you switch (or change layout).
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    // regular workspaces only (special:* ones have negative ids), in order
    readonly property var list: {
        var out = []
        var all = Hyprland.workspaces.values
        for (var i = 0; i < all.length; i++)
            if (all[i].id > 0) out.push(all[i])
        out.sort(function(a, b) { return a.id - b.id })
        return out
    }

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property string layout: "dwindle"          // layout of the focused workspace
    property bool popup: false                 // show the switch popup
    property bool ready: false

    // workspaces holding a window that sent a notification you haven't looked at yet.
    // One flag per workspace (not a count) - the dots just turn red.
    property var alerts: ({})

    function markAlert(id) {
        if (id <= 0 || id === root.focusedId || root.alerts[id]) return
        var a = Object.assign({}, root.alerts)
        a[id] = true
        root.alerts = a
    }

    function clearAlert(id) {
        if (!root.alerts[id]) return
        var a = Object.assign({}, root.alerts)
        delete a[id]
        root.alerts = a
    }

    function clearAlerts() { root.alerts = ({}) }

    // red if a notification is waiting there, or Hyprland itself says a window wants attention
    function alerted(ws) { return !!root.alerts[ws.id] || ws.urgent }                 // ignore the very first values at startup

    readonly property string layoutLabel: layout === "scrolling" ? "Scrolling" : (layout === "master" ? "Master" : "Tiled")

    function show() {
        root.popup = true
        popupTimer.restart()
    }

    function switchTo(id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"])
    }

    onFocusedIdChanged: {
        root.clearAlert(root.focusedId)         // you're looking at it now
        if (root.ready) root.show()
        layoutProcess.running = true
    }

    onLayoutChanged: if (root.ready) root.show()

    Timer {
        id: popupTimer
        interval: 1500
        onTriggered: root.popup = false
    }

    // the layout of the focused workspace (no Hyprland event fires when it changes,
    // so a cheap poll keeps it honest)
    Process {
        id: layoutProcess
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var l = JSON.parse(text).tiledLayout
                    if (l) root.layout = l
                } catch (e) {}
                root.ready = true
            }
        }
    }

    Timer {
        interval: 1200
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: layoutProcess.running = true
    }
}
