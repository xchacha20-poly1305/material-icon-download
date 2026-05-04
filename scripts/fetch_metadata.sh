#!/usr/bin/env bash
# Download (and cache) the Material Symbols metadata file.
# Prints the path to the cached metadata JSON on stdout.
#
# Why cached: the file is ~6 MB. We don't want to redownload every search.
# Cache lives in $TMPDIR (or /tmp). Re-fetched if older than 24h.

set -euo pipefail

cache_dir="${TMPDIR:-/tmp}/material-symbols-skill"
mkdir -p "$cache_dir"
metadata="$cache_dir/metadata.json"

# Refetch when missing or older than a day
if [[ ! -s "$metadata" ]] || [[ $(find "$metadata" -mtime +1 -print 2>/dev/null) ]]; then
  url='https://fonts.google.com/metadata/icons?key=material_symbols&incomplete=true'
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL "$url" -o "$tmp"
  # The response is prefixed with )]}' to defeat JSON hijacking. Strip it.
  if head -c 5 "$tmp" | grep -q "^)]}"; then
    sed -i '1{/^)\]\}/d}' "$tmp"
  fi
  mv "$tmp" "$metadata"
  trap - EXIT
fi

echo "$metadata"
