#!/usr/bin/env python3
"""Search Material Symbols icons by keyword.

Matches against the icon name, tags, and categories.

Usage:
  search.py <keyword> [keyword...]   # list matching icons
  search.py --json <keyword>         # raw JSON entries (for further processing)
  search.py --limit N <keyword>      # cap results (default 50)
"""

import argparse
import json
import signal
import sys
from pathlib import Path

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

from fetch_metadata import fetch_metadata


def matches(icon: dict, needles: list[str]) -> bool:
    name = icon.get("name", "").lower()
    tags = [t.lower() for t in icon.get("tags", [])]
    categories = [c.lower() for c in icon.get("categories", [])]
    for needle in needles:
        if needle in name:
            continue
        if any(needle in t for t in tags):
            continue
        if any(needle in c for c in categories):
            continue
        return False
    return True


def search(keywords: list[str], limit: int) -> list[dict]:
    metadata_path = fetch_metadata()
    data = json.loads(Path(metadata_path).read_text(encoding="utf-8"))
    needles = [k.lower() for k in keywords]

    results = [icon for icon in data.get("icons", []) if matches(icon, needles)]
    seen = set()
    unique = []
    for icon in results:
        if icon["name"] not in seen:
            seen.add(icon["name"])
            unique.append(icon)
    unique.sort(key=lambda i: -(i.get("popularity", 0)))
    return unique[:limit]


def main():
    parser = argparse.ArgumentParser(description="Search Material Symbols icons by keyword.")
    parser.add_argument("keywords", nargs="*", help="Keywords to search (AND'd)")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output raw JSON entries")
    parser.add_argument("--limit", type=int, default=50, help="Cap results (default 50)")
    args = parser.parse_args()

    if not args.keywords:
        parser.print_usage(sys.stderr)
        sys.exit(1)

    results = search(args.keywords, args.limit)

    if args.as_json:
        json.dump(results, sys.stdout, indent=2)
        print()
    else:
        for icon in results:
            name = icon["name"]
            cats = ",".join(icon.get("categories", []))
            pop = icon.get("popularity", 0)
            print(f"{name:<30s} {cats:<30s} pop={pop}")


if __name__ == "__main__":
    main()
