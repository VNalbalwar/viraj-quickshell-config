#!/bin/bash
# Builds the live-reload GIO module and turns it on for every GTK3 / GTK4 app you start from now on.
# No sudo, no system files: it builds into ~/.local/lib and adds one environment line for your session.
#   ./install.sh            build + install + enable        ./install.sh --remove   undo it
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/lib/qs-gtk-live"
UWSM_ENV="$HOME/.config/uwsm/env"
HYPR_ENV="$HOME/.config/hypr/modules/env.lua"
LINE='export GIO_EXTRA_MODULES="$HOME/.local/lib/qs-gtk-live${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}"   # qs-gtk-live: live gtk.css reload'
LUA='hl.env("GIO_EXTRA_MODULES", os.getenv("HOME") .. "/.local/lib/qs-gtk-live") -- qs-gtk-live: live gtk.css reload'

if [ "${1:-}" = "--remove" ]; then
    sed -i '/qs-gtk-live/d' "$UWSM_ENV" "$HYPR_ENV" 2>/dev/null || true
    rm -rf "$DEST"
    systemctl --user unset-environment GIO_EXTRA_MODULES 2>/dev/null || true
    echo "removed. Apps that are already open keep it until they are restarted."
    exit 0
fi

make -C "$HERE" -s
mkdir -p "$DEST"
install -m755 "$HERE/build/libqs-gtk-live.so" "$DEST/"
echo "installed $DEST/libqs-gtk-live.so"

grep -q qs-gtk-live "$UWSM_ENV" 2>/dev/null || { mkdir -p "$(dirname "$UWSM_ENV")"; printf '\n%s\n' "$LINE" >> "$UWSM_ENV"; echo "added to $UWSM_ENV (whole session, from the next login)"; }
grep -q qs-gtk-live "$HYPR_ENV" 2>/dev/null || { printf '\n%s\n' "$LUA" >> "$HYPR_ENV"; echo "added to $HYPR_ENV"; }

# this session, right now: programs started from here on (launcher, shortcuts, D-Bus activated apps) get it
systemctl --user set-environment GIO_EXTRA_MODULES="$DEST" 2>/dev/null || true
dbus-update-activation-environment --systemd GIO_EXTRA_MODULES="$DEST" 2>/dev/null || true

echo
echo "Done. GTK apps you open from now on follow theme changes live. Ones already open need one restart."
echo "(Flatpak apps are sandboxed and don't see it.)"
