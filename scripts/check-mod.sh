#!/usr/bin/env bash
# Validate the AutomationTools mod before an (expensive) game restart.
# EU4 fails SILENTLY on most of these, so catching them here saves restart cycles.
#   FAIL:  brace balance, .yml BOM, GUI<->custom_gui bindings (both ways),
#          referenced loc keys that don't exist, referenced event ids / scripted
#          effects that aren't defined, and `.GetValue` inside a log (crashes).
#   WARN:  unused loc keys, and `= PREV` comparisons (don't resolve in EU4).
# Usage: bash scripts/check-mod.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="$ROOT/AutomationTools"
fail=0
warn=0

section() { echo; echo "== $* =="; }

section "Brace balance"
while IFS= read -r f; do
  o=$(grep -o "{" "$f" | wc -l | tr -d ' '); c=$(grep -o "}" "$f" | wc -l | tr -d ' ')
  if [ "$o" = "$c" ]; then printf "  OK    %-48s (%s)\n" "${f#"$MOD"/}" "$o"
  else printf "  FAIL  %-48s (%s open / %s close)\n" "${f#"$MOD"/}" "$o" "$c"; fail=1; fi
done < <(find "$MOD" -type f \( -name "*.gui" -o -name "*.txt" \) | sort)

section "Localisation BOM"
while IFS= read -r f; do
  if [ "$(head -c3 "$f" | xxd -p)" = "efbbbf" ]; then printf "  OK    %s\n" "${f#"$MOD"/}"
  else printf "  FAIL  %s  (missing UTF-8 BOM -> file won't load)\n" "${f#"$MOD"/}"; fail=1; fi
done < <(find "$MOD" -type f -name "*.yml" | sort)

section "GUI scripted=yes  <->  custom_gui bindings"
gui=$(grep -rB1 "scripted = yes" "$MOD/interface" 2>/dev/null | grep -oE "atools_[a-z_]+" | sort -u)
cg=$(grep -roE "name = atools_[a-z_]+" "$MOD/common/custom_gui" 2>/dev/null | grep -oE "atools_[a-z_]+" | sort -u)
only_gui=$(comm -23 <(echo "$gui") <(echo "$cg"))
only_cg=$(comm -13 <(echo "$gui") <(echo "$cg"))
if [ -z "$only_gui" ] && [ -z "$only_cg" ]; then echo "  OK    every scripted element has a binding and vice-versa"
else
  [ -n "$only_gui" ] && { echo "  FAIL  scripted in .gui but no custom_gui binding:"; echo "$only_gui" | sed 's/^/          /'; fail=1; }
  [ -n "$only_cg" ]  && { echo "  FAIL  custom_gui entry with no scripted=yes element:"; echo "$only_cg" | sed 's/^/          /'; fail=1; }
fi

section "Localisation keys referenced but not defined"
defs=$(grep -hoE '^[[:space:]]+[A-Za-z0-9_.]+:[0-9]' "$MOD"/localisation/*.yml 2>/dev/null | grep -oE '[A-Za-z0-9_.]+' | grep -vE '^[0-9]+$' | sort -u)
refs=$( { grep -rhoE 'tooltip = (ATOOLS|AUTOMATION)[A-Z0-9_]+' "$MOD/common/custom_gui" 2>/dev/null
         grep -rhoE '(text|buttonText) = "(ATOOLS|AUTOMATION)[A-Z0-9_]+"' "$MOD/interface" 2>/dev/null ; } \
       | grep -oE '(ATOOLS|AUTOMATION)[A-Z0-9_]+' | sort -u)
missing=$(comm -23 <(echo "$refs") <(echo "$defs"))
if [ -z "$missing" ]; then echo "  OK    all referenced ATOOLS/AUTOMATION loc keys exist"
else echo "  FAIL  referenced but undefined loc keys:"; echo "$missing" | sed 's/^/          /'; fail=1; fi
unused=$(comm -13 <(echo "$refs") <(echo "$(echo "$defs" | grep -E '^(ATOOLS|AUTOMATION)')"))
if [ -n "$unused" ]; then echo "  warn  defined but unreferenced loc keys:"; echo "$unused" | sed 's/^/          /'; warn=1; fi

section "Event ids referenced but not defined"
edefs=$(grep -rhoE 'id = atools\.[0-9]+' "$MOD/events" 2>/dev/null | grep -oE 'atools\.[0-9]+' | sort -u)
erefs=$(grep -rhoE '(province_event|country_event) = \{ id = atools\.[0-9]+' "$MOD" 2>/dev/null | grep -oE 'atools\.[0-9]+' | sort -u)
emiss=$(comm -23 <(echo "$erefs") <(echo "$edefs"))
if [ -z "$emiss" ]; then echo "  OK    all referenced atools.* events are defined"
else echo "  FAIL  referenced but undefined events:"; echo "$emiss" | sed 's/^/          /'; fail=1; fi
grep -q "^namespace = atools" "$MOD/events"/*.txt 2>/dev/null || { echo "  FAIL  events file missing 'namespace = atools'"; fail=1; }

section "Scripted effects called but not defined"
sdefs=$(grep -rhoE 'atools_[a-z_]+_effect = \{' "$MOD/common/scripted_effects" 2>/dev/null | grep -oE 'atools_[a-z_]+_effect' | sort -u)
srefs=$(grep -rhoE 'atools_[a-z_]+_effect = yes' "$MOD" 2>/dev/null | grep -oE 'atools_[a-z_]+_effect' | sort -u)
smiss=$(comm -23 <(echo "$srefs") <(echo "$sdefs"))
if [ -z "$smiss" ]; then echo "  OK    all called atools_*_effect are defined"
else echo "  FAIL  called but undefined scripted effects:"; echo "$smiss" | sed 's/^/          /'; fail=1; fi

section "Known-crash / known-broken patterns"
if grep -rnE 'log = "[^"]*\.GetValue' "$MOD" >/dev/null 2>&1; then
  echo "  FAIL  '.GetValue' inside a log string (stack-overflow crash):"
  grep -rnE 'log = "[^"]*\.GetValue' "$MOD" | sed 's/^/          /'; fail=1
else echo "  OK    no variable .GetValue in any log string"; fi
# (ignore comment lines: content after file:line: starting with #)
prevhits=$(grep -rnE '= PREV\b' "$MOD"/common "$MOD"/events 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*#')
if [ -n "$prevhits" ]; then
  echo "  warn  '= PREV' comparison found (often doesn't resolve; prefer event_target):"
  echo "$prevhits" | sed 's/^/          /'; warn=1
else echo "  OK    no '= PREV' comparisons in code"; fi

echo
if [ "$fail" = 0 ]; then
  [ "$warn" = 0 ] && echo "ALL CHECKS PASSED" || echo "PASSED (with warnings)"
else echo "CHECKS FAILED"; fi
exit "$fail"
