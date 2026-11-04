pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
//  MediaState — EVERYTHING that is making sound, not just what has a media player.
//
//  Why: Chrome registers ONE media player (MPRIS) no matter how many tabs play, so 3 YouTube
//  tabs + Spotify showed up as 2 players. The audio layer knows better: every playing tab is its
//  own output stream. So the list is:
//     * every MPRIS player (full controls: play/pause, title, artist, art), plus
//     * every audio stream that isn't already explained by a PLAYING player
//       (e.g. the 2nd and 3rd Chrome tab) - those get a mute button, since only the app itself
//       can pause them.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property var streams: []                 // live pactl sink-inputs (compact), updated only on change
    property string streamsKey: ""

    readonly property var rows: root.buildRows(Mpris.players.values, root.streams, ChromeTabs.tabs)

    // The list's model is just the ORDERED KEYS, which only change when a source appears or goes
    // away. Rows read their live data through rowFor(). Result: muting / pausing / retitling a row
    // doesn't rebuild the list, so it doesn't jump back to the top under your pointer.
    property var keys: []
    property string keysKey: ""
    onRowsChanged: {
        var k = rows.map(function(r) { return r.key })
        var s = JSON.stringify(k)
        if (s !== root.keysKey) { root.keysKey = s; root.keys = k }
    }

    readonly property var emptyRow: ({ key: "", kind: "", player: null, app: "", title: "", subtitle: "", art: "",
                                       playing: false, muted: false, streamIndex: -1, browser: false, tabId: -1 })
    function rowFor(key) {
        for (var i = 0; i < rows.length; i++)
            if (rows[i].key === key) return rows[i]
        return emptyRow
    }
    readonly property int count: rows.length
    readonly property int playingCount: rows.filter(function(r) { return r.playing }).length

    function norm(s) { return (s || "").toLowerCase().replace(/[^a-z0-9]/g, "") }

    // generic stream names carry no information
    function usefulName(n) {
        var x = (n || "").trim()
        return (x === "" || /^(playback|audio stream|audiostream|alsa playback|output|stream)$/i.test(x)) ? "" : x
    }

    // does stream `s` belong to player `p`? (names are fuzzy: "Google Chrome" / chrome / google-chrome)
    function sameApp(p, s) {
        var pk = [norm(p.identity), norm(p.desktopEntry)].filter(function(k) { return k.length >= 3 })
        var sk = [norm(s.app), norm(s.bin)].filter(function(k) { return k.length >= 3 })
        for (var i = 0; i < pk.length; i++)
            for (var j = 0; j < sk.length; j++)
                if (pk[i].indexOf(sk[j]) !== -1 || sk[j].indexOf(pk[i]) !== -1) return true
        return false
    }

    // Chrome itself (not Brave/Edge): its players and its one mixed stream
    function isChrome(a, b) {
        var names = [norm(a), norm(b)]
        for (var i = 0; i < names.length; i++)
            if (names[i] === "chrome" || names[i].indexOf("googlechrome") !== -1) return true
        return false
    }

    function buildRows(players, streams, tabs) {
        // With the tab bridge connected and tabs reporting sound, every tab is its own row, so
        // Chrome's single (active-tab-only) player and its one mixed stream would only duplicate them.
        var haveTabs = tabs.length > 0
        var live = streams.filter(function(s) { return !s.corked && !(haveTabs && root.isChrome(s.app, s.bin)) })
        var used = {}
        var out = []

        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (haveTabs && root.isChrome(p.identity, p.desktopEntry)) continue
            var streamIndex = -1
            var muted = false
            if (p.isPlaying) {                       // a playing player accounts for ONE of its app's streams
                for (var k = 0; k < live.length; k++) {
                    if (!used[live[k].index] && root.sameApp(p, live[k])) {
                        used[live[k].index] = true
                        streamIndex = live[k].index
                        muted = live[k].mute
                        break
                    }
                }
            }
            out.push({
                key: "m" + i, kind: "mpris", player: p, app: p.identity,
                title: p.trackTitle || "Unknown title", subtitle: p.trackArtist || "",
                art: p.trackArtUrl || "", playing: p.isPlaying, muted: muted, streamIndex: streamIndex,
                // Chromium browsers mix ALL tabs into one audio stream and report one media session,
                // so nothing outside the browser can tell the tabs apart
                browser: /chrom|brave|edge|opera|vivaldi/i.test((p.identity || "") + " " + (p.desktopEntry || ""))
            })
        }

        // one row per Chrome tab that is making sound (or that we paused and can resume)
        for (var ti = 0; ti < tabs.length; ti++) {
            var tab = tabs[ti]
            out.push({
                key: "t" + tab.id, kind: "tab", player: null, app: ChromeTabs.browser || "Chrome",
                title: tab.title || "Untitled tab", subtitle: ChromeTabs.hostOf(tab.url),
                art: tab.favicon || "", playing: !!tab.audible, muted: !!tab.muted,
                streamIndex: -1, tabId: tab.id, browser: false
            })
        }

        var extra = 0
        for (var m = 0; m < live.length; m++) {
            if (used[live[m].index]) continue
            extra++
            out.push({
                key: "s" + live[m].index, kind: "stream", player: null, app: live[m].app,
                title: root.usefulName(live[m].name) || (live[m].app + " · audio " + extra),
                subtitle: "no player controls · can be muted",
                art: "", playing: true, muted: live[m].mute, streamIndex: live[m].index, tabId: -1
            })
        }

        // NOTE: deliberately NOT sorted by "playing" - rows must stay put, otherwise they jump
        // around under the pointer the moment you press a button.
        return out
    }

    // play / pause a player (rows that have one)
    function togglePlay(row) {
        if (row.kind === "tab") ChromeTabs.togglePause(row)
        else if (row.kind === "mpris" && row.player && row.player.canTogglePlaying) row.player.togglePlaying()
    }

    // mute / unmute that one source (its audio stream), whether or not it has a player.
    // NOTE: WirePlumber remembers volume/mute PER APP NAME, so a muted Chrome tab makes the next
    // Chrome tab start muted too - the row says "muted" and its button un-mutes it.
    function toggleMute(row) {
        if (row.kind === "tab") { ChromeTabs.setMuted(row.tabId, !row.muted); return }
        if (row.streamIndex < 0) return
        muteProcess.command = ["pactl", "set-sink-input-mute", String(row.streamIndex), "toggle"]
        muteProcess.running = false
        muteProcess.running = true
    }

    Process { id: muteProcess; onExited: root.refresh() }

    function refresh() {
        streamsProcess.running = false
        streamsProcess.running = true
    }

    Process {
        id: streamsProcess
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var compact = JSON.parse(text).map(function(i) {
                        var p = i.properties || {}
                        return {
                            index: i.index, corked: !!i.corked, mute: !!i.mute,
                            app: p["application.name"] || p["application.process.binary"] || "Audio",
                            bin: p["application.process.binary"] || "",
                            name: p["media.name"] || ""
                        }
                    })
                    var key = JSON.stringify(compact)
                    if (key !== root.streamsKey) {          // only touch the model when something changed
                        root.streamsKey = key
                        root.streams = compact
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
