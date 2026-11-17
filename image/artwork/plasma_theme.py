#!/usr/bin/env python3
"""Generates the "Kestrel" Plasma theme (DECISIONS.md D16).

Only the dock/top bar background and the task indicators are our own; Plasma takes every
other element from the default Breeze theme. Colours come from the active colour scheme
(current-color-scheme stylesheet), so light and dark mode both work.

Usage: plasma_theme.py OUTPUT_DIR
"""
import json
import sys
from pathlib import Path

NAME = "kestrel"
RADIUS = 18          # panel corner radius (the dock is about 64 px tall)
MARGIN = 3           # space between panel edge and its content (icons fill the dock)
TILE = 2000          # edge pieces; one tile covers any panel, so tiling leaves no seams

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


def rounded_frame(svg, prefix, x, y, radius, shape):
    """Nine pieces of a rounded rectangle; shape(name, path) draws one piece's part of it."""
    r, t = radius, TILE
    pieces = {
        "topleft": (x, y, r, r, f"M{x} {y + r} A{r} {r} 0 0 1 {x + r} {y} V{y + r} Z"),
        "top": (x + r, y, t, r, f"M{x + r} {y} H{x + r + t} V{y + r} H{x + r} Z"),
        "topright": (x + r + t, y, r, r, f"M{x + r + t} {y} A{r} {r} 0 0 1 {x + 2 * r + t} {y + r} H{x + r + t} Z"),
        "left": (x, y + r, r, t, f"M{x} {y + r} H{x + r} V{y + r + t} H{x} Z"),
        "center": (x + r, y + r, t, t, f"M{x + r} {y + r} h{t} v{t} h{-t} Z"),
        "right": (x + r + t, y + r, r, t, f"M{x + r + t} {y + r} h{r} v{t} h{-r} Z"),
        "bottomleft": (x, y + r + t, r, r, f"M{x} {y + r + t} H{x + r} V{y + 2 * r + t} A{r} {r} 0 0 1 {x} {y + r + t} Z"),
        "bottom": (x + r, y + r + t, t, r, f"M{x + r} {y + r + t} h{t} v{r} h{-t} Z"),
        "bottomright": (x + r + t, y + r + t, r, r,
                        f"M{x + r + t} {y + r + t} H{x + 2 * r + t} A{r} {r} 0 0 1 {x + r + t} {y + 2 * r + t} Z"),
    }
    for name, (px, py, w, h, d) in pieces.items():
        svg.element(f"{prefix}{name}", px, py, w, h, shape(name, d))


def panel_background():
    svg = Svg()
    fill = 'class="ColorScheme-Background" fill="currentColor"'

    def glass(name, d):
        # Frosted glass: translucent fill; KWin blurs what is behind it (see mask below).
        return [f'<path d="{d}" {fill} fill-opacity="0.62"/>']

    def mask(name, d):
        # Blur region: KWin blurs the background behind exactly this shape.
        return [f'<path d="{d}" fill="#000"/>']

    # Plasma first looks for pieces prefixed with the panel's screen edge. The top bar
    # ("north") is a flat strip: rounded corners there would also force a minimum height
    # of twice the radius. Every other panel, i.e. the dock, gets the rounded pieces.
    for prefix, radius, y in (("", RADIUS, 0), ("north-", 1, 6000)):
        rounded_frame(svg, prefix, 0, y, radius, glass)
        rounded_frame(svg, f"mask-{prefix}", 0, y + 3000, radius, mask)
        for side in ("top", "bottom", "left", "right"):
            m = MARGIN if prefix == "" else 1
            svg.element(f"{prefix}hint-{side}-margin", 0, -100, m, m)
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


def main():
    out = Path(sys.argv[1]) / NAME
    (out / "widgets").mkdir(parents=True, exist_ok=True)
    (out / "metadata.json").write_text(metadata())
    (out / "widgets" / "panel-background.svg").write_text(panel_background())
    (out / "widgets" / "tasks.svg").write_text(tasks())


if __name__ == "__main__":
    main()
