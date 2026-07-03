# EU4 modding reference (v1.37.5, no-DLC)

Lessons learned building this workspace. Everything here is **verified against the
1.37.5 game files or observed in-game** unless marked otherwise. Add to it as we learn.

---

## 1. Custom GUI (scripted UI)

EU4's scripted-UI system is **custom GUI**, defined in `common/custom_gui/*.txt`.
Authoritative reference: vanilla `common/custom_gui/example.txt` and `mission_previews.txt`.

- Object types: `custom_button`, `custom_text_box`, `custom_icon`, `custom_shield`,
  `custom_window`. Each references a GUI element in an `interface/*.gui` file **by
  `name`**, and that element **must have `scripted = yes`** or it is ignored.
- Fields: `potential = {}` (visibility trigger), `trigger = {}` (clickable),
  `effect = {}` (on click), `tooltip = <loc key>`, `frame = { number trigger }`
  (icon frame; first matching clause wins; or `frame_variable`).
- `custom_window`'s `potential` gates the whole window and skips children when hidden
  — toggle a global flag in it to show/hide a panel.

**Whitelist constraint (critical):** custom GUI objects only work when nested (any
depth) inside one of a fixed set of game windows. Observer-mode-friendly anchors:
`province_window` (ROOT = clicked province) and `buildings_window` (also province).
Others: `countrygovernmentview`, `countryeconomyview`, etc. (ROOT = FROM / selected
country). The global topbar is **not** on the whitelist. `FROM` = the country that
clicks (undefined in observer mode with no player).

`.gui` files do **not** merge — a modded `interface/provinceview.gui` fully replaces
vanilla, so we copied vanilla verbatim and injected our elements inside
`province_window` / `buildings_window`.

## 2. File loading rules

- `common/**` and `common/on_actions/*` **merge** additively across vanilla + mods.
  Our `on_actions` and `custom_gui` files just add entries.
- `interface/*.gui` **replace** wholesale (last loaded wins). Copy vanilla + edit.
- Localisation `*_l_english.yml` **must be UTF-8 with BOM** (`EF BB BF`) or it silently
  won't load. Verify: `head -c3 file | xxd` → `efbb bf`.
- `.mod` descriptor `path=` may point anywhere (absolute); the launcher rewrites the
  descriptor on import (reordering fields) — that's how you know it was detected.

## 3. Verified script idioms

### Guarding on saved event targets — use FLAGS, not `exists`
`exists = event_target:X` is **unreliable in this mod** — it returned `false` even when
the target was correctly saved (proven: `event_target:X = { ... }` scope-in worked, but
`exists` said no). Guard on a global flag instead:
```
random_country = { limit = { ... } save_event_target_as = my_target set_global_flag = have_target }
if = { limit = { has_global_flag = have_target } event_target:my_target = { ... } }
```
Also: `save_event_target_as`/`save_global_event_target_as` and effect iterators
(`random_country`/`every_country`) DO work from a province-event scope — the saves
succeed; it was only the `exists` check that lied.

### Find the largest / smallest country (NO `PREV`)
`total_development = PREV` does **not** resolve inside a nested `any_country` (vanilla
never uses `= PREV`). Save each candidate as an event target and compare to it:

```
every_country = {
    limit = { is_subject = no }
    save_event_target_as = atools_candidate
    if = {
        limit = {
            NOT = { any_country = {
                NOT = { tag = event_target:atools_candidate }   # exclude self
                total_development = event_target:atools_candidate # other's dev >= candidate's
            } }
        }
        save_global_event_target_as = atools_top_nation          # the strict maximum
    }
}
```
Numeric triggers **do** accept a scope on the right: `total_development = ROOT/FROM/
event_target:X` (all `>=` comparisons). For "weakest", flip to
`NOT = { total_development = event_target:candidate }` (strictly weaker exists).

### Borders / neighbours
- Country-level: `is_neighbor_of = event_target:X` (true across land **or straits**).
  Accepts scopes/event targets. **Use this** — the manual
  `any_owned_province = { any_neighbor_province = { owner = { tag = … } } }` nesting
  silently evaluated false for us.
- Province owner test: `owned_by = event_target:X`.
- Neighbour iterators: `any_neighbor_country`, `random_neighbor_country`,
  `any_neighbor_province`. Adjacency = the pixel graph from `map/provinces.bmp` **plus**
  strait/canal links from `map/adjacencies.csv` (`From;To;Type;Through;…`, Type `sea`
  = strait). Sea provinces have no owner → filtered out by `owned_by`/`is_city = yes`.

