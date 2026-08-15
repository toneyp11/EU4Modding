# EU4 Modding Workspace — Claude guide

Europa Universalis IV mod development. Read this fully before working; it encodes
hard-won, non-obvious lessons. Deep detail lives in [docs/](docs/).

## Environment & paths

- **Game**: EU4 **v1.37.5** "Inca", Steam. Design target is **no-DLC** (the mod must
  not *require* DLC), though the user's own install has several DLC enabled.
- **Game install** (vanilla files to reference, read-only):
  `C:/Program Files (x86)/Steam/steamapps/common/Europa Universalis IV`
- **Game data** — Documents is **OneDrive-redirected**:
  `C:/Users/isaac/OneDrive/Documents/Paradox Interactive/Europa Universalis IV`
  - `logs/` (game.log, error.log, setup_error.log), `crashes/`, `mod/`, `dlc_load.json`
- **Dev repo** (here): `C:/Development/EU4Modding`
- The launcher descriptor `mod/AutomationTools.mod` sets `path=` to
  `C:/Development/EU4Modding/AutomationTools`, so **we edit in-repo; no copying**.

## Build & test loop

There is no build step. **Every change requires a full game RESTART to test** —
hot-reload does NOT work reliably for this mod (`reloadinterface` does not pick up
modded `.gui`/custom_gui). So:

1. Edit files in `AutomationTools/`.
2. Restart EU4, load the **dev playset** (only this mod enabled), start a game and
   enter **observer mode** (spectate, no country).
3. Fast loop: **save right after entering observer**, reload that save after each
   restart to skip the setup screens.
4. Inspect results in-game and in the logs (`scripts/read-logs.sh`).

Because each iteration is expensive, **batch edits** and **validate before restart**
(`scripts/check-mod.sh`), and prefer adding `log = "ATOOLS: ..."` traces to learn
several things per run.

## Golden rules (EU4 no-DLC modding)

1. **Scripted UI is "custom GUI"** (`common/custom_gui/`), *not* HOI4 `scripted_gui`.
   A GUI element must have `scripted = yes` and be nested (any depth) inside a
   **whitelisted** window (`province_window`, `buildings_window`, `country*view`, …).
   See [docs/eu4-modding-reference.md](docs/eu4-modding-reference.md).
2. **`common/` files and `on_actions` MERGE** across mods/vanilla; **`interface/*.gui`
   files REPLACE wholesale.** That's why we copy vanilla `provinceview.gui` verbatim
   and inject into it.
3. **Localisation `.yml` must be UTF-8 *with BOM*** or it silently fails to load.
4. **Test = restart.** No reliable hot-reload.
5. **`Orientation` is parent-relative**, and the province view is engine-docked to
   the lower-left, so screen-centering a panel needs a calibrated offset, not `CENTER`.
6. **Ignore vanilla log noise**: `Synthetics`, `AST`, "no default sub-unit",
   "no primary culture", `economic_ideas` wrong-scope. None of these are our bugs.

## Compatibility (hard design constraint)

**This mod MUST stay compatible with other mods — the user runs it alongside others
(map mods especially). Weigh every change against this.**

