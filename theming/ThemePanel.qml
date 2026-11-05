import Quickshell.Widgets
import QtQuick
import "../theme"

// The wallpaper / theme picker that opens inside the notch.
//   Wallpapers : the picture. Colors follow it, unless a theme is locked in (then only the picture changes).
//   Themes     : the colors. A named palette applied to the terminal, borders, shell, GTK apps...
//                or "Follow wallpaper" to hand the colors back to the picture.
// Keys: ← → move, Enter apply, Tab switch page, Esc close.
Item {
    id: panel

    property bool active: false

    readonly property bool onWallpapers: ThemeState.tab === "wallpapers"
    readonly property real cardGap: 12
    readonly property real cardW: (width - 48 - 4 * cardGap) / 5
    readonly property real cardH: 104

    visible: opacity > 0.01
    opacity: active ? 1 : 0
    focus: active
    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    onVisibleChanged: if (visible) forceActiveFocus()

    // jump straight to the selection when the panel opens (no long scroll), then it glides as you move
    function jumpToSelection() {
        wallpaperStrip.currentIndex = ThemeState.selectedIndex
        themeStrip.currentIndex = ThemeState.themeCursor
        wallpaperStrip.positionViewAtIndex(ThemeState.selectedIndex, ListView.Center)
        themeStrip.positionViewAtIndex(ThemeState.themeCursor, ListView.Center)
    }
    onActiveChanged: if (active) settle.restart()
    Timer { id: settle; interval: 140; onTriggered: panel.jumpToSelection() }     // let the lists lay out first
    Connections {
        target: ThemeState.wallpapers
        function onCountChanged() { if (panel.visible) settle.restart() }
    }
    Connections {
        target: ThemeState
        function onTabChanged() { panel.forceActiveFocus() }
    }
    // (a Binding, not a plain `currentIndex:` - ListView overwrites that itself whenever its model refills)
    Binding { target: wallpaperStrip; property: "currentIndex"; value: ThemeState.selectedIndex }
    Binding { target: themeStrip; property: "currentIndex"; value: ThemeState.themeCursor }

    Keys.onPressed: function(event) {
        var count = onWallpapers ? ThemeState.wallpapers.count : ThemeState.themeCards.length
        if (event.key === Qt.Key_Escape) {
            ThemeState.hide()
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            ThemeState.nextTab()
        } else if (count > 0 && (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Right || event.key === Qt.Key_Down)) {
            var step = (event.key === Qt.Key_Left || event.key === Qt.Key_Up) ? -1 : 1
            if (onWallpapers) ThemeState.selectedIndex = (ThemeState.selectedIndex + step + count) % count
            else ThemeState.themeCursor = (ThemeState.themeCursor + step + count) % count
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (onWallpapers) ThemeState.selectAndApply(); else ThemeState.applyThemeCard()
        } else {
            return
        }
        event.accepted = true
    }

    // ── header: page switch + what the colors currently follow ────────────────────────────────────
    Row {
        id: tabs
        anchors { left: parent.left; leftMargin: 24; top: parent.top; topMargin: 14 }
        spacing: 6

        Repeater {
            model: [{ id: "wallpapers", label: "Wallpapers" }, { id: "themes", label: "Themes" }]

            Rectangle {
                readonly property bool on: ThemeState.tab === modelData.id
                width: tabLabel.implicitWidth + 28
                height: 30
                radius: 15
                color: on ? Colors.colBlue : (tabMouse.containsMouse ? Colors.alpha(Colors.colFg, 0.12) : Colors.alpha(Colors.colFg, 0.06))
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                scale: tabMouse.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.pop; easing.overshoot: Motion.overshoot } }

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.on ? Colors.colBg : Colors.fg
                    font { pixelSize: 13; weight: Font.DemiBold }
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { ThemeState.tab = modelData.id; panel.forceActiveFocus() }
                }
            }
        }
    }

    Text {
        id: status
        anchors { right: parent.right; rightMargin: 24; verticalCenter: tabs.verticalCenter }
        color: Colors.grey2
        font.pixelSize: 12
        text: panel.onWallpapers
            ? (ThemeState.buildingThumbs ? "Preparing previews…   " : "")
                + (ThemeState.mode === "preset" ? "Colors locked to " + ThemeState.presetLabel + " · picture only"
                                                : "Colors follow the wallpaper")
            : (ThemeState.mode === "preset" ? ThemeState.presetLabel + " is applied everywhere"
                                            : "Colors come from the wallpaper")
    }

    // ── wallpapers ───────────────────────────────────────────────────────────────────────────────
    ListView {
        id: wallpaperStrip
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 24; rightMargin: 24; bottomMargin: 10 }
        height: panel.cardH + 14
        orientation: ListView.Horizontal
        spacing: panel.cardGap
        clip: true
        cacheBuffer: 600
        interactive: false
        highlightRangeMode: ListView.StrictlyEnforceRange     // keeps the selection centered, animated
        preferredHighlightBegin: (width - panel.cardW) / 2
        preferredHighlightEnd: (width + panel.cardW) / 2
        highlightMoveDuration: 320
        highlight: Item {}
        model: ThemeState.wallpapers
        opacity: panel.onWallpapers ? 1 : 0
        visible: opacity > 0.01
        enabled: panel.onWallpapers
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        delegate: WallpaperCard {
            width: panel.cardW
            height: panel.cardH
            path: model.path
            thumb: model.thumb
            ready: model.ready
            selected: index === ThemeState.selectedIndex
            current: model.path === ThemeState.currentWallpaper
            onChosen: {
                ThemeState.selectedIndex = index
                panel.forceActiveFocus()
                ThemeState.selectAndApply()
            }
        }
    }

    // ── themes ───────────────────────────────────────────────────────────────────────────────────
    ListView {
        id: themeStrip
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 24; rightMargin: 24; bottomMargin: 10 }
        height: panel.cardH + 14
        orientation: ListView.Horizontal
        spacing: panel.cardGap
        clip: true
        interactive: false
        highlightRangeMode: ListView.StrictlyEnforceRange     // keeps the selection centered, animated
        preferredHighlightBegin: (width - panel.cardW) / 2
        preferredHighlightEnd: (width + panel.cardW) / 2
        highlightMoveDuration: 320
        highlight: Item {}
        model: ThemeState.themeCards.length
        opacity: panel.onWallpapers ? 0 : 1
        visible: opacity > 0.01
        enabled: !panel.onWallpapers
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        delegate: ThemeCard {
            readonly property var card: ThemeState.themeCards[index]
            width: panel.cardW
            height: panel.cardH
            info: card
            cursor: index === ThemeState.themeCursor
            applied: card.auto ? ThemeState.mode === "auto" : (ThemeState.mode === "preset" && ThemeState.preset === card.name)
            wallpaperThumb: ThemeState.currentThumb
            onChosen: {
                ThemeState.themeCursor = index
                panel.forceActiveFocus()
                ThemeState.applyThemeCard()
            }
        }
    }

    // wheel / trackpad: every ~60px of scrolling moves the selection one card
    property real wheelAccum: 0
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
            var d = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : (wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : (wheel.angleDelta.x !== 0 ? wheel.angleDelta.x / 2 : wheel.angleDelta.y / 2))
            panel.wheelAccum += d
            var steps = Math.trunc(panel.wheelAccum / 60)
            if (steps !== 0) {
                panel.wheelAccum -= steps * 60
                var count = panel.onWallpapers ? ThemeState.wallpapers.count : ThemeState.themeCards.length
                if (panel.onWallpapers) ThemeState.selectedIndex = Math.max(0, Math.min(ThemeState.selectedIndex - steps, count - 1))
                else ThemeState.themeCursor = Math.max(0, Math.min(ThemeState.themeCursor - steps, count - 1))
            }
            wheel.accepted = true
        }
    }
}
