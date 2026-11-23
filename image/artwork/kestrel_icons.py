#!/usr/bin/env python3
"""Kestrel icon theme (DECISIONS.md D28): the drawings and where they are installed.

Close to WhiteSur's look (which stays selectable), in Kestrel's colours and with the Kestrel
bird where it fits:
  - App icons: a rounded-square tile with a strong top-to-bottom gradient, a thin light inner
    edge and a soft shadow; the symbols have their own gradients and shadow (depth, not flat).
  - Folders: wide and flat, light Kestrel blue, a highlight on the front edge and the kind of
    folder pressed into the front.
  - Files: a page with a folded corner; media and program types are coloured pages with a large
    white symbol, text and pictures are white pages.
All icons are 128x128 SVG.
Usage: kestrel_icons.py --install THEME_DIR     install into the Kestrel icon theme (image build)
       kestrel_icons.py OUTPUT_DIR [WHITESUR_DIR] write the drawings (and a comparison page)
"""
import math
import sys
from pathlib import Path

S = 128
BIRD = "M1 6.2 C3.4 4.2 5.9 4.4 8 7.6 C10.1 4.4 12.6 4.2 15 6.2 C12.4 5.9 10.2 7.2 8 11.2 C5.8 7.2 3.6 5.9 1 6.2 Z"


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">{body}</svg>\n'


def lin(id_, top, bottom, x2=0, y2=1):
    return (f'<linearGradient id="{id_}" x1="0" y1="0" x2="{x2}" y2="{y2}">'
            f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>')


def shadow(id_, dy=3, sd=3, op=.3):
    return (f'<filter id="{id_}" x="-25%" y="-25%" width="150%" height="160%">'
            f'<feDropShadow dx="0" dy="{dy}" stdDeviation="{sd}" flood-color="#141432" flood-opacity="{op}"/></filter>')


def drawn_shadow(shape):
    """A soft shadow made of offset copies of the shape. KDE draws icons with Qt's SVG renderer,
    which ignores SVG filters (the feDropShadow above only shows in browsers)."""
    return "".join(f'<g transform="translate(0 {dy})" fill="#141432" opacity="{op}">{shape}</g>'
                   for dy, op in ((3.2, .06), (2.2, .08), (1.2, .1)))


def bird(x, y, scale, fill, extra=""):
    return f'<g transform="translate({x} {y}) scale({scale})"><path d="{BIRD}" fill="{fill}" {extra}/></g>'


# ---------- app tiles -------------------------------------------------------------------

TX, TY, TW, TR = 12, 9, 104, 24      # tile position, size, corner radius

TILES = {
    "blue": ("#9fabfc", "#4b5be4"),
    "violet": ("#c3a1fb", "#6f4bdc"),
    "graphite": ("#606070", "#26262e"),
    "silver": ("#f6f6f9", "#b9bac6"),
    "teal": ("#6fe0d1", "#17978c"),
    "amber": ("#ffd97a", "#f08f22"),
    "coral": ("#ffa58f", "#e8504a"),
    "pink": ("#ff9cc2", "#d9437f"),
    "red": ("#ff8585", "#c22f41"),
}


def tile(uid, colour, glyph, glyph_defs=""):
    top, bottom = TILES[colour]
    return svg(f"""<defs>{lin("t" + uid, top, bottom)}
  <linearGradient id="e{uid}" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset=".5" stop-color="#fff" stop-opacity=".08"/>
    <stop offset="1" stop-color="#000" stop-opacity=".12"/></linearGradient>
  {shadow("s" + uid)}{shadow("gs" + uid, 1.6, 1.6, .28)}{glyph_defs}</defs>
{drawn_shadow(f'<rect x="{TX}" y="{TY}" width="{TW}" height="{TW}" rx="{TR}"/>')}
<rect x="{TX}" y="{TY}" width="{TW}" height="{TW}" rx="{TR}" fill="url(#t{uid})" filter="url(#s{uid})"/>
<rect x="{TX + .75}" y="{TY + .75}" width="{TW - 1.5}" height="{TW - 1.5}" rx="{TR - .75}" fill="none" stroke="url(#e{uid})" stroke-width="1.5"/>
<g filter="url(#gs{uid})">{glyph}</g>""")


def gear_path(cx, cy, r_out, r_in, teeth):
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4) - math.pi / 2 + math.pi / (teeth * 4)
        r = r_out if i % 4 in (1, 2) else r_in
        pts.append(f"{cx + r * math.cos(a):.2f},{cy + r * math.sin(a):.2f}")
    return "M" + " L".join(pts) + " Z"


