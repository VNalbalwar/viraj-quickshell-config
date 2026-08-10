pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    property bool visible: false
    property int brightness: 0

    property int volume: 0
    property bool muted: false
    property string mode: "brightness"

    property bool micMuted: false

    property int battery: 0
    property string batteryState: "unknown"
    property bool batteryInitialized: false

    property bool capsLock: false
    property bool numLock: false
    property string lockType: "caps"
    property bool lockInitialized: false

    property string audioOutputName: ""
    property string audioOutputIcon: "󰕾"
    property string audioOutputId: ""
    property bool audioOutputInitialized: false

    readonly property var batteryDevice: UPower.displayDevice

    function readBrightness() {
        brightnessProcess.running = true
    }

    function readVolume() {
        volumeProcess.running = true
    }

    function readMicMute() {
        micMuteProcess.running = true
    }

    function updateBattery() {
        var device = root.batteryDevice

        if (!device || !device.ready)
            return

        root.battery = Math.max(0, Math.min(100, Math.round(device.percentage * 100)))

        if (device.state === UPowerDeviceState.Charging ||
            device.state === UPowerDeviceState.PendingCharge) {
            root.batteryState = "charging"
        } else if (device.state === UPowerDeviceState.FullyCharged) {
            root.batteryState = "fully-charged"
        } else if (device.state === UPowerDeviceState.Discharging ||
                   device.state === UPowerDeviceState.PendingDischarge) {
            root.batteryState = "discharging"
        } else {
            root.batteryState = "unknown"
        }
    }

    function updateLocks() {
        lockProcess.running = true
    }

    function normalizeAudioOutput(id, description) {
        var lower = description.toLowerCase()

        root.audioOutputId = id

        if (lower.indexOf("hdmi") !== -1 || lower.indexOf("displayport") !== -1) {
            root.audioOutputIcon = "󰍹"
            root.audioOutputName = "HDMI / DisplayPort"
        } else if (lower.indexOf("speaker") !== -1 ||
                   lower.indexOf("built-in") !== -1 ||
                   lower.indexOf("internal") !== -1) {
            root.audioOutputIcon = "󰕾"
            root.audioOutputName = "Speakers"
        } else if (lower.indexOf("headphone") !== -1 ||
                   lower.indexOf("headset") !== -1 ||
                   lower.indexOf("buds") !== -1 ||
                   lower.indexOf("bluetooth") !== -1 ||
                   lower.indexOf("bluez") !== -1) {
            root.audioOutputIcon = "󰋋"
            root.audioOutputName = description
        } else {
            root.audioOutputIcon = "󰕾"
            root.audioOutputName = description
        }
    }

    function updateAudioOutput() {
        if (!audioOutputProcess.running)
            audioOutputProcess.running = true
    }

    function handleAudioOutput(id, description) {
        if (!id || !description)
            return

        var changed = root.audioOutputInitialized && root.audioOutputId !== id

        root.normalizeAudioOutput(id, description)

        if (!root.audioOutputInitialized) {
            root.audioOutputInitialized = true
            return
        }

        if (changed)
            root.showAudioOutput()
    }

    function showLock(type) {
        root.mode = "lock"
        root.lockType = type
        root.visible = true
        hideTimer.restart()
    }

    function showAudioOutput() {
        root.mode = "audio-output"
        root.visible = true
        hideTimer.restart()
    }

    function showVolume() {
        root.mode = "volume"
        readVolume()
        root.visible = true
        hideTimer.restart()
    }

    function showMic() {
        root.mode = "mic"
        readMicMute()
        root.visible = true
        hideTimer.restart()
    }

    function showBattery() {
        root.mode = "battery"
        updateBattery()
        root.visible = true
        hideTimer.restart()
    }

    function show() {
        readBrightness()
        root.visible = true
        hideTimer.restart()
    }

    function hide() {
        hideTimer.stop()
        root.visible = false
    }

    function showBrightness() {
        root.mode = "brightness"
        readBrightness()
        root.visible = true
        hideTimer.restart()
    }

    function toggle() {
        if (root.visible)
            hide()
        else
            show()
    }

    Component.onCompleted: {
        readBrightness()
        updateBattery()
        updateLocks()
        updateAudioOutput()
    }

    Connections {
        target: root.batteryDevice

        function onPercentageChanged() {
            root.updateBattery()

            if (root.batteryInitialized)
                root.showBattery()
        }

        function onStateChanged() {
            root.updateBattery()

            if (root.batteryInitialized)
                root.showBattery()
        }
    }

    Process {
        id: brightnessProcess

        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(",")

                if (parts.length >= 4) {
                    var value = parseInt(parts[3].replace("%", ""))

                    if (!isNaN(value))
                        root.brightness = value
                }
            }
        }
    }

    Process {
        id: volumeProcess

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: SplitParser {
            onRead: data => {
                var output = data.trim()

                var match = output.match(/Volume:\s*([0-9.]+)/)

                if (match) {
                    var value = parseFloat(match[1])

                    if (!isNaN(value))
                        root.volume = Math.round(value * 100)
                }

                root.muted = output.indexOf("[MUTED]") !== -1
            }
        }
    }

    Process {
        id: micMuteProcess

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]

        stdout: SplitParser {
            onRead: data => {
                var output = data.trim()
                root.micMuted = output.indexOf("[MUTED]") !== -1
            }
        }
    }

    Process {
        id: audioOutputProcess

        command: ["sh", "-c", "wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep '^.*\\*' | head -n1"]

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()

                if (!line)
                    return

                var starIndex = line.indexOf("*")
                var dotIndex = line.indexOf(".", starIndex)
                var volumeIndex = line.lastIndexOf(" [vol:")

                if (starIndex === -1 || dotIndex === -1 || volumeIndex === -1)
                    return

                var id = line.slice(starIndex + 1, dotIndex).trim()
                var description = line.slice(dotIndex + 1, volumeIndex).trim()

                if (id && description)
                    root.handleAudioOutput(id, description)
            }
        }
    }

    Process {
        id: lockProcess

        command: ["sh", "-c", "hyprctl devices -j | jq -c '.keyboards[] | select(.main == true) | {capsLock, numLock}'"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    var keyboard = JSON.parse(data.trim())

                    var newCaps = !!keyboard.capsLock
                    var newNum = !!keyboard.numLock

                    if (!root.lockInitialized) {
                        root.capsLock = newCaps
                        root.numLock = newNum
                        root.lockInitialized = true
                        return
                    }

                    if (newCaps !== root.capsLock) {
                        root.capsLock = newCaps
                        root.showLock("caps")
                    }

                    if (newNum !== root.numLock) {
                        root.numLock = newNum
                        root.showLock("num")
                    }
                } catch (error) {
                    console.log("Failed to parse keyboard lock state:", error)
                }
            }
        }
    }

    Timer {
        id: lockTimer
        interval: 250
        repeat: true
        running: true
        onTriggered: root.updateLocks()
    }

    Timer {
        id: audioOutputTimer
        interval: 500
        repeat: true
        running: true
        onTriggered: root.updateAudioOutput()
    }

    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: root.visible = false
    }

    IpcHandler {
        target: "osd"

        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function showBrightness(): void { root.showBrightness() }
        function hide(): void { root.hide() }
        function showVolume(): void { root.showVolume() }
        function showMic(): void { root.showMic() }
        function showBattery(): void { root.showBattery() }
        function showAudioOutput(): void {
            root.updateAudioOutput()
            root.showAudioOutput()
        }
    }
}