- **Prefer engine primitives over hard-coded map data.** Backend logic (`every_country`,
  `is_overseas`, `total_development`, `release`, `change_religion = owner`, …) is
  map-agnostic — keep it so. Avoid baking in province IDs / area / region names; if a
  feature must enumerate them, generate it (and regenerate against the other mod's data).
- **`common/**` MERGES** across mods (additive, safe). **`interface/*.gui` REPLACES**
  wholesale — our `provinceview.gui` copy conflicts with any other mod that edits it
  (load order wins). Inherent to EU4; keep our GUI footprint minimal and note it.
- **Keep all names prefixed** (`atools_`/`ATOOLS_`) so nothing collides with other mods'
  tags/flags/vars/loc keys.
- **Known fragility (see backlog to harden):** province 1 is hard-coded as the state
  "hub" (all global vars + the atools.1 timer) — robust for map-expansion mods (province
  ID 1 exists in every map) but would break under a total conversion.
- **No console shortcut for the panel.** Mods cannot add console commands (the list is
  hardcoded), and scripted GUI only renders inside its host window - so there is no way to
  pop the panel open from the console. The panel is reached from the province view.
  (Global flags like `atools_cede_enabled` *can* be flipped with `set_flag`/`clr_flag` if
  ever needed for debugging - that works for free, no code.)
- **`check-mod.sh` enforces this** (Compatibility section: no non-hub hard-coded province
  ids, all loc keys prefixed, `provinceview.gui` purely additive). Full guide +
  load-order guidance: [docs/compatibility.md](docs/compatibility.md).

## Idioms that bit us (use these, not the "obvious" version)

- **Find the EXACT biggest/smallest country** — running max/min (the vanilla
  `flavorBYZ` idiom, VERIFIED working here): iterate `every_country` /
  `every_neighbor_country`; a candidate whose dev beats the current best overwrites the
  saved target; the first candidate seeds it (guarded by a flag, since `exists` lies).
  Max: `limit = { OR = { NOT = { has_global_flag = have } total_development =
  event_target:best } }`. Min: flip to `NOT = { total_development = event_target:best }`
  (strictly-smaller replaces). Mutating and comparing the SAME target mid-iteration is
  fine. **Do NOT use `PREV`** (`total_development = PREV` does not resolve) — but
  `total_development = event_target:X` / `= ROOT` **do** resolve. This supersedes the
  old threshold-ladder workaround (that was a detour around the `exists` bug, not this).
- **"Does A border B"**: `is_neighbor_of = event_target:B` (land or strait). Do NOT
  hand-roll `any_owned_province = { any_neighbor_province = { owner = { tag = … } } }`
  — it silently returns false.
- **Province owner test**: `owned_by = event_target:X`.
- **Global once-per-period timer**: use the engine's **`on_monthly_pulse`** (it fires per
  COUNTRY, so gate it with `owns = <hub province>` to get exactly one run per month), and
  keep counters on the hub. **NEVER build a timer from an event that re-schedules ITSELF**
  — an event fired from inside another event stores its firing context, so every tick
  nests inside the previous one, the chain is serialised into the save, and the game dies
  of `EXCEPTION_STACK_OVERFLOW` once it is deep enough (measured here: 1,840 levels ≈ 3,700
  frames ≈ every 146 game years). `check-mod.sh` now fails on any self-refiring event.
- **Guard on saved event targets with GLOBAL FLAGS, not `exists`**: `exists =
  event_target:X` returns *false here even when the target IS saved* (verified: you
  can scope into it, but `exists` says no). Set a flag when you save, check the flag.
- **NEVER put ANY scope command (`[X.GetValue]`, `[X.GetName]`, any `[X.Get…]`) inside a
  `log` string** → `EXCEPTION_STACK_OVERFLOW`. Both `.GetValue` AND `.GetName` have
  crashed this mod. Log plain ASCII markers only; show values/names in loc/UI instead.
  (`check-mod.sh` now flags `.Get…` in any log.)

## Debugging playbook

- **Trace with logs**: `log = "ATOOLS: step X, [This.GetName]"` → `game.log`.
- **"Search found nobody" signal**: `clear_global_event_target = T` before a
  `random_/every_… { save_global_event_target_as = T }`; then
  `Trying to remove undefined event target: T` in `error.log` counts how often that
  search failed. Per-target counts pinpoint which step is broken.
- `scripts/read-logs.sh` — ATOOLS trace + real errors + latest crash summary.
- Crash dumps: `crashes/eu4_*/meta.yml` (loaded mods), `exception.txt` (crash type:
  `ACCESS_VIOLATION` = usually a render-time GUI bug; `STACK_OVERFLOW` = string/loc
  recursion, e.g. `.GetValue` in a log).

## Dev helpers (use these constantly)

- `bash scripts/check-mod.sh` — **run before every restart.** Lints for the silent
  failures: brace balance, `.yml` BOM, GUI↔custom_gui bindings, referenced-but-undefined
  loc keys / events / scripted effects, `.GetValue`-in-log (crash), and that the
  launcher descriptor still points at this repo. Exit 0 = safe. **A git pre-commit hook
  runs this automatically and blocks a broken commit** (bypass: `git commit --no-verify`).
  On a fresh clone, enable it once: `git config core.hooksPath scripts/git-hooks`.
