#!/usr/bin/env bash
# Validate the AutomationTools mod before an (expensive) game restart:
#   - brace balance of every .gui / .txt
#   - UTF-8 BOM on every localisation .yml (required or it silently won't load)
#   - every `scripted = yes` GUI element has a matching custom_gui binding
# Usage: bash scripts/check-mod.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="$ROOT/AutomationTools"
fail=0

echo "== Brace balance =="
while IFS= read -r f; do
  o=$(grep -o "{" "$f" | wc -l | tr -d ' ')
  c=$(grep -o "}" "$f" | wc -l | tr -d ' ')
  if [ "$o" = "$c" ]; then printf "  OK    %-48s (%s)\n" "${f#"$MOD"/}" "$o"
  else printf "  BAD   %-48s (%s open / %s close)\n" "${f#"$MOD"/}" "$o" "$c"; fail=1; fi
done < <(find "$MOD" -type f \( -name "*.gui" -o -name "*.txt" \) | sort)

echo "== Localisation BOM =="
while IFS= read -r f; do
  if [ "$(head -c3 "$f" | xxd -p)" = "efbbbf" ]; then printf "  OK    %s\n" "${f#"$MOD"/}"
  else printf "  NOBOM %s\n" "${f#"$MOD"/}"; fail=1; fi
done < <(find "$MOD" -type f -name "*.yml" | sort)

echo "== GUI scripted=yes vs custom_gui bindings =="
gui=$(grep -rB1 "scripted = yes" "$MOD/interface" 2>/dev/null | grep -oE "atools_[a-z_]+" | sort -u)
cg=$(grep -roE "name = atools_[a-z_]+" "$MOD/common/custom_gui" 2>/dev/null | grep -oE "atools_[a-z_]+" | sort -u)
if [ "$gui" = "$cg" ]; then echo "  OK    all scripted GUI elements have a binding"
else echo "  MISMATCH (left = in .gui only, right = in custom_gui only):"; diff <(echo "$gui") <(echo "$cg") | sed 's/^/    /'; fail=1; fi

echo
if [ "$fail" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit "$fail"
