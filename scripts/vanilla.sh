#!/usr/bin/env bash
# Search the vanilla EU4 install (read-only reference) for how the base game does
# something - the fastest way to find a working idiom or confirm a token exists.
# Usage: bash scripts/vanilla.sh <pattern> [subdir] [max]
#   <pattern>  extended-regex to search for
#   [subdir]   limit to a subfolder, e.g. events, common/scripted_effects, interface
#   [max]      max result lines (default 60)
# Examples:
#   bash scripts/vanilla.sh 'cede_province'            events
#   bash scripts/vanilla.sh 'is_neighbor_of = '        common
#   bash scripts/vanilla.sh 'name = "GFX_button'       interface
set -u
EU4="C:/Program Files (x86)/Steam/steamapps/common/Europa Universalis IV"
[ -d "$EU4" ] || { echo "FATAL: EU4 install not found: $EU4"; exit 2; }
pat="${1:?usage: vanilla.sh <pattern> [subdir] [max]}"
sub="${2:-}"
max="${3:-60}"
grep -rnE --include="*.txt" --include="*.gui" --include="*.gfx" --include="*.yml" \
     -- "$pat" "$EU4/$sub" 2>/dev/null | head -n "$max"
