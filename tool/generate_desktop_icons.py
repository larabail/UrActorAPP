#!/usr/bin/env python3
"""Derive the macOS and Windows app icons from the iOS one.

`flutter create` writes a Flutter logo into `macos/` and `windows/`, and
nothing replaces it: only the Android and iOS icons were ever set, so the
desktop builds shipped with the toolchain's placeholder. This regenerates both
from the iOS artwork so all four platforms show the same icon.

Run it after changing the iOS icon:

    pip3 install --user Pillow
    python3 tool/generate_desktop_icons.py

It rewrites tracked binaries in place, so check `git diff --stat` afterwards.
Pillow is deliberately not a CI dependency -- the generated icons are committed
and this only runs when the artwork changes.

Two details that are easy to get wrong, and are the reason this is a script
rather than a note in a README:

* The iOS icon has *opaque white* corners. The App Store rejects an icon with
  an alpha channel, so the rounded shape is painted on rather than cut out.
  Copied straight to macOS, that renders as a white square with the icon inside
  it. The corners are flood filled back to transparent here, starting from the
  four corners so that the white sprocket holes in the artwork -- which are not
  connected to the edge -- are left alone.

* macOS icons are not full bleed. Apple's grid leaves a margin, and an icon
  that fills its canvas looks oversized next to every other icon in the Dock.
  The artwork is scaled to 824px inside a transparent 1024px canvas, which is
  the proportion Apple's own icons use. Windows has no such convention, so it
  keeps the full bleed square.
"""

from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is needed: pip3 install --user Pillow")

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png"
MACOS_DIR = REPO / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
WINDOWS_ICO = REPO / "windows/runner/resources/app_icon.ico"

# Named in Contents.json. 16 and 64 exist only as the @2x of 32 and 32,
# so every size below is referenced even though the set looks redundant.
MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]

# What Explorer, the taskbar and the Inno Setup installer pick between.
WINDOWS_SIZES = [16, 24, 32, 48, 64, 128, 256]

# Fraction of the canvas Apple's grid gives to a rounded-rect icon.
MACOS_ARTWORK_RATIO = 824 / 1024

# How close to white a pixel must be to count as corner padding. The artwork's
# own white is pure, so this only needs to tolerate resampling fringes.
WHITE_THRESHOLD = 238


def cut_transparent_corners(image: Image.Image) -> Image.Image:
    """Flood fill the painted-on corners back to transparent.

    Starts from the four corners and spreads through connected near-white
    pixels, so interior white in the artwork survives. A corner that is already
    transparent costs one lookup and stops.
    """
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()

    seen = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    for start in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        queue.append(start)

    while queue:
        x, y = queue.popleft()
        if not (0 <= x < width and 0 <= y < height):
            continue
        index = y * width + x
        if seen[index]:
            continue
        seen[index] = 1

        r, g, b, a = pixels[x, y]
        if a == 0:
            # Already transparent: nothing to clear, but keep spreading so a
            # partly transparent source still reaches its white fringe.
            queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
            continue
        if not (r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD):
            continue

        pixels[x, y] = (r, g, b, 0)
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    return image


def inset_for_macos(image: Image.Image) -> Image.Image:
    """Centre the artwork on a transparent canvas, leaving Apple's margin."""
    canvas_size = image.size[0]
    artwork_size = round(canvas_size * MACOS_ARTWORK_RATIO)
    artwork = image.resize((artwork_size, artwork_size), Image.LANCZOS)

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    offset = (canvas_size - artwork_size) // 2
    canvas.paste(artwork, (offset, offset), artwork)
    return canvas


def main() -> int:
    if not SOURCE.is_file():
        sys.exit(f"no source icon at {SOURCE}")

    source = Image.open(SOURCE)
    if source.size != (1024, 1024):
        sys.exit(f"expected a 1024x1024 source, got {source.size}")

    cut = cut_transparent_corners(source)

    macos_master = inset_for_macos(cut)
    for size in MACOS_SIZES:
        target = MACOS_DIR / f"app_icon_{size}.png"
        macos_master.resize((size, size), Image.LANCZOS).save(target, "PNG")
        print(f"  wrote {target.relative_to(REPO)}")

    # Pillow builds every requested size into the one file, so Windows picks
    # the right one instead of scaling a single bitmap badly.
    WINDOWS_ICO.parent.mkdir(parents=True, exist_ok=True)
    cut.save(WINDOWS_ICO, "ICO", sizes=[(s, s) for s in WINDOWS_SIZES])
    print(f"  wrote {WINDOWS_ICO.relative_to(REPO)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