APPS = {
    "files": ("blue",
              lin("ff", "#ffffff", "#dfe4ff")
              , '<path d="M30 44 a6 6 0 0 1 6 -6 h18 a6 6 0 0 1 4.5 2 l5 5.5 h28.5 a6 6 0 0 1 6 6 v34.5 a6 6 0 0 1 -6 6 H36 a6 6 0 0 1 -6 -6 Z" fill="url(#ff)"/>'
                '<path d="M30 56 h68" stroke="#4b5be4" stroke-opacity=".18" stroke-width="2"/>'
              + bird(48, 60, 2, "#5b6cf0", 'opacity=".75"')),
    "terminal": ("silver",
                 lin("scr", "#3d3d48", "#15151b"),
                 '<rect x="21" y="18" width="86" height="86" rx="16" fill="url(#scr)"/>'
                 '<rect x="21.5" y="18.5" width="85" height="85" rx="15.5" fill="none" stroke="#000" stroke-opacity=".5"/>'
                 '<path d="M33 35 l11 9 l-11 9" fill="none" stroke="#9aa6fb" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>'
                 '<path d="M51 56 h18" stroke="#f2f2f6" stroke-width="5" stroke-linecap="round"/>'),
    "settings": ("silver",
                 lin("gm", "#a4a4b0", "#4e4e5a") + lin("gi", "#e9e9ef", "#b3b4c0"),
                 f'<path d="{gear_path(64, 61, 40, 33, 12)}" fill="url(#gm)" stroke="url(#gm)" stroke-width="3" stroke-linejoin="round"/>'
                 '<circle cx="64" cy="61" r="25" fill="url(#gi)"/>'
                 f'<path d="{gear_path(64, 61, 21, 16, 8)}" fill="url(#gm)" stroke="url(#gm)" stroke-width="2" stroke-linejoin="round"/>'
                 '<circle cx="64" cy="61" r="9" fill="#5b6cf0"/><circle cx="64" cy="61" r="9" fill="none" stroke="#fff" stroke-opacity=".5" stroke-width="1.5"/>'),
    "store": ("violet",
              lin("bag", "#ffffff", "#eae2ff"),
              '<path d="M38 50 h52 l-4.5 38 a6 6 0 0 1 -6 5.3 H48.5 a6 6 0 0 1 -6 -5.3 Z" fill="url(#bag)"/>'
              '<path d="M51 52 v-7 a13 13 0 0 1 26 0 v7" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/>'
              + bird(46, 58, 2.25, "#6f4bdc")),
    "launchpad": ("graphite", "",
                  "".join(f'<rect x="{31 + 23 * (i % 3)}" y="{28 + 23 * (i // 3)}" width="18" height="18" rx="5.5" fill="{c}"/>'
                          for i, c in enumerate(["#ff6b61", "#ffa53a", "#ffd34a", "#47cf6c", "#2dc2b3", "#5b6cf0",
                                                 "#8c63ee", "#f2589a", "#c4c4cf"]))),
    "texteditor": ("amber",
                   lin("pg", "#ffffff", "#f3efe6"),
                   '<rect x="36" y="27" width="50" height="66" rx="7" fill="url(#pg)"/>'
                   + "".join(f'<path d="M45 {42 + 9 * i} h{31 - (10 if i == 4 else 0)}" stroke="#e7a04a" stroke-width="4" stroke-linecap="round"/>' for i in range(5))
                   + '<path d="M76 92 l20 -20 l7 7 l-20 20 l-9.5 2.5 Z" fill="#3a3a44"/><path d="M96 72 l3.5 -3.5 a3 3 0 0 1 4.2 0 l2.8 2.8 a3 3 0 0 1 0 4.2 l-3.5 3.5 Z" fill="#ff7a7a"/>'),
    "images": ("teal",
               lin("sky", "#bfeaff", "#e9f8ff") + lin("hill", "#36c49a", "#14806f"),
               '<rect x="28" y="33" width="72" height="56" rx="8" fill="#fff"/>'
               '<rect x="33" y="38" width="62" height="46" rx="5" fill="url(#sky)"/>'
               '<circle cx="80" cy="51" r="6" fill="#ffc93d"/>'
               '<path d="M33 84 l17 -20 l12 12 l9 -8 l24 16 Z" fill="url(#hill)"/>'),
    "calculator": ("graphite",
                   lin("key", "#8a8a98", "#5e5e6c") + lin("eq", "#ffb648", "#f0841c"),
                   "".join(f'<rect x="{34 + 31 * (i % 2)}" y="{30 + 31 * (i // 2)}" width="27" height="27" rx="8" fill="url(#{c})"/>'
                           for i, c in enumerate(["key", "key", "key", "eq"]))
                   + '<path d="M42 43.5 h11 M73 43.5 h11 M78.5 38 v11 M42 74.5 h11 M73 71 h11 M73 78 h11" stroke="#fff" stroke-width="3.5" stroke-linecap="round"/>'),
    "screenshot": ("coral", "",
                   '<path d="M33 50 v-11 a6 6 0 0 1 6 -6 h11 M78 33 h11 a6 6 0 0 1 6 6 v11 M95 74 v11 a6 6 0 0 1 -6 6 h-11 M50 91 h-11 a6 6 0 0 1 -6 -6 v-11" fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round"/>'
                   '<circle cx="64" cy="62" r="13" fill="#fff"/><circle cx="64" cy="62" r="6" fill="#e8504a"/>'),
    "music": ("pink",
              lin("note", "#ffffff", "#ffe4ef"),
              '<path d="M55 36 l33 -7 v44" fill="none" stroke="url(#note)" stroke-width="6.5" stroke-linejoin="round" stroke-linecap="round"/>'
              '<path d="M55 36 v45" stroke="url(#note)" stroke-width="6.5" stroke-linecap="round"/>'
              '<ellipse cx="46" cy="83" rx="11" ry="9" fill="url(#note)"/><ellipse cx="79" cy="75" rx="11" ry="9" fill="url(#note)"/>'),
    "videos": ("red",
               lin("film", "#ffffff", "#ffe6e6"),
               '<rect x="29" y="35" width="70" height="52" rx="9" fill="url(#film)"/>'
               + "".join(f'<rect x="{34 + 12 * i}" y="39" width="7" height="5" rx="1.5" fill="#c22f41" opacity=".55"/><rect x="{34 + 12 * i}" y="78" width="7" height="5" rx="1.5" fill="#c22f41" opacity=".55"/>' for i in range(6))
               + '<path d="M57 51 l16 10 l-16 10 Z" fill="#c22f41" stroke="#c22f41" stroke-width="3" stroke-linejoin="round"/>'),
    # "Install Kestrel OS" on the live stick: an arrow going down into a drive with the bird on it.
    "installer": ("blue",
                  lin("drv", "#ffffff", "#dfe4ff"),
                  '<path d="M64 25 v31" stroke="#fff" stroke-width="8" stroke-linecap="round"/>'
                  '<path d="M48 44 l16 16 l16 -16" fill="none" stroke="#fff" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>'
                  '<rect x="28" y="68" width="72" height="26" rx="8" fill="url(#drv)"/>'
                  '<circle cx="88" cy="81" r="3.5" fill="#2dc2b3"/>'
                  + bird(40, 73, 1.45, "#5b6cf0", 'opacity=".8"')),
    "archiver": ("amber",
                 lin("box", "#fff7e6", "#ffe0a8"),
                 '<path d="M33 50 h62 v35 a7 7 0 0 1 -7 7 H40 a7 7 0 0 1 -7 -7 Z" fill="url(#box)"/>'
                 '<rect x="29" y="36" width="70" height="16" rx="5.5" fill="#fff"/>'
                 '<rect x="54" y="60" width="20" height="9" rx="4.5" fill="#f08f22"/>'),
}


