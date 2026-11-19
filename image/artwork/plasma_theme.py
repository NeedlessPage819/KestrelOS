#!/usr/bin/env python3
"""Generates the "Kestrel" Plasma theme (DECISIONS.md D16).

Only the dock/top bar background and the task indicators are our own; Plasma takes every
other element from the default Breeze theme. Colours come from the active colour scheme
(current-color-scheme stylesheet), so light and dark mode both work.

Usage: plasma_theme.py OUTPUT_DIR [DOCK_GEOMETRY_JS]
       plasma_theme.py --dock-height
The dock geometry below is the single source for the theme, the Kestrel Dock widget
(written to DOCK_GEOMETRY_JS) and the dock height in the panel layout (--dock-height).
"""
import json
import sys
from pathlib import Path

NAME = "kestrel"
RADIUS = 18          # dock glass corner radius (the glass is 64 px tall)
GLASS_OPACITY = 0.62 # dock and top bar glass; the dock widget extends it with the same value
TILE = 2000          # edge pieces; one tile covers any panel, so tiling leaves no seams

# Kestrel Dock (DECISIONS.md D19). Icons rest at DOCK_ICON px and grow up to DOCK_ZOOM times
# under the pointer, into an empty band above (DOCK_OVERFLOW, which also holds the name
# label) and beside (DOCK_SIDE) the glass. The dock widget draws the glass itself, with RADIUS and GLASS_OPACITY from here.
DOCK_ICON = 48       # default size; System Settings > Dock allows DOCK_ICON_MIN..MAX (D27)
DOCK_ZOOM = 1.6      # default magnification, up to DOCK_ZOOM_MAX
DOCK_ICON_MIN, DOCK_ICON_MAX = 32, 72
DOCK_ZOOM_MAX = 1.8
DOCK_PAD = 6         # glass above the icons and between glass edge and first/last icon
DOCK_BOTTOM = 10     # glass below the icons, holds the running-app dot
DOCK_SPACING = 6     # between icons
DOCK_LABEL = 30      # room above a magnified icon for its name label
# The bands are sized for the largest settings, so the theme (fixed in the image) fits every
# size the dock settings allow; only the panel height follows the chosen icon size.
DOCK_OVERFLOW = round(DOCK_ICON_MAX * (DOCK_ZOOM_MAX - 1)) + 2 + DOCK_LABEL
DOCK_SIDE = round(DOCK_ICON_MAX * (DOCK_ZOOM_MAX - 1) * 1.5)


def dock_height(icon):
    return DOCK_OVERFLOW + DOCK_PAD + icon + DOCK_BOTTOM


DOCK_HEIGHT = dock_height(DOCK_ICON)

STYLE = ('<style id="current-color-scheme" type="text/css">'
         '.ColorScheme-Background{color:#eff0f1}.ColorScheme-Text{color:#232629}'
         '.ColorScheme-NegativeText{color:#da4453}.ColorScheme-Highlight{color:#3daee9}</style>')


class Svg:
    def __init__(self):
        self.body = []

    def element(self, name, x, y, w, h, shapes=()):
        # The invisible rect pins the element bounds to exactly x, y, w, h.
        self.body.append(f'<g id="{name}"><rect x="{x}" y="{y}" width="{w}" height="{h}" '
                         f'fill="#000" fill-opacity="0"/>{"".join(shapes)}</g>')

    def text(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg">{STYLE}'
                f'{"".join(self.body)}</svg>\n')


def rounded_frame(svg, prefix, x, y, radius, shape, top_band=0, side_band=0):
    """Nine pieces of a rounded rectangle; shape(name, path) draws one piece's part of it.
    top_band/side_band leave empty space above and beside the shape inside the pieces."""
    r, t, tb, sb = radius, TILE, top_band, side_band
    vx, vy = x + sb, y + tb          # top-left corner of the rounded rectangle itself
    pieces = {
        "topleft": (x, y, sb + r, tb + r, f"M{vx} {vy + r} A{r} {r} 0 0 1 {vx + r} {vy} V{vy + r} Z"),
        "top": (vx + r, y, t, tb + r, f"M{vx + r} {vy} H{vx + r + t} V{vy + r} H{vx + r} Z"),
        "topright": (vx + r + t, y, r + sb, tb + r,
                     f"M{vx + r + t} {vy} A{r} {r} 0 0 1 {vx + 2 * r + t} {vy + r} H{vx + r + t} Z"),
        "left": (x, vy + r, sb + r, t, f"M{vx} {vy + r} H{vx + r} V{vy + r + t} H{vx} Z"),
        "center": (vx + r, vy + r, t, t, f"M{vx + r} {vy + r} h{t} v{t} h{-t} Z"),
        "right": (vx + r + t, vy + r, r + sb, t, f"M{vx + r + t} {vy + r} h{r} v{t} h{-r} Z"),
        "bottomleft": (x, vy + r + t, sb + r, r,
                       f"M{vx} {vy + r + t} H{vx + r} V{vy + 2 * r + t} A{r} {r} 0 0 1 {vx} {vy + r + t} Z"),
        "bottom": (vx + r, vy + r + t, t, r, f"M{vx + r} {vy + r + t} h{t} v{r} h{-t} Z"),
        "bottomright": (vx + r + t, vy + r + t, r + sb, r,
                        f"M{vx + r + t} {vy + r + t} H{vx + 2 * r + t} A{r} {r} 0 0 1 {vx + r + t} {vy + 2 * r + t} Z"),
    }
    for name, (px, py, w, h, d) in pieces.items():
        svg.element(f"{prefix}{name}", px, py, w, h, shape(name, d))


