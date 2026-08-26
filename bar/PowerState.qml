pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io

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

    function runCommand(command) {
        hide()
        commandProcess.command = ["bash", "-c", command]
        commandProcess.running = false
        commandProcess.running = true
    }

    function sleep() {
        runCommand("systemctl suspend")
    }

    function logout() {
        runCommand("hyprctl dispatch exit")
    }

    function reboot() {
        runCommand("systemctl reboot")
    }

    function powerOff() {
        runCommand("systemctl poweroff")
    }

    Process {
        id: commandProcess
        command: ["bash", "-c", ""]
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