# ---------- trash -----------------------------------------------------------------------

def trash(full):
    uid = "tr" + ("f" if full else "")
    papers = ""
    if full:
        papers = ('<path d="M42 42 l9 -17 l18 9 l-6 10 Z" fill="#fff" stroke="#c9cad6" stroke-width="1.2"/>'
                  '<path d="M58 40 l15 -15 l15 14 l-7 5 Z" fill="#eef0ff" stroke="#c9cad6" stroke-width="1.2"/>'
                  '<path d="M70 42 l20 -6 l4 10 Z" fill="#fff6e0" stroke="#d9cfb6" stroke-width="1.2"/>')
    ribs = "".join(f'<path d="M{48 + 11 * i} 58 v39" stroke="#fff" stroke-opacity=".8" stroke-width="3" stroke-linecap="round"/>'
                   f'<path d="M{49.5 + 11 * i} 58 v39" stroke="#8d8fa3" stroke-opacity=".45" stroke-width="1.5" stroke-linecap="round"/>' for i in range(4))
    return svg(f"""<defs>
  <linearGradient id="b{uid}" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#c9cad8"/><stop offset=".45" stop-color="#f9f9fc"/><stop offset="1" stop-color="#bfc0cf"/></linearGradient>
  {lin("l" + uid, "#f4f5fb", "#d3d4e0")}{shadow("s" + uid)}</defs>
<g filter="url(#s{uid})">{papers}
  <path d="M33 47 h62 l-6.5 56 a8 8 0 0 1 -8 7 H47.5 a8 8 0 0 1 -8 -7 Z" fill="url(#b{uid})" stroke="#9c9eb2" stroke-width="1"/>
  {ribs}
  <rect x="27" y="38" width="74" height="11" rx="5.5" fill="url(#l{uid})" stroke="#9c9eb2" stroke-width="1"/>
  <rect x="27" y="38" width="74" height="4" rx="2" fill="#8d9af6"/>
</g>""")


