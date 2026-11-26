# AutoHotkey / Age of Empires IV setup

This folder holds the canonical copy of the AutoHotkey v2 script used for
Age of Empires IV control-group management. Read this before changing any
of the AoE4 hotkeys.

## Files

| Path | Role |
| --- | --- |
| `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\main.ahk` | **Active** script, launched at login. This is the one that matters at runtime. |
| `C:\Users\Brandon\Documents\dotfiles\windows\autohotkey\main.ahk` | Canonical/source copy. Keep text-identical to the active script. |
| `C:\Users\Brandon\Downloads\main.ahk` | Original pre-change backup. **Do not modify.** Keep it byte-for-byte as-is. |
| `C:\Users\Brandon\Documents\My Games\Age of Empires IV\keyBindingProfiles\Main.rkp` | AoE4 keybinding profile. |
| `C:\Users\Brandon\Documents\My Games\Age of Empires IV\keyBindingProfiles\Main.rkp.bak-ahk-tune` | Profile backup before AoE4 binding edits. |

After any script edit: apply it to **both** the active ProgramData file and the
dotfiles copy, run the syntax check, then start the ProgramData file so the new
instance replaces the old one. Confirm only one `AutoHotkey64.exe` process runs.

Syntax check used during development:
`C:\Users\Brandon\AppData\Local\Temp\opencode\validate_ahk.ps1`
(it compiles the script with `#Requires AutoHotkey v2.0`, `#SingleInstance Off`,
and `ExitApp` prepended, then reports stderr).

## Physical mouse / keyboard mapping (Logitech software)

Do not assume standard AHK mouse button names when reasoning about the user's
input — Logitech remaps several buttons before Windows/AHK sees them.

| Physical control | What Windows/AHK receives | Used for |
| --- | --- | --- |
| Lower thumb button (below forward) | `F8` | **Smart add** (main key) |
| Forward side button | `Ctrl` | Ctrl modifiers / control-group assignment |
| Back side button | `MouseX1` | AoE4 `cancel_last_production_item` — must be left untouched by AHK |
| Esc key | `F9` | AoE4 select idle military |
| XButton2 (historical) | `F10` | Legacy/backup — currently not produced by the described mouse mapping |

All AoE4 hotkeys are scoped with `#HotIf WinActive("ahk_exe RelicCardinal.exe")`
(or `HotIfWinActive` for hotkeys created with `Hotkey()`).

## Current AoE4 hotkeys

### Control groups

| Input | Effect |
| --- | --- |
| bare `1`..`0` | Select group N (passes through with `~`), and set `LastGroup := N` |
| `Ctrl+N` | First press in a Ctrl sequence sends `/` (remove selection from all groups), then assigns to group N; sets `LastGroup := N` |
| `F10 + N` | Assign selection to group N **without** `/`; sets `LastGroup := N` |
| **F8** (lower thumb button) | **Smart add**: `Send("!" . LastGroup)` — add the current selection to the last group, without removing it from other groups |
| `F10` tap | Backup smart-add trigger (harmless; current mouse maps forward to Ctrl, so this may never fire) |
| `Shift + Middle-click` over a unit | Detach that one unit to raid group **6**: select it, `/`, `Ctrl+6` |
| `F9` | AoE4 select idle military (profile binding, moved off F8) |
| `Ctrl+Q` / `Ctrl+W` | Select next scout / next monk, then focus (`.`) via the `FocusKeys` macro |

### Other script behavior

- `Space` is remapped to held Shift; `\` is remapped to Space. Since the
  detach macro requires **physical** Shift (`GetKeyState("Shift", "P")`), the
  Space remap does not trigger it.
- The old F9→focus macro was removed. Ctrl+Q/Ctrl+W still auto-focus because
  `q` and `w` are in `FocusKeys`.
- `Ctrl+\`` (`pick_all_of_current_types`) is deliberately **not** used.
  The user wants local, explicit selection only; map-wide type selection can
  grab raiders that were intentionally left elsewhere.

## Design notes / gotchas

- `LastGroup` starts at `1`. It is updated in three places:
  `TrackGroup` (bare numbers), `HandleCtrlNumber` (`Ctrl+N`), and
  `HandleControlGroup` (`F10+N`). The Ctrl/F10 updates were the actual fix for
  "last group doesn't follow Ctrl+number" — the original script only tracked
  bare numbers.
- Hotkey callbacks receive `A_ThisHotkey` as an extra argument. Every bound
  callback must accept it, e.g. `TrackGroup(n, *)`. A past error was
  `Too many parameters passed to function` because `TrackGroup(n)` lacked `*`.
  The same applies to `SetLastGroup` calls: it takes **one** argument; older
  versions called it with `(key, "Ctrl+")` / `(key, "F10+")` and caused the
  same error.
- `Send("N")` does **not** trigger AHK hotkeys in this setup (verified with a
  scratch test), so the script's own `Send()` calls do not disturb `LastGroup`.
- Replacing `~N` trackers with wildcard `~*N` (plus Numpad variants) was tried
  and reverted. It added complexity and did not solve the real problem; the
  direct `SetLastGroup` calls in the Ctrl/F10 handlers did.
- An earlier `F8` macro absorbed intake group 5 into `LastGroup`
  (`5` → `/` → `Alt+target`). It was removed at the user's request; F8 is now
  pure smart-add. Do not reintroduce group-5 logic without asking.
- AoE4 may use RawInput for mouse buttons, so a conflicting in-game binding
  can fire alongside an AHK hotkey. `Shift+MouseMiddle` was removed from
  `pick_all_archers_on_screen` in `Main.rkp` for this reason; `Control+S`
  remains that command's binding.
- Profile conflicts already cleared: F9 removed from `pick_next_monk`
  (Ctrl+W only), F9 removed from `quick_load`, F8/F9 removed from
  `focus_selected` (Period only). F8 is still `quick_save` in the profile,
  but AHK swallows F8 while AoE4 is active.
- After a machine restart, an old AHK instance can survive with a stale
  version of the script. If behavior looks like an older revision or errors
  mention removed code (e.g. two-argument `SetLastGroup`), check for multiple
  `AutoHotkey64.exe` processes, stop the stale one, and relaunch the
  ProgramData script.

## Development history (condensed)

1. Shift+Middle-click detach to raid group added; raid group changed 9 → 6.
2. Smart add implemented, originally on `XButton1`; moved to F8/F10 once the
   Logitech button mapping was understood.
3. Ctrl+number and F10+number handlers taught to update `LastGroup`.
4. F8 absorb macro added, then removed; F8 is now pure smart-add.
5. Temporary `trackgroup.log` diagnostics were added during debugging and
   removed once confirmed working. Do not re-add unless debugging a new
   tracking problem.
