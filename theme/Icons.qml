pragma Singleton

import Quickshell
import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
//  Icons — find a REAL icon for an app, or say "none".
//
//  Why this exists: asking Quickshell's icon provider for a name the theme doesn't have does NOT
//  fail - it hands back a fallback icon (here: the nmgui logo), which then looks like a successful
//  load. So every candidate is checked with Quickshell.iconPath(name, true) first, and when nothing
//  verifies we return "" and the caller shows its own neutral glyph instead of someone else's logo.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    // an image source for the first candidate that is a real icon, else ""
    // (candidates: theme names, absolute paths, file:// urls)
    function source(candidates) {
        for (var i = 0; i < candidates.length; i++) {
            var c = candidates[i]
            if (!c || c === "") continue
            if (c.indexOf("file://") === 0) return c
            if (c.indexOf("/") === 0) return "file://" + c
            if (Quickshell.iconPath(c, true) !== "") return "image://icon/" + c
        }
        return ""
    }

    // an installed app's icon, trying its own icon name first and then name guesses
    function forApp(app) {
        if (!app) return ""
        var guesses = [app.icon, app.id, (app.name || "").toLowerCase().replace(/\s+/g, "-")]
        return source(guesses)
    }

    // the icon for a notification: the sender's own image/icon if it is real, otherwise the icon
    // of the app it belongs to (found through its desktop entry or by name)
    function forNotification(n) {
        if (!n) return ""
        var tries = []

        // `image` is pre-filled by Quickshell with "image://icon/<name>" when the app only sent an
        // icon NAME - that is a name to verify, not a picture. Anything else (e.g. a chat avatar or
        // image data sent with the message) is a real image and wins.
        var img = n.image || ""
        if (img.indexOf("image://icon/") === 0) tries.push(img.substring("image://icon/".length))
        else if (img !== "") return img

        tries.push(n.appIcon)
        var entry = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null
        if (entry) tries.push(entry.icon)
        var byName = n.appName ? DesktopEntries.heuristicLookup(n.appName) : null
        if (byName) tries.push(byName.icon)
        tries.push(n.desktopEntry, n.appName, (n.appName || "").toLowerCase().replace(/\s+/g, "-"))

        var res = source(tries)
        return res
    }
}