# ---------- folders ---------------------------------------------------------------------

FOLDER_GLYPHS = {
    "folder": "",
    "home": '<path d="M64 60 l-17 14 v17 h12 v-10 h10 v10 h12 v-17 Z"/>',
    "documents": '<path d="M53 58 h15 l8 8 v24 a3 3 0 0 1 -3 3 H53 a3 3 0 0 1 -3 -3 V61 a3 3 0 0 1 3 -3 Z"/>',
    "downloads": '<path d="M60 58 h8 v16 h8 l-12 13 l-12 -13 h8 Z"/><rect x="50" y="89" width="28" height="4" rx="2"/>',
    "pictures": '<path d="M47 91 l12 -15 l8 8 l6 -6 l12 13 Z"/><circle cx="75" cy="66" r="5"/>',
    "music": '<path d="M57 63 l20 -5 v23" fill="none" stroke-width="5" stroke-linejoin="round"/><path d="M57 63 v24" fill="none" stroke-width="5"/><ellipse cx="51" cy="88" rx="7" ry="5.5"/><ellipse cx="71" cy="82" rx="7" ry="5.5"/>',
    "videos": '<path d="M57 61 l21 13 l-21 13 Z" stroke-width="4" stroke-linejoin="round"/>',
    "desktop": '<rect x="46" y="59" width="36" height="24" rx="3"/><rect x="58" y="86" width="12" height="4" rx="2"/>',
}


