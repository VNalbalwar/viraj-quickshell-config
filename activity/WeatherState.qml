pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Current weather for the notch's hover panel (Open-Meteo, no account or key).
// Your rough location comes from your public IP once a day (cached), so nothing needs configuring.
Singleton {
    id: root

    property bool ready: false
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
                if (nl < 0) return
                try {
                    var cur = JSON.parse(text.slice(nl + 1)).current
                    root.place = text.slice(0, nl)
                    root.temp = cur.temperature_2m
                    root.code = cur.weather_code
                    root.day = cur.is_day === 1
                    root.ready = true
                } catch (e) { console.log("weather:", e) }
            }
        }
    }

    Timer { interval: 1800000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
