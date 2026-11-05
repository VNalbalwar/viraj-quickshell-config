import Quickshell.Services.Pipewire
import QtQuick
import "../theme"

// Pick the default output (speakers / headphones / HDMI) and input (mic).
Page {
    id: page
    name: "audio"

    // one row per app that is playing sound (its own volume) first, then the devices (outputs, then inputs)
    readonly property var devices: {
        var list = []
        var apps = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (!n.audio) continue
            if (n.isStream) {                                              // app streams: playback only (not recorders)
                if ((n.properties || {})["media.class"] === "Stream/Output/Audio") apps.push(n)
                continue
            }
            list.push(n)
        }
        list.sort(function(a, b) {
            if (a.isSink !== b.isSink) return a.isSink ? -1 : 1
            return (a.description || a.name).localeCompare(b.description || b.name)
        })
        apps.sort(function(a, b) { return page.appName(a).localeCompare(page.appName(b)) })
        return apps.concat(list)
    }

    function appName(node) {
        var props = node.properties || {}
        return props["application.name"] || node.description || node.nickname || node.name
    }

    count: devices.length

    // the list's model is just the ordered node ids (diff-synced), so a stream appearing / leaving animates
    // only that row instead of rebuilding the whole list
    ListModel { id: rows }
    function nodeFor(id) {
        for (var i = 0; i < devices.length; i++) if (devices[i].id === id) return devices[i]
        return null
    }
    onDevicesChanged: ControlState.syncModel(rows, "nodeId", devices.map(function(n) { return { nodeId: n.id } }))
    Component.onCompleted: ControlState.syncModel(rows, "nodeId", devices.map(function(n) { return { nodeId: n.id } }))

    // needed so each node's `audio` (volume / mute) and `properties` are populated - including app streams,
    // which have to be tracked BEFORE we can tell whether they are playback streams
    readonly property var streamNodes: Pipewire.nodes.values.filter(function(n) { return n.isStream })
    PwObjectTracker { objects: page.streamNodes }
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
        if (node.isStream) { node.audio.muted = !node.audio.muted; return }      // an app row: mute / unmute that app
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }

    onActivateRequested: if (listIndex < devices.length) choose(devices[listIndex])

    AnimatedList {
        id: list
        anchors { fill: parent; leftMargin: Ui.sideMargin; rightMargin: Ui.sideMargin; topMargin: Ui.bodyTop; bottomMargin: Ui.bottomMargin }
        pick: page.listIndex
        model: rows

        delegate: ListRow {
            required property int nodeId
            required property int index
            readonly property var modelData: page.nodeFor(nodeId)
            visible: modelData !== null

            width: list.width
            icon: modelData.isStream ? "󰝚" : page.iconFor(modelData)
            title: modelData.isStream ? page.appName(modelData)
                : (modelData.description || modelData.nickname || modelData.name).replace(/^\d+ Series Chipset Family HD Audio\s*/, "")
            subtitle: modelData.isStream ? "App volume · scroll to change, click to mute" : (modelData.isSink ? "Output" : "Input")
            tag: modelData.audio ? (modelData.audio.muted ? "Muted" : Math.round(modelData.audio.volume * 100) + "%") : ""
            on: modelData.isStream ? (modelData.audio && !modelData.audio.muted) : page.isDefault(modelData)
            picked: index === page.listIndex

            onEntered: page.listIndex = index
            onClicked: page.choose(modelData)

            // scroll over an app row: its own volume, 5% a notch
            WheelHandler {
                enabled: modelData.isStream
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                    var step = event.angleDelta.y > 0 ? 0.05 : -0.05
                    modelData.audio.volume = Math.max(0, Math.min(1.5, modelData.audio.volume + step))
                }
            }
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