def folder(kind):
    uid = "f" + kind
    glyph = FOLDER_GLYPHS[kind]
    if glyph:
        # Pressed into the front: a light edge just below a darker shape.
        glyph = (f'<g fill="#fff" stroke="#fff" opacity=".45" transform="translate(0 1.2)">{glyph}</g>'
                 f'<g fill="#4655d8" stroke="#4655d8" opacity=".42">{glyph}</g>')
    return svg(f"""<defs>{lin("bk" + uid, "#6f7fee", "#5869e2")}{lin("fr" + uid, "#a3aefb", "#c6cdfe")}{shadow("s" + uid, 2.5, 2.4, .25)}</defs>
{drawn_shadow('<rect x="10" y="41" width="108" height="66" rx="7"/>')}
<g filter="url(#s{uid})">
  <path d="M10 30 a7 7 0 0 1 7 -7 h29 a7 7 0 0 1 5.5 2.6 l5 6.4 h54.5 a7 7 0 0 1 7 7 v54 H10 Z" fill="url(#bk{uid})"/>
  <rect x="10" y="41" width="108" height="66" rx="7" fill="url(#fr{uid})"/>
  <path d="M17 41.8 h94" stroke="#fff" stroke-opacity=".75" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M15 106.2 h98" stroke="#4655d8" stroke-opacity=".35" stroke-width="1.4" stroke-linecap="round"/>
</g>{glyph}""")


# ---------- files -----------------------------------------------------------------------

FILE_TYPES = {
    # name: (page top, page bottom, fold colour, drawing)
    "text": ("#ffffff", "#f1f1f6", "#dcdde6",
             "".join(f'<path d="M38 {50 + 9 * i} h{44 - (16 if i == 5 else 0)}" stroke="#b9bac8" stroke-width="4" stroke-linecap="round"/>' for i in range(6))),
    "image": ("#ffffff", "#f1f1f6", "#dcdde6",
              '<rect x="34" y="50" width="56" height="44" rx="5" fill="#d8f2ff"/><path d="M34 94 l16 -19 l10 10 l8 -7 l22 16 Z" fill="#1fa58f"/><circle cx="76" cy="62" r="5.5" fill="#ffc93d"/>'),
    "pdf": ("#ff7470", "#d93a42", "#ffb3b0",
            '<text x="61" y="86" text-anchor="middle" font-family="Inter, sans-serif" font-weight="800" font-size="24" fill="#fff">PDF</text>'
            '<path d="M42 56 h38 M42 64 h30" stroke="#fff" stroke-opacity=".75" stroke-width="4" stroke-linecap="round"/>'),
    "archive": ("#ffcf66", "#ef8f1f", "#ffe6b0",
                "".join(f'<rect x="57" y="{18 + 9 * i}" width="9" height="5" rx="1.5" fill="#fff" opacity=".9"/>' for i in range(5))
                + '<rect x="53" y="64" width="17" height="20" rx="4" fill="#fff"/><rect x="58" y="72" width="7" height="6" rx="1.5" fill="#ef8f1f"/>'),
    "audio": ("#ff8fbd", "#d6437e", "#ffc6dc",
              '<path d="M52 62 l22 -5 v26" fill="none" stroke="#fff" stroke-width="5" stroke-linejoin="round"/><path d="M52 62 v27" stroke="#fff" stroke-width="5"/><ellipse cx="45" cy="90" rx="8" ry="6.5" fill="#fff"/><ellipse cx="67" cy="84" rx="8" ry="6.5" fill="#fff"/>'),
    "video": ("#b48cff", "#6d45d8", "#d9c6ff",
              '<path d="M52 60 l24 15 l-24 15 Z" fill="#fff" stroke="#fff" stroke-width="4" stroke-linejoin="round"/>'),
    "exe": ("#9fabfc", "#4b5be4", "#cfd5ff",
            '<rect x="36" y="56" width="50" height="38" rx="6" fill="#fff"/><path d="M36 66 h50" stroke="#4b5be4" stroke-opacity=".35" stroke-width="2"/>'
            '<circle cx="42" cy="61" r="1.8" fill="#ff6b61"/><circle cx="48" cy="61" r="1.8" fill="#ffc93d"/><circle cx="54" cy="61" r="1.8" fill="#47cf6c"/>'
            + bird(49, 70, 1.6, "#5b6cf0")),
}


