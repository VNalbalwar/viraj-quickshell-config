import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import Quickshell.Io
import "./bar"
import "./app_launcher"
import "./wallpaper_switcher"

ShellRoot {
    // ── App launcher (slides up from bottom center) ────────────────────────
    Variants {
        model: Quickshell.screens

        AppLauncher {
            property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        WallpaperSwitcher {
            property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
        }
    }
}
