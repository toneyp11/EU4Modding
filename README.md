# EU4 Modding Workspace

Europa Universalis IV (v1.37.5, no-DLC) mod development, done with Claude Code.

- **`AutomationTools/`** — the mod: a toggleable "automation tools" UI panel for
  observer mode, with an anti-snowball auto-cede tool. See
  [docs/automationtools.md](docs/automationtools.md).
- **`CLAUDE.md`** — start here. Environment, the build/test loop, and the golden rules.
- **`docs/eu4-modding-reference.md`** — hard-won EU4 modding lessons, verified idioms,
  and every crash/gotcha with its fix.
- **`scripts/`** — `check-mod.sh` (validate the mod before restarting) and
  `read-logs.sh` (inspect game logs / latest crash).

## Quick start (testing a change)
1. Edit files in `AutomationTools/`.
2. `bash scripts/check-mod.sh` — brace balance, BOM, GUI bindings.
3. **Restart EU4** (no hot-reload), load the dev playset, enter observer mode.
4. `bash scripts/read-logs.sh` to see traces / errors.

The launcher reads the mod from this repo directly (descriptor `path=` points here),
so there's nothing to copy or build.
