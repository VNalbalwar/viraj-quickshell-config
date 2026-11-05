"""Zed: generates a `Wallust` theme file. Zed watches its themes folder, so a selected Wallust theme
changes live; select it once (command palette -> "theme selector: toggle")."""
import json
import os

from .palette import is_dark, mix, shade

HOME = os.path.expanduser("~")
THEME = os.path.join(HOME, ".config/zed/themes/wallust.json")


def theme(p):
    bg, fg = p["background"], p["foreground"]
    dark = is_dark(p)
    s = lambda a: shade(p, bg, a)
    a = lambda c, al="ff": c + al
    muted = mix(bg, fg, 0.55)
    style = {
        "background": s(0.03), "border": s(0.12), "border.variant": s(0.08), "border.focused": p["color4"],
        "border.selected": p["color4"], "border.transparent": "#00000000", "border.disabled": s(0.08),
        "elevated_surface.background": s(0.06), "surface.background": s(0.04),
        "element.background": s(0.07), "element.hover": s(0.12), "element.active": s(0.16),
        "element.selected": s(0.14), "element.disabled": s(0.05),
        "ghost_element.background": "#00000000", "ghost_element.hover": s(0.08), "ghost_element.active": s(0.12),
        "ghost_element.selected": s(0.10), "ghost_element.disabled": s(0.04),
        "text": fg, "text.muted": muted, "text.placeholder": mix(bg, fg, 0.4), "text.disabled": mix(bg, fg, 0.3),
        "text.accent": p["color12"], "icon": fg, "icon.muted": muted, "icon.disabled": mix(bg, fg, 0.3),
        "icon.placeholder": muted, "icon.accent": p["color12"],
        "status_bar.background": s(0.03), "title_bar.background": s(0.03), "title_bar.inactive_background": bg,
        "toolbar.background": bg, "tab_bar.background": s(0.03), "tab.inactive_background": s(0.03),
        "tab.active_background": bg, "search.match_background": mix(bg, p["color4"], 0.35),
        "panel.background": s(0.03), "panel.focused_border": p["color4"],
        "pane.focused_border": p["color4"], "scrollbar.thumb.background": s(0.15),
        "scrollbar.thumb.hover_background": s(0.22), "scrollbar.thumb.border": s(0.15),
        "scrollbar.track.background": "#00000000", "scrollbar.track.border": s(0.06),
        "editor.foreground": fg, "editor.background": bg, "editor.gutter.background": bg,
        "editor.subheader.background": s(0.04), "editor.active_line.background": s(0.05),
        "editor.highlighted_line.background": s(0.07), "editor.line_number": mix(bg, fg, 0.35),
        "editor.active_line_number": fg, "editor.invisible": mix(bg, fg, 0.25), "editor.wrap_guide": s(0.08),
        "editor.active_wrap_guide": s(0.14), "editor.document_highlight.read_background": mix(bg, p["color4"], 0.2),
        "editor.document_highlight.write_background": mix(bg, p["color4"], 0.3),
        "terminal.background": bg, "terminal.foreground": fg, "terminal.ansi.background": bg,
        "conflict": p["color3"], "created": p["color2"], "deleted": p["color1"], "error": p["color1"],
        "hint": p["color6"], "info": p["color4"], "modified": p["color3"], "success": p["color2"],
        "warning": p["color3"], "predictive": mix(bg, fg, 0.4), "renamed": p["color4"], "unreachable": muted,
        "players": [{"cursor": p["color4"], "background": p["color4"], "selection": mix(bg, p["color4"], 0.3)}],
        "syntax": {
            "comment": {"color": mix(bg, fg, 0.45), "font_style": "italic"},
            "string": {"color": p["color2"]}, "keyword": {"color": p["color5"]}, "function": {"color": p["color4"]},
            "type": {"color": p["color3"]}, "number": {"color": p["color9"]}, "boolean": {"color": p["color9"]},
            "constant": {"color": p["color9"]}, "variable": {"color": fg}, "property": {"color": p["color6"]},
            "operator": {"color": p["color6"]}, "punctuation": {"color": muted}, "tag": {"color": p["color1"]},
            "attribute": {"color": p["color3"]}, "constructor": {"color": p["color3"]},
        },
    }
    for k in ("terminal.ansi.black", "terminal.ansi.red", "terminal.ansi.green", "terminal.ansi.yellow",
              "terminal.ansi.blue", "terminal.ansi.magenta", "terminal.ansi.cyan", "terminal.ansi.white"):
        i = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white").index(k.rsplit(".", 1)[1])
        style[k] = p[f"color{i}"]
        style[k.replace("ansi.", "ansi.bright_")] = p[f"color{i + 8}"]
    return {"$schema": "https://zed.dev/schema/themes/v0.2.0.json", "name": "Wallust", "author": "qs-theme",
            "themes": [{"name": "Wallust", "appearance": "dark" if dark else "light", "style": style}]}


def apply(p):
    if not os.path.isdir(os.path.dirname(THEME)):
        return
    with open(THEME + ".tmp", "w") as f:
        json.dump(theme(p), f, indent=1)
    os.replace(THEME + ".tmp", THEME)
