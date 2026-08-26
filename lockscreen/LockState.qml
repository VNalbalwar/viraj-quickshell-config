pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// ─────────────────────────────────────────────────────────────────────────────
//  LockState — shared state + PAM authentication for the lockscreen.
//
//  Drives two independent surfaces that share this one PAM conversation:
//    • demoActive → Lockscreen.qml  — Stage-1 dismissible test (always escapable
//                                     via Esc or `qs ipc call lock hide`).
//    • locked     → SessionLock.qml — Stage-2 REAL ext-session-lock.
//
//  PAM uses config "hyprlock" (a proven local stack). `locked` defaults false,
//  so reloading the config never locks you, and forceUnlock() is the backstop.
//
//    Test overlay:   qs ipc call lock demo     (dismiss: Esc / lock hide)
//    Real lock:      qs ipc call lock lock      (unlock: password → Enter)
//    Emergency:      qs ipc call lock forceUnlock
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    // Stage-1 dismissible test overlay visibility.
    property bool demoActive: false

    // Stage-2 REAL ext-session-lock. Defaults false so a config reload NEVER
    // locks you — only lock() / `qs ipc call lock lock` sets it true.
    property bool locked: false

    // Shared auth/UI state (read by the on-screen surfaces).
    property bool authenticating: false   // PAM conversation in flight
    property bool unlocking: false         // success beat before dismiss
    property bool errorState: false        // last attempt failed
    property string statusText: ""         // small line under the field

    signal failed()      // wrong password / error  → UI shakes + clears
    signal succeeded()   // correct password        → UI success beat

    // Password lives here only transiently, during the async PAM exchange.
    property string _pending: ""

    function _resetState() {
        authenticating = false
        unlocking = false
        errorState = false
        statusText = ""
        _pending = ""
    }

    function showDemo() {
        pam.abort()
        _resetState()
        demoActive = true
    }

    function hideDemo() {
        pam.abort()
        _resetState()
        demoActive = false
    }

    // Stage 2: engage the REAL ext-session-lock.
    function lock() {
        pam.abort()
        _resetState()
        demoActive = false   // the real lock supersedes any demo overlay
        locked = true
    }

    // Emergency escape hatch — clears every lock state. Safe to call at any
    // time, e.g. `qs ipc call lock forceUnlock` from another TTY if the UI ever
    // wedges. This is the "never locked out" backstop.
    function forceUnlock() {
        pam.abort()
        _resetState()
        locked = false
        demoActive = false
        console.log("[lock] forceUnlock — cleared all lock state")
    }

    // Called by the surface when the user submits the password field.
    function submit(pw) {
        if (authenticating || unlocking)
            return
        if (!pw || pw.length === 0)
            return

        _pending = pw
        errorState = false
        authenticating = true
        statusText = "Authenticating…"

        console.log("[lock] starting PAM conversation (config: hyprlock)")
        if (!pam.start()) {
            console.log("[lock] pam.start() returned false")
            authenticating = false
            _pending = ""
            errorState = true
            statusText = "Authentication unavailable"
            root.failed()
        }
    }

    PamContext {
        id: pam
        config: "hyprlock"   // reuse /etc/pam.d/hyprlock — a proven local lock stack
        // `user` intentionally left unset → defaults to the current user (viraj).

        // PAM asks for the password → hand it the pending value once.
        onResponseRequiredChanged: {
            if (responseRequired && root.authenticating && root._pending.length > 0) {
                console.log("[lock] pam requested response, responding")
                pam.respond(root._pending)
            }
        }

        onCompleted: function (result) {
            console.log("[lock] pam completed:", PamResult.toString(result))
            root._pending = ""
            root.authenticating = false

            if (result === PamResult.Success) {
                root.errorState = false
                root.statusText = "Welcome back"
                root.succeeded()
                root.unlocking = true   // begins the fade-out on the live surface
                if (root.locked)
                    unlockTimer.restart()   // Stage 2: fade out, THEN drop the lock
                else
                    dismissTimer.restart()  // Stage 1: brief beat, then hide the demo
            } else if (result === PamResult.MaxTries) {
                root.errorState = true
                root.statusText = "Too many attempts"
                root.failed()
            } else {
                // Failed or Error
                root.errorState = true
                root.statusText = "Incorrect password"
                root.failed()
            }
        }

        onError: function (err) {
            console.log("[lock] pam error:", PamError.toString(err))
            root._pending = ""
            root.authenticating = false
            root.errorState = true
            root.statusText = "Authentication error"
            root.failed()
        }
    }

    // Stage 1: after the brief success beat, dismiss the test overlay.
    Timer {
        id: dismissTimer
        interval: 480
        onTriggered: {
            root.demoActive = false
            root.unlocking = false
            root.statusText = ""
        }
    }

    // Stage 2: hold the REAL lock surface up through its fade-out, THEN release
    // it. The compositor destroys the surface the instant `locked` goes false, so
    // if we dropped it immediately there'd be no animation — this delay lets the
    // content dissolve first (see SessionLock.qml's opacity Behavior, 300 ms).
    Timer {
        id: unlockTimer
        interval: 340
        onTriggered: {
            root.locked = false
            root.unlocking = false
            root.statusText = ""
        }
    }

    IpcHandler {
        target: "lock"

        function demo(): void {
            root.showDemo()
        }

        function hide(): void {
            root.hideDemo()
        }

        function lock(): void {
            root.lock()
        }

        function forceUnlock(): void {
            root.forceUnlock()
        }
    }
}
