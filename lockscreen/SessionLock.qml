import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

// ─────────────────────────────────────────────────────────────────────────────
//  SessionLock (STAGE 2) — the REAL lock, via the ext-session-lock protocol.
//
//  While `LockState.locked` is true the compositor renders ONLY these lock
//  surfaces (the bar/notch and every app are hidden by the compositor itself).
//  It is INERT until then, so simply reloading the config never locks you:
//  `LockState.locked` defaults to false.
//
//    Engage the lock:            qs ipc call lock lock
//    Unlock normally:            type your password → Enter
//    EMERGENCY unlock (TTY):     qs ipc call lock forceUnlock
//
//  One WlSessionLock manages one surface per screen automatically — do NOT wrap
//  it in Variants.
// ─────────────────────────────────────────────────────────────────────────────
WlSessionLock {
    id: sessionLock

    locked: LockState.locked

    WlSessionLockSurface {
        id: surface

        // Safe opaque base in case the wallpaper frame is missing.
        color: Colors.colBg

        // The ext-session-lock surface itself appears/vanishes instantly (the
        // compositor creates it on lock and destroys it on unlock), so the smooth
        // feel comes from animating the CONTENT's opacity, not the surface:
        //   • fade IN  — `shown` flips false→true right after the surface is built
        //   • fade OUT — `LockState.unlocking` goes true on a correct password and
        //     stays true through LockState's unlockTimer (340 ms), so the content
        //     finishes dissolving (300 ms) BEFORE `locked` drops and the surface
        //     is torn down. No dissolve = the old instant snap you saw.
        property bool shown: false
        Component.onCompleted: shown = true

        LockContent {
            anchors.fill: parent
            active: LockState.locked
            testMode: false

            opacity: (surface.shown && !LockState.unlocking) ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
        }
    }
}
