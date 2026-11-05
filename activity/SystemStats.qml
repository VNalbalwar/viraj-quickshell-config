pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Live CPU / RAM / temperature / power numbers for the notch's hover glance. It only polls while
// something is looking (`watching`), so it costs nothing the rest of the time.
Singleton {
    id: root

    property bool watching: false
    property int cpu: 0              // %
    property int ram: 0              // %
    property int temp: 0             // °C, CPU package

    property var _last: null         // previous /proc/stat totals, for the CPU delta

    Process {
        id: sample
        command: ["sh", "-c",
            "head -1 /proc/stat; " +
            "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print t, a}' /proc/meminfo; " +
            "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = coretemp ] && cat $h/temp1_input && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                if (l.length < 3) return
                var f = l[0].trim().split(/\s+/).slice(1).map(Number)
                var idle = f[3] + (f[4] || 0)
                var total = f.reduce(function(a, b) { return a + b }, 0)
                if (root._last) {
                    var dt = total - root._last.total
                    if (dt > 0) root.cpu = Math.round(100 * (1 - (idle - root._last.idle) / dt))
                }
                root._last = { idle: idle, total: total }
                var m = l[1].trim().split(/\s+/).map(Number)
                root.ram = Math.round(100 * (1 - m[1] / m[0]))
                root.temp = Math.round(Number(l[2]) / 1000)
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: root.watching
        triggeredOnStart: true
        onTriggered: sample.running = true
        onRunningChanged: if (!running) root._last = null
    }
}
