# AutomationTools — backlog

Running list of planned work and ideas, so we don't lose them. Newest context at top.

## In progress
- (nothing active)

## Paused
- [ ] **Region-based breakaway tool** — split a nation's holdings *outside its capital's
  region* into separate nations (matches EU4's "French Russia" naming). PROGRESS:
  detection CONFIRMED working via `capital_scope = { save_event_target_as = P }` then
  `region = event_target:P` (region= needs a PROVINCE, not a country). Creation drafted
  as cede-to-living-core-holder (`random_core_country` + `cede_province = event_target`).
  OPEN DECISION — recipient coverage (3 cases): (1) living independent claimant → works;
  (2) dead historical claimant → needs revive (release=TAG is literal-only → hardcoded
  list or custom pool); (3) no claimant ever (colonies) → only the custom tag pool covers
  it. Dormant spike code is in scripted_effects (`atools_split_effect`), not wired to the
  timer. Resume by re-adding the timer call + choosing a creation route.

## Planned
- [ ] **True exclave breakaways** — split off blocks with no land connection to the
  capital (stricter than region-based). Hard: EU4 has NO connectivity trigger, so this
  needs a multi-tick flood-fill (mark capital connected → spread to adjacent owned
  provinces each month → unflagged = exclave). Heavy/slow; only if region-based isn't enough.
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
