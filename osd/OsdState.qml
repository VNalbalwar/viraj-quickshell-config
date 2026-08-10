pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool visible: false

    function show() {
        root.visible = true
        hideTimer.restart()
    }

    function hide() {
        hideTimer.stop()
        root.visible = false
    }

    function toggle() {
        if (root.visible)
            hide()
        else
            show()
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
        function hide(): void { root.hide() }
    }
}
