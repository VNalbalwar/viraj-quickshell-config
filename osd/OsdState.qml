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

    property string performanceProfile: ""
    property string performanceLabel: ""
    property bool performanceInitialized: false

    property int fanSpeedLeft: 0
    property int fanSpeedRight: 0
    property string fanMode: ""
    property bool fanInitialized: false

    property bool wifiConnected: false
    property string wifiName: ""
    property string wifiIcon: "󰤨"
    property bool wifiInitialized: false

    property bool bluetoothPowered: false
    property bool bluetoothConnected: false
    property string bluetoothName: ""
    property string bluetoothIcon: "󰂯"
    property bool bluetoothInitialized: false

    readonly property var batteryDevice: UPower.displayDevice

    function readBrightness() { brightnessProcess.running = true }
    function readVolume() { volumeProcess.running = true }
    function readMicMute() { micMuteProcess.running = true }

    function updateBattery() {
        var device = root.batteryDevice
        if (!device || !device.ready)
            return

        root.battery = Math.max(0, Math.min(100, Math.round(device.percentage * 100)))

        if (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
            root.batteryState = "charging"
        else if (device.state === UPowerDeviceState.FullyCharged)
            root.batteryState = "fully-charged"
        else if (device.state === UPowerDeviceState.Discharging || device.state === UPowerDeviceState.PendingDischarge)
            root.batteryState = "discharging"
        else
            root.batteryState = "unknown"
    }

    function updateLocks() { lockProcess.running = true }

    function normalizeAudioOutput(id, description) {
        var lower = description.toLowerCase()
        root.audioOutputId = id

        if (lower.indexOf("hdmi") !== -1 || lower.indexOf("displayport") !== -1) {
            root.audioOutputIcon = "󰍹"
            root.audioOutputName = "HDMI / DisplayPort"
        } else if (lower.indexOf("speaker") !== -1 || lower.indexOf("built-in") !== -1 || lower.indexOf("internal") !== -1) {
            root.audioOutputIcon = "󰕾"
            root.audioOutputName = "Speakers"
        } else if (lower.indexOf("headphone") !== -1 || lower.indexOf("headset") !== -1 || lower.indexOf("buds") !== -1 || lower.indexOf("bluetooth") !== -1 || lower.indexOf("bluez") !== -1) {
            root.audioOutputIcon = "󰋋"
            root.audioOutputName = description
        } else {
            root.audioOutputIcon = "󰕾"
            root.audioOutputName = description
        }
    }

    function updateAudioOutput() { if (!audioOutputProcess.running) audioOutputProcess.running = true }

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

    function updatePerformanceProfile() { if (!performanceProcess.running) performanceProcess.running = true }

    function handlePerformanceProfile(profile) {
        profile = profile.trim()
        if (!profile)
            return

        var label = profile
        if (profile === "low-power") label = "Low Power"
        else if (profile === "quiet") label = "Quiet"
        else if (profile === "balanced") label = "Balanced"
        else if (profile === "balanced-performance") label = "Balanced Performance"
        else if (profile === "performance") label = "Performance"

        var changed = root.performanceInitialized && root.performanceProfile !== profile
        root.performanceProfile = profile
        root.performanceLabel = label

        if (!root.performanceInitialized) {
            root.performanceInitialized = true
            return
        }

        if (changed)
            root.showPerformance()
    }

    function updateFanMode() { if (!fanProcess.running) fanProcess.running = true }

    function handleFanSpeed(data) {
        var parts = data.trim().split(",")
        if (parts.length < 2)
            return

        var left = parseInt(parts[0])
        var right = parseInt(parts[1])
        if (isNaN(left) || isNaN(right))
            return

        var newMode = "Custom"
        if (left === 0 && right === 0) newMode = "Auto"
        else if (left === 30 && right === 30) newMode = "Quiet"
        else if (left === 50 && right === 50) newMode = "Balanced"
        else if (left === 70 && right === 70) newMode = "Performance"
        else if (left === 100 && right === 100) newMode = "Turbo"

        var changed = root.fanInitialized && (root.fanSpeedLeft !== left || root.fanSpeedRight !== right)
        root.fanSpeedLeft = left
        root.fanSpeedRight = right
        root.fanMode = newMode

        if (!root.fanInitialized) {
            root.fanInitialized = true
            return
        }

        if (changed)
            root.showFanMode()
    }

    function updateWifi() { if (!wifiProcess.running) wifiProcess.running = true }

    function handleWifi(data) {
        var parts = data.trim().split("|")
        if (parts.length < 2)
            return

        var connected = parts[0] === "100 (connected)"
        var name = parts.slice(1).join("|").trim()
        if (!connected)
            name = ""

        var changed = root.wifiInitialized && (root.wifiConnected !== connected || root.wifiName !== name)
        root.wifiConnected = connected
        root.wifiName = name
        root.wifiIcon = connected ? "󰤨" : "󰤭"

        if (!root.wifiInitialized) {
            root.wifiInitialized = true
            return
        }

        if (changed)
            root.showWifi()
    }

    function updateBluetooth() { if (!bluetoothProcess.running) bluetoothProcess.running = true }

    function handleBluetooth(data) {
        var parts = data.trim().split("|")
        if (parts.length < 3)
            return

        var powered = parts[0] === "yes"
        var connected = parts[1] === "yes"
        var name = parts.slice(2).join("|").trim()

        var changed = root.bluetoothInitialized && (root.bluetoothPowered !== powered || root.bluetoothConnected !== connected || root.bluetoothName !== name)
        root.bluetoothPowered = powered
        root.bluetoothConnected = connected
        root.bluetoothName = name
        root.bluetoothIcon = connected ? "󰂯" : (powered ? "󰂯" : "󰂲")

        if (!root.bluetoothInitialized) {
            root.bluetoothInitialized = true
            return
        }

        if (changed)
            root.showBluetooth()
    }

    function showLock(type) { root.mode = "lock"; root.lockType = type; root.visible = true; hideTimer.restart() }
    function showAudioOutput() { root.mode = "audio-output"; root.visible = true; hideTimer.restart() }
    function showPerformance() { root.mode = "performance"; root.visible = true; hideTimer.restart() }
    function showFanMode() { root.mode = "fan"; root.visible = true; hideTimer.restart() }
    function showWifi() { root.mode = "wifi"; root.visible = true; hideTimer.restart() }
    function showBluetooth() { root.mode = "bluetooth"; root.visible = true; hideTimer.restart() }
    function showVolume() { root.mode = "volume"; readVolume(); root.visible = true; hideTimer.restart() }
    function showMic() { root.mode = "mic"; readMicMute(); root.visible = true; hideTimer.restart() }
    function showBattery() { root.mode = "battery"; updateBattery(); root.visible = true; hideTimer.restart() }
    function show() { readBrightness(); root.visible = true; hideTimer.restart() }
    function hide() { hideTimer.stop(); root.visible = false }
    function showBrightness() { root.mode = "brightness"; readBrightness(); root.visible = true; hideTimer.restart() }
    function toggle() { if (root.visible) hide(); else show() }

    Component.onCompleted: {
        readBrightness()
        updateBattery()
        updateLocks()
        updateAudioOutput()
        updatePerformanceProfile()
        updateFanMode()
        updateWifi()
        updateBluetooth()
    }

    Connections {
        target: root.batteryDevice
        function onPercentageChanged() { root.updateBattery(); if (root.batteryInitialized) root.showBattery() }
        function onStateChanged() { root.updateBattery(); if (root.batteryInitialized) root.showBattery() }
    }

    Process {
        id: brightnessProcess
        command: ["brightnessctl", "-m"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(",")
                if (parts.length >= 4) {
                    var value = parseInt(parts[3].replace("%", ""))
                    if (!isNaN(value)) root.brightness = value
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
                    if (!isNaN(value)) root.volume = Math.round(value * 100)
                }
                root.muted = output.indexOf("[MUTED]") !== -1
            }
        }
    }

    Process {
        id: micMuteProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: SplitParser { onRead: data => root.micMuted = data.trim().indexOf("[MUTED]") !== -1 }
    }

    Process {
        id: audioOutputProcess
        command: ["sh", "-c", "wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep '^.*\\*' | head -n1"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                var marker = line.indexOf(".")
                var star = line.indexOf("*")
                var vol = line.indexOf("[vol:")
                if (star === -1 || marker === -1 || vol === -1) return
                root.handleAudioOutput(line.substring(star + 1, marker).trim(), line.substring(marker + 1, vol).trim())
            }
        }
    }

    Process {
        id: performanceProcess
        command: ["cat", "/sys/firmware/acpi/platform_profile"]
        stdout: SplitParser { onRead: data => root.handlePerformanceProfile(data) }
    }

    Process {
        id: fanProcess
        command: ["cat", "/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/fan_speed"]
        stdout: SplitParser { onRead: data => root.handleFanSpeed(data) }
    }

    Process {
        id: wifiProcess
        command: ["sh", "-c", "dev=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2==\"wifi\"{print $1; exit}'); if [ -n \"$dev\" ]; then nmcli -t -f GENERAL.STATE,GENERAL.CONNECTION dev show \"$dev\" | paste -sd '|' -; else printf '0 (disconnected)|\\n'; fi"]
        stdout: SplitParser { onRead: data => root.handleWifi(data) }
    }

    Process {
        id: bluetoothProcess
        command: ["sh", "-c", "powered=$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/{print $2; exit}'); line=$(bluetoothctl devices Connected 2>/dev/null | head -n1); if [ -n \"$line\" ]; then name=${line#* * }; printf '%s|yes|%s\\n' \"$powered\" \"$name\"; else printf '%s|no|\\n' \"$powered\"; fi"]
        stdout: SplitParser { onRead: data => root.handleBluetooth(data) }
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

    Timer { id: lockTimer; interval: 250; repeat: true; running: true; onTriggered: root.updateLocks() }
    Timer { id: audioOutputTimer; interval: 500; repeat: true; running: true; onTriggered: root.updateAudioOutput() }
    Timer { id: performanceTimer; interval: 500; repeat: true; running: true; onTriggered: root.updatePerformanceProfile() }
    Timer { id: fanTimer; interval: 500; repeat: true; running: true; onTriggered: root.updateFanMode() }
    Timer { id: wifiTimer; interval: 1000; repeat: true; running: true; onTriggered: root.updateWifi() }
    Timer { id: bluetoothTimer; interval: 1000; repeat: true; running: true; onTriggered: root.updateBluetooth() }

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
        function showAudioOutput(): void { root.updateAudioOutput(); root.showAudioOutput() }
        function showPerformance(): void { root.updatePerformanceProfile(); root.showPerformance() }
        function showFanMode(): void { root.updateFanMode(); root.showFanMode() }
        function showWifi(): void { root.updateWifi(); root.showWifi() }
        function showBluetooth(): void { root.updateBluetooth(); root.showBluetooth() }
    }
}
