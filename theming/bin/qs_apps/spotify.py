"""Spotify via spicetify: writes the `wallust` color scheme and refreshes the running client.
Needs the one-time setup in theming/extras/spotify-setup.sh (spicetify-cli + a patched Spotify)."""
import os
import shutil
import subprocess

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
    # live: re-inject colors into the running Spotify (falls back to nothing if it isn't running)
    subprocess.run([exe, "-q", "refresh", "-s"], capture_output=True, timeout=20)
