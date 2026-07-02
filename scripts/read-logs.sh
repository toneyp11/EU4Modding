#!/usr/bin/env bash
# Inspect EU4 game logs after a test run: our ATOOLS traces, real errors
# (vanilla noise filtered), and a summary of the latest crash.
# Usage: bash scripts/read-logs.sh [N]   (N = how many trace lines, default 40)
set -u
GAMEDATA="C:/Users/isaac/OneDrive/Documents/Paradox Interactive/Europa Universalis IV"
LOGS="$GAMEDATA/logs"
N="${1:-40}"
NOISE="economic_ideas|EmperorOfChina|Synthetics|no default sub-unit|no primary culture|no religion specified|FAILED TO CLEAR SPY"

echo "== ATOOLS trace (last $N lines of game.log) =="
grep "ATOOLS" "$LOGS/game.log" 2>/dev/null | tail -n "$N" || echo "  (none)"

echo
echo "== error.log (vanilla noise filtered, last 25) =="
grep -viE "$NOISE" "$LOGS/error.log" 2>/dev/null | grep -vE "^\s*$" | tail -n 25 || echo "  (none)"

echo
echo "== undefined-event-target counts (search-found-nothing signal) =="
grep -oE "undefined event target: [a-z_]+" "$LOGS/error.log" 2>/dev/null | sort | uniq -c || echo "  (none)"

echo
echo "== Latest crash =="
latest=$(ls -t "$GAMEDATA/crashes" 2>/dev/null | grep '^eu4_' | head -1)
if [ -n "${latest:-}" ]; then
  CR="$GAMEDATA/crashes/$latest"
  echo "  $latest"
  grep -i "Mods:" "$CR/meta.yml" 2>/dev/null | sed 's/^/  /'
  grep -i "Unhandled" "$CR/exception.txt" 2>/dev/null | sed 's/^/  /'
else
  echo "  (no crash dumps)"
fi
