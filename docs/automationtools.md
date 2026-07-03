# AutomationTools mod — architecture & state

A toggleable **automation tools** panel for EU4, usable in **observer mode**. The
province view is just a launch point; the panel is conceptually a standalone global UI.

## How to use in-game
Enable the mod (dev playset) → start a game → observer mode → click any land province →
click **"Automation"** (above the Buildings panel) → the centered tools panel opens.

## Layered design (UI vs backend)

The mod is split into two layers that talk ONLY through a small contract, so either
side can be rewritten without breaking the other.

```
UI LAYER (presentation + input)                 BACKEND LAYER (logic)
  interface/provinceview.gui   ── layout          common/on_actions/*  ── startup + state init
  common/custom_gui/*          ── bindings         events/*             ── timer / dispatcher
  localisation/*               ── text             common/scripted_effects/* ── tool logic
        │                                                   ▲
        └───────────── UI <-> BACKEND CONTRACT ─────────────┘
                 (global flags + province-1 hub variables)
```

- **UI layer** only reads/writes contract flags & hub vars. It contains no game
  logic and never calls backend effects. Redesign the panel = touch only the `.gui`,
  `custom_gui`, and `localisation` — the backend is untouched.
- **Backend layer** only reads/writes contract flags & hub vars. It never references
  GUI element names. Change the logic = touch only `scripted_effects`/`events`/`on_actions`.

## The contract (the ONLY coupling between layers)
Defined and documented in `common/on_actions/atools_on_actions.txt`:

| Name | Kind | Direction |
|---|---|---|
| `atools_panel_open` | global flag | UI-only (panel visibility) |
| `atools_cede_enabled` | global flag | UI writes → backend reads |
| `atools_cede_interval` | hub var (prov 1) | UI writes → backend reads (months, ≥1) |
| `atools_cede_count` | hub var (prov 1) | backend writes → UI reads (display) |

Backend-internal (NOT part of the contract; UI must not touch): `atools_months`,
`atools_timer_started`, `atools_have_top`, `atools_have_receiver`, and the event
targets `atools_top_nation` / `atools_receiver`.

## File map
```
AutomationTools/
  descriptor.mod
  interface/provinceview.gui              UI: vanilla copy + injected panel & launcher button
  common/custom_gui/automation_tools.txt  UI: element bindings (flags/vars only)
  localisation/atools_l_english.yml       UI: text (UTF-8 + BOM!)
  common/on_actions/atools_on_actions.txt BACKEND: startup + THE CONTRACT header
  events/atools_events.txt                BACKEND: atools.1 monthly timer / dispatcher
  common/scripted_effects/atools_scripted_effects.txt  BACKEND: tool logic (the cede effect)
```
`interface/provinceview.gui` is a verbatim 1.37.5 vanilla copy with our elements
injected (`.gui` don't merge). See only our edits: `bash scripts/gui-diff.sh provinceview.gui`.

## Runtime flow
`on_startup` (once, flag-guarded) inits hub vars + fires `atools.1` on province 1.
`atools.1` re-fires every ~30 days; each tick it increments `atools_months`, and if
`atools_cede_enabled` and `atools_months >= atools_cede_interval`, it resets and calls
`atools_cede_effect`.

## Tool: Auto-cede from #1 nation (anti-snowball) — WORKING
Every `atools_cede_interval` months the largest-development nation cedes one border
province to a weak neighbour. Selection is by development **bracket** (threshold ladder),
not exact rank — if several nations share the top/bottom bracket, one is chosen at random.
Thresholds are tunable at the top of `atools_scripted_effects.txt`.

Reliability lessons baked in (do not "simplify" away):
- Guarded with **global flags**, not `exists = event_target:X` (which returns false
  even when the target is saved).
- Biggest/weakest found via **numeric threshold ladders** + `any_country`/
  `random_country`, not mid-iteration `event_target`/`PREV` comparisons (don't resolve).
- **No `log` with scope commands** (`.GetName`/`.GetValue` in a log crashes).

## Adding a new tool (pattern that preserves the split)
1. **Contract**: pick a new flag `atools_<tool>_enabled` (and any vars); add them to the
   contract header in `on_actions` and init defaults there.
2. **UI**: add a `scripted = yes` element in `provinceview.gui`, a `custom_button` in
   `custom_gui` that only toggles the flag, and loc keys. No logic.
3. **Backend**: write `atools_<tool>_effect` in `scripted_effects`, and add an
   `if enabled … call it` block to the `atools.1` timer.
4. `bash scripts/check-mod.sh` → restart to test.
