#!/usr/bin/env bash
#
# Builds the .plasmoid archive that the KDE Store accepts, and that
# `kpackagetool6 --install` can read directly.
#
# A .plasmoid is a plain zip whose ROOT contains metadata.json and contents/.
# Nesting those inside a folder is the usual reason an upload is rejected.
#
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$SRC/dist}"

command -v zip >/dev/null || { echo "Error: zip is not installed." >&2; exit 1; }

VERSION="$(python3 -c "
import json
print(json.load(open('$SRC/package/metadata.json'))['KPlugin']['Version'])")"
ID="$(python3 -c "
import json
print(json.load(open('$SRC/package/metadata.json'))['KPlugin']['Id'])")"

# Keep Icons.js in step with the SVG files it is generated from.
python3 "$SRC/tools/gen_icons.py" --check >/dev/null || {
    echo "Error: Icons.js is stale. Run: python3 tools/gen_icons.py" >&2
    exit 1
}

mkdir -p "$OUT_DIR"
ARCHIVE="$OUT_DIR/${ID}-${VERSION}.plasmoid"
rm -f "$ARCHIVE"

( cd "$SRC/package" && zip -q -r -X "$ARCHIVE" metadata.json contents \
    -x '*.pyc' -x '__pycache__/*' -x '.*' )

echo "built $ARCHIVE"
python3 - "$ARCHIVE" <<'PY'
import sys, zipfile
names = zipfile.ZipFile(sys.argv[1]).namelist()
assert "metadata.json" in names, "metadata.json must be at the archive root"
assert any(n.startswith("contents/") for n in names), "contents/ missing"
print(f"  {len(names)} entries, metadata.json at root — layout is correct")
PY
