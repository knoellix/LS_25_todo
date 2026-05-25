#!/usr/bin/env python3
"""
Generate FS25_FieldToDoList graphics from SVG sources.

Outputs:
  gui/menuIcon.svg      Source for menuIcon.dds (dev/build only, not shipped)
  gui/menuIcon.dds      In-game ESC menu tab texture
  gui/icons/*.svg       Optional button icon sources (not used in current UI)
  icon.dds              Mod list icon (512x512)

Requirements for conversion (at least one):
  - ImageMagick (convert or magick)
  - or: rsvg-convert + ImageMagick

Usage:
  python3 tools/generate_assets.py
  python3 tools/generate_assets.py --only svg
  python3 tools/generate_assets.py --only dds
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUI_DIR = ROOT / "gui"

# Light glyph for dark in-game menu sidebars (FS25 tab icons)
MENU_ICON_SVG = """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <rect width="1024" height="1024" fill="none"/>
  <!-- Clipboard -->
  <rect x="280" y="200" width="464" height="620" rx="48" fill="none" stroke="#F2F2F2" stroke-width="44"/>
  <rect x="392" y="140" width="240" height="88" rx="36" fill="none" stroke="#F2F2F2" stroke-width="40"/>
  <!-- Checklist lines -->
  <path d="M360 380 L420 440 L540 320" fill="none" stroke="#8BC34A" stroke-width="40" stroke-linecap="round" stroke-linejoin="round"/>
  <line x1="580" y1="380" x2="680" y2="380" stroke="#D8D8D8" stroke-width="32" stroke-linecap="round"/>
  <path d="M360 520 L420 580 L540 460" fill="none" stroke="#8BC34A" stroke-width="40" stroke-linecap="round" stroke-linejoin="round"/>
  <line x1="580" y1="520" x2="720" y2="520" stroke="#D8D8D8" stroke-width="32" stroke-linecap="round"/>
  <circle cx="400" cy="660" r="28" fill="none" stroke="#B0B0B0" stroke-width="28"/>
  <line x1="580" y1="660" x2="700" y2="660" stroke="#B0B0B0" stroke-width="32" stroke-linecap="round"/>
  <!-- Small field grid (field overview hint) -->
  <rect x="720" y="720" width="180" height="120" rx="12" fill="none" stroke="#8BC34A" stroke-width="24"/>
  <line x1="780" y1="720" x2="780" y2="840" stroke="#8BC34A" stroke-width="16"/>
  <line x1="840" y1="720" x2="840" y2="840" stroke="#8BC34A" stroke-width="16"/>
  <line x1="720" y1="780" x2="900" y2="780" stroke="#8BC34A" stroke-width="16"/>
</svg>
"""

# 128x128 button icons (white on transparent) — replace gui/icons/*.svg anytime
BUTTON_ICONS: dict[str, str] = {
    "add": """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" fill="none"/>
  <line x1="64" y1="28" x2="64" y2="100" stroke="#F2F2F2" stroke-width="14" stroke-linecap="round"/>
  <line x1="28" y1="64" x2="100" y2="64" stroke="#F2F2F2" stroke-width="14" stroke-linecap="round"/>
</svg>
""",
    "edit": """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" fill="none"/>
  <path d="M88 24 L104 40 L52 92 L28 100 L36 76 Z" fill="none" stroke="#F2F2F2" stroke-width="10" stroke-linejoin="round"/>
  <line x1="76" y1="36" x2="92" y2="52" stroke="#8BC34A" stroke-width="8" stroke-linecap="round"/>
</svg>
""",
    "done": """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" fill="none"/>
  <path d="M28 72 L52 96 L100 36" fill="none" stroke="#8BC34A" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M72 88 L100 88 L100 100 L28 100 L28 72 L40 72 L40 88 Z" fill="none" stroke="#F2F2F2" stroke-width="8" stroke-linejoin="round"/>
</svg>
""",
    "delete": """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" fill="none"/>
  <line x1="36" y1="36" x2="92" y2="92" stroke="#F2F2F2" stroke-width="14" stroke-linecap="round"/>
  <line x1="92" y1="36" x2="36" y2="92" stroke="#F2F2F2" stroke-width="14" stroke-linecap="round"/>
</svg>
""",
}

LOGO_SVG = """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <linearGradient id="field" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#3d6b2e"/>
      <stop offset="100%" style="stop-color:#6fa84a"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="64" fill="url(#field)"/>
  <rect x="96" y="72" width="220" height="300" rx="24" fill="none" stroke="#ffffff" stroke-width="16"/>
  <rect x="156" y="48" width="100" height="40" rx="12" fill="none" stroke="#ffffff" stroke-width="14"/>
  <path d="M128 160 L156 188 L200 132" fill="none" stroke="#c8e6c9" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>
  <line x1="220" y1="160" x2="280" y2="160" stroke="#ffffff" stroke-width="12" stroke-linecap="round"/>
  <path d="M128 220 L156 248 L200 192" fill="none" stroke="#c8e6c9" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>
  <line x1="220" y1="220" x2="300" y2="220" stroke="#ffffff" stroke-width="12" stroke-linecap="round"/>
  <rect x="300" y="300" width="120" height="80" rx="8" fill="none" stroke="#e8f5e9" stroke-width="10"/>
  <line x1="340" y1="300" x2="340" y2="380" stroke="#e8f5e9" stroke-width="6"/>
  <line x1="380" y1="300" x2="380" y2="380" stroke="#e8f5e9" stroke-width="6"/>
  <line x1="300" y1="340" x2="420" y2="340" stroke="#e8f5e9" stroke-width="6"/>