def page(kind):
    top, bottom, fold, drawing = FILE_TYPES[kind]
    uid = "p" + kind
    edge = 'stroke="#d0d1dc" stroke-width="1.2"' if top == "#ffffff" else ""
    outline = "M28 12 h50 l28 28 v68 a8 8 0 0 1 -8 8 H28 a8 8 0 0 1 -8 -8 V20 a8 8 0 0 1 8 -8 Z"
    return svg(f"""<defs>{lin("pg" + uid, top, bottom)}{shadow("s" + uid, 2.5, 2.4, .25)}</defs>
{drawn_shadow(f'<path d="{outline}"/>')}
<g filter="url(#s{uid})">
  <path d="M28 12 h50 l28 28 v68 a8 8 0 0 1 -8 8 H28 a8 8 0 0 1 -8 -8 V20 a8 8 0 0 1 8 -8 Z" fill="url(#pg{uid})" {edge}/>
  <path d="M78 12 v20 a8 8 0 0 0 8 8 h20 Z" fill="{fold}"/>
</g>{drawing}""")


# ---------- preview ---------------------------------------------------------------------

LABELS = {
    "app-files": "Files", "app-terminal": "Terminal", "app-settings": "Settings", "app-store": "Store",
    "app-launchpad": "Launchpad", "app-texteditor": "Text Editor", "app-images": "Images",
    "app-calculator": "Calculator", "app-screenshot": "Screenshot", "app-music": "Music",
    "app-videos": "Videos", "app-archiver": "Archiver", "app-installer": "Install", "trash": "Trash", "trash-full": "Trash (full)",
    "folder-folder": "Folder", "folder-home": "Home", "folder-documents": "Documents",
    "folder-downloads": "Downloads", "folder-pictures": "Pictures", "folder-music": "Music",
    "folder-videos": "Videos", "folder-desktop": "Desktop", "file-text": "Text", "file-image": "Image",
    "file-pdf": "PDF", "file-archive": "Archive", "file-audio": "Audio", "file-video": "Video",
    "file-exe": "Windows program",
}
SECTIONS = [("Apps", [k for k in LABELS if k.startswith("app-") or k.startswith("trash")]),
            ("Folders", [k for k in LABELS if k.startswith("folder-")]),
            ("Files", [k for k in LABELS if k.startswith("file-")])]


def data_uri(path):
    import base64
    return "data:image/svg+xml;base64," + base64.b64encode(path.read_bytes()).decode()


