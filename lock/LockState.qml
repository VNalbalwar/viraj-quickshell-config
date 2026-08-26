pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool visible: false

    function show() {
        root.visible = true
    }

    function hide() {
        root.visible = false
    }

    function toggle() {
        root.visible = !root.visible
    }

    IpcHandler {
        target: "lock"

        function show(): void {
            root.show()
        }

        function hide(): void {
            root.hide()
        }

        function toggle(): void {
            root.toggle()
        }
    }
}