"""Regenerate the theme wallpaper tiles from one shared glyph mask.

Every theme paints the same wallpaper. `assets/images/background_tile.png` is
the mask itself — an outline scatter of kana and kanji on pure white — and each
theme tile is that exact alpha channel re-tinted, so a theme never introduces a
second texture language.

Sakura's tile was painted by hand before this script existed. It is listed here
on purpose: reproducing a committed tile proves the script is faithful, and a
tile whose pixels already match is left untouched, so a clean tree stays clean
and `--check` can run as a guard.

Usage:
    <venv>/python tool/theme_tiles/make_theme_tile.py [--check]

`--check` writes nothing and exits non-zero if a tile is missing, is the wrong
size, or no longer matches its mask+tint.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops

REPO = Path(__file__).resolve().parents[2]
ASSET_DIR = REPO / "assets" / "images"

# The alpha mask every theme tile is built from.
MASK_FILE = "background_tile.png"

# Tile file -> tint. Order is stable so the output reads the same every run.
TILES: dict[str, tuple[int, int, int]] = {
    "background_tile_sakura.png": (0xC2, 0x5B, 0x77),
    "background_tile_ps1.png": (0x6E, 0x6E, 0x6E),
}


def hex_of(tint: tuple[int, int, int]) -> str:
    return "#%02X%02X%02X" % tint


def build(mask: Image.Image, tint: tuple[int, int, int]) -> Image.Image:
    """Flat tint at the mask's alpha — the shape comes from the mask alone."""
    out = Image.new("RGB", mask.size, tint).convert("RGBA")
    out.putalpha(mask.getchannel("A"))
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report only; exit non-zero if a tile needs regenerating",
    )
    args = parser.parse_args()

    mask_path = ASSET_DIR / MASK_FILE
    if not mask_path.exists():
        print(f"mask not found: {mask_path}")
        return 1
    mask = Image.open(mask_path).convert("RGBA")
    print(f"mask {MASK_FILE}  {mask.size[0]}x{mask.size[1]}\n")

    stale: list[str] = []

    for name, tint in TILES.items():
        target = ASSET_DIR / name
        expected = build(mask, tint)

        if not target.exists():
            if args.check:
                print(f"MISSING  {name:32s} {hex_of(tint)}")
                stale.append(name)
                continue
            expected.save(target)
            print(f"CREATED  {name:32s} {hex_of(tint)}  {target.stat().st_size} B")
            continue

        actual = Image.open(target).convert("RGBA")
        if actual.size != mask.size:
            print(f"SIZE     {name:32s} {actual.size} != {mask.size}")
            stale.append(name)
            continue

        if ImageChops.difference(actual, expected).getbbox() is None:
            print(f"OK       {name:32s} {hex_of(tint)}  pixels match, untouched")
            continue

        if args.check:
            print(f"STALE    {name:32s} {hex_of(tint)}  does not match mask+tint")
            stale.append(name)
            continue

        expected.save(target)
        print(f"UPDATED  {name:32s} {hex_of(tint)}  {target.stat().st_size} B")

    if stale:
        print(f"\n{len(stale)} tile(s) need attention")
        return 1
    print("\nall theme tiles consistent with the shared mask")
    return 0


if __name__ == "__main__":
    sys.exit(main())
