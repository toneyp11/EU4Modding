# AutomationTools — backlog

Running list of planned work and ideas, so we don't lose them. Newest context at top.

## In progress
- [ ] **Region-based breakaway tool** — split a nation's holdings that lie *outside its
  capital's region* into separate nations (matches EU4's "French Russia" naming, which
  is region-based). Step 1: confirm foreign-region detection (`region = event_target:X`).
  Step 2: build creation (release a native tag of the region, or custom tag).
  Follows the UI/backend layer pattern. See [docs/automationtools.md](docs/automationtools.md).

## Planned
- [ ] **True exclave breakaways** — split off blocks with no land connection to the
  capital (stricter than region-based). Hard: EU4 has NO connectivity trigger, so this
  needs a multi-tick flood-fill (mark capital connected → spread to adjacent owned
  provinces each month → unflagged = exclave). Heavy/slow; only if region-based isn't enough.
- [ ] **Exact #1 / exact weakest** for the cede tool, instead of development brackets.
  Feasible now that we know to guard with flags (not `exists`) — a variable-based
  running-max/min over `every_country`.
- [ ] **Tune cede thresholds / interval cadence** — the bracket ladders and default
  interval are first-pass values; adjust to taste once we've watched more games.
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
- [x] Auto-cede from #1 nation (anti-snowball) — working; UI/backend split; documented.
- [x] Claude-ready workspace: CLAUDE.md, docs, scripts (check-mod/read-logs/vanilla/gui-diff),
  CWTools, git + GitHub backup, pre-commit validation hook.