def preview(out, whitesur):
    """Self-contained comparison page: Kestrel draft next to the current WhiteSur icon."""
    def img(d, name, size):
        p = d / f"{name}.svg"
        return (f'<img src="{data_uri(p)}" width="{size}" height="{size}" alt="">' if p.exists()
                else f'<span class="none" style="width:{size}px;height:{size}px">–</span>')

    def grid(d):
        rows = []
        for title, names in SECTIONS:
            cells = "".join(f'<figure>{img(d, n, 64)}<figcaption>{LABELS[n]}</figcaption></figure>' for n in names)
            rows.append(f"<h3>{title}</h3><div class='grid'>{cells}</div>")
        return "".join(rows)

    def dock(d):
        names = ["app-launchpad", "app-files", "FIREFOX", "STEAM", "app-store", "app-terminal", "app-settings", "SEP", "trash"]
        items = []
        for n in names:
            if n == "SEP":
                items.append('<span class="sep"></span>')
            elif n in ("FIREFOX", "STEAM"):
                items.append(f'<span class="brand">{n.title()}</span>')
            else:
                items.append(img(d, n, 52))
        return f"<div class='dock'>{''.join(items)}</div>"

    def sizes(d):
        names = ["folder-documents", "app-files", "file-pdf", "app-terminal"]
        return "<div class='sizes'>" + "".join(img(d, n, s) for n in names for s in (48, 32, 22, 16)) + "</div>"

    columns = "".join(f"""<section class="col {mode}"><h2>{label}</h2>{dock(d)}{grid(d)}<h3>Small sizes</h3>{sizes(d)}</section>"""
                      for label, d in (("Kestrel (draft 2)", out), ("WhiteSur (now)", whitesur)) for mode in ("light", "dark"))
    html = f"""<!doctype html><html><head><meta charset="utf-8"><title>Kestrel icons</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root {{ color-scheme: light dark; }}
body {{ margin: 0; font-family: Inter, system-ui, sans-serif; background: #f4f4f8; color: #1d1d24; }}
header {{ padding: 24px 28px 8px; }} header h1 {{ margin: 0 0 6px; font-weight: 600; font-size: 22px; }}
header p {{ margin: 0; max-width: 72ch; color: #55556a; line-height: 1.5; font-size: 14px; }}
main {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(520px, 1fr)); gap: 20px; padding: 20px 28px 40px; }}
.col {{ border-radius: 18px; padding: 18px 20px 22px; }}
.col.light {{ background: linear-gradient(160deg, #aebcf8, #d9c8f2 55%, #c9a0d6); color: #1d1d24; }}
.col.dark {{ background: linear-gradient(160deg, #1b1c3c, #3a2f6e 55%, #5a2e64); color: #eeeef4; }}
h2 {{ margin: 0 0 12px; font-size: 16px; font-weight: 600; }}
h3 {{ margin: 18px 0 8px; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: .06em; opacity: .7; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(86px, 1fr)); gap: 10px 6px; }}
figure {{ margin: 0; text-align: center; }} figcaption {{ font-size: 11.5px; margin-top: 4px; opacity: .85; }}
.dock {{ display: flex; align-items: center; gap: 8px; padding: 8px 12px; border-radius: 20px; width: fit-content;
        background: rgba(255,255,255,.45); border: 1px solid rgba(255,255,255,.5); backdrop-filter: blur(10px); }}
.dark .dock {{ background: rgba(30,30,40,.5); border-color: rgba(255,255,255,.18); }}
.sep {{ width: 1px; height: 40px; background: currentColor; opacity: .25; margin: 0 2px; }}
.brand {{ width: 52px; height: 52px; border-radius: 13px; display: grid; place-items: center; font-size: 9px;
         background: rgba(0,0,0,.08); opacity: .7; }}
.sizes {{ display: flex; align-items: flex-end; gap: 12px; flex-wrap: wrap; }}
.none {{ display: inline-grid; place-items: center; opacity: .4; }}
</style></head><body>
<header><h1>Kestrel icons: draft 2, close to WhiteSur</h1>
<p>WhiteSur's look (rounded tiles with depth, flat light folders with a pressed-in symbol, coloured file pages) in Kestrel's
colours, with the Kestrel bird where it fits. Firefox and Steam keep their own icons (grey boxes in the dock).
The draft is in the first two panels, WhiteSur as it is now in the last two, each on the light and the dark wallpaper.</p></header>
<main>{columns}</main></body></html>"""
    (out.parent / "icons-preview.html").write_text(html)


