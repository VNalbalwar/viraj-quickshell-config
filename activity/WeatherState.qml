pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Current weather for the notch's hover panel (Open-Meteo, no account or key).
// Your rough location comes from your public IP once a day (cached), so nothing needs configuring.
Singleton {
    id: root

    // `ready` = we have a recent reading. When the network is down the chip hides itself after two failed
    // tries, and we keep retrying every minute, so it comes back by itself once you're online.
    property bool ready: false
    property double lastOk: 0
    property real temp: 0
    property int code: 0
    property bool day: true
    property string place: ""

    readonly property string glyph: {
        var c = root.code
        if (c === 0) return root.day ? "󰖙" : "󰖔"
        if (c <= 2) return "󰖕"
        if (c === 3) return "󰖐"
        if (c === 45 || c === 48) return "󰖑"
        if (c >= 51 && c <= 57) return "󰖗"
        if (c >= 61 && c <= 67) return "󰖗"
        if (c >= 71 && c <= 77) return "󰖘"
        if (c >= 80 && c <= 82) return "󰖖"
        if (c >= 85 && c <= 86) return "󰖘"
        if (c >= 95) return "󰖓"
        return "󰖐"
    }

    readonly property string cache: Quickshell.env("HOME") + "/.cache/qs-weather-loc.json"

    function refresh() { fetch.running = false; fetch.running = true }

    property int failures: 0
    function checkStale() {                    // two misses in a row (about two minutes): hide it, keep retrying
        root.failures++
        if (root.failures >= 2) root.ready = false
    }

    // location (cached for a day) -> current conditions
    Process {
        id: fetch
        command: ["sh", "-c",
            "f=\"$1\"; " +
            "if [ ! -s \"$f\" ] || [ -n \"$(find \"$f\" -mmin +1440 2>/dev/null)\" ]; then " +
            "  curl -fsS -m 8 'http://ip-api.com/json/?fields=status,city,lat,lon' > \"$f.tmp\" && mv \"$f.tmp\" \"$f\"; fi; " +
            "lat=$(sed -n 's/.*\"lat\":\\([-0-9.]*\\).*/\\1/p' \"$f\"); lon=$(sed -n 's/.*\"lon\":\\([-0-9.]*\\).*/\\1/p' \"$f\"); " +
            "city=$(sed -n 's/.*\"city\":\"\\([^\"]*\\)\".*/\\1/p' \"$f\"); " +
            "echo \"$city\"; " +
            "curl -fsS -m 8 \"https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,is_day\"",
            "sh", root.cache]
        stdout: StdioCollector {
            onStreamFinished: {
                var nl = text.indexOf("\n")
                if (nl < 0) { root.checkStale(); return }
                try {
                    var cur = JSON.parse(text.slice(nl + 1)).current
                    root.place = text.slice(0, nl)
                    root.temp = cur.temperature_2m
                    root.code = cur.weather_code
                    root.day = cur.is_day === 1
                    root.lastOk = Date.now()
                    root.failures = 0
                    root.ready = true
                } catch (e) { root.checkStale() }
            }
        }
    }

    // Is there internet at all? NetworkManager knows within seconds, so the chip hides the moment you go
    // offline and a fresh reading is fetched the moment you're back (no waiting for the next timer tick).
    property bool online: true
    Process {
        id: netCheck
        command: ["nmcli", "-t", "-g", "CONNECTIVITY", "general"]
        stdout: StdioCollector {
            onStreamFinished: {
                var up = text.trim() === "full"
                if (up === root.online) return
                root.online = up
                if (up) { root.failures = 0; root.refresh() }
                else root.ready = false
            }
        }
    }
    Timer { interval: 10000; repeat: true; running: true; onTriggered: netCheck.running = true }

    // every 15 minutes normally; every minute while we have no reading (offline), so it reappears quickly
    Timer {
        interval: (root.ready && root.failures === 0) ? 900000 : 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
