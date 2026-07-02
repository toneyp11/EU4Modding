# CWTools (in-editor EU4 validation) — setup notes

CWTools gives live, in-editor validation of EU4 script (unknown tokens, bad scopes,
missing loc, etc.) — a bigger net than `scripts/check-mod.sh`, catching many silent
failures before a restart. Getting it working here was non-obvious; this records why.

## The gotcha
CWTools auto-detects which game a workspace is by looking for the game name
("Europa Universalis IV") in the **workspace path**. Our dev path
(`C:/Development/EU4Modding/AutomationTools`) has no game name, so CWTools defaulted to
the **Stellaris** ruleset and loaded **0 EU4 effects** → syntax coloring worked but
nothing validated. A directory junction with the game name in it did NOT help — VS Code
resolves the junction back to the real path before CWTools sees it.

## The fix: force the EU4 ruleset manually
1. Clone the EU4 config once (outside the repo):
   ```
   git clone --depth 1 https://github.com/cwtools/cwtools-eu4-config.git C:/Development/cwtools-eu4-config
   ```
2. `AutomationTools/.vscode/settings.json` points CWTools at it and at the vanilla install:
   ```json
   {
     "cwtools.cache.eu4": "C:/Program Files (x86)/Steam/steamapps/common/Europa Universalis IV",
     "cwtools.rules_version": "manual",
     "cwtools.rules_folder": "C:/Development/cwtools-eu4-config"
   }
   ```
3. Open the mod folder (`AutomationTools`) in VS Code → Reload Window.

## Verify it's working (CWTools Output channel)
Good state shows: `Rules loaded`, `Parsing 6 files` / `Validating N files`, and
`Looking for effect ... in the 1454 effects loaded` (NOT "0 effects loaded"). A bogus
token like `zzz_not_a_real_token = yes` should get a red squiggle.

## Known FALSE POSITIVES (CWTools rule gaps — do NOT "fix" these)
CWTools' EU4 rules don't model some valid idioms we rely on. These errors are bogus:
- **`CW263: 1 is unexpected in ...`** — `1 = {}` (scope to province by ID) is valid
  vanilla. CWTools doesn't model numeric province scopes. We use province 1 as the hub.
- **`CW263: NOT is unexpected in limit`** — `NOT` in a `limit` is always valid. CWTools
  can't infer a scripted effect's scope, so it mis-validates the limit blocks inside it.
- **`CW266: ... command 1 which does not exist`** — `[1.var.GetValue]` (display a
  province-1 variable in loc) is valid vanilla (`[1.GPW_counting_variable.GetValue]`).
- **`CW240: Expecting a float, got <our_var>`** (warning) — our runtime variables set
  via `1 = { set_variable }`; CWTools can't track them (downstream of the `1={}` gap).

**Rule of thumb:** trust CWTools on unknown tokens/typos, scope mismatches on normal
country/province scopes, and undefined loc keys. Distrust anything about `1 = {}`,
`[1....]`, `NOT`-in-limit inside scripted effects, and our own variables. A cleaner-panel
option (not done, to avoid churning working code): save province 1 as a global event
target at startup and use `event_target:atools_hub` everywhere instead of `1 = {}`.

## Notes
- The `repoPath = ...stellaris...` line in the init log is just a default echo; the
  rules actually loaded are the manual EU4 ones (paths under `cwtools-eu4-config`).
- `Unexpected modifier category` / `Unexpected leaf` spam = CWTools parsing quirks in
  its own config repo. Harmless; not your mod.
- `effects.log/triggers.log not found` is fine — the `.cwt` config already provides the
  1454 effects. (Those game-exported logs are only needed for extra coverage.)
- To update rules for a new EU4 version: `git pull` in `C:/Development/cwtools-eu4-config`.
- CWTools is a preview tool — git is our safety net.
