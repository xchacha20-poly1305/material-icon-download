#!/usr/bin/env bash
# Search Material Symbols icons by keyword.
# Matches against the icon name, tags, and categories.
#
# Usage:
#   search.sh <keyword> [keyword...]   # list matching icons
#   search.sh --json <keyword>         # raw JSON entries (for further processing)
#   search.sh --limit N <keyword>      # cap results (default 50)

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
metadata=$("$here/fetch_metadata.sh")

format="text"
limit=50
keywords=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) format="json"; shift ;;
    --limit) limit="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# //; s/^#//'
      exit 0 ;;
    *) keywords+=("$1"); shift ;;
  esac
done

if [[ ${#keywords[@]} -eq 0 ]]; then
  echo "Usage: $0 [--json] [--limit N] <keyword> [keyword...]" >&2
  exit 1
fi

# Lowercase pattern; jq does the matching case-insensitively.
# We match a keyword if it appears in name, tags, or categories.
# Multiple keywords are AND'd (every keyword must match somewhere).
jq_filter='
  [.icons[] | select(
    . as $i |
    ($needles | all(. as $n |
      ($i.name | ascii_downcase | contains($n))
      or ($i.tags // [] | map(ascii_downcase) | any(contains($n)))
      or ($i.categories // [] | map(ascii_downcase) | any(contains($n)))
    ))
  )]
  | unique_by(.name)
  | sort_by(-(.popularity // 0))
  | .[0:$lim]
'

needles_json=$(printf '%s\n' "${keywords[@]}" | jq -R 'ascii_downcase' | jq -s '.')

if [[ "$format" == "json" ]]; then
  jq --argjson needles "$needles_json" --argjson lim "$limit" "$jq_filter" "$metadata"
else
  jq -r --argjson needles "$needles_json" --argjson lim "$limit" "$jq_filter | .[] |
    \"\\(.name)\\t\\(.categories // [] | join(\",\"))\\tpop=\\(.popularity // 0)\"
  " "$metadata" | column -t -s $'\t'
fi