- `bash scripts/read-logs.sh [N]` — after a test run: ATOOLS traces, real errors (noise
  filtered), undefined-event-target counts, latest crash summary.
- `bash scripts/vanilla.sh <regex> [subdir] [max]` — search the vanilla install for a
  working idiom / to confirm a token exists (faster than manual greps).
- `bash scripts/gui-diff.sh [file.gui]` — show ONLY our injections into an overridden
  `.gui` (vs the vanilla copy). Use for reviewing GUI edits and for patch migration.
- **CWTools** (VS Code) gives live in-editor EU4 validation — a bigger net than
  `check-mod.sh`. Setup is fiddly (it defaults to the wrong game for our path); see
  [docs/cwtools-setup.md](docs/cwtools-setup.md). Config: `AutomationTools/.vscode/settings.json`.
- **VS Code tasks** (`AutomationTools/.vscode/tasks.json`) wire the loop into the editor:
  `Ctrl+Shift+B` = Validate mod; `Tasks: Run Task` → Read logs / GUI diff / Launch game
  (Steam) / Validate + Launch. NOTE: launching still goes through the Paradox launcher
  (Steam DRM) → click Play → observer; the game restart itself can't be automated away.

## Conventions

- Everything is prefixed `atools_` / `ATOOLS_` (script names, flags, vars) or
  `AUTOMATION_` (older loc keys) so it's greppable and collision-free.
- **Hub = province 1** (Stockholm, always exists): global vars live here
  (`1 = { set_variable … }`; display `[1.var.GetValue]`).
- Global flags: `atools_panel_open`, `atools_cede_enabled`, `atools_timer_started`,
  `atools_dbg_logged`. Global timer event = `atools.1`.
- New tools follow the pattern in [docs/automationtools.md](docs/automationtools.md):
  UI toggle → global flag → logic in a pulse or the `atools.1` timer.

## Repo layout

- `AutomationTools/` — the mod. Architecture & state: [docs/automationtools.md](docs/automationtools.md).
- `docs/eu4-modding-reference.md` — EU4 lessons, idioms, crash cases + fixes.
- `docs/automationtools.md` — mod architecture, state, and how to add a tool.
- `scripts/` — `check-mod.sh`, `read-logs.sh`, `vanilla.sh`, `gui-diff.sh`.
- `.claude/settings.json` — permission allowlist (read-only cmds + in-repo edits).

## Maintenance

**When you learn something non-obvious, record it** — add to
`docs/eu4-modding-reference.md` (general EU4) or `docs/automationtools.md` (this mod),
and update this file's rules/idioms if it's a top-level trap. That is the point of
this setup.

## Current state

Custom **Automation Tools** panel opens from the province view in observer mode
(centered, translucent). First real tool — **"Auto-shrink: largest nation"**
(anti-snowball) — **works**: every configured interval (months) the **exact** most-developed
nation is shrunk by first **releasing every possible nation as independent**
(`release_all_possible_countries` + `release_all_subjects`); if nothing is releasable
(detected via a `total_development` before/after snapshot), it instead **cedes a border
province to its exact weakest neighbour**. Both the #1 and the weakest neighbour are found
by an exact running max/min over `every_country`/`every_neighbor_country` (no dev
brackets); subjects are eligible on both sides. Code is split into a **UI layer** and a
**backend layer** that talk only through a documented flag/variable contract, so the panel
can be redesigned without touching the logic — see [docs/automationtools.md](docs/automationtools.md).
All debug logging has been stripped (production-clean).

**Architecture rule:** UI (`interface/`, `custom_gui/`, `localisation/`) and backend
(`on_actions/`, `events/`, `scripted_effects/`) communicate ONLY via the contract
(global flags + province-1 hub vars) documented at the top of
`common/on_actions/atools_on_actions.txt`. Neither layer references the other's internals.
