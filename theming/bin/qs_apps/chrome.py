"""Google Chrome (and Chromium-family browsers): sets the browser theme color through a managed policy.
Chrome watches its policy folder and applies BrowserThemeColor / BrowserColorScheme to open windows
immediately, with its own color transition. The folder is root-owned by default; the one-time
theming/extras/chrome-setup.sh hands it to your user so no sudo is needed after that."""
import json
import os

from .palette import is_dark, mix

FOLDERS = [
    "/etc/opt/chrome/policies/managed",        # Google Chrome
    "/etc/chromium/policies/managed",          # Chromium
    "/etc/brave/policies/managed",             # Brave
]
FILE = "qs-theme.json"


def apply(p):
    policy = {
        # a tasteful blend of the background and the accent: Chrome builds the whole UI palette from it
        "BrowserThemeColor": mix(p["background"], p["color4"], 0.32),
        "BrowserColorScheme": "dark" if is_dark(p) else "light",
    }
    text = json.dumps(policy, indent=1)
    for d in FOLDERS:
        if not os.access(d, os.W_OK):
            continue                                       # not set up for this browser: skip quietly
        path = os.path.join(d, FILE)
        try:
            if open(path).read() == text:
                continue
        except OSError:
            pass
        with open(path + ".tmp", "w") as f:
            f.write(text)
        os.replace(path + ".tmp", path)
