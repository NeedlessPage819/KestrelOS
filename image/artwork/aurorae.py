#!/usr/bin/env python3
"""Generates the "Kestrel" Aurorae window decoration (DECISIONS.md D15).

Aurorae themes are plain SVG drawn by KWin itself, so Plasma updates cannot break them.
Qt's SVG renderer has no blur or clipping, so the soft shadow is built from gradients:
each of the nine frame pieces draws exactly its own part of the window and shadow.

Geometry (all pixels): the shadow band is SHADOW wide on every side; the window body
reaches INNER pixels into the side and bottom pieces, where it lies under the client
area and is never visible. Only the title bar corners are rounded.

Usage: aurorae.py OUTPUT_DIR
"""
import sys
from pathlib import Path

NAME = "Kestrel"
SHADOW = 24          # shadow band on each side
INNER = 10           # window body inside corner pieces (>= RADIUS)
RADIUS = 10          # title bar corner radius
TITLE = 30           # title bar height
STRETCH = 2000       # middle pieces; tiles leave faint seams, so make one cover any window edge

STATES = {
    # prefix: (title bar colour, shadow opacity, outline opacity)
    "decoration": ("#f3f3f5", 0.28, 0.14),
    "decoration-inactive": ("#f7f7f8", 0.14, 0.10),
}
MAXIMIZED = {"decoration-maximized": "#f3f3f5", "decoration-maximized-inactive": "#f7f7f8"}

BUTTONS = {
    # name: (fill, border, glyph)
    "close": ("#ff5f57", "#e2463f", "M7.5 12.5 L12.5 17.5 M12.5 12.5 L7.5 17.5"),
    "minimize": ("#febc2e", "#de9f1f", "M7 15 L13 15"),
    "maximize": ("#28c840", "#1aa52c", "M10 12 L10 18 M7 15 L13 15"),
    "restore": ("#28c840", "#1aa52c", "M7 15 L13 15"),
}
BUTTON_W, BUTTON_H, BUTTON_R = 20, 30, 6.5
INACTIVE_BUTTON = ("#dcdcde", "#c9c9cc")


def falloff_stops(opacity, start=0.0):
    """Gradient stops for a soft quadratic shadow falloff between offset start and 1."""
    stops = []
    for t, k in ((0.0, 1.0), (0.25, 0.56), (0.5, 0.25), (0.75, 0.06), (1.0, 0.0)):
        offset = start + (1 - start) * t
        stops.append(f'<stop offset="{offset:.4f}" stop-color="#000" stop-opacity="{opacity * k:.4f}"/>')
    return "".join(stops)


class Svg:
    def __init__(self):
        self.defs = []
        self.body = []
        self.ids = 0

    def gradient(self, kind, opacity, start=0.0, **attrs):
        self.ids += 1
        gid = f"g{self.ids}"
        attr = " ".join(f'{k.replace("_", "-")}="{v}"' for k, v in attrs.items())
        self.defs.append(f'<{kind}Gradient id="{gid}" gradientUnits="userSpaceOnUse" {attr}>'
                         f'{falloff_stops(opacity, start)}</{kind}Gradient>')
        return f"url(#{gid})"

    def text(self):
        return ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>\n')


