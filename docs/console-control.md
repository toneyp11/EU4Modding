# Console control — running AutomationTools with no UI

The panel is **optional**. Every tool is driven by *global flags*, and EU4's console can
set those directly, so the whole mod is usable from the console alone.

**Why this matters:** scripted GUI must live inside a whitelisted window, every whitelisted
window lives in a vanilla `interface/*.gui` file, and those files **replace wholesale**
rather than merge. So shipping a panel always risks clobbering another mod's version of
that screen. Measured against this machine's installed mods, `provinceview.gui` — the file
we host the panel in — is overridden by **9** of them.

Using the console instead sidesteps that entirely:

> **Delete the mod's `interface/` folder and AutomationTools has zero `.gui` conflicts with
> any mod, while remaining fully functional.**

The backend never references a GUI element name (see the UI↔backend contract in
`common/on_actions/atools_on_actions.txt`), so removing the UI layer changes nothing else.

## Enabling the console

Single-player only. Press `` ` `` (grave/backtick), `~`, or `SHIFT+2` / `SHIFT+3`
depending on keyboard layout.

## Turning tools on and off

| Action | Command |
|---|---|
| Shrink the largest nation — on | `set_flag atools_cede_enabled` |
| Shrink — off | `clr_flag atools_cede_enabled` |
| Convert religion/culture — on | `set_flag atools_convert_enabled` |
| Convert — off | `clr_flag atools_convert_enabled` |
| Grow the weakest nation — on | `set_flag atools_grow_enabled` |
| Grow — off | `clr_flag atools_grow_enabled` |
| Absorb exclaves — on | `set_flag atools_absorb_enabled` |
| Absorb — off | `clr_flag atools_absorb_enabled` |

## The panel flag (and why it is rarely useful)

The panel's own visibility is also a global flag:

| Action | Command |
|---|---|
| Open the panel | `set_flag atools_panel_open` |
| Close the panel | `clr_flag atools_panel_open` |

**But setting it does not by itself make the panel appear.** The panel is a `windowType`
nested inside `province_window`, so it only renders while the province view is open — a
child window cannot draw when its parent is not drawn. With the province view open, the
"Automation" button already toggles this same flag, so the command adds nothing.

There is no console command that can spawn the UI on its own: scripted GUI only renders
inside its host window. If you want control without opening any screen, use the tool flags
above instead — that is the point of console control.

## Setting intervals

Intervals live in hub variables and the console has no variable setter, so each one has a
**request flag**: set it, and the next monthly tick applies the value and clears the flag
(so it takes effect within one game month).

| Tool | Commands |
|---|---|
| Shrink | `set_flag atools_cede_set_1` · `_6` · `_12` · `_24` |
| Convert | `set_flag atools_convert_set_12` · `_24` · `_60` · `_120` |
| Grow | `set_flag atools_grow_set_1` · `_6` · `_12` · `_24` |
| Absorb | `set_flag atools_absorb_set_1` · `_6` · `_12` · `_24` |

Example — shrink every month and grow every 6 months:

```
set_flag atools_cede_enabled
set_flag atools_cede_set_1
set_flag atools_grow_enabled
set_flag atools_grow_set_6
```

## Reading the counters without the panel

The success/failure counters are hub variables shown in the panel's status lines. With no
UI, read them from the log instead — the tools trace every run to `game.log`:

```bash
bash scripts/read-logs.sh
```

`ATOOLS shrink …` / `grow …` / `absorb …` lines show what each run did, and
`S: un-shrinkable` / `S: un-growable` show skipped candidates. A save can also be
inspected directly:

```bash
python scripts/check-save.py "<save.eu4>" --tools
```

**Do not** try to print a variable with a `log` containing `[1.atools_x.GetValue]` — a
scope command inside a log string is a stack-overflow crash (see
`docs/eu4-modding-reference.md`).

## Keeping the panel as well

Nothing here disables the panel; the flags are the same ones its buttons write, so the two
stay in sync. Use the panel when running solo, and the console when running alongside mods
that touch the same screen. If you keep the UI, load AutomationTools **last** so its panel
wins — at the cost of the other mod's version of that screen (see
[compatibility.md](compatibility.md)).
