#!/bin/bash
# One-time setup so Chrome follows the wallpaper / theme live (needs sudo once, so you run it).
# Chrome reads "managed policies" from a root-owned folder and applies BrowserThemeColor to open windows
# immediately. This hands that one folder to your user, so qs-theme can update it without sudo.
# Side effect: Chrome shows "Managed by your organization" in its menu / settings - that is just this policy file.
set -euo pipefail
DIR=/etc/opt/chrome/policies/managed
sudo mkdir -p "$DIR"
sudo chown "$USER" "$DIR"
"$(dirname "$0")/../bin/qs-theme" auto          # writes the first policy file
echo
echo "Done. Open chrome://policy and press Reload policies once to check: BrowserThemeColor should be listed."
echo "From now on Chrome recolors with every wallpaper / theme change."
