#!/usr/bin/env bash
# We override whole vanilla .gui files and inject our elements. This isolates JUST
# our edits by diffing against the vanilla install copy - so you review ~30 lines
# instead of scrolling 6900. Also the tool to use if EU4 ever patches a .gui we override.
# Usage: bash scripts/gui-diff.sh [file.gui]   (omit to diff all overridden .gui)
set -u
EU4="C:/Program Files (x86)/Steam/steamapps/common/Europa Universalis IV"
[ -d "$EU4" ] || { echo "FATAL: EU4 install not found: $EU4"; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="$ROOT/AutomationTools"
one="${1:-}"
found=0
for f in "$MOD"/interface/*.gui; do
  [ -e "$f" ] || continue
  [ -n "$one" ] && [ "$(basename "$f")" != "$one" ] && continue
  found=1
  base="$EU4/interface/$(basename "$f")"
  echo "### $(basename "$f")  (< vanilla | > ours) ###"
  if [ -f "$base" ]; then diff "$base" "$f" || true; else echo "(no vanilla counterpart - fully custom file)"; fi
  echo
done
[ "$found" = 0 ] && echo "no matching .gui under $MOD/interface"
