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
# Where the launcher reads the mod from, and the external CWTools config.
DEPLOYED_MOD="C:/Users/isaac/OneDrive/Documents/Paradox Interactive/Europa Universalis IV/mod/AutomationTools.mod"
CWTOOLS_CONFIG="C:/Development/cwtools-eu4-config"
fail=0
warn=0

# Fail loud if the mod dir itself is missing (don't silently "pass" on nothing).
[ -d "$MOD" ] || { echo "FATAL: mod dir not found: $MOD"; exit 2; }

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

section "Localisation Latin1-safe (non-Latin1 chars break EU4 loc rendering)"
# EU4's loc parser is Latin1: a char like U+2192 (->) errors with "Couldn't find
# Latin1 character" and can blow up the render path. Use ASCII/Latin1 only (the color
# code section-sign is fine). Strip the 3-byte BOM, then test each line via iconv.
while IFS= read -r f; do
  bad=0; ln=0
  while IFS= read -r line; do
    ln=$((ln+1))
    printf '%s' "$line" | iconv -f UTF-8 -t ISO-8859-1 >/dev/null 2>&1 || {
      echo "  FAIL  ${f#"$MOD"/}:$ln  non-Latin1 character (EU4 can't render it)"; fail=1; bad=1; }
  done < <(tail -c +4 "$f")
  [ "$bad" = 0 ] && printf "  OK    %s\n" "${f#"$MOD"/}"
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
if grep -rnE 'log = "[^"]*\.Get[A-Za-z]+' "$MOD" >/dev/null 2>&1; then
  echo "  FAIL  scope command (.GetValue/.GetName/...) inside a log string (stack-overflow crash):"
  grep -rnE 'log = "[^"]*\.Get[A-Za-z]+' "$MOD" | sed 's/^/          /'; fail=1
else echo "  OK    no scope .Get commands in any log string"; fi
# (ignore comment lines: content after file:line: starting with #)
prevhits=$(grep -rnE '= PREV\b' "$MOD"/common "$MOD"/events 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*#')
if [ -n "$prevhits" ]; then
  echo "  warn  '= PREV' comparison found (often doesn't resolve; prefer event_target):"
  echo "$prevhits" | sed 's/^/          /'; warn=1
else echo "  OK    no '= PREV' comparisons in code"; fi

section "Self-refiring event chains (save-corrupting stack overflow)"
# An event that re-schedules ITSELF stores its firing context each time, so every tick
# nests inside the previous one. The chain is serialised into the save and grows one
# level per firing; at ~2 stack frames per level the game dies with a
# EXCEPTION_STACK_OVERFLOW (measured: 1,840 levels -> ~3,700 frames -> crash).
# Use on_monthly_pulse / on_yearly_pulse instead - the engine starts a fresh scope.
selfref=""
while IFS= read -r f; do
  # For every event id defined in this file, does the same file schedule that same id?
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    if grep -qE "(province_event|country_event) = \{ *id = ${id//./\\.}\b" "$f" 2>/dev/null; then
      selfref="$selfref\n          ${f#"$MOD"/}: event $id re-schedules itself"
    fi
  done < <(grep -hoE "^[[:space:]]*id = atools\.[0-9]+" "$f" 2>/dev/null | grep -oE "atools\.[0-9]+")
done < <(find "$MOD/events" -type f -name "*.txt" 2>/dev/null | sort)
if [ -z "$selfref" ]; then echo "  OK    no event re-schedules itself"
else echo "  FAIL  self-refiring event chain (nests in the save until it overflows the stack):"; printf "%b\n" "$selfref"; fail=1; fi

section "Compatibility (must stay usable alongside other mods)"
# (a) Hard-coded province scopes: only province 1 (the documented hub) is sanctioned.
#     Any other `<n> = {` is map-specific and breaks on mods that renumber provinces.
badids=$(grep -rnoE '\b[0-9]+ = \{' "$MOD/common" "$MOD/events" 2>/dev/null | grep -vE ':1 = \{$')
if [ -z "$badids" ]; then echo "  OK    no hard-coded province ids except the hub (province 1)"
else echo "  warn  hard-coded province id other than the hub (map-mod risk; or a random_list weight):"; echo "$badids" | sed 's/^/          /'; warn=1; fi
# (b) Every loc key must be prefixed (atools_/ATOOLS_/AUTOMATION_) so we never clobber
#     another mod's or vanilla's localisation.
badloc=$(grep -hoE '^[[:space:]]+[A-Za-z0-9_.]+:[0-9]' "$MOD"/localisation/*.yml 2>/dev/null \
         | grep -oE '[A-Za-z0-9_.]+' | grep -vE '^[0-9]+$' \
         | grep -vE '^(atools|ATOOLS|AUTOMATION)' | sort -u)
if [ -z "$badloc" ]; then echo "  OK    every loc key is prefixed (no vanilla/other-mod key overridden)"
else echo "  FAIL  un-prefixed loc key(s) - would override vanilla/other mods:"; echo "$badloc" | sed 's/^/          /'; fail=1; fi
# (c) Our provinceview.gui override must be PURELY ADDITIVE vs vanilla (only append hunks).
#     If it changes/removes vanilla lines, we'd strip vanilla behaviour when we win load order.
VANILLA_GUI="C:/Program Files (x86)/Steam/steamapps/common/Europa Universalis IV/interface/provinceview.gui"
if [ -f "$VANILLA_GUI" ] && [ -f "$MOD/interface/provinceview.gui" ]; then
  nonadd=$(diff "$VANILLA_GUI" "$MOD/interface/provinceview.gui" 2>/dev/null | grep -E '^[0-9]+(,[0-9]+)?[cd][0-9]')
  if [ -z "$nonadd" ]; then echo "  OK    provinceview.gui override is purely additive (vanilla behaviour intact)"
  else echo "  warn  provinceview.gui CHANGES/REMOVES vanilla lines (or vanilla was updated) - review:"; echo "$nonadd" | sed 's/^/          /'; warn=1; fi
else echo "  warn  vanilla provinceview.gui not found - skipped additive check"; warn=1; fi

section "Deployment & external tooling"
# The game loads the mod via this descriptor; if it's missing or points elsewhere,
# you're editing files the game never reads (a silent, maddening failure).
# descriptor uses Windows form (C:/...); git-bash $MOD is MSYS (/c/...). Normalize.
WINMOD="$(cygpath -m "$MOD" 2>/dev/null || echo "$MOD")"
if [ -f "$DEPLOYED_MOD" ]; then
  if grep -qF "path=\"$WINMOD\"" "$DEPLOYED_MOD"; then echo "  OK    launcher descriptor points at this repo"
  else echo "  FAIL  launcher descriptor does NOT point at $WINMOD :"; grep -E '^path=' "$DEPLOYED_MOD" | sed 's/^/          /'; fail=1; fi
else echo "  FAIL  launcher descriptor missing: $DEPLOYED_MOD (game won't load the mod)"; fail=1; fi
# CWTools silently uses the wrong game's rules if this is gone (see docs/cwtools-setup.md).
if [ -d "$CWTOOLS_CONFIG" ]; then echo "  OK    CWTools EU4 config present"
else echo "  warn  CWTools config missing ($CWTOOLS_CONFIG) - in-editor validation degrades silently"; warn=1; fi

echo
if [ "$fail" = 0 ]; then
  [ "$warn" = 0 ] && echo "ALL CHECKS PASSED" || echo "PASSED (with warnings)"
else echo "CHECKS FAILED"; fi
exit "$fail"
