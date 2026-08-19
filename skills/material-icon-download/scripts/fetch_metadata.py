#!/usr/bin/env python3
"""Download (and cache) the Material Symbols metadata file.

Prints the path to the cached metadata JSON on stdout.

Why cached: the file is ~6 MB. We don't want to redownload every search.
Cache lives in $TMPDIR (or /tmp). Re-fetched if older than 24h.
"""

import os
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

METADATA_URL = "https://fonts.google.com/metadata/icons?key=material_symbols&incomplete=true"
MAX_AGE_SECONDS = 86400  # 24 hours


def fetch_metadata() -> str:
    cache_dir = Path(os.environ.get("TMPDIR", "/tmp")) / "material-symbols-skill"
    cache_dir.mkdir(parents=True, exist_ok=True)
    metadata = cache_dir / "metadata.json"

    needs_fetch = (
        not metadata.exists()
        or metadata.stat().st_size == 0
        or (time.time() - metadata.stat().st_mtime) > MAX_AGE_SECONDS
    )

    if needs_fetch:
        req = urllib.request.Request(METADATA_URL)
        with urllib.request.urlopen(req) as resp:
            data = resp.read()
        # The response is prefixed with )]}' to defeat JSON hijacking. Strip it.
        text = data.decode("utf-8")
        if text.startswith(")]}'"):
            text = text.split("\n", 1)[1] if "\n" in text else text[4:]
        metadata.write_text(text, encoding="utf-8")

    return str(metadata)


if __name__ == "__main__":
    print(fetch_metadata())
