# AutomationTools — backlog

Running list of planned work and ideas, so we don't lose them. Newest context at top.

- (awaiting in-game test) **Auto-convert religion & culture tool** — new toggle with its
  OWN interval (`atools_convert_interval`, default 60 mo, cycles 12/24/60/120), fully
  decoupled from the shrink interval. Each convert run, every owned province whose
  religion/culture differs from its owner's has a 20% chance to flip toward the owner
  (`change_religion = owner` / `change_culture = owner`) — including same-group cases
  (Catholic→Orthodox) the AI never converts. Chance is tunable in `atools_convert_effect`.

## Shelved (removed from main; preserved on branch `wip-exclave-breakaway`)
- [ ] **Exclave breakaway + 100-tag custom-nation pool** — DISABLED per user (2026-07).
  Full working feature lives on branch `wip-exclave-breakaway` (commit 5a47b46) + the
  generator `scripts/gen_pool.sh`. What it does: detects exclaves via `is_overseas = yes`
  (the correct connectivity test — supersedes the old region criterion, which wrongly
  chopped contiguous multi-region empires), cedes claimable exclaves to living
  core-holders, and breaks the rest away as new nations from a 100-tag pool (AT0-BV9),
  named after their area (`atools_name_by_area`). WHY SHELVED: not fully validated +
  compatibility concerns. WHEN RESUMING: (1) confirm `is_overseas` catches land exclaves
  in-game; (2) do compatibility hardening FIRST (below); (3) restore 12mo interval (branch
  has 1mo test value). `override_country_name` does NOT resolve scope commands (so exact
  per-province names impossible — area names are the max).

## Compatibility (STANDING PRIORITY — user runs this with other mods)
- [x] **Audit done** — backend logic is fully map-agnostic; only province 1 (hub) is
  hard-coded, no area/region names, no un-prefixed loc keys, provinceview.gui is purely
  additive. See [docs/compatibility.md](docs/compatibility.md).
- [x] **Enforced** — check-mod.sh Compatibility section (non-hub province ids, un-prefixed
  loc keys, provinceview.gui additiveness). Load-order guidance documented.
- [ ] **Dynamic hub province** (only needed for total conversions) — stop hard-coding
  province 1; pick a guaranteed-existing province at startup. Low priority: province ID 1
  exists in every map, so map-expansion mods are already fine.

## Planned
- [ ] **Tune interval cadence** — default interval is a first-pass value; adjust to
  taste once we've watched more games. (Dev brackets are gone — now exact #1/weakest.)
- [ ] **Polish the panel's visual design** — layout, styling, icons. Pure UI now
  (contract-isolated), so it won't touch backend logic.

## Ideas / maybe
- [ ] **Custom-named breakaway nations** — a mod-defined pool of tags with dynamic names
  (`override_country_name`) + flags, for invented nations rather than historical ones.
  Bigger effort (finite pool, flag art, name scheme).
- [ ] **Verify `create_client_state` DLC status** — dynamic-nation option (engine
  generates the name); useful if we want dynamic nations without a predefined tag pool.
- [ ] Additional automation tools as they come up (each = flag + backend effect + timer
  block + UI toggle, per the add-a-tool recipe in docs/automationtools.md).

## Done
- [x] **Combined anti-snowball tool** (one toggle) — each interval the exact #1 nation is
  shrunk: first releases every possible nation as INDEPENDENT
  (`release_all_possible_countries` + `release_all_subjects`), else (nothing releasable,
  detected via a total_development before/after snapshot) cedes a border province to its
  exact weakest neighbour. Subjects eligible both ways. Verified in-game.
- [x] **Exact #1 / exact weakest** — replaced the development-bracket ladders with exact
  running max/min over `every_country` / `every_neighbor_country` (vanilla flavorBYZ
  idiom). Verified `total_development = event_target:X` resolves reliably.
- [x] Auto-cede from #1 nation (anti-snowball) — working; UI/backend split; documented.
- [x] Claude-ready workspace: CLAUDE.md, docs, scripts (check-mod/read-logs/vanilla/gui-diff),
  CWTools, git + GitHub backup, pre-commit validation hook.
