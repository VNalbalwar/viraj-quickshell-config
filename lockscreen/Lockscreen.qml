import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

// ─────────────────────────────────────────────────────────────────────────────
//  Lockscreen (STAGE 1) — a dismissible full-screen test surface.
//
//  An ordinary layer-shell overlay, NOT ext-session-lock. It cannot trap you:
//  Esc dismisses it, `qs ipc call lock hide` dismisses it, and Hyprland keybinds
//  keep working. It exists to prove PAM auth + the visual before the real lock.
//
//  The visual + input all live in the shared LockContent (also used by the real
//  SessionLock), so this file is just the fading overlay shell around it.
//
//  One instance is spawned per screen from shell.qml.
// ─────────────────────────────────────────────────────────────────────────────
PanelWindow {
    id: lock

    // Kept mapped through the fade-out even after demoActive flips false.
    property bool reallyVisible: false
    visible: reallyVisible

    WlrLayershell.namespace: "qs-lockscreen"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: LockState.demoActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    exclusiveZone: 0
    color: "transparent"

    // Input region: whole screen while the demo is up, but COLLAPSES TO NOTHING
    // the instant it's dismissed — so during the fade-out (and even if the
    // surface lingers a moment before unmapping) every click falls straight
    // through to the windows underneath.
    mask: Region {
        width: LockState.demoActive ? lock.width : 0
        height: LockState.demoActive ? lock.height : 0
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Connections {
        target: LockState
        function onDemoActiveChanged() {
            if (LockState.demoActive) {
                hideTimer.stop()
                lock.reallyVisible = true
            } else {
                // Fade out, THEN unmap — from a Timer, because a NumberAnimation
                // inside a Behavior never emits finished(). (If we relied on that,
                // the transparent overlay would stay mapped and eat every click.)
                hideTimer.restart()
            }
        }
    }

    // Unmaps the surface shortly after the 320 ms fade-out finishes.
    Timer {
        id: hideTimer
        interval: 380
        onTriggered: lock.reallyVisible = false
    }

    // The shared lock UI, faded in/out as one.
    LockContent {
        anchors.fill: parent
        active: LockState.demoActive
        testMode: true

        opacity: LockState.demoActive ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 320; easing.type: Motion.settle }
        }
    }
}
