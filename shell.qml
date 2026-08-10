import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import Quickshell.Io
import "./bar"
import "./app_launcher"
import "./wallpaper_switcher"
import "./osd"

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

    Variants {
        model: Quickshell.screens

        Osd {
            property var modelData
            screen: modelData
        }
    }
}