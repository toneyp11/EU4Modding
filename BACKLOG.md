# AutomationTools — backlog

Running list of planned work and ideas, so we don't lose them. Newest context at top.

## Active — the ~1590 STACK_OVERFLOW crash hunt
- [ ] **Find the name-resolution cycle.** A 1444 game with the mod dies consistently at
  ~1590-1591; a fresh 1590 game ran fine to 1690. EVIDENCE SO FAR:
  - All six crash dumps overflowed at an **identical ~3702 stack frames** with
    `ntdll RtlCreateUnicodeString` on top → a **true infinite recursion in string/name
    building**, not deep data. (Constant depth = the stack simply ran out.)
  - This rules out every volume theory (mass releases, subject counts, chain depth).
  - LEADING HYPOTHESIS: a **cycle in the name-derivation links** (`overlord` /
    `colonial_parent`). EU4 derives a subject's display name from its parent, so a loop
    recurses forever. Our shrink is the only thing that mass-rewires those links, and the
    stuck #1 was **Florida, a colonial nation**.
  - CONTRADICTION still unexplained: "crashed with tools disabled" (implies the cycle is
    baked into the save) vs "vanilla ran that same save fine" (implies it isn't). One test
    was almost certainly confounded — autosaves rotate fast and got overwritten mid-session.
  - NEXT: capture a pre-crash save (`precrash.eu4`, ~1585, before rotation) and run
    `python scripts/check-save.py <save>`. It reports cycles in both graphs and, via the
    `atools_last_top` country flag, names the nation the shrink last acted on.
  - Decisive isolation if needed: fresh **1444** game, mod loaded, **tools never enabled**,
    run to 1600. Crash → the passive `atools.1` timer chain. Clean → the tools' churn.

## Compatibility (STANDING PRIORITY — user runs this with other mods)
- [x] **Audit done** — backend logic is fully map-agnostic; only province 1 (hub) is
  hard-coded, no area/region names, no un-prefixed loc keys, provinceview.gui is purely
  additive. See [docs/compatibility.md](docs/compatibility.md).
- [x] **Enforced** — check-mod.sh Compatibility section (non-hub province ids, un-prefixed
  loc keys, provinceview.gui additiveness). Load-order guidance documented.
- [ ] **Dynamic hub province** (only needed for total conversions) — stop hard-coding
  province 1; pick a guaranteed-existing province at startup. Low priority: province ID 1
  exists in every map, so map-expansion mods are already fine.

## Shelved (removed from main; preserved on branch `wip-exclave-breakaway`)
- [ ] **Exclave breakaway + 100-tag custom-nation pool** — DISABLED per user (2026-07).
  Full working feature lives on branch `wip-exclave-breakaway` (commit 5a47b46) + the
  generator `scripts/gen_pool.sh`. What it does: detects exclaves via `is_overseas = yes`
  (the correct connectivity test — supersedes the old region criterion, which wrongly
  chopped contiguous multi-region empires), cedes claimable exclaves to living
  core-holders, and breaks the rest away as new nations from a 100-tag pool (AT0-BV9),
  named after their area (`atools_name_by_area`). WHY SHELVED: not fully validated +
  compatibility concerns. WHEN RESUMING: (1) confirm `is_overseas` catches land exclaves
  in-game; (2) do compatibility hardening FIRST (above); (3) restore 12mo interval (branch
  has 1mo test value). `override_country_name` does NOT resolve scope commands (so exact
  per-province names impossible — area names are the max).

## Planned
- [ ] **Tune interval cadence** — defaults (shrink 12mo, convert 60mo) are first-pass
  values; adjust to taste once the crash is resolved and we've watched more games.
- [ ] **Polish the panel's visual design** — layout, styling, icons. Pure UI now
  (contract-isolated), so it won't touch backend logic. The panel is 3 tool-rows tall and
  the breakaway toggle was deferred from it, so this is overdue.
- [ ] **Strip the diagnostic traces** (`ATOOLS shrink A..K`) and the `atools_last_top`
  flag once the crash is understood — they exist only for this investigation.

## Ideas / maybe
- [ ] **Custom-named breakaway nations** — a mod-defined pool of tags with dynamic names
  + flags, for invented nations rather than historical ones. NOTE: naming is capped at
  AREA level (override_country_name prints a loc key's text verbatim; it does NOT evaluate
  scope commands, so per-province names are impossible).
- [ ] **Verify `create_client_state` DLC status** — dynamic-nation option (engine
  generates the name); useful if we want dynamic nations without a predefined tag pool.
- [ ] Additional automation tools as they come up (each = flag + backend effect + timer
  block + UI toggle, per the add-a-tool recipe in docs/automationtools.md).

## Done
- [x] **Defensive hardening pass** (commit 0b06de0) — fixed a stale marker-flag leak,
  permanent country-variable pollution (`export_to_variable` with no `clear_variable` in
  EU4), and unbounded core stacking; added guards so the tools can never hand the engine a
  degenerate state (#1 must own >=2 cities, never cede a capital, a colonial #1 shrinks by
  ceding only, receivers prefer non-colonial with a fallback pass, convert skips occupied
  provinces, on_startup self-heals a missing/zero interval).
- [x] **Save analyzer + #1 diagnostic** (commit ec023b6) — `scripts/check-save.py` detects
  cycles in the overlord/colonial_parent graphs; the shrink stamps `atools_last_top`.
- [x] **Stuck-shrink fix** — the weakest neighbour is now required to actually border one
  of the #1's cities, so the cede always finds a province (previously the #1 could pick a
  neighbour it shared no city border with and silently never shrink).
- [x] **Auto-convert religion & culture tool** — own interval (default 60mo, cycles
  12/24/60/120), 20% chance per mismatched province per run, `change_religion = owner` /
  `change_culture = owner`. Converts same-group cases (Catholic->Orthodox) the AI never does.
- [x] **Anti-snowball shrink tool** — each run the exact #1 nation releases every nation it
  can as independent states; if nothing is releasable it cedes a border province to its
  exact weakest neighbour. Subjects eligible on both sides.
- [x] **Exact #1 / exact weakest** — replaced the development-bracket ladders with exact
  running max/min over `every_country` / `every_neighbor_country` (vanilla flavorBYZ
  idiom). Verified `total_development = event_target:X` resolves reliably.
- [x] Claude-ready workspace: CLAUDE.md, docs, scripts (check-mod/read-logs/vanilla/
  gui-diff/check-save), CWTools, git + GitHub backup, pre-commit validation hook.
