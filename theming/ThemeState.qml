pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../theme"

// Wallpaper + theme state for the notch panel. All the real work is done by bin/qs-theme; this just
// lists things, runs it, and remembers what's selected.
//   wallpaper = the picture      theme = the colors (a named palette, or "follow the wallpaper")
Singleton {
    id: root

    readonly property string bin: "/home/viraj/.config/quickshell/theming/bin/qs-theme"
    readonly property var wallpaperDirs: ["/home/viraj/Pictures/Hyprland-Wallpapers", "/home/viraj/Pictures/Wallpapers"]

    property bool visible: false
    property string tab: "wallpapers"          // "wallpapers" | "themes"

    // wallpapers
    property ListModel wallpapers: ListModel {}    // { path, thumb, ready }
    property int selectedIndex: 0
    property string currentWallpaper: ""
    property bool buildingThumbs: false
    readonly property string currentThumb: {
        for (var i = 0; i < wallpapers.count; i++) {
            var w = wallpapers.get(i)
            if (w.path === currentWallpaper) return w.ready ? w.thumb : ""
        }
        return ""
    }

    // themes
    property var presets: []                   // curated list from presets.json
    property var themeCards: []                // "follow wallpaper" card first, then the presets
    property int themeCursor: 0
    property string mode: "auto"               // "auto" = colors follow the wallpaper | "preset"
    property string preset: ""
    readonly property string presetLabel: {
        for (var i = 0; i < presets.length; i++)
            if (presets[i].name === preset) return presets[i].label
        return preset
    }

    function show() {
        refreshStatus()
        refreshList()
        selectCurrent()
        if (presets.length === 0) loadPresets()
        root.visible = true
    }
    function hide() { root.visible = false }
    function toggle() { if (root.visible) hide(); else show() }
    function nextTab() { root.tab = root.tab === "wallpapers" ? "themes" : "wallpapers" }

    // ── applying (queued, newest wins per kind) ──────────────────────────────────────────────────
    property var queue: []
    function enqueue(args) {
        queue = queue.filter(function(q) { return q[0] !== args[0] }).concat([args])
        if (!applyProcess.running) runNext()
    }
    function runNext() {
        if (queue.length === 0) return
        var a = queue[0]
        queue = queue.slice(1)
        applyProcess.command = [root.bin].concat(a)
        applyProcess.running = true
    }

    function applyWallpaper(path) {
        if (!path) return
        root.currentWallpaper = path
        enqueue(["wallpaper", path])
    }
    function selectAndApply() {
        if (wallpapers.count === 0) return
        applyWallpaper(wallpapers.get(selectedIndex).path)
        hide()
    }

    function applyPreset(name) {
        root.mode = "preset"
        root.preset = name
        enqueue(["preset", name])
    }
    function followWallpaper() {
        root.mode = "auto"
        root.preset = ""
        enqueue(["auto"])
    }
    function applyThemeCard() {
        var c = themeCards[themeCursor]
        if (!c) return
        if (c.auto) followWallpaper(); else applyPreset(c.name)
    }

    // ── reading state ────────────────────────────────────────────────────────────────────────────
    function refreshStatus() { statusProcess.running = false; statusProcess.running = true }
    function refreshList() { listProcess.running = false; listProcess.running = true }

    function loadPresets() { presetProcess.running = false; presetProcess.running = true }

    function syncList(items) {
        var same = items.length === wallpapers.count
        for (var i = 0; same && i < items.length; i++)
            if (wallpapers.get(i).path !== items[i].path) same = false
        if (same) {                                   // just thumbnails becoming ready: update in place, view doesn't move
            for (var k = 0; k < items.length; k++)
                if (wallpapers.get(k).ready !== items[k].ready) wallpapers.setProperty(k, "ready", items[k].ready)
        } else {
            wallpapers.clear()
            for (var j = 0; j < items.length; j++) wallpapers.append(items[j])
            var idx = -1
            for (var n = 0; n < items.length; n++) if (items[n].path === root.currentWallpaper) idx = n
            root.selectedIndex = idx >= 0 ? idx : 0
        }
        var missing = false
        for (var m = 0; m < items.length; m++) if (!items[m].ready) { missing = true; break }
        if (missing && !thumbProcess.running) { root.buildingThumbs = true; thumbProcess.running = true }
    }

    Process {
        id: applyProcess
        onExited: { Colors.reload(); root.refreshStatus(); root.runNext() }
    }

    Process {
        id: statusProcess
        command: [root.bin, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var s = JSON.parse(text)
                    root.mode = s.mode
                    root.preset = s.preset
                    if (s.wallpaper) root.currentWallpaper = s.wallpaper
                    if (s.wallpaper && !root.visible) root.selectCurrent()     // a status that arrives after the list
                    root.rebuildCards()
                } catch (e) {}
            }
        }
    }

    Process {
        id: listProcess
        command: [root.bin, "list"].concat(root.wallpaperDirs)
        stdout: StdioCollector {
            onStreamFinished: { if (text.trim() === "") return; try { root.syncList(JSON.parse(text)) } catch (e) { console.log("theme list:", e) } }
        }
    }

    Process {
        id: thumbProcess
        command: [root.bin, "thumbs"].concat(root.wallpaperDirs)
        onExited: { root.buildingThumbs = false; root.refreshList() }
    }

    // while previews are being made, pick them up as they appear
    Timer {
        interval: 1500
        repeat: true
        running: root.buildingThumbs && root.visible
        onTriggered: root.refreshList()
    }

    Process {
        id: presetProcess
        command: [root.bin, "presets"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.presets = JSON.parse(text); root.rebuildCards() } catch (e) {} }
        }
    }

    function selectCurrent() {
        for (var i = 0; i < wallpapers.count; i++)
            if (wallpapers.get(i).path === currentWallpaper) { root.selectedIndex = i; return }
    }

    function rebuildCards() {
        var cards = [{ auto: true, name: "", label: "Follow wallpaper", dark: true, bg: "", fg: "", colors: [] }]
        cards = cards.concat(presets)
        root.themeCards = cards
        var idx = 0
        for (var i = 0; i < cards.length; i++)
            if ((mode === "auto" && cards[i].auto) || (mode === "preset" && cards[i].name === preset)) idx = i
        root.themeCursor = idx
    }

    Component.onCompleted: { refreshStatus(); loadPresets() }

    IpcHandler {
        target: "wallpaper-switcher"
        function toggle() { root.toggle() }
        function open() { root.tab = "wallpapers"; root.show() }
        function hide() { root.hide() }
    }

    // qs ipc call theme toggle | show | preset <Name> | wallpaper <path> | auto
    IpcHandler {
        target: "theme"
        function toggle() { root.tab = "themes"; root.toggle() }
        function open() { root.tab = "themes"; root.show() }
        function hide() { root.hide() }
        function preset(name: string) { root.applyPreset(name) }
        function wallpaper(path: string) { root.applyWallpaper(path) }
        function auto() { root.followWallpaper() }
    }
}