# Icon names (freedesktop and KDE app ids) each drawing is installed under (DECISIONS.md D28).
# Anything not listed comes from WhiteSur, which the Kestrel theme inherits.
INSTALL = {
    "apps": {
        "app-files": ["org.kde.dolphin", "system-file-manager"],
        "app-terminal": ["org.kde.konsole", "utilities-terminal", "konsole"],
        "app-settings": ["systemsettings", "preferences-system", "org.kde.systemsettings"],
        "app-store": ["org.kde.discover", "plasmadiscover"],
        "app-launchpad": ["view-app-grid"],
        "app-texteditor": ["org.kde.kate", "org.kde.kwrite", "accessories-text-editor", "kate", "kwrite"],
        "app-images": ["org.kde.gwenview", "gwenview"],
        "app-calculator": ["org.kde.kcalc", "accessories-calculator", "kcalc"],
        "app-screenshot": ["org.kde.spectacle", "spectacle"],
        "app-music": ["org.kde.elisa", "elisa"],
        "app-videos": ["org.kde.haruna", "org.kde.dragonplayer", "multimedia-video-player"],
        "app-archiver": ["org.kde.ark", "ark", "utilities-file-archiver"],
        # Own name, not "system-software-install": that one means "install software" in other apps.
        "app-installer": ["kestrel-installer", "anaconda", "org.fedoraproject.AnacondaInstaller", "liveinst"],
    },
    "places": {
        "trash": ["user-trash"],
        "trash-full": ["user-trash-full"],
        "folder-folder": ["folder", "inode-directory"],
        "folder-home": ["user-home", "folder-home"],
        "folder-documents": ["folder-documents"],
        "folder-downloads": ["folder-download", "folder-downloads"],
        "folder-pictures": ["folder-pictures", "folder-images"],
        "folder-music": ["folder-music"],
        "folder-videos": ["folder-videos"],
        "folder-desktop": ["user-desktop", "folder-desktop"],
    },
    "mimetypes": {
        "file-text": ["text-plain", "text-x-generic"],
        "file-image": ["image-png", "image-jpeg", "image-x-generic", "image-webp", "image-gif"],
        "file-pdf": ["application-pdf"],
        "file-archive": ["application-zip", "application-x-tar", "application-x-compressed-tar",
                         "application-x-7z-compressed", "application-x-rar", "application-x-archive",
                         "package-x-generic"],
        "file-audio": ["audio-mpeg", "audio-x-generic", "audio-flac", "audio-ogg", "audio-x-wav"],
        "file-video": ["video-mp4", "video-x-generic", "video-x-matroska", "video-webm"],
        "file-exe": ["application-x-ms-dos-executable", "application-x-msdownload", "application-x-msi",
                     "application-vnd.microsoft.portable-executable"],
    },
}


def drawings():
    out = {f"app-{n}": tile(n, c, g, d) for n, (c, d, g) in APPS.items()}
    out["trash"], out["trash-full"] = trash(False), trash(True)
    out.update({f"folder-{k}": folder(k) for k in FOLDER_GLYPHS})
    out.update({f"file-{k}": page(k) for k in FILE_TYPES})
    return out


def install(theme_dir):
    """Writes the drawings into an icon theme: <context>/kestrel/<name>.svg (see index.theme)."""
    art = drawings()
    for context, names in INSTALL.items():
        d = theme_dir / context / "kestrel"
        d.mkdir(parents=True, exist_ok=True)
        for drawing, aliases in names.items():
            for alias in aliases:
                (d / f"{alias}.svg").write_text(art[drawing])


def main():
    if sys.argv[1] == "--install":
        install(Path(sys.argv[2]))
        return
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, text in drawings().items():
        (out / f"{name}.svg").write_text(text)
    if len(sys.argv) > 2:
        preview(out, Path(sys.argv[2]))


if __name__ == "__main__":
    main()
