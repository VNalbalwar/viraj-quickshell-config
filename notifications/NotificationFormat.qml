pragma Singleton
import Quickshell
import QtQuick
import "../theme"

// Turns a raw notification into what is worth reading, in the order you want to read it.
//
// Chrome (and other browsers) deliver web notifications as:  title = chat / subject,
// body = "<site> ~ <sender>: <message>". Left as is, the site name and URLs push the actual message out
// of view. Here the sender comes first, then the message, with the site as a small label and its logo
// as the icon (so WhatsApp looks like WhatsApp, not a generic avatar).
Singleton {
    id: root

    // site -> { name, icon, chat }  (chat = "Sender: message" style bodies)
    readonly property var sites: ({
        "web.whatsapp.com":      { name: "WhatsApp", icon: "whatsapp", chat: true },
        "web.telegram.org":      { name: "Telegram", icon: "telegram", chat: true },
        "discord.com":           { name: "Discord", icon: "discord", chat: true },
        "app.slack.com":         { name: "Slack", icon: "slack", chat: true },
        "teams.microsoft.com":   { name: "Teams", icon: "teams", chat: true },
        "teams.live.com":        { name: "Teams", icon: "teams", chat: true },
        "outlook.office.com":    { name: "Outlook", icon: "ms-outlook", chat: false },
        "outlook.office365.com": { name: "Outlook", icon: "ms-outlook", chat: false },
        "outlook.live.com":      { name: "Outlook", icon: "ms-outlook", chat: false },
        "mail.google.com":       { name: "Gmail", icon: "gmail", chat: false },
        "calendar.google.com":   { name: "Calendar", icon: "google-calendar", chat: false },
        "github.com":            { name: "GitHub", icon: "github", chat: false },
        "www.youtube.com":       { name: "YouTube", icon: "youtube", chat: false },
        "www.linkedin.com":      { name: "LinkedIn", icon: "linkedin", chat: false },
        "www.instagram.com":     { name: "Instagram", icon: "instagram", chat: true }
    })

    function isBrowser(app) { return /chrome|chromium|brave|vivaldi|edge|opera|firefox/i.test(app || "") }

    function clip(s, n) { return s.length > n ? s.slice(0, n - 1).trimEnd() + "…" : s }

    // -> { label, title, body, plain, icon }
    function format(n) {
        var summary = n.summary || ""
        var body = n.body || ""
        var out = { label: n.appName || "", title: summary, body: body, plain: false, icon: "" }

        // screenshots / recordings: the file name and folder, not a wall of path
        if (/^(hyprshot|capture)$/i.test(n.appName || "")) {
            var f = NotificationState.capturePath(n.appName, body, n.appIcon)
            if (f !== "") {
                var slash = f.lastIndexOf("/")
                out.label = "Capture"
                out.body = f.slice(slash + 1) + "  ·  " + f.slice(0, slash).replace(/^\/home\/[^\/]+/, "~") + "  ·  click to show"
                out.plain = true
                return out
            }
        }

        var m = null
        if (isBrowser(n.appName)) {
            m = body.match(/^\s*([a-z0-9][a-z0-9.-]*\.[a-z]{2,})\s*[~|·–—-]\s*([\s\S]*)$/i)          // "site ~ message"
            if (!m) {                                                                                     // "web.whatsapp.com Sticker": no separator
                var bare = body.match(/^\s*([a-z0-9][a-z0-9.-]*\.[a-z]{2,})\s+([\s\S]*)$/i)
                if (bare && sites[bare[1].toLowerCase()]) m = bare
            }
        }
        if (!m) return out

        var host = m[1].toLowerCase()
        var rest = m[2]
        var site = sites[host]
        if (!site) {
            var parts = host.replace(/^www\./, "").split(".")
            var word = parts.length > 1 ? parts[parts.length - 2] : parts[0]
            site = { name: word.charAt(0).toUpperCase() + word.slice(1), icon: "", chat: false }
        }

        // links: "https://teams.microsoft.com/meet/…long…" -> "teams.microsoft.com ↗"
        rest = rest.replace(new RegExp("https?://([^\\s/]+)\\S*", "g"), "$1 ↗").replace(/\s+/g, " ").trim()

        var title = summary
        var chat = ""
        if (site.chat) {
            var sm = rest.match(/^([^:\n]{1,32}):\s+([\s\S]+)$/)
            if (sm && summary !== sm[1]) {               // group chat: "Sender: message"
                title = sm[1]
                chat = summary
                rest = sm[2]
            }
        }

        out.label = site.name + (chat !== "" ? "  ·  " + clip(chat, 28) : "")
        out.title = clip(title, 60)
        out.body = clip(rest, 170)
        out.plain = true
        out.icon = site.icon !== "" ? Icons.source([site.icon]) : ""
        return out
    }
}
