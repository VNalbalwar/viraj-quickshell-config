pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var palette: ({})
    property int version: 0

    FileView {
        id: paletteFile

        path: "/home/viraj/.cache/wallust/quickshell.json"

        blockLoading: true
        watchChanges: true

        Component.onCompleted: {
            try {
                root.palette = JSON.parse(text())
            } catch (e) {
                console.log("Failed to load palette:", e)
            }
        }

        onFileChanged: {
            reload()

            try {
                root.palette = JSON.parse(text())
                version++
                console.log("Version =", version)
            } catch (e) {
                console.log("Failed to reload palette:", e)
            }
        }
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
    
    readonly property color colBg: root.palette.background || "#1d2021"
    readonly property color colFg: root.palette.foreground || "#d4be98"

    readonly property color colBlack: root.palette.color0 || "#282828"
    readonly property color colRed: root.palette.color1 || "#ea6962"
    readonly property color colGreen: root.palette.color2 || "#a9b665"
    readonly property color colYellow: root.palette.color3 || "#d8a657"
    readonly property color colBlue: root.palette.color4 || "#7daea3"
    readonly property color colPurple: root.palette.color5 || "#d3869b"
    readonly property color colCyan: root.palette.color6 || "#89b482"
    readonly property color colWhite: root.palette.color7 || "#d4be98"

    readonly property color colBrightBlack: root.palette.color8 || "#928374"
    readonly property color colBrightRed: root.palette.color9 || "#ea6962"
    readonly property color colBrightGreen: root.palette.color10 || "#a9b665"
    readonly property color colBrightYellow: root.palette.color11 || "#d8a657"
    readonly property color colBrightBlue: root.palette.color12 || "#7daea3"
    readonly property color colBrightPurple: root.palette.color13 || "#d3869b"
    readonly property color colBrightCyan: root.palette.color14 || "#89b482"
    readonly property color colBrightWhite: root.palette.color15 || "#d4be98"

    // Bar / UI aliases
    readonly property color bg1: colBg
    readonly property color fg: colFg
    readonly property color grey2: colBrightBlack
}
