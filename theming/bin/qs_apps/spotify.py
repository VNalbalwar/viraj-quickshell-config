"""Spotify via spicetify: writes the `wallust` color scheme and reloads the running client (needs --remote-debugging-port=8089 in its launcher).
Needs the one-time setup in theming/extras/spotify-setup.sh (spicetify-cli + a patched Spotify)."""
import base64
import json
import os
import shutil
import socket
import subprocess
import urllib.request

from .palette import hexs, is_dark, mix, rgb, shade

HOME = os.path.expanduser("~")
THEME_DIR = os.path.join(HOME, ".config/spicetify/Themes/wallust")


def hx(c):
    return c.lstrip("#").lower()


def color_ini(p):
    bg, fg = p["background"], p["foreground"]
    s = lambda a: shade(p, bg, a)
    c = {
        "text": fg, "subtext": mix(bg, fg, 0.7), "main": bg, "main-elevated": s(0.06),
        "highlight": s(0.10), "highlight-elevated": s(0.14), "sidebar": s(0.03), "player": s(0.04),
        "card": s(0.07), "shadow": mix(bg, "#000000", 0.4), "selected-row": fg, "button": p["color4"],
        "button-active": p["color12"], "button-disabled": s(0.25), "tab-active": s(0.10),
        "notification": s(0.10), "notification-error": p["color1"], "equalizer": p["color4"], "misc": s(0.14),
    }
    return "[wallust]\n" + "\n".join(f"{k:<20}= {hx(v)}" for k, v in c.items()) + "\n"


def apply(p):
    exe = shutil.which("spicetify") or os.path.join(HOME, ".local/bin/spicetify")
    if not os.access(exe, os.X_OK):
        return                                         # not set up: nothing to do (see spotify-setup.sh)
    os.makedirs(THEME_DIR, exist_ok=True)
    ini = os.path.join(THEME_DIR, "color.ini")
    new = color_ini(p)
    try:
        if open(ini).read() == new:
            return
    except OSError:
        pass
    with open(ini, "w") as f:
        f.write(new)
    css = os.path.join(THEME_DIR, "user.css")
    if not os.path.exists(css):
        open(css, "w").close()
    # keep the files current for the next start, and recolor the running Spotify smoothly (no reload)
    subprocess.run([exe, "-q", "refresh", "-s"], capture_output=True, timeout=20)
    live_recolor(p)


def live_recolor(p):
    """Set spicetify's --spice-* variables on the running page, with a short CSS transition so the
    colors fade into each other instead of flashing. Needs Spotify started with --remote-debugging-port=8089."""
    vars_ = {}
    for line in color_ini(p).splitlines()[1:]:
        k, _, v = line.partition("=")
        h = v.strip()
        if h:
            vars_[k.strip()] = (h, ", ".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4)))
    js = ("(() => { const r = document.documentElement;"
          " let st = document.getElementById('qs-fade');"
          " if (!st) { st = document.createElement('style'); st.id = 'qs-fade'; document.head.appendChild(st); }"
          " st.textContent = '*, *::before, *::after { transition: background-color .7s ease, color .7s ease,"
          " border-color .7s ease, fill .7s ease, stroke .7s ease, box-shadow .7s ease !important; }';"
          " const v = %s;"
          " for (const k in v) { r.style.setProperty('--spice-' + k, '#' + v[k][0]); r.style.setProperty('--spice-rgb-' + k, v[k][1]); }"
          " clearTimeout(window.__qsFade); window.__qsFade = setTimeout(() => { st.textContent = ''; }, 1100); })()") % json.dumps(vars_)
    cdp("Runtime.evaluate", {"expression": js})


def cdp(method, params, port=8089):
    """Send one Chrome DevTools command to Spotify's UI page over a minimal websocket."""
    try:
        pages = json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=2))
        ws = next(pg["webSocketDebuggerUrl"] for pg in pages if pg.get("type") == "page" and "xpui" in pg.get("url", ""))
    except (OSError, StopIteration, ValueError):
        return                                          # Spotify isn't running (or wasn't started with the port)
    path = ws.split(f":{port}", 1)[1]
    s = socket.create_connection(("127.0.0.1", port), timeout=3)
    key = base64.b64encode(os.urandom(16)).decode()
    s.sendall((f"GET {path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
               f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
    s.recv(4096)
    payload = json.dumps({"id": 1, "method": method, "params": params}).encode()
    mask = os.urandom(4)
    n = len(payload)
    head = bytes([0x81, 0x80 | n]) if n < 126 else bytes([0x81, 0x80 | 126]) + n.to_bytes(2, "big") if n < 65536 else bytes([0x81, 0x80 | 127]) + n.to_bytes(8, "big")
    s.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))
    try:
        s.settimeout(1); s.recv(4096)                   # let it run before we hang up
    except OSError:
        pass
    s.close()
