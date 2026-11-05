pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool configured: false
    property string error: ""
    property var events: []            // [{ title, start (ISO), allDay }]

    function refresh() { agenda.running = false; agenda.running = true }

    Process {
        id: agenda
        command: ["python3", Quickshell.shellDir + "/control_center/agenda.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.configured = d.configured
                    root.error = d.error || ""
                    root.events = d.events
                } catch (e) { root.events = [] }
            }
        }
    }
}
