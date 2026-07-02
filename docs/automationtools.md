# AutomationTools mod — architecture & state

A custom, toggleable **automation tools** panel for EU4, usable in **observer mode**.
The province view is only a convenient launch point; the panel is conceptually a
standalone global UI.

## How to use in-game
Enable the mod (dev playset) → start a game → observer mode → click any land province →
an **"Automation"** button sits above the Buildings panel → click it to open the
centered, translucent tools panel.

## File map
```
AutomationTools/
  descriptor.mod                          mod descriptor
  interface/provinceview.gui              vanilla copy + injected panel & launcher button
  common/custom_gui/automation_tools.txt  behaviour of every scripted GUI element
  common/on_actions/atools_on_actions.txt on_startup: starts the global timer (once)
  common/scripted_effects/atools_scripted_effects.txt  the cede logic
  events/atools_events.txt                atools.1 self-refiring monthly timer
  localisation/atools_l_english.yml       all text (UTF-8 + BOM!)
```
The launcher descriptor `mod/AutomationTools.mod` (in the OneDrive game-data `mod/`
folder) points `path=` here.

## Architecture

**Panel + launcher** (`provinceview.gui` + `automation_tools.txt`)
- Launcher button `atools_master_toggle` lives in `buildings_window`, toggles global
  flag `atools_panel_open`.
- `atools_panel` (`custom_window`) is `potential = { has_global_flag = atools_panel_open }`,
  nested in `province_window`. Centered on screen via `Orientation = "CENTER"` +
  calibrated `position` (parent-relative; province view is docked lower-left).
  Background = child `gfx_transp_black_50` (translucent). Close button `atools_close`.

**Hub** = province 1 (Stockholm, always exists). Holds global vars, addressed as
`1 = {}` in script and `[1.var.GetValue]` in loc:
- `atools_months` — timer tick counter
- `atools_cede_interval` — 1 / 6 / 12 / 24 (default 12), set by the cycle button
- `atools_cede_count` — cessions so far (shown in the status text)

**Global flags**: `atools_panel_open`, `atools_cede_enabled`, `atools_timer_started`,
`atools_dbg_logged`.

**Timer** (`atools_events.txt` + `on_startup`): `atools.1` is a hidden province_event on
province 1 that re-fires every 30 days. Each tick: `atools_months += 1`; if
`atools_cede_enabled` and `atools_months >= atools_cede_interval`, reset and run
`atools_cede_effect`. Started once from `on_startup` (flag-guarded so save reloads
don't spawn duplicate chains; pending events persist in the save).

## Tool: "Auto-cede from #1 nation" (anti-snowball)
Every `atools_cede_interval` months, the largest independent nation (by
`total_development`) cedes one border province to a bordering neighbour, to stop any
single nation snowballing.

`atools_cede_effect` steps:
1. Clear last picks (`clear_global_event_target`) so a failed search can't reuse stale data.
2. Find #1: `every_country` + `save_event_target_as` candidate + "no other country's dev ≥ mine".
3. Find recipient: weakest independent neighbour (`is_neighbor_of = event_target:atools_top_nation`).
4. Cede a border province (`owned_by = event_target:atools_receiver` neighbour) and swap cores.

### Tie behaviour
- **#1 tie** (two nations exactly max dev): strict-max search matches neither → cession
  skipped that interval (self-resolves next tick).
- **weakest tie**: multiple qualify → an arbitrary one of the tied-weakest is taken.

### Current state / open issue
- Timer, toggle, interval selector, #1-nation pick, and the actual cession all **work**
  (verified: Ming picked as #1, a province ceded).
- **Open**: recipient came out as Dai Viet for Ming when a weaker neighbour was expected.
  Under investigation — either `is_neighbor_of` excludes the tiny bordering nations
  (too-narrow set) or the weakest-comparison is off. A diagnostic block logs every
  independent neighbour of the top nation once (`ATOOLS DBG neighbour: …`) to game.log.
- The effect currently carries temporary `ATOOLS:` trace logging + the diagnostic
  block. **Strip these once the recipient logic is confirmed** (search `ATOOLS` and the
  `atools_dbg_logged` block).

## Adding a new tool (pattern)
1. **UI**: add a `scripted = yes` element inside `atools_panel` in `provinceview.gui`,
   plus its behaviour in `automation_tools.txt` (a `custom_button` toggling a global
   flag, with a `frame` clause for on/off).
2. **Logic**: for per-country continuous effects, add an `if` in a country pulse
   (`on_monthly_pulse` etc.); for global/periodic effects, hook into the `atools.1`
   timer or add a similar scripted effect.
3. **Text**: add loc keys (keep the file BOM'd).
4. Validate with `scripts/check-mod.sh`, then restart to test.
