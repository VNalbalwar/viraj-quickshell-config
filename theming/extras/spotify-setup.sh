#!/bin/bash
# One-time setup so Spotify follows the wallpaper / theme (needs sudo once, so you run it).
#   spicetify patches Spotify's client; after this, qs-theme refreshes the running Spotify on every change.
set -euo pipefail
echo "1/4 installing spicetify-cli (official prebuilt release, no compiling)"
# The AUR package builds with pnpm, which can't resolve DNS inside makepkg here; the release binary is the same program.
if ! command -v spicetify >/dev/null; then
    VER=2.46.4
    TMP="$(mktemp -d)"
    curl -fsSL "https://github.com/spicetify/cli/releases/download/v${VER}/spicetify-${VER}-linux-amd64.tar.gz" -o "$TMP/s.tgz"
    mkdir -p ~/.local/bin
    tar -xzf "$TMP/s.tgz" -C "$TMP"
    install -m755 "$TMP/spicetify" ~/.local/bin/spicetify
    for d in jsHelper CustomApps Extensions Themes; do [ -d "$TMP/$d" ] && cp -r "$TMP/$d" ~/.local/bin/; done   # spicetify looks for these next to itself
    rm -rf "$TMP"
fi
export PATH="$HOME/.local/bin:$PATH"
spicetify --version
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
# live reload needs Spotify started with a debugging port: add it to your launcher entry
mkdir -p ~/.local/share/applications
if [ -f ~/.local/share/applications/spotify.desktop ]; then
    sed -i 's|^Exec=spotify |Exec=spotify --remote-debugging-port=8089 |; s|--remote-debugging-port=8089 --remote-debugging-port=8089|--remote-debugging-port=8089|' ~/.local/share/applications/spotify.desktop
fi
echo
echo "Done. Close and reopen Spotify once; after that it recolors live."
