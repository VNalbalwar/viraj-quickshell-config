pragma Singleton

import Quickshell

// Shared look-and-feel constants for the notch control center.
Singleton {
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    readonly property int sideMargin: 38
    readonly property int bodyTop: 68
    readonly property int bottomMargin: 22

    readonly property int tileW: 104
    readonly property int tileH: 74
    readonly property int gap: 10
    readonly property int columns: 4
    readonly property int rows: 4

    readonly property int gridHeight: rows * tileH + (rows - 1) * gap
    readonly property int width: 740
    readonly property int height: bodyTop + gridHeight + bottomMargin
}
