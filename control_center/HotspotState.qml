pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../osd"

// ─────────────────────────────────────────────────────────────────────────────
//  HotspotState — share your Wi-Fi without leaving it.
//
//  NetworkManager normally puts a hotspot on wlan0 itself, which drops your own
//  Wi-Fi connection. Intel radios can run one station + one AP at once, as long
//  as both use the SAME channel. So we:
//    1. add a second virtual interface (qsap0) next to wlan0   (root helper)
//    2. let NetworkManager run an access point on it, on wlan0's current channel,
//       with ipv4.method=shared (DHCP + NAT for the devices that join)
//  wlan0 is never touched. Needs: extras/predator/install.sh (the helper).
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property bool active: false
    property int clients: 0
    property bool busy: false
    property bool helper: false

    property string ssid: "NotchSpot"
    property string password: ""
    property int channel: 0

    readonly property string helperPath: "/usr/local/bin/qs-hotspot-iface"
    readonly property string configFile: "/home/viraj/.config/qs-hotspot.json"
    readonly property string connection: "qs-hotspot"

    function notify(body) {
        Quickshell.execDetached(["notify-send", "-a", "Hotspot", "Hotspot", body])
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", text])
    }

    function toggle() {
        if (root.busy) return
        if (root.active) stop()
        else start()
    }

    function start() {
        if (!root.helper) {
            root.notify("Run extras/predator/install.sh once to enable the hotspot")
            return
        }
        if (!OsdState.wifiConnected) {
            root.notify("Connect to Wi-Fi first - the hotspot shares that connection and uses its channel")
            return
        }
        if (root.password.length < 8) {
            root.notify("No password yet - try again in a second")
            return
        }
        root.busy = true
        startProcess.command = ["sh", "-c", startScript, "sh", root.ssid, root.password, root.helperPath, root.connection]
        startProcess.running = false
        startProcess.running = true
    }

    function stop() {
        root.busy = true
        stopProcess.command = ["sh", "-c", stopScript, "sh", root.helperPath, root.connection]
        stopProcess.running = false
        stopProcess.running = true
    }

    function refresh() {
        helperProcess.running = true
        statusProcess.running = true
    }

    // Same channel/band as the current Wi-Fi link; the AP rides next to it on qsap0.
    readonly property string startScript:
        "set -e\n" +
        "ssid=\"$1\"; pass=\"$2\"; helper=\"$3\"; con=\"$4\"\n" +
        "freq=$(iw dev wlan0 link | awk '/freq:/ {print int($2)}')\n" +
        "[ -n \"$freq\" ] || { echo 'not connected' >&2; exit 3; }\n" +
        "if [ \"$freq\" -ge 5000 ]; then band=a; ch=$(( (freq - 5000) / 5 )); else band=bg; ch=$(( (freq - 2407) / 5 )); fi\n" +
        "pkexec \"$helper\" add\n" +
        "nmcli connection delete \"$con\" >/dev/null 2>&1 || true\n" +
        "nmcli connection add type wifi ifname qsap0 con-name \"$con\" autoconnect no ssid \"$ssid\" mode ap " +
            "802-11-wireless.band \"$band\" 802-11-wireless.channel \"$ch\" " +
            "wifi-sec.key-mgmt wpa-psk wifi-sec.psk \"$pass\" ipv4.method shared ipv6.method ignore >/dev/null\n" +
        "nmcli connection up \"$con\" ifname qsap0 >/dev/null\n" +
        "echo \"$ch\"\n"

    readonly property string stopScript:
        "helper=\"$1\"; con=\"$2\"\n" +
        "nmcli connection down \"$con\" >/dev/null 2>&1 || true\n" +
        "nmcli connection delete \"$con\" >/dev/null 2>&1 || true\n" +
        "pkexec \"$helper\" del || true\n"

    Process {
        id: startProcess
        stdout: SplitParser { onRead: data => root.channel = parseInt(data.trim()) || 0 }
        onExited: function(code) {
            root.busy = false
            if (code !== 0) {
                root.notify("Couldn't start the hotspot - your Wi-Fi was left alone")
                root.stop()          // tidy up any half-created interface
            }
            root.refresh()
        }
    }

    Process {
        id: stopProcess
        onExited: {
            root.busy = false
            root.channel = 0
            root.refresh()
        }
    }

    Process {
        id: helperProcess
        command: ["test", "-x", root.helperPath]
        onExited: function(code) { root.helper = (code === 0) }
    }

    Process {
        id: statusProcess
        command: ["sh", "-c",
            "a=$(nmcli -t -f NAME connection show --active | grep -c '^" + root.connection + "$'); " +
            "c=$(iw dev qsap0 station dump 2>/dev/null | grep -c '^Station'); echo \"$a $c\""]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ")
                root.active = (parseInt(p[0]) || 0) > 0
                root.clients = parseInt(p[1]) || 0
            }
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ── persisted name + password (generated once, kept out of the git repo) ──
    function save() {
        saveProcess.command = ["sh", "-c", "umask 077; printf '%s' \"$2\" > \"$1\"", "sh", root.configFile,
            JSON.stringify({ ssid: root.ssid, password: root.password })]
        saveProcess.running = false
        saveProcess.running = true
    }

    Process { id: saveProcess }

    Process {
        id: passwordProcess
        command: ["sh", "-c", "head -c 12 /dev/urandom | base64 | tr -d '+/=' | head -c 10"]
        stdout: SplitParser {
            onRead: data => {
                root.password = data.trim()
                root.save()
            }
        }
    }

    FileView {
        id: configView
        path: root.configFile
        blockLoading: true

        Component.onCompleted: {
            try {
                var c = JSON.parse(text())
                if (c.ssid) root.ssid = c.ssid
                if (c.password && c.password.length >= 8) root.password = c.password
            } catch (e) {}
            if (root.password.length < 8) passwordProcess.running = true
        }
    }
}
