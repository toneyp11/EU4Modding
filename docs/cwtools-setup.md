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

## Notes
- The `repoPath = ...stellaris...` line in the init log is just a default echo; the
  rules actually loaded are the manual EU4 ones (paths under `cwtools-eu4-config`).
- `Unexpected modifier category` / `Unexpected leaf` spam = CWTools parsing quirks in
  its own config repo. Harmless; not your mod.
- `effects.log/triggers.log not found` is fine — the `.cwt` config already provides the
  1454 effects. (Those game-exported logs are only needed for extra coverage.)
- To update rules for a new EU4 version: `git pull` in `C:/Development/cwtools-eu4-config`.
- CWTools is a preview tool — git is our safety net.