### Cede a province
`cede_province = event_target:X` (province scope) transfers ownership+control. We also
`add_core = receiver` then `remove_core = giver` so it sticks:
```
event_target:atools_top_nation = {
    random_owned_province = {
        limit = { is_city = yes any_neighbor_province = { owned_by = event_target:atools_receiver } }
        add_core = event_target:atools_receiver
        cede_province = event_target:atools_receiver
        remove_core = event_target:atools_top_nation
    }
}
```

### Global once-per-period timer
Per-country pulses (`on_monthly_pulse`) fire once *per country*. For a single global
tick, use a self-refiring hidden event on a permanent scope (province 1 = Stockholm,
always exists), started once from `on_startup` behind a flag:
```
# on_actions:
on_startup = {
    if = {
        limit = { NOT = { has_global_flag = atools_timer_started } }
        set_global_flag = atools_timer_started
        1 = { set_variable = { which = atools_months value = 0 }
              province_event = { id = atools.1 days = 30 } }
    }
}
# event (hidden, is_triggered_only):
province_event = {
    id = atools.1
    title = none  desc = none  hidden = yes  is_triggered_only = yes
    immediate = {
        province_event = { id = atools.1 days = 30 }   # re-arm (survives save/load)
        change_variable = { which = atools_months value = 1 }
        ...
    }
    option = { name = atools.1.a }   # hidden events still want one option (silences a warning)
}
```
`days = 30` ≈ monthly (drifts slightly vs calendar). Pending delayed events are saved
with the game, so the chain survives reloads — hence the flag guard against duplicates.

### Variables & the hub
Variables attach to a scope. We keep global counters on **province 1** as the "hub":
- Write from anywhere: `1 = { set_variable = { which = X value = N } }`.
- Compare two variables: `check_variable = { which = A which = B }` (A >= B).
- **Display in UI/loc**: `[1.X.GetValue]` (this is how vanilla shows province-1 vars).
  Whole numbers render clean; may show decimals otherwise.

### Logging / debugging
- `log = "text [This.GetName] [Root.GetName] [GetYear]"` writes to `game.log`. Scope
  **name** commands work in logs.
- **`.GetValue` (variable display) does NOT work in `log`** and causes
  `EXCEPTION_STACK_OVERFLOW`. Only use `.GetValue` in loc/UI.
- "Did this search find anything" probe: `clear_global_event_target = T` before a
  `save_global_event_target_as = T`; `Trying to remove undefined event target: T` in
  `error.log` means the search found nobody that pass. Counts per name localize the bug.

## 4. Crash cases & gotchas (symptom → cause → fix)

| Symptom | Cause | Fix |
|---|---|---|
| `ACCESS_VIOLATION` at load/render, no parse error | `corneredTileSpriteType` (e.g. `gfx_message_bg`) used as a windowType `backGround` | `backGround=""`; draw bg as a **child** `guiButtonType`/`iconType` `quadTextureSprite` with explicit `size` |
| `STACK_OVERFLOW` in `RtlCreateUnicodeString` | a variable `.GetValue` inside a `log` string | remove it; log names only, or show the value in UI |
| Search silently finds nobody | `total_development = PREV` (doesn't resolve) | save candidate as event target, compare to `event_target:X` |
| Neighbour search always false | hand-rolled `any_owned_province/any_neighbor_province/owner` border test | use `is_neighbor_of = event_target:X` |
| Panel button barely visible | animated button sprites render translucent at rest (`GFX_button_150_24`, `GFX_button_60_29`, `button_*_animated.dds`) | use a solid `textSpriteType`, e.g. `button_type_8` (189x31, the province view's own button) |
| Panel centres on the province UI, not screen | `Orientation="CENTER"` is parent-relative; province view is docked lower-left | keep `CENTER` + `position = (-halfSize) + (screenCentre − provinceWindowCentre)`; calibrated `{886,-461}`-ish at 2560×1440; resolution-specific |
| `.yml` changes don't show | missing BOM | write UTF-8 with BOM |
| GUI changes don't apply without restart | modded-GUI hot-reload is unreliable | restart; there is no good workaround |

**Vanilla log noise to ignore** (not mod bugs): `Synthetics has no primary culture/
religion` (hidden Synthetic Dawn tag), `AST … no default sub-unit` (Astrakhan),
`economic_ideas … wrong scope`, `Undefined event target: EmperorOfChina` (no MoH DLC).

## 5. Useful sprites (no custom art needed)
- Solid text button: `button_type_8` (189×31), `button_type_4`.
- Checkbox (on/off frames): `GFX_checkbox` (4 frames; frame 2 = ticked).
- Close button: `GFX_button_close`.
- Translucent panel bg: `gfx_transp_black_50` (resizable corneredTile, ~50% black) as a
  child `quadTextureSprite` with `size`.
- Province-view tab: `GFX_province_tab_button` (198×46, 2 frames).
