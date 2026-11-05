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

Apps that follow the colors: the shell, kitty (and every open terminal, live), Hyprland borders (live), GTK3 + dark/light
switch, cava, hyprlock variables (`~/.cache/wallust/colors-hyprlock.conf`). Add an app = a template + one line in `wallust/wallust.toml`.

CLI: `qs-theme wallpaper <file>` · `qs-theme preset Nord` · `qs-theme auto` · `qs-theme status`
(all ~400 wallust themes work: `wallust theme list`). IPC: `qs ipc call theme preset Nord`.
