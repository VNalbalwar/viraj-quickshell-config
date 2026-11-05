"""Small color helpers shared by the app hooks."""
import colorsys


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexs(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, round(v))) for v in c)


def luminance(h):
    r, g, b = (v / 255 for v in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def is_dark(pal):
    return luminance(pal["background"]) < 0.5


def mix(a, b, t):
    """t=0 -> a, t=1 -> b"""
    ra, rb = rgb(a), rgb(b)
    return hexs(tuple(x + (y - x) * t for x, y in zip(ra, rb)))


def shade(pal, base, amount):
    """a step away from `base` toward the foreground: lighter on dark themes, darker on light ones"""
    return mix(base, pal["foreground"], amount)


def with_lightness(h, delta):
    r, g, b = (v / 255 for v in rgb(h))
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb(hh, max(0, min(1, ll + delta)), ss)
    return hexs((r * 255, g * 255, b * 255))


def readable_on(bg, light="#FFFFFF", dark="#000000"):
    return dark if luminance(bg) > 0.55 else light
