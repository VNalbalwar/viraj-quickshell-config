import QtQuick
import "../theme"

// Tiny always-visible indicator in the collapsed notch: one dot per existing workspace, the current one
// stretched into a pill. A workspace with a pending notification turns red (always the same red).
// With more than 5 workspaces it shows a sliding window of 5 around the current one; the dots at a cut-off
// edge are smaller (more are hidden that way) and turn red if a hidden workspace is waiting for you.
Row {
    id: dots

    property bool shown: true

    readonly property int maxDots: 5
    readonly property int total: WorkspaceState.list.length
    readonly property int count: total

    // the workspaces to draw: [{ ws, edge: "" | "start" | "end", hiddenAlert }]
    readonly property var items: {
        var list = WorkspaceState.list
        var n = list.length
        if (n <= maxDots) return list.map(function(w) { return { ws: w, edge: "", hiddenAlert: false } })
        var cur = 0
        for (var i = 0; i < n; i++) if (list[i].id === WorkspaceState.focusedId) cur = i
        var start = Math.max(0, Math.min(cur - 2, n - maxDots))
        var out = []
        for (var j = start; j < start + maxDots; j++) {
            var edge = (j === start && start > 0) ? "start" : (j === start + maxDots - 1 && start + maxDots < n) ? "end" : ""
            var hidden = false
            if (edge === "start") for (var a = 0; a < start; a++) if (WorkspaceState.alerted(list[a])) hidden = true
            if (edge === "end") for (var b = start + maxDots; b < n; b++) if (WorkspaceState.alerted(list[b])) hidden = true
            out.push({ ws: list[j], edge: edge, hiddenAlert: hidden })
        }
        return out
    }

    spacing: 4
    opacity: (shown && count > 1) ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 220 } }

    Repeater {
        model: dots.items

        delegate: Rectangle {
            required property var modelData
            readonly property bool current: modelData.ws.id === WorkspaceState.focusedId
            readonly property bool alerted: (!current && WorkspaceState.alerted(modelData.ws)) || modelData.hiddenAlert
            readonly property bool edge: modelData.edge !== ""

            width: current ? 16 : (edge ? 4 : 6)
            height: edge ? 4 : 6
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: alerted ? "#ff6b6b" : (current ? Colors.fg : Colors.alpha(Colors.colFg, edge ? 0.2 : 0.3))

            Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            Behavior on height { NumberAnimation { duration: 240 } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
}
