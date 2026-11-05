# Wallpaper + theme switching

Everything lives here; nothing about it is scattered any more.

| Piece | What it is |
|---|---|
| `bin/qs-theme` | the one engine: sets the wallpaper (**awww**), derives or applies colors (**wallust**), reloads apps |
| `wallust/` | wallust config + one template per app (`~/.config/wallust` points here) |
| `presets.json` | the curated themes (generated: `qs-theme index-presets`) |
| `ThemeState.qml`, `ThemePanel.qml`, `*Card.qml` | the notch panel |

**Wallpaper** = the picture. **Theme** = the colors.
- *Follow wallpaper* (default): colors are extracted from the picture (wallust).
- *Locked theme* (Catppuccin, Nord, ...): fixed colors; changing the picture leaves them alone.

Keys: `SUPER+P` wallpapers, `SUPER+SHIFT+P` themes. In the panel: ← → move, Enter apply, Tab switch page, Esc close.

Wallpapers are read from `~/Pictures/Hyprland-Wallpapers` and `~/Pictures/Wallpapers` (`wallpaperDirs` in
`ThemeState.qml`); small previews are cached in `~/.cache/qs-theme/thumbs`.

Apps that follow the colors, and how:
- Live, instantly: the shell (notch, control center, lock screen), kitty and every open terminal, Hyprland borders, cava,
  **Neovim** (every running instance, via its socket), **Zed** (select the "Wallust" theme once).
- On next start: GTK3/GTK4/libadwaita apps (Nautilus, Thunar...) - GTK has no way to reload CSS in a running app.
- After a one-time setup: **Spotify** (`theming/extras/spotify-setup.sh`, fades live) and **Chrome** (`theming/extras/chrome-setup.sh`, live via a browser policy).
- Generated, not yet used: hyprlock color variables (the real lock screen is `lockscreen/`, in QML).
Each app is a small file in `bin/qs_apps/`; add one to `MODULES` in `bin/qs_apps/__init__.py`. Retired Waybar/swaync/Rofi
templates are kept in `wallust/unused/`.

CLI: `qs-theme wallpaper <file>` · `qs-theme preset Nord` · `qs-theme auto` · `qs-theme status`
(all ~400 wallust themes work: `wallust theme list`). IPC: `qs ipc call theme preset Nord`.
