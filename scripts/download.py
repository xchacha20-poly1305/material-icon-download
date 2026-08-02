#!/usr/bin/env python3
"""Download a Material Symbols icon as SVG, PNG, or Android Vector Drawable.

Usage: download.py <icon_name> [options]

Options:
  --format <svg|png|drawable>  Output format. Default: svg.
                               "drawable" produces an Android Vector XML.
  --family <outlined|rounded|sharp>  Symbol family. Default: outlined.
  --size <20|24|40|48>         Optical size. Default: 24.
  --weight <100..700>          Weight axis. Default: 400.
  --grade <-25|0|200>          Grade axis. Default: 0.
  --fill <0|1>                 Fill axis. Default: 0.
  --color <hex>                Hex color (with or without #). SVG/PNG only.
                               Default: 1f1f1f.
  --output <path>              Output file path. Default: name based on params.
  --out-dir <dir>              Directory to drop the auto-named file into.
                               Ignored if --output is given. Default: cwd.

Drawables ship with a tint reference, not a hard color, so --color is ignored
for that format — Android applies tint at render time.

PNGs are produced locally by rendering the SVG with rsvg-convert (preferred),
cairosvg, or magick. The site itself rasterizes client-side, so there is no
upstream PNG to fetch.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

FAMILY_PATHS = {
    "outlined": "materialsymbolsoutlined",
    "rounded": "materialsymbolsrounded",
    "sharp": "materialsymbolssharp",
}


def build_variant(weight: int, grade: int, fill: int) -> str:
    parts = []
    if weight != 400:
        parts.append(f"wght{weight}")
    if grade != 0:
        if grade < 0:
            parts.append(f"gradN{abs(grade)}")
        else:
            parts.append(f"grad{grade}")
    if fill != 0:
        parts.append(f"fill{fill}")
    return "".join(parts) or "default"


def build_url(family: str, icon: str, variant: str, size: int, fmt: str) -> str:
    family_path = FAMILY_PATHS[family]
    ext = "xml" if fmt in ("drawable", "xml") else "svg"
    return f"https://fonts.gstatic.com/s/i/short-term/release/{family_path}/{icon}/{variant}/{size}px.{ext}"


def inject_color_into_svg(path: Path, hex_color: str):
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    tree = ET.parse(path)
    tree.getroot().set("fill", f"#{hex_color}")
    tree.write(path, xml_declaration=False, encoding="utf-8")


def default_filename(icon: str, size: int, color: str, fill: int, weight: int, grade: int, fmt: str) -> str:
    upper_color = color.upper()
    if fmt in ("drawable", "xml"):
        return f"{icon}_{size}dp.xml"
    ext = "png" if fmt == "png" else "svg"
    return f"{icon}_{size}dp_{upper_color}_FILL{fill}_wght{weight}_GRAD{grade}_opsz{size}.{ext}"


def download_file(url: str, dest: str):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as resp:
        Path(dest).write_bytes(resp.read())


def svg_to_png(svg_path: str, png_path: str, size: int):
    try:
        import cairosvg
        cairosvg.svg2png(url=svg_path, write_to=png_path,
                         output_width=size, output_height=size)
    except ImportError:
        if shutil.which("rsvg-convert"):
            subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", png_path, svg_path], check=True)
        elif shutil.which("magick"):
            subprocess.run(["magick", "-background", "none", svg_path, "-resize", f"{size}x{size}", png_path], check=True)
        else:
            print("PNG export needs cairosvg (pip install cairosvg), rsvg-convert, or magick (ImageMagick).", file=sys.stderr)
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Download a Material Symbols icon.")
    parser.add_argument("icon", help="Icon name (snake_case)")
    parser.add_argument("--format", default="svg", choices=["svg", "png", "drawable", "xml"], dest="fmt")
    parser.add_argument("--family", default="outlined", choices=["outlined", "rounded", "sharp"])
    parser.add_argument("--size", type=int, default=24)
    parser.add_argument("--weight", type=int, default=400)
    parser.add_argument("--grade", type=int, default=0)
    parser.add_argument("--fill", type=int, default=0)
    parser.add_argument("--color", default="1f1f1f")
    parser.add_argument("--output", "-o", default="")
    parser.add_argument("--out-dir", default=".")
    args = parser.parse_args()

    color = args.color.lstrip("#")
    variant = build_variant(args.weight, args.grade, args.fill)
    url = build_url(args.family, args.icon, variant, args.size, args.fmt)

    if args.output:
        output = args.output
    else:
        filename = default_filename(args.icon, args.size, color, args.fill, args.weight, args.grade, args.fmt)
        output = os.path.join(args.out_dir, filename)

    Path(output).parent.mkdir(parents=True, exist_ok=True)

    if args.fmt in ("drawable", "xml"):
        download_file(url, output)
    elif args.fmt == "svg":
        download_file(url, output)
        inject_color_into_svg(Path(output), color)
    elif args.fmt == "png":
        with tempfile.NamedTemporaryFile(suffix=".svg", delete=False) as tmp:
            tmpsvg = tmp.name
        try:
            download_file(url, tmpsvg)
            inject_color_into_svg(Path(tmpsvg), color)
            svg_to_png(tmpsvg, output, args.size)
        finally:
            os.unlink(tmpsvg)

    print(output)


if __name__ == "__main__":
    main()
