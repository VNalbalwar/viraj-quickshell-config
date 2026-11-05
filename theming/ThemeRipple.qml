import Quickshell
import Quickshell.Wayland
import QtQuick
import "../theme"

// When the colors change (a theme or wallpaper switch), a soft ring of the new accent color spreads from the
// notch across the whole screen. It is a click-through overlay that only exists for about a second.
PanelWindow {
    id: win

    property real progress: 0
    readonly property real reach: Math.sqrt(width * width + height * height)

    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-theme-ripple"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {}          // nothing here takes clicks

    // palette files can change twice in a row (watch + explicit reload): wait for the dust to settle
    Connections {
        target: Colors
        function onVersionChanged() { debounce.restart() }
    }
    Timer { id: debounce; interval: 200; onTriggered: { win.visible = true; anim.restart() } }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: win; property: "progress"; from: 0; to: 1; duration: 1600; easing.type: Easing.OutCubic }
        ScriptAction { script: win.visible = false }
    }

    // soft wash that fills as the ring passes
    Rectangle {
        width: win.progress * win.reach * 2
        height: width
        radius: width / 2
        x: win.width / 2 - width / 2
        y: -height / 2
        color: Colors.alpha(Colors.colBlue, 0.14 * (1 - win.progress))
    }

    // the ring itself
    Rectangle {
        width: win.progress * win.reach * 2
        height: width
        radius: width / 2
        x: win.width / 2 - width / 2
        y: -height / 2
        color: "transparent"
        border.width: 7 * (1 - win.progress) + 1
        border.color: Colors.alpha(Colors.colBlue, 0.9 * (1 - win.progress))
    }
}
