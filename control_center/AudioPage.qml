import Quickshell.Services.Pipewire
import QtQuick
import "../theme"

// Pick the default output (speakers / headphones / HDMI) and input (mic).
Page {
    id: page
    name: "audio"

    // real hardware/bluetooth devices only (no per-app streams), outputs first
    readonly property var devices: {
        var list = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.isStream || !n.audio) continue
            list.push(n)
        }
        list.sort(function(a, b) {
            if (a.isSink !== b.isSink) return a.isSink ? -1 : 1
            return (a.description || a.name).localeCompare(b.description || b.name)
        })
        return list
    }

    count: devices.length

    // needed so each node's `audio` (volume / mute) properties are populated
    PwObjectTracker { objects: page.devices }

    function iconFor(node) {
        var d = (node.description || node.name || "").toLowerCase()
        if (!node.isSink) return "󰍬"
        if (d.indexOf("hdmi") !== -1 || d.indexOf("displayport") !== -1) return "󰍹"
        if (d.indexOf("bluez") !== -1 || d.indexOf("bluetooth") !== -1 || d.indexOf("buds") !== -1 || d.indexOf("headphone") !== -1 || d.indexOf("headset") !== -1)
            return "󰋋"
        return "󰓃"
    }

    function isDefault(node) {
        return node === Pipewire.defaultAudioSink || node === Pipewire.defaultAudioSource
    }

    function choose(node) {
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }

    onActivateRequested: if (listIndex < devices.length) choose(devices[listIndex])

    AnimatedList {
        id: list
        anchors { fill: parent; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: Ui.bodyTop; bottomMargin: Ui.bottomMargin }
        pick: page.listIndex
        model: page.devices

        delegate: ListRow {
            required property var modelData
            required property int index

            width: list.width
            icon: page.iconFor(modelData)
            title: (modelData.description || modelData.nickname || modelData.name).replace(/^\d+ Series Chipset Family HD Audio\s*/, "")
            subtitle: modelData.isSink ? "Output" : "Input"
            tag: modelData.audio ? (modelData.audio.muted ? "Muted" : Math.round(modelData.audio.volume * 100) + "%") : ""
            on: page.isDefault(modelData)
            picked: index === page.listIndex

            onEntered: page.listIndex = index
            onClicked: page.choose(modelData)
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: "No audio devices"
            color: Colors.fg
            opacity: 0.5
            font.pixelSize: 13
        }
    }
}
