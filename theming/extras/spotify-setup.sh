#!/bin/bash
# One-time setup so Spotify follows the wallpaper / theme (needs sudo once, so you run it).
#   spicetify patches Spotify's client; after this, qs-theme refreshes the running Spotify on every change.
set -euo pipefail
echo "1/4 installing spicetify-cli (AUR)"
command -v spicetify >/dev/null || yay -S --needed spicetify-cli
echo "2/4 letting your user patch Spotify (needs sudo, one time)"
sudo chmod a+wr /opt/spotify
sudo chmod a+wr -R /opt/spotify/Apps
echo "3/4 creating the Wallust theme (colors come from qs-theme)"
spicetify >/dev/null 2>&1 || true
mkdir -p ~/.config/spicetify/Themes/wallust
"$(dirname "$0")/../bin/qs-theme" auto            # writes color.ini
echo "4/4 applying"
spicetify config current_theme wallust color_scheme wallust
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1
spicetify backup apply
echo
echo "Done. Close and reopen Spotify once; after that it recolors live."