def panel_background():
    svg = Svg()
    fill = 'class="ColorScheme-Background" fill="currentColor"'

    def glass(name, d):
        # Frosted glass: translucent fill; KWin blurs what is behind it (see mask below).
        return [f'<path d="{d}" {fill} fill-opacity="{GLASS_OPACITY}"/>']

    def mask(name, d):
        # Blur region: KWin blurs the background behind exactly this shape.
        return [f'<path d="{d}" fill="#000"/>']

    def empty(name, d):
        # Invisible but not empty: Plasma treats elements without any drawing as missing
        # and falls back to another background.
        return [f'<path d="{d}" fill="#000" fill-opacity="0"/>']

    # Plasma first looks for pieces prefixed with the panel's screen edge, else the plain
    # ones. The plain pieces are the flat top bar: a new panel briefly uses them before its
    # edge is known, and rounded corners there would lock the top bar to twice the radius.
    rounded_frame(svg, "", 0, 0, 1, glass)
    rounded_frame(svg, "mask-", 0, 3000, 1, mask)
    for side in ("top", "bottom", "left", "right"):
        svg.element(f"hint-{side}-margin", 0, -100, 1, 1)

    # The dock ("south") draws its own glass, so it can grow with the magnified icons
    # (DECISIONS.md D19): its visible pieces are empty. Plasma uses the mask both as the
    # blur region and as the area that takes mouse input, so the mask is the dock's glass
    # at rest: inset by the empty bands the icons grow into. An empty mask would mean
    # "blur the whole window". Margins are 1 px, not 0: Plasma ignores zero-sized margin
    # hints and falls back to the piece sizes.
    bands = (DOCK_OVERFLOW, DOCK_SIDE)
    rounded_frame(svg, "south-", 0, 6000, RADIUS, empty, *bands)
    rounded_frame(svg, "mask-south-", 0, 9000, RADIUS, mask, *bands)
    for side in ("top", "bottom", "left", "right"):
        svg.element(f"south-hint-{side}-margin", 0, -100, 1, 1)
    svg.element("hint-stretch-borders", 0, -200, 1, 1)
    return svg.text()


