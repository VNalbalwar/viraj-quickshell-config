import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import Quickshell.Io
import "./bar"
import "./app_launcher"
import "./theming"
import "./lockscreen"

ShellRoot {
    // ── Original standalone app launcher kept as a safety fallback ─────────
    // Variants {
    //     model: Quickshell.screens
    //
    //     AppLauncher {
    //         property var modelData
    //         screen: modelData
    //     }
    // }

    // Variants {
    //     model: Quickshell.screens
    //
    //     WallpaperSwitcher {
    //         property var modelData
    //         screen: modelData
    //     }
    // }

    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
        }
    }

    // ── Lockscreen (Stage 1: dismissible test overlay, one per screen) ────────
    Variants {
        model: Quickshell.screens

        Lockscreen {
            property var modelData
            screen: modelData
        }
    }

    // ── Lockscreen (Stage 2: the REAL ext-session-lock) ───────────────────────
    // Inert until `LockState.locked` flips true (via `qs ipc call lock lock`).
    // A single instance manages one lock surface per screen automatically.
    SessionLock {}
}
