#!/usr/bin/env python3
"""Generates the "Kestrel" and "KestrelDark" Aurorae window decorations (DECISIONS.md D15, D20).

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

SHADOW = 24          # shadow band on each side
INNER = 10           # window body inside corner pieces (>= RADIUS)
RADIUS = 10          # title bar corner radius
TITLE = 30           # title bar height
STRETCH = 2000       # middle pieces; tiles leave faint seams, so make one cover any window edge

# Light and dark variant (DECISIONS.md D20); the "Kestrel" and "Kestrel Dunkel" global
# themes pick one each. Only colours differ.
VARIANTS = {
    "Kestrel": {
        # prefix: (title bar colour, shadow opacity, outline opacity)
        "states": {"decoration": ("#f3f3f5", 0.28, 0.14), "decoration-inactive": ("#f7f7f8", 0.14, 0.10)},
        "maximized": {"decoration-maximized": "#f3f3f5", "decoration-maximized-inactive": "#f7f7f8"},
        "outline": "#000",                       # dark hairline around light windows
        "inactive_button": ("#dcdcde", "#c9c9cc"),
        "text": ("58,58,60", "160,160,164"),     # active, inactive title text
        "comment": "Kestrel OS window decoration",
    },
    "KestrelDark": {
        "states": {"decoration": ("#2c2b30", 0.50, 0.16), "decoration-inactive": ("#302f34", 0.28, 0.10)},
        "maximized": {"decoration-maximized": "#2c2b30", "decoration-maximized-inactive": "#302f34"},
        "outline": "#fff",                       # light hairline around dark windows, as on macOS
        "inactive_button": ("#4a4a4f", "#3e3e43"),
        "text": ("230,230,232", "140,140,146"),
        "comment": "Kestrel OS window decoration, dark",
    },
}

BUTTONS = {
    # name: (fill, border, glyph)
    "close": ("#ff5f57", "#e2463f", "M7.5 12.5 L12.5 17.5 M12.5 12.5 L7.5 17.5"),
    "minimize": ("#febc2e", "#de9f1f", "M7 15 L13 15"),
    "maximize": ("#28c840", "#1aa52c", "M10 12 L10 18 M7 15 L13 15"),
    "restore": ("#28c840", "#1aa52c", "M7 15 L13 15"),
}
BUTTON_W, BUTTON_H, BUTTON_R = 20, 30, 6.5


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


def frame(svg, prefix, title, shadow, outline, line_colour, ox):
    """Nine frame pieces for one state; ox shifts the state's virtual window on the canvas."""
    s, i, r = SHADOW, INNER, RADIUS
    side, top, bottom = s + i, s + TITLE, s + i
    width = side + STRETCH + side
    height = top + STRETCH + bottom
    x0, y0, x1, y1 = ox + s, s, ox + width - s, height - s   # window rectangle

    def bar(x, y, w, h):
        # The 1 px outline is drawn as filled areas, never as strokes: Qt counts half a
        # stroke width beyond a piece's edge, which makes the piece half a pixel too large,
        # gets it scaled, and leaves a light seam in the shadow where pieces meet.
        return [rect(x, y, w, h, line_colour, f'fill-opacity="{outline}"')] if w > 0 and h > 0 else []

    def ring(d):
        return [f'<path d="{d}" fill="{line_colour}" fill-opacity="{outline}"/>']

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
        *bar(x0 - 1, y0 + r, 1, top - y0 - r), *bar(x0 + r, y0 - 1, mid - x0 - r, 1),
        *ring(f"M{x0 - 1} {y0 + r} A{r + 1} {r + 1} 0 0 1 {x0 + r} {y0 - 1} V{y0} A{r} {r} 0 0 0 {x0} {y0 + r} Z"),
    ])
    framed_piece(svg, prefix, "top", (mid, 0, STRETCH, top), [
        vshadow(mid, 0, STRETCH, s, True),
    ], body_rect(mid, y0, STRETCH, TITLE), bar(mid, y0 - 1, STRETCH, 1))
    framed_piece(svg, prefix, "topright", (right, 0, side, top), [
        corner_shadow(x1, 0, s, s, x1, y0, 0),
        vshadow(right, 0, i, s, True),
        hshadow(x1, y0, s, TITLE, False),
    ], body_path(f"M{x1} {top} V{y0 + r} A{r} {r} 0 0 0 {x1 - r} {y0} H{right} V{top} Z"), [
        *bar(x1, y0 + r, 1, top - y0 - r), *bar(right, y0 - 1, x1 - r - right, 1),
        *ring(f"M{x1 + 1} {y0 + r} A{r + 1} {r + 1} 0 0 0 {x1 - r} {y0 - 1} V{y0} A{r} {r} 0 0 1 {x1} {y0 + r} Z"),
    ])
    framed_piece(svg, prefix, "left", (left, ymid, side, STRETCH), [
        hshadow(left, ymid, s, STRETCH, True),
    ], body_rect(x0, ymid, i, STRETCH), bar(x0 - 1, ymid, 1, STRETCH))
    framed_piece(svg, prefix, "center", (mid, ymid, STRETCH, STRETCH), [], body_rect(mid, ymid, STRETCH, STRETCH))
    framed_piece(svg, prefix, "right", (right, ymid, side, STRETCH), [
        hshadow(x1, ymid, s, STRETCH, False),
    ], body_rect(right, ymid, i, STRETCH), bar(x1, ymid, 1, STRETCH))
    framed_piece(svg, prefix, "bottomleft", (left, ybot, side, bottom), [
        hshadow(left, ybot, s, i, True),
        vshadow(x0, y1, i, s, False),
        corner_shadow(left, y1, s, s, x0, y1, 0),
    ], body_rect(x0, ybot, i, i), [*bar(x0 - 1, ybot, 1, y1 + 1 - ybot), *bar(x0, y1, mid - x0, 1)])
    framed_piece(svg, prefix, "bottom", (mid, ybot, STRETCH, bottom), [
        vshadow(mid, y1, STRETCH, s, False),
    ], body_rect(mid, ybot, STRETCH, i), bar(mid, y1, STRETCH, 1))
    framed_piece(svg, prefix, "bottomright", (right, ybot, side, bottom), [
        hshadow(x1, ybot, s, i, False),
        vshadow(right, y1, i, s, False),
        corner_shadow(x1, y1, s, s, x1, y1, 0),
    ], body_rect(right, ybot, i, i), [*bar(x1, ybot, 1, y1 + 1 - ybot), *bar(right, y1, x1 - right, 1)])
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


