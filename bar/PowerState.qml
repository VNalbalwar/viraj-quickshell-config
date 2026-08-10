pragma Singleton

import Quickshell
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
        target: "power"

        function toggle(): void {
            root.toggle()
        }

        function show(): void {
            root.show()
        }

        function hide(): void {
            root.hide()
        }
    }
}