</svg>
"""


def write_svgs() -> None:
    GUI_DIR.mkdir(parents=True, exist_ok=True)
    icons_dir = GUI_DIR / "icons"
    icons_dir.mkdir(parents=True, exist_ok=True)

    (GUI_DIR / "menuIcon.svg").write_text(MENU_ICON_SVG, encoding="utf-8")
    (GUI_DIR / "logo.svg").write_text(LOGO_SVG, encoding="utf-8")
    print(f"Wrote {GUI_DIR / 'menuIcon.svg'}")
    print(f"Wrote {GUI_DIR / 'logo.svg'}")

    for name, svg in BUTTON_ICONS.items():
        path = icons_dir / f"{name}.svg"
        path.write_text(svg, encoding="utf-8")
        print(f"Wrote {path}")


def find_convert() -> list[str] | None:
    if shutil.which("magick"):
        return ["magick"]
    if shutil.which("convert"):
        return ["convert"]
    return None


def svg_to_png(svg_path: Path, png_path: Path, size: int) -> bool:
    if shutil.which("rsvg-convert"):
        cmd = [
            "rsvg-convert",
            "-w",
            str(size),
            "-h",
            str(size),
            "-o",
            str(png_path),
            str(svg_path),
        ]
        subprocess.run(cmd, check=True)
        return True

    convert = find_convert()
    if convert is None:
        return False

    cmd = [
        *convert,
        "-background",
        "none",
        "-resize",
        f"{size}x{size}",
        str(svg_path),
        str(png_path),
    ]
    subprocess.run(cmd, check=True)
    return True


def png_to_dds(png_path: Path, dds_path: Path, use_alpha: bool) -> bool:
    convert = find_convert()
    if convert is None:
        return False

    compression = "dxt5" if use_alpha else "dxt1"
    cmd = [
        *convert,
        str(png_path),
        "-define",
        f"dds:compression={compression}",
        "-define",
        "dds:mipmaps=0",
        str(dds_path),
    ]
    subprocess.run(cmd, check=True)
    return True


def convert_all() -> int:
    menu_svg = GUI_DIR / "menuIcon.svg"
    logo_svg = GUI_DIR / "logo.svg"

    if not menu_svg.is_file() or not logo_svg.is_file():
        write_svgs()

    tmp_dir = ROOT / ".build" / "assets"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    menu_png = tmp_dir / "menuIcon.png"
    icon_png = tmp_dir / "icon.png"

    try:
        if not svg_to_png(menu_svg, menu_png, 1024):
            print("error: need rsvg-convert or ImageMagick to rasterize SVG", file=sys.stderr)
            return 1

        if not svg_to_png(logo_svg, icon_png, 512):
            print("error: failed to rasterize logo.svg", file=sys.stderr)
            return 1

        if not png_to_dds(menu_png, GUI_DIR / "menuIcon.dds", use_alpha=True):
            print("error: ImageMagick required for DDS export", file=sys.stderr)
            return 1

        if not png_to_dds(icon_png, ROOT / "icon.dds", use_alpha=False):
            print("error: failed to write icon.dds", file=sys.stderr)
            return 1

        icons_dir = GUI_DIR / "icons"
        icons_dir.mkdir(parents=True, exist_ok=True)
        for name in BUTTON_ICONS:
            svg_path = icons_dir / f"{name}.svg"
            if not svg_path.is_file():
                write_svgs()
            icon_png = tmp_dir / f"{name}.png"
            icon_dds = icons_dir / f"{name}.dds"
            if not svg_to_png(svg_path, icon_png, 128):
                print(f"error: failed to rasterize {svg_path}", file=sys.stderr)
                return 1
            if not png_to_dds(icon_png, icon_dds, use_alpha=True):
                print(f"error: failed to write {icon_dds}", file=sys.stderr)
                return 1
            print(f"Wrote {icon_dds}")

    except subprocess.CalledProcessError as exc:
        print(f"error: conversion command failed: {exc}", file=sys.stderr)
        return 1

    print(f"Wrote {GUI_DIR / 'menuIcon.dds'}")
    print(f"Wrote {ROOT / 'icon.dds'}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate FS25_FieldToDoList SVG/DDS assets")
    parser.add_argument(
        "--only",
        choices=("svg", "dds", "all"),
        default="all",
        help="Generate only SVG sources, only DDS textures, or everything",
    )
    args = parser.parse_args()

    if args.only in ("svg", "all"):
        write_svgs()

    if args.only in ("dds", "all"):
        return convert_all()

    return 0


if __name__ == "__main__":
    sys.exit(main())