def decoration_svg(v):
    svg, ox = Svg(), 0
    for prefix, (title, shadow, outline) in v["states"].items():
        ox += frame(svg, prefix, title, shadow, outline, v["outline"], ox) + 10
    for prefix, title in v["maximized"].items():
        ox += maximized_frame(svg, prefix, title, ox) + 10
    return svg.text()


def button_svg(fill, border, glyph, inactive):
    cx, cy = BUTTON_W / 2, BUTTON_H / 2
    states = {
        "active": (fill, border, False),
        "hover": (fill, border, True),
        "pressed": (border, border, True),
        "inactive": (*inactive, False),
        "deactivated": (*inactive, False),
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


def rc(v):
    return f"""[General]
ActiveTextColor={v["text"][0]}
InactiveTextColor={v["text"][1]}
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

def metadata(name, v):
    return f"""[Desktop Entry]
Name={name}
Comment={v["comment"]}
X-KDE-PluginInfo-Name={name}
X-KDE-PluginInfo-Author=Kestrel OS
X-KDE-PluginInfo-License=GPL-2.0-or-later
X-KDE-PluginInfo-Version=1.0
"""


def main():
    for name, v in VARIANTS.items():
        out = Path(sys.argv[1]) / name
        out.mkdir(parents=True, exist_ok=True)
        (out / "decoration.svg").write_text(decoration_svg(v))
        for button, (fill, border, glyph) in BUTTONS.items():
            (out / f"{button}.svg").write_text(button_svg(fill, border, glyph, v["inactive_button"]))
        (out / f"{name}rc").write_text(rc(v))
        (out / "metadata.desktop").write_text(metadata(name, v))


if __name__ == "__main__":
    main()
