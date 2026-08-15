# AutomationTools — mod compatibility

Compatibility with other mods is a **hard design constraint** (the user runs this
alongside others, map mods especially). This documents how compatible the mod is, the
two unavoidable touchpoints, and how it's enforced.

## TL;DR
- **Backend logic is map-agnostic.** Shrink + auto-convert use only engine primitives
  (`every_country`, `is_overseas`, `total_development`, `release`, `change_religion =
  owner`, …). No province IDs, area, or region names are baked in.
- **Two touchpoints** (below): the province-1 "hub", and the `provinceview.gui` override.
- **`scripts/check-mod.sh` enforces it** — see the "Compatibility" section it prints.

## What works out of the box
- **Map-expansion mods** (add/tweak provinces, keep vanilla areas + province 1, don't
  edit the province view) → fully compatible.
- Rule/gameplay mods that only touch `common/**`, `events/**`, `on_actions/**` → these
  MERGE with ours; no conflict as long as names differ (ours are all `atools_`-prefixed).

## The escape hatch: run with no UI at all
The panel is the only real conflict surface. Because every tool is driven by global flags
that the console can set, **deleting the mod's `interface/` folder removes all .gui
conflicts while keeping the mod fully usable** — see [console-control.md](console-control.md).
Measured on this machine, `provinceview.gui` is overridden by **9** installed mods, so for
a heavily modded playset this is the recommended way to run it.

## Touchpoint 1 — `interface/provinceview.gui` REPLACES (not merges)
EU4 `.gui` files don't merge: if two mods ship `provinceview.gui`, only the **last one
loaded** is used. Our copy is **vanilla 1.37.5 verbatim + purely additive injections**
(a launcher button and the tools panel — verified append-only by `check-mod.sh` and
`gui-diff.sh`). Consequences:
- **vs a map mod** (doesn't touch province view) → no conflict.
- **vs a UI / overhaul mod that edits the province view** → conflict, one wins:
  - Load **AutomationTools LAST** → our panel works; you keep full **vanilla** province
    view but lose the *other mod's* province-view changes.
  - Load **AutomationTools FIRST** → the other mod's province view wins; our panel button
    disappears (the backend tools still run, just no UI to toggle them).
- This is inherent to EU4 and cannot be fully avoided while anchoring the panel in the
  province view (the only observer-mode-friendly custom-GUI window).

## Touchpoint 2 — province 1 as the state "hub"
All global variables live on **province 1**, and the monthly tick is normally driven by
whichever country **owns** it. Province ID 1 exists in every EU4 map (maps number from 1),
so map-expansion mods are fine.

**Total conversions**: if province 1 is uncolonised, wasteland or sea, nobody owns it and
the tick gate would never pass - the whole mod would silently do nothing. Guarded: at
startup, if `NOT = { any_country = { owns = 1 } }`, a random landed country is flagged
`atools_ticker` and drives the tick instead. The expensive `any_country` scan sits behind
a cheap flag check, so it costs at most one scan per month.

Residual limit: if that ticker country is later annexed while the hub is still unowned,
the tick stops until the next save load (on_startup re-nominates). Only reachable on a
map where province 1 is permanently unowned.

## (old) Touchpoint 2 notes
All global variables and the `atools.1` timer live on **province 1**. Province ID 1
exists in every EU4 map (maps are numbered from 1), so this is robust for map-expansion
mods. It would only break under a **total-conversion** that removes/repurposes province 1.
Hardening (dynamic hub) is on the backlog; not needed for typical map mods.

## Needs adaptation
- **Total-conversion mods** (new map, renumbered provinces): province-1 hub may need the
  dynamic-hub change; otherwise fine.
- The shelved **exclave breakaway** feature (branch `wip-exclave-breakaway`) hard-codes
  ~889 vanilla area names for naming — regenerate `scripts/gen_pool.sh` against the other
  mod's `area.txt` before reviving it there.

## Enforcement (don't let it regress)
`bash scripts/check-mod.sh` fails/warns on:
- a hard-coded province scope other than the hub (map-mod risk),
- any loc key not prefixed `atools_/ATOOLS_/AUTOMATION_` (would clobber vanilla/other mods),
- `provinceview.gui` changing/removing vanilla lines (must stay purely additive).
