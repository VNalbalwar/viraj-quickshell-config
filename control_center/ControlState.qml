pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick
import "../osd"
import "../wallpaper_switcher"

// ─────────────────────────────────────────────────────────────────────────────
//  ControlState — the notch control center's state + the actions its tiles fire.
//
//  Brightness / volume / mic / battery / wifi status are shared with OsdState
//  (it already tracks them), so the OSD and the control center never disagree.
//  Everything else (DND, airplane, power profile, wifi scan) lives here.
//
//    qs ipc call control toggle | show | hide
//    qs ipc call control page wifi | bluetooth | main
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property bool visible: false
    property string page: "main"          // main | wifi | bluetooth
    property bool adjusting: false        // a slider is being dragged

    property bool dnd: false
    property bool airplane: false
    property string powerProfile: "balanced"
    property var wifiNetworks: []
    property bool wifiScanning: false

    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: bluetoothAdapter ? bluetoothAdapter.enabled : false

    readonly property var profiles: ["power-saver", "balanced", "performance"]
    readonly property string profileLabel:
        powerProfile === "power-saver" ? "Saver"
        : powerProfile === "performance" ? "Performance"
        : "Balanced"

    // ── visibility ───────────────────────────────────────────────────────────
    function show() {
        root.page = "main"
        root.refresh()
        root.visible = true
    }

    function hide() {
        root.visible = false
        root.setBluetoothScan(false)
    }

    function toggle() {
        if (root.visible) hide()
        else show()
    }

    function showPage(name) {
        if (!root.visible) show()
        root.openPage(name)
    }

    function openPage(name) {
        root.page = name
        root.setBluetoothScan(name === "bluetooth")
        if (name === "wifi") root.scanWifi()
    }

    function back() {
        if (root.page === "main") hide()
        else root.openPage("main")
    }

    function refresh() {
        OsdState.readBrightness()
        OsdState.readVolume()
        OsdState.readMicMute()
        OsdState.updateWifi()
        OsdState.updateBattery()
        dndReadProcess.running = true
        airplaneReadProcess.running = true
        profileReadProcess.running = true
    }

    // ── sliders (written throttled so dragging stays smooth) ─────────────────
    property int pendingBrightness: -1
    property int pendingVolume: -1

    function setBrightness(percent) {
        percent = Math.max(1, Math.min(100, Math.round(percent)))
        OsdState.brightness = percent
        root.pendingBrightness = percent
        if (!brightnessTimer.running) brightnessTimer.start()
    }

    function setVolume(percent) {
        percent = Math.max(0, Math.min(100, Math.round(percent)))
        OsdState.volume = percent
        root.pendingVolume = percent
        if (!volumeTimer.running) volumeTimer.start()
    }

    Timer {
        id: brightnessTimer
        interval: 45
        onTriggered: {
            brightnessProcess.command = ["brightnessctl", "-q", "set", root.pendingBrightness + "%"]
            brightnessProcess.running = false
            brightnessProcess.running = true
        }
    }

    Timer {
        id: volumeTimer
        interval: 45
        onTriggered: {
            volumeProcess.command = ["sh", "-c",
                "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ "
                + (root.pendingVolume / 100).toFixed(2)]
            volumeProcess.running = false
            volumeProcess.running = true
        }
    }

    Process { id: brightnessProcess }
    Process {
        id: volumeProcess
        onExited: OsdState.readVolume()
    }

    // ── toggles ──────────────────────────────────────────────────────────────
    function runAction(command, after) {
        actionProcess.afterExit = after || function() {}
        actionProcess.command = command
        actionProcess.running = false
        actionProcess.running = true
    }

    Process {
        id: actionProcess
        property var afterExit: function() {}
        onExited: afterExit()
    }

    function toggleMute() {
        runAction(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"], function() { OsdState.readVolume() })
    }

    function toggleMic() {
        runAction(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"], function() { OsdState.readMicMute() })
    }

    function toggleWifi() {
        runAction(["nmcli", "radio", "wifi", OsdState.wifiEnabled ? "off" : "on"], function() {
            OsdState.updateWifi()
            if (root.page === "wifi") root.scanWifi()
        })
    }

    function toggleBluetooth() {
        if (root.bluetoothAdapter)
            root.bluetoothAdapter.enabled = !root.bluetoothAdapter.enabled
    }

    function toggleAirplane() {
        runAction(["rfkill", root.airplane ? "unblock" : "block", "all"], function() {
            airplaneReadProcess.running = true
            OsdState.updateWifi()
        })
    }

    function toggleDnd() {
        dndToggleProcess.running = false
        dndToggleProcess.running = true
    }

    function cycleProfile() {
        var next = root.profiles[(root.profiles.indexOf(root.powerProfile) + 1) % root.profiles.length]
        runAction(["powerprofilesctl", "set", next], function() { profileReadProcess.running = true })
    }

    function openWallpapers() {
        hide()
        WallpaperState.show()
    }

    function screenshot() {
        hide()
        screenshotTimer.start()
    }

    Timer {
        id: screenshotTimer
        interval: 350   // let the notch finish collapsing before the region picker grabs the screen
        onTriggered: Quickshell.execDetached(["hyprshot", "-m", "region"])
    }

    // ── bluetooth (native Quickshell.Bluetooth) ──────────────────────────────
    function setBluetoothScan(on) {
        if (root.bluetoothAdapter && root.bluetoothAdapter.enabled)
            root.bluetoothAdapter.discovering = on
    }

    function activateBluetoothDevice(device) {
        if (!device) return
        if (device.connected) device.disconnect()
        else if (!device.paired) device.pair()
        else device.connect()
    }

    // ── wifi list ────────────────────────────────────────────────────────────
    function scanWifi() {
        if (!OsdState.wifiEnabled) {
            root.wifiNetworks = []
            return
        }
        root.wifiScanning = true
        wifiScanProcess.running = false
        wifiScanProcess.running = true
    }

    function connectWifi(ssid) {
        root.wifiConnecting = ssid
        wifiConnectProcess.ssid = ssid
        wifiConnectProcess.command = ["nmcli", "-w", "20", "device", "wifi", "connect", ssid]
        wifiConnectProcess.running = false
        wifiConnectProcess.running = true
    }

    property string wifiConnecting: ""

    Process {
        id: wifiScanProcess
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                var best = {}
                var lines = text.trim().length > 0 ? text.trim().split("\n") : []
                for (var i = 0; i < lines.length; i++) {
                    // nmcli -t escapes ':' inside values as '\:'
                    var parts = lines[i].replace(/\\:/g, "\u0001").split(":")
                    if (parts.length < 4) continue
                    var ssid = parts[1].replace(/\u0001/g, ":")
                    if (ssid === "") continue
                    var entry = {
                        ssid: ssid,
                        active: parts[0] === "*",
                        signal: parseInt(parts[2]) || 0,
                        secure: parts[3] !== "" && parts[3] !== "--"
                    }
                    var old = best[ssid]
                    if (!old || entry.active || (!old.active && entry.signal > old.signal))
                        best[ssid] = entry
                }
                var list = Object.keys(best).map(function(k) { return best[k] })
                list.sort(function(a, b) {
                    if (a.active !== b.active) return a.active ? -1 : 1
                    return b.signal - a.signal
                })
                root.wifiNetworks = list
            }
        }
        onExited: root.wifiScanning = false
    }

    Process {
        id: wifiConnectProcess
        property string ssid: ""
        onExited: function(code) {
            root.wifiConnecting = ""
            OsdState.updateWifi()
            root.scanWifi()
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "Wi-Fi", "Couldn't connect to " + ssid + " (new secured network? connect once with nmtui)"])
        }
    }

    // ── state readers ────────────────────────────────────────────────────────
    Process {
        id: dndReadProcess
        command: ["swaync-client", "-D"]
        stdout: SplitParser { onRead: data => root.dnd = data.trim() === "true" }
    }

    Process {
        id: dndToggleProcess
        command: ["swaync-client", "-d", "-sw"]
        stdout: SplitParser { onRead: data => root.dnd = data.trim() === "true" }
    }

    Process {
        id: airplaneReadProcess
        command: ["sh", "-c", "rfkill list | grep -c 'Soft blocked: yes'"]
        stdout: SplitParser { onRead: data => root.airplane = (parseInt(data.trim()) || 0) >= 2 }
    }

    Process {
        id: profileReadProcess
        command: ["powerprofilesctl", "get"]
        stdout: SplitParser { onRead: data => { if (data.trim()) root.powerProfile = data.trim() } }
    }

    // keep values live while the panel is open (but never fight a slider drag)
    Timer {
        interval: 1500
        repeat: true
        running: root.visible && !root.adjusting
        onTriggered: root.refresh()
    }

    // wifi list refresh while the wifi page is open
    Timer {
        interval: 8000
        repeat: true
        running: root.visible && root.page === "wifi"
        onTriggered: root.scanWifi()
    }

    IpcHandler {
        target: "control"

        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
        function page(name: string): void { root.showPage(name) }
    }
}
