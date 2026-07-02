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

## Idioms that bit us (use these, not the "obvious" version)

- **Find the biggest/smallest country**: `every_country` → `save_event_target_as`
  each candidate → `if` no other country beats it, compared via
  `total_development = event_target:candidate`. **Do NOT use `PREV`** —
  `total_development = PREV` does not resolve and yields a broken scope.
- **"Does A border B"**: `is_neighbor_of = event_target:B` (land or strait). Do NOT
  hand-roll `any_owned_province = { any_neighbor_province = { owner = { tag = … } } }`
  — it silently returns false.
- **Province owner test**: `owned_by = event_target:X`.
- **Global once-per-period timer**: self-refiring hidden `province_event` on
  province 1 (`days = 30`), started once from `on_startup` behind a flag guard.
- **NEVER put a variable `.GetValue` inside a `log` string** → `EXCEPTION_STACK_OVERFLOW`.
  `.GetValue` is only valid in localisation/UI. Scope *name* commands
  (`[This.GetName]`, `[Root.GetName]`) ARE fine in logs.

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
(centered, translucent). First real tool — **"Auto-cede from #1 nation"** (anti-snowball):
each interval the highest-development nation cedes a border province to a neighbour.
Cessions fire correctly; **open issue**: the "weakest neighbour" recipient selection
needs verification (picked Dai Viet for Ming when a weaker neighbour was expected).
The cede effect currently carries temporary `ATOOLS:`/`ATOOLS DBG:` trace logging.
