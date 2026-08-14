# AutomationTools — backlog

Running list of planned work and ideas, so we don't lose them. Newest context at top.

## Planned next — "Auto-grow: weakest nation" (the reverse of the shrink)
- [ ] **Grow the world's least-developed nation each interval**, so with the shrink also
  on, development converges from both ends. Separate toggle + its own interval.
  ORDER OF PREFERENCE: (1) **claim an adjacent uncolonized province outright**, (2) else
  **take a border province from its strongest neighbour**.
  - PRIMITIVES (all verified in vanilla): `random_empty_neighbor_province` (11 uses) with
    the matching trigger `any_empty_neighbor_province` (9); `create_colony = 1000` — 1000
    is the colony->city threshold, so it settles the province INSTANTLY as a full owned
    province, no colony phase (exact vanilla idiom in PropagateReligionEvents.txt:1033).
    Also `is_wasteland` (44) to exclude wastelands, `had_province_flag = { flag days }` (9)
    for a transfer cooldown.
  - STRUCTURE: `atools_grow_effect` (exact running MINIMUM over `every_country`, same
    flag-seeded idiom as the shrink's maximum; stamps `atools_last_weakest` for diagnosis)
    -> claim branch, else `atools_grow_take_effect` (exact running MAXIMUM over
    `every_neighbor_country` for the donor). "Move a border province from A to B" is now
    used by both tools, so factor it into a shared `atools_transfer_province_effect`.
  - GUARDS (every lesson so far): donor eligibility trigger kept CHARACTER-IDENTICAL to
    the transfer's own limit (`is_city = yes`, `is_capital = no`, borders the weakest) -
    the mismatch bug has bitten twice; donor must keep >= 2 cities; never take a capital;
    province cooldown flag respected by BOTH tools so shrink and grow cannot ping-pong the
    same border province; engine primitives only (no hard-coded ids) for compatibility.
  - CONTRACT: flag `atools_grow_enabled`; hub vars `atools_grow_interval` /
    `atools_grow_months` / `atools_grow_count`; panel toggle + interval cycle + status.
  - SPIKE FIRST (the one real unknown): **who does `create_colony` colonise FOR?** Vanilla
    only calls it from a country event (ROOT = the coloniser); ours runs from a province
    event (ROOT = province 1), so verify that nesting it as
    `event_target:atools_weakest = { <province> = { create_colony = 1000 } }` attributes
    the province correctly. Fallback route if not: `add_core` + `cede_province` on the
    empty province.
  - EXPECTATION: the claim branch rarely fires in the Old World (no empty provinces left),
    so the take branch dominates outside frontier regions.
  - The panel would reach 4 tools -> do the deferred panel-polish (two-column layout)
    as part of this rather than stacking another row.

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
- [x] **SOLVED: the ~1590 STACK_OVERFLOW.** Root cause was the mod's own global timer:
  `atools.1` was a hidden province_event that re-scheduled ITSELF every 30 days. An event
  fired from inside another event stores its firing context, so every tick nested inside
  the previous one; the chain never unwound and was serialised into the save on the hub
  province. Measured at 1590 in a 1444 game: province 1 = **5,007,426 bytes** (median
  province 4,042) with **1,840 nested scope blocks, 511 tabs deep** -> ~2 stack frames per
  level -> the measured **3,701-3,703 frame** overflow, every ~146 game years, regardless
  of what the tools did. Vanilla loaded the same save fine only because it has no
  `atools.1` defined and discarded the pending chain (which is why the vanilla A/B test
  read as "mod required" - it was, but via the timer, not the tools).
  FIX: the tick now runs in `on_monthly_pulse` gated with `owns = 1` (fresh scope each
  month, nothing accumulates); the event file is empty. `check-mod.sh` now FAILS on any
  self-refiring event so this cannot come back. Docs updated (the old idiom was
  recommended in CLAUDE.md and the reference - both corrected).
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