def rect(x, y, w, h, fill, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" {extra}/>'


def piece(svg, element, x, y, w, h, shapes):
    # The transparent rect pins the element's bounds to exactly x, y, w, h.
    svg.body.append(f'<g id="{element}">{rect(x, y, w, h, "#000", "fill-opacity=\"0\"")}{"".join(shapes)}</g>')


def framed_piece(svg, prefix, name, bounds, shadow, body, outline=()):
    """One frame piece plus its mask. KWin blurs the background behind the decoration's
    mask; without an explicit one that is every visible pixel, so the shadow would show
    frosted rectangles. The mask is the window body only, where blur is never visible.
    Aurorae reads a single mask ("mask-topleft" ...) for every state, taken from the active one."""
    piece(svg, f"{prefix}-{name}", *bounds, [*shadow, *body("title"), *outline])
    if prefix == "decoration":
        piece(svg, f"mask-{name}", *bounds, body("mask"))


def frame(svg, prefix, title, shadow, outline, ox):
    """Nine frame pieces for one state; ox shifts the state's virtual window on the canvas."""
    s, i, r = SHADOW, INNER, RADIUS
    side, top, bottom = s + i, s + TITLE, s + i
    width = side + STRETCH + side
    height = top + STRETCH + bottom
    x0, y0, x1, y1 = ox + s, s, ox + width - s, height - s   # window rectangle
    line = f'stroke="#000" stroke-opacity="{outline}" stroke-width="1" fill="none"'

    def hshadow(x, y, w, h, towards_left):
        edge = x + w if towards_left else x
        far = x if towards_left else x + w
        return rect(x, y, w, h, svg.gradient("linear", shadow, x1=edge, y1=0, x2=far, y2=0))

    def vshadow(x, y, w, h, upwards):
        edge = y + h if upwards else y
        far = y if upwards else y + h
        return rect(x, y, w, h, svg.gradient("linear", shadow, x1=0, y1=edge, x2=0, y2=far))

    def corner_shadow(x, y, w, h, cx, cy, inner):
        grad = svg.gradient("radial", shadow, start=inner / (inner + s), cx=cx, cy=cy, r=inner + s, fx=cx, fy=cy)
        return rect(x, y, w, h, grad)

    left, mid, right = ox, ox + side, ox + side + STRETCH
    ymid, ybot = top, top + STRETCH

    fills = {"title": title, "mask": "#000"}

    def body_path(d):
        return lambda kind: [f'<path d="{d}" fill="{fills[kind]}"/>']

    def body_rect(x, y, w, h):
        return lambda kind: [rect(x, y, w, h, fills[kind])]

    # Aurorae hands the padding band to KWin as a real shadow, which KWin rebuilds from
    # SHADOW x SHADOW corner squares and stretched edges. So each corner's shadow must stay
    # inside its square and the edges must be uniform along their length, or the stretched
    # edges show light gaps next to the corners.
    framed_piece(svg, prefix, "topleft", (left, 0, side, top), [
        corner_shadow(left, 0, s, s, x0, y0, 0),
        vshadow(x0, 0, i, s, True),
        hshadow(left, y0, s, TITLE, True),
    ], body_path(f"M{x0} {top} V{y0 + r} A{r} {r} 0 0 1 {x0 + r} {y0} H{mid} V{top} Z"), [
        f'<path d="M{x0 - 0.5} {top} V{y0 + r} A{r + 0.5} {r + 0.5} 0 0 1 {x0 + r} {y0 - 0.5} H{mid}" {line}/>',
    ])
    framed_piece(svg, prefix, "top", (mid, 0, STRETCH, top), [
        vshadow(mid, 0, STRETCH, s, True),
    ], body_rect(mid, y0, STRETCH, TITLE), [f'<path d="M{mid} {y0 - 0.5} H{right}" {line}/>'])
    framed_piece(svg, prefix, "topright", (right, 0, side, top), [
        corner_shadow(x1, 0, s, s, x1, y0, 0),
        vshadow(right, 0, i, s, True),
        hshadow(x1, y0, s, TITLE, False),
    ], body_path(f"M{x1} {top} V{y0 + r} A{r} {r} 0 0 0 {x1 - r} {y0} H{right} V{top} Z"), [
        f'<path d="M{x1 + 0.5} {top} V{y0 + r} A{r + 0.5} {r + 0.5} 0 0 0 {x1 - r} {y0 - 0.5} H{right}" {line}/>',
    ])
    framed_piece(svg, prefix, "left", (left, ymid, side, STRETCH), [
        hshadow(left, ymid, s, STRETCH, True),
    ], body_rect(x0, ymid, i, STRETCH), [f'<path d="M{x0 - 0.5} {ymid} V{ybot}" {line}/>'])
    framed_piece(svg, prefix, "center", (mid, ymid, STRETCH, STRETCH), [], body_rect(mid, ymid, STRETCH, STRETCH))
    framed_piece(svg, prefix, "right", (right, ymid, side, STRETCH), [
        hshadow(x1, ymid, s, STRETCH, False),
    ], body_rect(right, ymid, i, STRETCH), [f'<path d="M{x1 + 0.5} {ymid} V{ybot}" {line}/>'])
    framed_piece(svg, prefix, "bottomleft", (left, ybot, side, bottom), [
        hshadow(left, ybot, s, i, True),
        vshadow(x0, y1, i, s, False),
        corner_shadow(left, y1, s, s, x0, y1, 0),
    ], body_rect(x0, ybot, i, i), [f'<path d="M{x0 - 0.5} {ybot} V{y1 + 0.5} H{mid}" {line}/>'])
    framed_piece(svg, prefix, "bottom", (mid, ybot, STRETCH, bottom), [
        vshadow(mid, y1, STRETCH, s, False),
    ], body_rect(mid, ybot, STRETCH, i), [f'<path d="M{mid} {y1 + 0.5} H{right}" {line}/>'])
    framed_piece(svg, prefix, "bottomright", (right, ybot, side, bottom), [
        hshadow(x1, ybot, s, i, False),
        vshadow(right, y1, i, s, False),
        corner_shadow(x1, y1, s, s, x1, y1, 0),
    ], body_rect(right, ybot, i, i), [f'<path d="M{x1 + 0.5} {ybot} V{y1 + 0.5} H{right}" {line}/>'])
    return width


def maximized_frame(svg, prefix, title, ox):
    """Flat title bar without shadow or rounding."""
    pieces = {
        "topleft": (ox, 0, 1, TITLE), "top": (ox + 1, 0, STRETCH, TITLE), "topright": (ox + 1 + STRETCH, 0, 1, TITLE),
        "left": (ox, TITLE, 1, STRETCH), "center": (ox + 1, TITLE, STRETCH, STRETCH),
        "right": (ox + 1 + STRETCH, TITLE, 1, STRETCH),
        "bottomleft": (ox, TITLE + STRETCH, 1, 1), "bottom": (ox + 1, TITLE + STRETCH, STRETCH, 1),
        "bottomright": (ox + 1 + STRETCH, TITLE + STRETCH, 1, 1),
    }
    fills = {"title": title, "mask": "#000"}
    for name, (x, y, w, h) in pieces.items():
        framed_piece(svg, prefix, name, (x, y, w, h), [], lambda kind, b=(x, y, w, h): [rect(*b, fills[kind])])
    return STRETCH + 2


def decoration_svg():
    svg, ox = Svg(), 0
    for prefix, (title, shadow, outline) in STATES.items():
        ox += frame(svg, prefix, title, shadow, outline, ox) + 10
    for prefix, title in MAXIMIZED.items():
        ox += maximized_frame(svg, prefix, title, ox) + 10
    return svg.text()


def button_svg(fill, border, glyph):
    cx, cy = BUTTON_W / 2, BUTTON_H / 2
    states = {
        "active": (fill, border, False),
        "hover": (fill, border, True),
        "pressed": (border, border, True),
        "inactive": (*INACTIVE_BUTTON, False),
        "deactivated": (*INACTIVE_BUTTON, False),
    }
    body = []
    for n, (state, (f, b, show_glyph)) in enumerate(states.items()):
        x = n * (BUTTON_W + 4)
        parts = [rect(x, 0, BUTTON_W, BUTTON_H, "#000", 'fill-opacity="0"'),
                 f'<circle cx="{x + cx}" cy="{cy}" r="{BUTTON_R}" fill="{f}" stroke="{b}" stroke-width="0.8"/>']
        if show_glyph:
            parts.append(f'<path transform="translate({x} 0)" d="{glyph}" stroke="#000" stroke-opacity="0.55" '
                         'stroke-width="1.3" stroke-linecap="round" fill="none"/>')
        body.append(f'<g id="{state}-center">{"".join(parts)}</g>')
    return f'<svg xmlns="http://www.w3.org/2000/svg">{"".join(body)}</svg>\n'


RC = f"""[General]
ActiveTextColor=58,58,60
InactiveTextColor=160,160,164
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=150

[Layout]
BorderLeft=0
BorderRight=0
BorderBottom=0
TitleEdgeTop=0
TitleEdgeBottom=0
TitleEdgeLeft=8
TitleEdgeRight=8
TitleEdgeTopMaximized=0
TitleEdgeBottomMaximized=0
TitleEdgeLeftMaximized=8
TitleEdgeRightMaximized=8
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={TITLE}
ButtonWidth={BUTTON_W}
ButtonHeight={BUTTON_H}
ButtonSpacing=0
ButtonMarginTop=0
ExplicitButtonSpacer=8
PaddingTop={SHADOW}
PaddingBottom={SHADOW}
PaddingLeft={SHADOW}
PaddingRight={SHADOW}
"""

METADATA = f"""[Desktop Entry]
Name={NAME}
Comment=Kestrel OS window decoration
X-KDE-PluginInfo-Name={NAME}
X-KDE-PluginInfo-Author=Kestrel OS
X-KDE-PluginInfo-License=GPL-2.0-or-later
X-KDE-PluginInfo-Version=1.0
"""


def main():
    out = Path(sys.argv[1]) / NAME
    out.mkdir(parents=True, exist_ok=True)
    (out / "decoration.svg").write_text(decoration_svg())
    for name, (fill, border, glyph) in BUTTONS.items():
        (out / f"{name}.svg").write_text(button_svg(fill, border, glyph))
    (out / f"{NAME}rc").write_text(RC)
    (out / "metadata.desktop").write_text(METADATA)


if __name__ == "__main__":
    main()
