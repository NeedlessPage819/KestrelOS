#!/usr/bin/env python3
"""Rounded progress bar for the Kestrel boot screen (DECISIONS.md D21).

Plymouth's built-in progress bar is a plain rectangle. Its two-step module can instead show
a "progress animation": numbered pictures progress-0000.png ... of which it shows the one
matching the boot progress. This writes those pictures: a thin bar with fully rounded ends,
like the Mac's start screen, white on dark grey.

Usage: boot_progress.py OUTPUT_DIR
"""
import subprocess
import sys
from pathlib import Path

W, H = 180, 6            # same width as before, 2 px taller so the round ends show
FRAMES = 50
TRACK = "#3a3a3c"
FILL = "#ffffff"


def frame(fraction):
    r = H / 2
    fill_w = max(H, round(W * fraction, 2))   # never thinner than a dot, so the ends stay round
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}">
  <rect width="{W}" height="{H}" rx="{r}" fill="{TRACK}"/>
  <rect width="{fill_w}" height="{H}" rx="{r}" fill="{FILL}"/>
</svg>"""


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for i in range(FRAMES):
        svg = frame(i / (FRAMES - 1))
        subprocess.run(["rsvg-convert", "-o", str(out / f"progress-{i:04d}.png")],
                       input=svg.encode(), check=True)


if __name__ == "__main__":
    main()
