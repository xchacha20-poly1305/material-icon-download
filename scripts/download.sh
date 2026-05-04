#!/usr/bin/env bash
# Download a Material Symbols icon as SVG, PNG, or Android Vector Drawable.
#
# Usage: download.sh <icon_name> [options]
#
# Options:
#   --format <svg|png|drawable>  Output format. Default: svg.
#                                "drawable" produces an Android Vector XML.
#   --family <outlined|rounded|sharp>  Symbol family. Default: outlined.
#   --size <20|24|40|48>         Optical size. Default: 24.
#   --weight <100..700>          Weight axis. Default: 400.
#   --grade <-25|0|200>          Grade axis. Default: 0.
#   --fill <0|1>                 Fill axis. Default: 0.
#   --color <hex>                Hex color (with or without #). SVG/PNG only.
#                                Default: 1f1f1f.
#   --output <path>              Output file path. Default: name based on params.
#   --out-dir <dir>              Directory to drop the auto-named file into.
#                                Ignored if --output is given. Default: cwd.
#
# Drawables ship with a tint reference, not a hard color, so --color is ignored
# for that format — Android applies tint at render time.
#
# PNGs are produced locally by rendering the SVG with rsvg-convert (preferred),
# cairosvg, or magick. The site itself rasterizes client-side, so there is no
# upstream PNG to fetch.

set -euo pipefail

icon=""
format="svg"
family="outlined"
size="24"
weight="400"
grade="0"
fill="0"
color="1f1f1f"
output=""
out_dir="."

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

icon="$1"; shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) format="$2"; shift 2 ;;
    --family) family="$2"; shift 2 ;;
    --size) size="$2"; shift 2 ;;
    --weight) weight="$2"; shift 2 ;;
    --grade) grade="$2"; shift 2 ;;
    --fill) fill="$2"; shift 2 ;;
    --color) color="${2#\#}"; shift 2 ;;
    --output|-o) output="$2"; shift 2 ;;
    --out-dir) out_dir="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Family path (lowercase, no spaces)
case "$family" in
  outlined) family_path="materialsymbolsoutlined" ;;
  rounded)  family_path="materialsymbolsrounded" ;;
  sharp)    family_path="materialsymbolssharp" ;;
  *) echo "Invalid --family: $family (use outlined|rounded|sharp)" >&2; exit 1 ;;
esac

# Build variant path. Order is fixed: wght, grad, fill.
# Each axis is omitted when at its default (wght=400, grad=0, fill=0).
# Negative grad is encoded with capital N (e.g., grad=-25 -> "gradN25").
# When all axes are default the path segment is the literal "default".
variant=""
[[ "$weight" != "400" ]] && variant+="wght${weight}"
if [[ "$grade" != "0" ]]; then
  if [[ "$grade" == -* ]]; then
    variant+="gradN${grade#-}"
  else
    variant+="grad${grade}"
  fi
fi
[[ "$fill" != "0" ]] && variant+="fill${fill}"
[[ -z "$variant" ]] && variant="default"

# What file extension does gstatic serve?
case "$format" in
  svg|png)        src_ext="svg" ;;
  drawable|xml)   src_ext="xml" ;;
  *) echo "Invalid --format: $format (use svg|png|drawable)" >&2; exit 1 ;;
esac

url="https://fonts.gstatic.com/s/i/short-term/release/${family_path}/${icon}/${variant}/${size}px.${src_ext}"

# Default output filename mirrors the one fonts.google.com produces, so files
# stay recognizable to people used to downloading from the site.
if [[ -z "$output" ]]; then
  upper_color=$(printf '%s' "$color" | tr 'a-z' 'A-Z')
  case "$format" in
    svg) output="${out_dir%/}/${icon}_${size}dp_${upper_color}_FILL${fill}_wght${weight}_GRAD${grade}_opsz${size}.svg" ;;
    png) output="${out_dir%/}/${icon}_${size}dp_${upper_color}_FILL${fill}_wght${weight}_GRAD${grade}_opsz${size}.png" ;;
    drawable|xml) output="${out_dir%/}/${icon}_${size}dp.xml" ;;
  esac
fi

mkdir -p "$(dirname "$output")"

inject_color_into_svg() {
  # The upstream SVG has no fill attribute. The website injects fill on the
  # <svg> element when rendering its preview. We do the same so the resulting
  # file looks like the one users would download from fonts.google.com.
  #
  # Parse as XML instead of poking at the markup with a regex: attribute order,
  # whitespace, and pre-existing fill attributes all become non-issues, and
  # register_namespace keeps the default xmlns on the root (otherwise
  # ElementTree would rewrite it with a synthetic ns0: prefix).
  local file="$1" hex="$2"
  python3 -c "
import sys
import xml.etree.ElementTree as ET

path, hex_ = sys.argv[1], sys.argv[2]
ET.register_namespace('', 'http://www.w3.org/2000/svg')
tree = ET.parse(path)
tree.getroot().set('fill', f'#{hex_}')
tree.write(path, xml_declaration=False, encoding='utf-8')
" "$file" "$hex"
}

case "$format" in
  drawable|xml)
    curl -fsSL "$url" -o "$output"
    ;;
  svg)
    curl -fsSL "$url" -o "$output"
    inject_color_into_svg "$output" "$color"
    ;;
  png)
    tmpsvg=$(mktemp --suffix=.svg)
    trap 'rm -f "$tmpsvg"' EXIT
    curl -fsSL "$url" -o "$tmpsvg"
    inject_color_into_svg "$tmpsvg" "$color"
    if command -v rsvg-convert >/dev/null 2>&1; then
      rsvg-convert -w "$size" -h "$size" -o "$output" "$tmpsvg"
    elif command -v cairosvg >/dev/null 2>&1; then
      cairosvg "$tmpsvg" -W "$size" -H "$size" -o "$output"
    elif command -v magick >/dev/null 2>&1; then
      magick -background none "$tmpsvg" -resize "${size}x${size}" "$output"
    else
      echo "PNG export needs rsvg-convert, cairosvg, or magick (ImageMagick) installed." >&2
      exit 1
    fi
    ;;
esac

echo "$output"