def tasks():
    """Task button states. A running app gets a small pill under its icon (like macOS),
    hover a soft rounded highlight. The pill is built from the two bottom corners, each
    holding one rounded end, plus the bottom edge between them."""
    svg = Svg()
    c, h, pill = 20, 6, 4            # corner size, bottom band height, pill thickness
    t = TILE
    text = 'class="ColorScheme-Text" fill="currentColor"'
    states = {
        # prefix: (pill opacity, pill class, hover background opacity)
        "normal": (0.55, text, 0),
        "focus": (0.85, text, 0),
        "minimized": (0.30, text, 0),
        "attention": (1.0, 'class="ColorScheme-NegativeText" fill="currentColor"', 0),
        "hover": (0.0, text, 0.22),
        "progress": (0.0, text, 0.0),
    }
    x = 0
    for prefix, (alpha, cls, bg) in states.items():
        y0, y1, y2 = 0, c, c + t      # rows: top corners, middle, bottom corners
        py = y2 + c - h + (h - pill) / 2
        r = pill / 2
        bg_fill = 'class="ColorScheme-Background" fill="currentColor"'

        def hover_bg(d):
            return [f'<path d="{d}" {bg_fill} fill-opacity="{bg}"/>'] if bg else []

        rr = 10
        shapes = {
            "topleft": hover_bg(f"M{x} {y0 + c} V{y0 + rr} A{rr} {rr} 0 0 1 {x + rr} {y0} H{x + c} V{y0 + c} Z"),
            "top": hover_bg(f"M{x + c} {y0} h{t} v{c} h{-t} Z"),
            "topright": hover_bg(f"M{x + c + t} {y0} H{x + 2 * c + t - rr} A{rr} {rr} 0 0 1 {x + 2 * c + t} {y0 + rr} V{y0 + c} H{x + c + t} Z"),
            "left": hover_bg(f"M{x} {y1} h{c} v{t} h{-c} Z"),
            "center": hover_bg(f"M{x + c} {y1} h{t} v{t} h{-t} Z"),
            "right": hover_bg(f"M{x + c + t} {y1} h{c} v{t} h{-c} Z"),
            "bottomleft": hover_bg(f"M{x} {y2} h{c} v{c} H{x + rr} A{rr} {rr} 0 0 1 {x} {y2 + c - rr} Z"),
            "bottom": hover_bg(f"M{x + c} {y2} h{t} v{c} h{-t} Z"),
            "bottomright": hover_bg(f"M{x + c + t} {y2} h{c} V{y2 + c - rr} A{rr} {rr} 0 0 1 {x + 2 * c + t - rr} {y2 + c} H{x + c + t} Z"),
        }
        if alpha:
            pill_attr = f'{cls} fill-opacity="{alpha}"'
            shapes["bottomleft"] += [f'<path d="M{x + c} {py} A{r} {r} 0 0 0 {x + c} {py + pill} Z" {pill_attr}/>']
            shapes["bottom"] += [f'<rect x="{x + c}" y="{py}" width="{t}" height="{pill}" {pill_attr}/>']
            shapes["bottomright"] += [f'<path d="M{x + c + t} {py} A{r} {r} 0 0 1 {x + c + t} {py + pill} Z" {pill_attr}/>']
        bounds = {
            "topleft": (x, y0, c, c), "top": (x + c, y0, t, c), "topright": (x + c + t, y0, c, c),
            "left": (x, y1, c, t), "center": (x + c, y1, t, t), "right": (x + c + t, y1, c, t),
            "bottomleft": (x, y2, c, c), "bottom": (x + c, y2, t, c), "bottomright": (x + c + t, y2, c, c),
        }
        for name, b in bounds.items():
            svg.element(f"{prefix}-{name}", *b, shapes[name])
        x += 2 * c + t + 20
    # Small margins so the icon keeps its full size inside the button.
    for side, m in (("top", 2), ("bottom", h), ("left", 2), ("right", 2)):
        svg.element(f"normal-hint-{side}-margin", 0, -100, m, m)
    for side in ("top", "bottom", "left", "right"):
        svg.element(f"group-expander-{side}", 0, -300, 8, 8)
    return svg.text()


def metadata():
    return json.dumps({
        "KPlugin": {
            "Id": NAME,
            "Name": "Kestrel",
            "Description": "Kestrel OS: frosted dock and top bar",
            "License": "GPL-2.0-or-later",
            "Version": "1.0",
            "Authors": [{"Name": "Kestrel OS"}],
        },
        "X-Plasma-API-Minimum-Version": "6.0",
    }, indent=4) + "\n"


def dock_geometry_js():
    values = {"icon": DOCK_ICON, "zoom": DOCK_ZOOM, "pad": DOCK_PAD, "bottom": DOCK_BOTTOM,
              "spacing": DOCK_SPACING, "overflow": DOCK_OVERFLOW, "side": DOCK_SIDE,
              "radius": RADIUS, "glassOpacity": GLASS_OPACITY, "label": DOCK_LABEL,
              "iconMin": DOCK_ICON_MIN, "iconMax": DOCK_ICON_MAX, "zoomMax": DOCK_ZOOM_MAX}
    lines = [".pragma library",
             "// Generated by image/artwork/plasma_theme.py; edit the DOCK_* values there."]
    lines += [f"var {k} = {v};" for k, v in values.items()]
    return "\n".join(lines) + "\n"


def main():
    if sys.argv[1] == "--dock-height":
        print(DOCK_HEIGHT)
        return
    if len(sys.argv) > 2:
        Path(sys.argv[2]).parent.mkdir(parents=True, exist_ok=True)
        Path(sys.argv[2]).write_text(dock_geometry_js())
    out = Path(sys.argv[1]) / NAME
    (out / "widgets").mkdir(parents=True, exist_ok=True)
    (out / "metadata.json").write_text(metadata())
    (out / "widgets" / "panel-background.svg").write_text(panel_background())
    (out / "widgets" / "tasks.svg").write_text(tasks())


if __name__ == "__main__":
    main()
