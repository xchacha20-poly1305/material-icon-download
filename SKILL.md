---
name: material-icon-download
description: Download Material Symbols icons from fonts.google.com/icons as SVG, PNG, or Android Vector Drawable. Use this whenever the user asks for a Material icon, Material Symbols icon, or asks to grab a "home icon", "search icon", etc. from Google Fonts — even if they don't explicitly say "Material" or name the format. Also use it for any reference to material-symbols-outlined / rounded / sharp, or when the user wants to find an icon by keyword (e.g., "I need an icon that means 'sync'") and download it.
---

# Material Symbols icon download

This skill fetches icons from `fonts.gstatic.com` directly. The URL pattern was reverse-engineered from `fonts.google.com/icons`, so no browser, MCP server, or scraping is needed at runtime.

Two scripts live in `scripts/`:

- `search.sh` — find icons by keyword. Searches the Material Symbols metadata catalog (cached locally) by name, tag, and category. Returns icons sorted by popularity.
- `download.sh` — download a specific icon. Supports SVG, PNG, and Android Vector Drawable (`*.xml`).

Both scripts are self-contained shell + `jq` + `curl` + `python3`. No node, no headless browser. PNG output additionally needs one of `rsvg-convert`, `cairosvg`, or `magick` (ImageMagick) on the path; the script picks whichever it finds.

## When to use this skill

Use it any time the user wants a Material icon. Common phrasings:

- "Get me the home icon as an SVG"
- "Download a search icon for my React app"
- "I need an Android drawable for a settings gear"
- "Find me an icon that means 'refresh' or 'reload'"
- "Save the favorite icon (filled) at 48px in red"

Don't use it for non-Material icon sets (Font Awesome, Lucide, Heroicons, etc.) — that requires a different source.

## Workflow

1. **If the user gave you the exact icon name** (e.g., "home", "search", "favorite"): jump straight to `download.sh`.
2. **If the user described the icon by meaning** ("an icon for cloud sync", "something that means delete"): run `search.sh` first to get candidates, show the top results, then download once the user picks one (or pick the most popular yourself if the user signaled they don't care).
3. **If the user is unsure about variant** (FILL/weight/grade/size): default to SVG, outlined, 24px, weight 400 — that matches what `fonts.google.com/icons` shows on first load. Mention you used defaults so they can change them.

## Searching

```bash
scripts/search.sh <keyword> [more keywords] [--limit N] [--json]
```

- Multiple keywords are AND'd. `search.sh home house` finds icons that match both.
- Output is `name <TAB> categories <TAB> popularity`. Higher popularity is more commonly used and usually what the user wants.
- `--json` gives the full metadata entries for downstream scripting.
- Metadata is cached at `$TMPDIR/material-symbols-skill/metadata.json` and refreshed once a day. The first call may take a few seconds (it downloads ~6 MB).

Examples:

```bash
scripts/search.sh search                # → search, search_off, manage_search…
scripts/search.sh sync cloud            # → cloud_sync, cloud_upload…
scripts/search.sh trash --limit 3       # top 3 trash-related icons
```

## Downloading

```bash
scripts/download.sh <icon_name> [options]
```

Options (all optional except the icon name):

| Option | Values | Default | Notes |
| --- | --- | --- | --- |
| `--format` | `svg` / `png` / `drawable` | `svg` | `drawable` produces an Android Vector XML (`<vector>`). |
| `--family` | `outlined` / `rounded` / `sharp` | `outlined` | Three Material Symbols families. |
| `--size` | `20` / `24` / `40` / `48` | `24` | Optical size, baked into the glyph shape. |
| `--weight` | `100`–`700` (steps of 100) | `400` | |
| `--grade` | `-25` / `0` / `200` | `0` | Only these three values exist. |
| `--fill` | `0` / `1` | `0` | |
| `--color` | hex (with or without `#`) | `1f1f1f` | Ignored for `drawable` — Android applies tint at render. |
| `--output` | path | auto | Full output path. |
| `--out-dir` | dir | `.` | Directory for the auto-named file. Ignored if `--output` is set. |

The auto-named filename matches what `fonts.google.com` produces on download, e.g. `home_24dp_1F1F1F_FILL0_wght400_GRAD0_opsz24.svg`. Drawables are named `home_24dp.xml`.

The script prints the resulting file path on stdout, so you can chain it:

```bash
out=$(scripts/download.sh home --color 005bbb --out-dir ./icons)
echo "saved $out"
```

### Examples

```bash
# Default 24px outlined SVG
scripts/download.sh home

# Filled, heavy weight, 48px, in brand red
scripts/download.sh favorite --fill 1 --weight 700 --size 48 --color e91e63

# Android drawable for the rounded family
scripts/download.sh settings --family rounded --format drawable

# PNG for a slide deck, named explicitly
scripts/download.sh download --format png --size 48 --output ~/decks/dl.png
```

## Format notes (why each format works the way it does)

- **SVG**: fetched from `fonts.gstatic.com/.../{size}px.svg`. Upstream the file has no fill, so the script injects `fill="#<color>"` on the `<svg>` element to match what the website ships in its download. Edit the file freely; it's just XML.
- **Drawable XML**: fetched from `fonts.gstatic.com/.../{size}px.xml`. The `<vector>` ships with `android:tint="?attr/colorControlNormal"` and a placeholder fill of `@android:color/white` — Android applies the actual color at render time. That's why `--color` is ignored here.
- **PNG**: there is no upstream PNG. The website rasterizes client-side. The script does the same: fetch the SVG, inject the color, then render with `rsvg-convert` (preferred), `cairosvg`, or `magick`.

## Variant URL construction (for reference)

The script does this for you, but if you ever need to debug or build a URL by hand:

```
https://fonts.gstatic.com/s/i/short-term/release/{family_path}/{icon}/{variant}/{size}px.{ext}
```

- `family_path` ∈ `materialsymbolsoutlined` / `materialsymbolsrounded` / `materialsymbolssharp`
- `variant` is `default` if all axes match the defaults (wght=400, grad=0, fill=0). Otherwise it's the non-default axes concatenated **in this fixed order**: `wght{N}`, then `grad{N}` (negative grade → `gradN{abs}`), then `fill{N}`. Example: weight 500 + grade 200 + fill 1 → `wght500grad200fill1`.
- `ext` is `svg` for SVG/PNG, `xml` for drawable.

If you swap the axis order, gstatic returns 404 — order matters.

## Common pitfalls

- **Icon name format**: the metadata uses `snake_case` (e.g., `arrow_back`, `check_circle`). If you got a name from a designer that uses spaces or camelCase, lowercase it and replace separators with underscores.
- **Some icons aren't supported in every family**. The metadata records `unsupported_families` per icon. If a download 404s for `--family rounded`, try a different family.
- **Grade is sparse**: only `-25`, `0`, and `200` are valid. Other values 404.
- **PNG color matters**: the upstream SVG is colorless, so you must pass `--color` if you want anything other than the dark grey default.
