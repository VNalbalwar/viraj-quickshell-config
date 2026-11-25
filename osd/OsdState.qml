pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
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

    property bool wifiEnabled: true
    property bool wifiConnected: false
    property string wifiName: ""
    property string wifiIcon: "󰤨"
    property bool wifiInitialized: false

    readonly property var batteryDevice: UPower.displayDevice
    // on mains power (charging or full): drives the little bolt next to the clock
    readonly property bool pluggedIn: !UPower.onBattery

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

    function handleLocks(newCaps, newNum) {
        if (!root.lockInitialized) { root.capsLock = newCaps; root.numLock = newNum; root.lockInitialized = true; return }
        if (newCaps !== root.capsLock) { root.capsLock = newCaps; root.showLock("caps") }
        if (newNum !== root.numLock) { root.numLock = newNum; root.showLock("num") }
    }

    function normalizeAudioOutput(id, description) {
        description = description.replace(/^\d+ Series Chipset Family HD Audio( Controller)?\s*/, "")     // "…HD Audio Headphones" -> "Headphones"
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

    // PipeWire announces a new default output itself; no need to ask `wpctl status` twice a second
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property string defaultSinkName: defaultSink && defaultSink.ready ? (defaultSink.description || defaultSink.nickname || defaultSink.name) : ""
    onDefaultSinkNameChanged: updateAudioOutput()
    function updateAudioOutput() { if (root.defaultSinkName !== "") root.handleAudioOutput(String(root.defaultSink.id), root.defaultSinkName) }
    PwObjectTracker { objects: root.defaultSink ? [root.defaultSink] : [] }
    function handleAudioOutput(id, description) {
        if (!id || !description) return
        var changed = root.audioOutputInitialized && root.audioOutputId !== id
        root.normalizeAudioOutput(id, description)
        if (!root.audioOutputInitialized) { root.audioOutputInitialized = true; return }
        if (changed) root.showAudioOutput()
    }

    function updatePerformanceProfile() { if (!performanceProcess.running) performanceProcess.running = true }   // on demand only
    function handlePerformanceProfile(profile) {
        profile = profile.trim()
        if (!profile) return
        var label = profile
        if (profile === "low-power") label = "Low Power"
        else if (profile === "quiet") label = "Quiet"
        else if (profile === "balanced") label = "Balanced"
        else if (profile === "balanced-performance") label = "Balanced Performance"
        else if (profile === "performance") label = "Performance"
        var changed = root.performanceInitialized && root.performanceProfile !== profile
        root.performanceProfile = profile
        root.performanceLabel = label
        if (!root.performanceInitialized) { root.performanceInitialized = true; return }
        if (changed) root.showPerformance()
    }

    function updateFanMode() { if (!fanProcess.running) fanProcess.running = true }
    function handleFanSpeed(data) {
        var parts = data.trim().split(",")
        if (parts.length < 2) return
        var left = parseInt(parts[0]); var right = parseInt(parts[1])
        if (isNaN(left) || isNaN(right)) return
        var newMode = "Custom"
        if (left === 0 && right === 0) newMode = "Auto"
        else if (left === 30 && right === 30) newMode = "Quiet"
        else if (left === 50 && right === 50) newMode = "Balanced"
        else if (left === 70 && right === 70) newMode = "Performance"
        else if (left === 100 && right === 100) newMode = "Turbo"
        var changed = root.fanInitialized && (root.fanSpeedLeft !== left || root.fanSpeedRight !== right)
        root.fanSpeedLeft = left; root.fanSpeedRight = right; root.fanMode = newMode
        if (!root.fanInitialized) { root.fanInitialized = true; return }
        if (changed) root.showFanMode()
    }

    property bool wifiStale: false
    signal networkChanged()                      // anything NetworkManager reports (also used by the weather chip)
    function updateWifi() { if (!wifiProcess.running) wifiProcess.running = true; else wifiStale = true }
    function handleWifi(data) {
        var parts = data.trim().split("|")
        if (parts.length < 3) return
        var enabled = parts[0].trim() === "enabled"
        var state = parts[1].trim()
        var connected = state.indexOf("100 (connected)") === 0
        var name = parts.slice(2).join("|").trim()
        if (!enabled) name = ""
        else if (!connected) name = ""

        var changed = root.wifiInitialized && (root.wifiEnabled !== enabled || root.wifiConnected !== connected || root.wifiName !== name)
        root.wifiEnabled = enabled
        root.wifiConnected = connected
        root.wifiName = name
        root.wifiIcon = !enabled ? "󰖪" : (connected ? "󰤨" : "󰤭")

        if (!root.wifiInitialized) { root.wifiInitialized = true; return }
        if (changed) root.showWifi()
    }

    function showLock(type) { root.mode = "lock"; root.lockType = type; root.visible = true; hideTimer.restart() }
    function showAudioOutput() { root.mode = "audio-output"; root.visible = true; hideTimer.restart() }
    function showPerformance() { root.mode = "performance"; root.visible = true; hideTimer.restart() }
    function showFanMode() { root.mode = "fan"; root.visible = true; hideTimer.restart() }
    function showWifi() { root.mode = "wifi"; root.visible = true; hideTimer.restart() }
    function showVolume() { root.mode = "volume"; readVolume(); root.visible = true; hideTimer.restart() }
    function showMic() { root.mode = "mic"; readMicMute(); root.visible = true; hideTimer.restart() }
    function showBattery() { root.mode = "battery"; updateBattery(); root.visible = true; hideTimer.restart() }
    function show() { readBrightness(); root.visible = true; hideTimer.restart() }
    function hide() { hideTimer.stop(); root.visible = false }
    function showBrightness() { root.mode = "brightness"; readBrightness(); root.visible = true; hideTimer.restart() }
    function toggle() { if (root.visible) hide(); else show() }

    Component.onCompleted: {
        readBrightness(); updateBattery(); updateAudioOutput(); updateWifi()
    }

    Connections {
        target: root.batteryDevice
        function onPercentageChanged() { root.updateBattery(); if (root.batteryInitialized) root.showBattery() }
        function onStateChanged() { root.updateBattery(); if (root.batteryInitialized) root.showBattery() }
    }

    Process { id: brightnessProcess; command: ["brightnessctl", "-m"]; stdout: SplitParser { onRead: data => { var parts = data.trim().split(","); if (parts.length >= 4) { var value = parseInt(parts[3].replace("%", "")); if (!isNaN(value)) root.brightness = value } } } }
    Process { id: volumeProcess; command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]; stdout: SplitParser { onRead: data => { var output = data.trim(); var match = output.match(/Volume:\s*([0-9.]+)/); if (match) { var value = parseFloat(match[1]); if (!isNaN(value)) root.volume = Math.round(value * 100) }; root.muted = output.indexOf("[MUTED]") !== -1 } } }
    Process { id: micMuteProcess; command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]; stdout: SplitParser { onRead: data => root.micMuted = data.trim().indexOf("[MUTED]") !== -1 } }
    Process { id: performanceProcess; command: ["cat", "/sys/firmware/acpi/platform_profile"]; stdout: SplitParser { onRead: data => root.handlePerformanceProfile(data) } }
    Process { id: fanProcess; command: ["cat", "/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/fan_speed"]; stdout: SplitParser { onRead: data => root.handleFanSpeed(data) } }

    Process {
        id: wifiProcess
        command: ["sh", "-c", "radio=$(nmcli -t radio wifi); dev=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2==\"wifi\"{print $1; exit}'); if [ \"$radio\" = \"enabled\" ] && [ -n \"$dev\" ]; then state=$(nmcli -t -f GENERAL.STATE dev show \"$dev\" | sed 's/^GENERAL.STATE://'); conn=$(nmcli -t -f GENERAL.CONNECTION dev show \"$dev\" | sed 's/^GENERAL.CONNECTION://'); printf 'enabled|%s|%s\\n' \"$state\" \"$conn\"; else printf '%s|0 (disconnected)|\\n' \"$radio\"; fi"]
        stdout: SplitParser { onRead: data => root.handleWifi(data) }
        onExited: if (root.wifiStale) { root.wifiStale = false; root.updateWifi() }
    }

    // Caps / Num Lock, power profile, fan: one long-running watcher that prints only changes
    Process {
        id: hwWatch
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", Quickshell.shellDir + "/osd/hw-watch.sh"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ")
                if (p[0] === "locks") root.handleLocks(p[1] === "1", p[2] === "1")
                else if (p[0] === "profile") root.handlePerformanceProfile(p[1])
                else if (p[0] === "fan") root.handleFanSpeed(p[1])
            }
        }
        onExited: hwRestart.start()
    }
    Timer { id: hwRestart; interval: 2000; onTriggered: hwWatch.running = true }

    // Wi-Fi: react to NetworkManager events (a burst of them becomes one query)
    Process {
        id: netMonitor
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "nmcli", "monitor"]
        stdout: SplitParser { onRead: data => netSettle.restart() }
        onExited: netRestart.start()
    }
    Timer { id: netRestart; interval: 5000; onTriggered: netMonitor.running = true }
    Timer { id: netSettle; interval: 350; onTriggered: { root.updateWifi(); root.networkChanged() } }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: root.updateWifi() }      // safety net

    Timer { id: hideTimer; interval: 1800; repeat: false; onTriggered: root.visible = false }

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
    }
}