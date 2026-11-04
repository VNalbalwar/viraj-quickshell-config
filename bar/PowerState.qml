pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io
import "../lockscreen"

// ─────────────────────────────────────────────────────────────────────────────
//  PowerState — the notch power menu's state + the actions its buttons fire.
//
//    Lock      → engage the lockscreen only (NO suspend). Suspend happens on lid
//                close, handled by logind + a before-sleep hook OUTSIDE this
//                shell (the hook runs `qs ipc call lock lock`, so a lid-close
//                resumes straight into this same lock).
//    Log Out   → uwsm stop   (ends the uwsm session → back to the GDM greeter)
//    Reboot    → systemctl reboot
//    Power Off → systemctl poweroff
// ─────────────────────────────────────────────────────────────────────────────
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

    // Lock only — no suspend. (Closing the lid suspends via logind; a
    // before-sleep hook calls `qs ipc call lock lock` so you resume into this
    // same lock.)
    function lock() {
        hide()
        LockState.lock()
    }

    // Hyprland runs under uwsm (launched via GDM → uwsm), so the clean logout
    // is `uwsm stop`: it tears the whole user session down and returns you to
    // the GDM login screen. `hyprctl dispatch exit` only kills the compositor
    // and under uwsm doesn't end the session — that's why logout did nothing.
    function logout() {
        runCommand("uwsm stop")
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
