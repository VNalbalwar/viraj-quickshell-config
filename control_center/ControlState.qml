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
//  Everything else (DND, airplane, power profile, wifi + bluetooth lists) lives
//  here.
//
//  The wifi / bluetooth lists are ListModels that are DIFF-synced (insert /
//  move / remove / update in place) instead of replaced, so the list updates
//  live in the background and new entries animate in without any flicker.
//
//    qs ipc call control toggle | hide
//    qs ipc call control page wifi | bluetooth | main
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property bool visible: false
    property string page: "main"          // main | wifi | bluetooth
    property bool adjusting: false        // a slider is being dragged

    property bool dnd: false
    property bool airplane: false
    property string powerProfile: "balanced"   // power-profiles-daemon view
    property string platformProfile: ""        // raw ACPI platform_profile ("" = not exposed)
    property bool wifiScanning: false
    property string wifiConnecting: ""

    readonly property alias wifiModel: wifiListModel
    readonly property alias btModel: btListModel
    property var btByAddress: ({})

    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: bluetoothAdapter ? bluetoothAdapter.enabled : false

    readonly property var profiles: ["power-saver", "balanced", "performance"]
    readonly property string effectiveProfile: platformProfile !== "" ? platformProfile : powerProfile
    readonly property string profileLabel: profileName(effectiveProfile)

    function profileName(p) {
        switch (p) {
        case "low-power":
        case "power-saver": return "Saver"
        case "quiet": return "Quiet"
        case "balanced": return "Balanced"
        case "balanced-performance": return "Balanced+"
        case "performance": return "Performance"
        case "turbo": return "Turbo"
        default: return p
        }
    }

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
        if (name === "wifi") {
            root.scanWifi()
            root.rescanWifi()
        } else if (name === "bluetooth") {
            root.syncBluetooth()
        }
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
        platformProfileProcess.running = true
        profileHelperProcess.running = true
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
        onExited: function(code) { afterExit(code) }
    }

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", title, body])
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
            if (root.page === "wifi") {
                root.scanWifi()
                root.rescanWifi()
            }
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

    // The Predator mode key cycles these four platform_profile values. Writing
    // platform_profile needs root, so when the polkit-whitelisted helper is
    // installed we cycle the same four; otherwise fall back to the three
    // power-profiles-daemon profiles.
    readonly property var keyCycle: ["quiet", "balanced", "balanced-performance", "performance"]
    readonly property string profileHelperPath: "/usr/local/bin/predator-profile"
    property bool profileHelper: false

    function cycleProfile() {
        var command, next
        if (root.profileHelper && root.platformProfile !== "") {
            // low-power (not on the key's cycle) rejoins at the start
            next = root.keyCycle[(root.keyCycle.indexOf(root.platformProfile) + 1) % root.keyCycle.length]
            command = ["pkexec", root.profileHelperPath, next]
        } else {
            next = root.profiles[(root.profiles.indexOf(root.powerProfile) + 1) % root.profiles.length]
            command = ["powerprofilesctl", "set", next]
        }
        runAction(command, function(code) {
            profileReadProcess.running = true
            platformProfileProcess.running = true
            if (code !== 0) root.notify("Power profile", "Couldn't switch to " + next)
        })
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

    // ── generic diff-sync for the animated lists ─────────────────────────────
    // `items` is the desired, already-sorted list; `key` names the identity field.
    function syncModel(model, key, items) {
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            var found = -1
            for (var j = i; j < model.count; j++) {
                if (model.get(j)[key] === item[key]) { found = j; break }
            }
            if (found < 0) {
                model.insert(i, item)
            } else {
                if (found !== i) model.move(found, i, 1)
                model.set(i, item)
            }
        }
        while (model.count > items.length)
            model.remove(model.count - 1)
    }

    // ── bluetooth (native Quickshell.Bluetooth) ──────────────────────────────
    ListModel { id: btListModel }

    function setBluetoothScan(on) {
        if (root.bluetoothAdapter && root.bluetoothAdapter.enabled && root.bluetoothAdapter.discovering !== on)
            root.bluetoothAdapter.discovering = on
    }

    function syncBluetooth() {
        var adapter = root.bluetoothAdapter
        var discovering = adapter && adapter.discovering
        var devices = Bluetooth.devices.values
        var map = {}
        var list = []

        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            var name = d.name || d.deviceName
            if (!name || !(d.paired || d.connected || discovering)) continue
            // unpaired beacons advertise their MAC as a "name" — just noise
            if (!d.paired && !d.connected && /^([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}$/.test(name)) continue
            map[d.address] = d
            list.push({ address: d.address, sortName: name, sortConnected: d.connected, sortPaired: d.paired })
        }

        list.sort(function(a, b) {
            if (a.sortConnected !== b.sortConnected) return a.sortConnected ? -1 : 1
            if (a.sortPaired !== b.sortPaired) return a.sortPaired ? -1 : 1
            return a.sortName.localeCompare(b.sortName)
        })

        root.btByAddress = map
        root.syncModel(btListModel, "address", list.map(function(e) { return { address: e.address } }))
    }

    function activateBluetoothDevice(device) {
        if (!device) return
        if (device.connected) device.disconnect()
        else if (!device.paired) device.pair()
        else device.connect()
    }

    // live: keep the list in step with BlueZ and keep discovery running
    Timer {
        interval: 600
        repeat: true
        running: root.visible && root.page === "bluetooth"
        onTriggered: root.syncBluetooth()
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.visible && root.page === "bluetooth"
        onTriggered: root.setBluetoothScan(true)
    }

    // ── wifi list ────────────────────────────────────────────────────────────
    ListModel { id: wifiListModel }

    function scanWifi() {
        if (!OsdState.wifiEnabled) {
            root.syncModel(wifiListModel, "ssid", [])
            return
        }
        wifiListProcess.running = false
        wifiListProcess.running = true
    }

    function rescanWifi() {
        if (!OsdState.wifiEnabled) return
        root.wifiScanning = true
        wifiRescanProcess.running = false
        wifiRescanProcess.running = true
    }

    function connectWifi(ssid) {
        root.wifiConnecting = ssid
        wifiConnectProcess.ssid = ssid
        wifiConnectProcess.command = ["nmcli", "-w", "20", "device", "wifi", "connect", ssid]
        wifiConnectProcess.running = false
        wifiConnectProcess.running = true
    }

    function parseWifi(text) {
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
                strength: parseInt(parts[2]) || 0,
                secure: parts[3] !== "" && parts[3] !== "--"
            }
            var old = best[ssid]
            if (!old || entry.active || (!old.active && entry.strength > old.strength))
                best[ssid] = entry
        }
        var list = Object.keys(best).map(function(k) { return best[k] })
        // bucketed strength keeps the order calm while signals jitter by a few %
        list.sort(function(a, b) {
            if (a.active !== b.active) return a.active ? -1 : 1
            var ba = Math.floor(a.strength / 20), bb = Math.floor(b.strength / 20)
            if (ba !== bb) return bb - ba
            return a.ssid.localeCompare(b.ssid)
        })
        return list
    }

    Process {
        id: wifiListProcess
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: root.syncModel(wifiListModel, "ssid", root.parseWifi(text))
        }
    }

    Process {
        id: wifiRescanProcess
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: {
            root.wifiScanning = false
            root.scanWifi()
        }
    }

    Process {
        id: wifiConnectProcess
        property string ssid: ""
        onExited: function(code) {
            root.wifiConnecting = ""
            OsdState.updateWifi()
            root.scanWifi()
            if (code !== 0)
                root.notify("Wi-Fi", "Couldn't connect to " + ssid + " (new secured network? connect once with nmtui)")
        }
    }

    // live: cached list every couple of seconds, a real radio rescan every 12s
    Timer {
        interval: 2500
        repeat: true
        running: root.visible && root.page === "wifi"
        onTriggered: root.scanWifi()
    }

    Timer {
        interval: 12000
        repeat: true
        running: root.visible && root.page === "wifi"
        onTriggered: root.rescanWifi()
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

    // The Predator's hardware mode key moves ACPI platform_profile directly, so
    // read that too — it's the truth. (Only exists while linuwu_sense is loaded.)
    Process {
        id: platformProfileProcess
        command: ["cat", "/sys/firmware/acpi/platform_profile"]
        stdout: SplitParser { onRead: data => root.platformProfile = data.trim() }
        onExited: function(code) { if (code !== 0) root.platformProfile = "" }
    }

    Process {
        id: profileHelperProcess
        command: ["test", "-x", root.profileHelperPath]
        onExited: function(code) { root.profileHelper = (code === 0) }
    }

    // keep values live while the panel is open (but never fight a slider drag)
    Timer {
        interval: 1500
        repeat: true
        running: root.visible && !root.adjusting
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "control"

        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
        function page(name: string): void { root.showPage(name) }
    }
}
