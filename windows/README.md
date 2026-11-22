# Windows tiling setup (Komorebi + whkd + YASB)

AeroSpace-style tiling for Windows. `alt` is the primary modifier because `ctrl`
is mapped to `alt` on the Mac keyboard.

This folder is intentionally separate from the top-level README.

## Tools

| Tool | Purpose | Install |
| --- | --- | --- |
| [Komorebi](https://github.com/LGUG2Z/komorebi) | Tiling window manager (native `Grid` layout) | `winget install LGUG2Z.komorebi` |
| [whkd](https://github.com/LGUG2Z/whkd) | Hotkey daemon | `winget install LGUG2Z.whkd` |
| [YASB](https://github.com/amnweb/yasb) | Status bar | `winget install AmN.YASB` |

## Config locations

Copy the files in this folder to:

```
komorebi/komorebi.json            -> C:\Users\Brandon\komorebi.json
whkd/whkdrc                       -> C:\Users\Brandon\.config\whkdrc
autohotkey/main.ahk               -> C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\main.ahk
yasb/config.yaml                  -> C:\Users\Brandon\.config\yasb\config.yaml
yasb/styles.css                   -> C:\Users\Brandon\.config\yasb\styles.css
```

Komorebi's static config path can be confirmed with `komorebic configuration`.

## Startup

Shortcuts in `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`:

| Shortcut | Target | Arguments |
| --- | --- | --- |
| `komorebi.lnk` | `C:\Program Files\komorebi\bin\komorebic-no-console.exe` | `start --whkd` |
| `yasb.lnk` | `C:\Program Files\YASB\yasb.exe` | — |
| `watch-whkd.lnk` | `powershell.exe` | `-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ...\whkd\watch-whkd.ps1` |
| `game-hotkey-guard.lnk` | `powershell.exe` | `-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ...\whkd\game-hotkey-guard.ps1` |

The original global script is not a shortcut: `main.ahk` sits directly in the
**all-users** Startup folder (`C:\ProgramData\Microsoft\Windows\Start Menu\
Programs\Startup\main.ahk`) and is launched via the registered `.ahk`
association. See [Global hotkeys](#global-hotkeys-mainahk).

`komorebic start --whkd` starts Komorebi and whkd; `watch-whkd.ps1` restarts
whkd if it exits mid-session (only after Komorebi is running), so hotkeys
recover without a logout. `game-hotkey-guard.ps1` stops whkd while a game is
running and restarts it on exit (see below). YASB is the only bar, so `--bar`
is deliberately omitted from the Komorebi shortcut to avoid a duplicate bar.

Add `C:\Program Files\komorebi\bin` and `C:\Program Files\whkd\bin` to `PATH`
so YASB can subscribe to Komorebi's named pipe.

## Grid layout

The native `Grid` layout is used on all four workspaces (2 per monitor). It
reproduces the AeroSpace `ceil(sqrt(n))` grid growth without a script:

| Windows | Shape |
| --- | --- |
| 3 | `1 + 2` |
| 4 | `2 x 2` |
| 5 | `1 + 2 + 2` |

## Dual monitor spacing

- Primary monitor: 3840x2160 @ 150% scaling. YASB app-bar mode
  (`windows_app_bar: true`) reserves the bar space via Windows.
- Secondary monitor: 2560x1440 @ 100% scaling. With the taskbar pinned to the
  bottom, Windows reserves the YASB app-bar space on **both** monitors, so no
  static `work_area_offset` is needed. An old `top: 35` offset used to double
  the gap (windows started 35px below the bar); remove it if you see that.
- `default_workspace_padding` and `default_container_padding` are both `1`,
  giving a 2px visual gap around windows.
- YASB bar padding is 1px on all sides.

Runtime `komorebic monitor-work-area-offset` changes are additive on top of
the config value and can double the gap — prefer editing `komorebi.json`
and restarting Komorebi. Also note `komorebic reload-configuration` only
reloads legacy configs; it does not reload `komorebi.json`.

## Keybindings

| Keys | Action |
| --- | --- |
| `alt+h/j/k/l` | Focus left / down / up / right |
| `alt+shift+h/j/k/l` | Move window left / down / up / right |
| `alt+w` / `alt+q` | Next / previous workspace on monitor |
| `alt+shift+w` / `alt+shift+q` | Move window to next / previous workspace |
| `alt+1` / `alt+3` | Focus workspace 1 / 3 on monitor 0 |
| `alt+2` / `alt+4` | Focus workspace 2 / 4 on monitor 1 |
| `alt+shift+1..4` | Move window to the matching workspace (key N = workspace N) |
| `win+1..4` | Move window to the matching workspace (AHK helper) |
| `win+q`, `ctrl+shift+q`, `alt+shift+z` | Close window |
| `alt+m` | Minimize |
| `alt+shift+p` | Toggle pause (visible in the bar as `PAUSED`) |
| `alt+shift+r` | Retile |
| `alt+t` | Toggle float |
| `alt+f`, `ctrl+f` | Monocle / fullscreen |
| `alt+left` / `alt+right` | Resize width − / + |
| `alt+down` / `alt+up` | Resize height − / + |
| `alt+u` / `alt+p` | Resize width − / + |
| `alt+shift+arrows` | Stack window in a direction |
| `alt+shift+a` / `alt+shift+s` | Previous / next monitor |

`alt+1..4` uses `focus-monitor-workspace` (and `move-to-monitor-workspace`)
rather than `focus-workspace`, because the plain commands target the
*currently focused monitor*. On a two-workspace monitor, asking for index 2
or 3 would create new unnamed workspaces there instead of switching monitors.

Workspace **names match their number keys**: `1,3` are on monitor 0 and `2,4`
are on monitor 1. The number identifies the workspace, not a slot on a
monitor — `alt+2` focuses workspace `2` on monitor 1.

Explorer claims `win+1..4` for taskbar app switching before whkd can see
them, so `autohotkey/main.ahk` intercepts those combos and calls
`komorebic move-to-monitor-workspace` directly. `DisabledHotkeys = 1234` is
also set under `HKCU\...\Explorer\Advanced` to stop Explorer claiming them;
**sign out and back in** after first applying that registry value. `win+q`
is handled by whkd and does not conflict.

`alt+p` is used for resizing rather than pause, so pause is `alt+shift+p` only.
Komorebi's Grid layout ignores `resize-axis`, so all resize keys call
`whkd/resize-grid.ps1`, which adjusts the focused workspace's grid column/row
ratios in small steps. The old `+`/`-` resize bindings are still available as
aliases. Stacking and the shortcuts overlay are also bound in `whkdrc`.

## Global hotkeys (main.ahk)

`autohotkey/main.ahk` is the original global AHK script. It lives as a raw
`.ahk` file in the **all-users** Startup folder
(`C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\main.ahk`),
where Windows launches it at logon through the registered `.ahk` association
(`AutoHotkeyUX.exe` -> `AutoHotkey64.exe`). It is the only AHK script; the
`win+1..4` workspace bindings were merged into it.

| Keys | Action |
| --- | --- |
| `win+h` | Hibernate (`SetSuspendState` with hibernate) |
| `win+shift+h` | Sleep (`SetSuspendState` without hibernate) |
| `win+e` | Focus or launch File Pilot (`FPilot.exe`) instead of Explorer |
| `win+w` | Focus or launch Vivaldi |
| `win+s` | Focus or launch Steam |
| `win+x` | Focus or launch Spotify |
| `win+ctrl+x` | Send window to next monitor (`win+shift+right`) |
| `win+1..4` | Move window to matching Komorebi workspace |
| `alt+shift+z` | Close window (`alt+F4`) |

The second half of the script is an Age of Empires IV block guarded by
`#HotIf WinActive("ahk_exe RelicCardinal.exe")`: Space behaves as Shift,
backslash as Space, and `Ctrl`/`F10` + number/focus keys bind control groups.
These only fire while the game is focused. The game guard stops **whkd** while
the game runs, but it does not stop AHK, so these in-game bindings keep working.

## Gaming (disabling hotkeys)

`whkd/game-hotkey-guard.ps1` polls every 2 seconds for `RelicCardinal.exe`
(Age of Empires IV). While it is running, whkd is stopped so **all** tiling
hotkeys are released, including `alt+1..4`/`win+1..4` that the game also uses;
whkd is restarted automatically when the game exits.

whkd uses `RegisterHotKey`, which swallows keys at the OS level before the
foreground app sees them — even an app-specific `Ignore` rule only skips the
command, it does not pass the key through. Stopping whkd is therefore the only
way to give the game its keys back. `watch-whkd.ps1` knows about this and will
not restart whkd while the game is running.

Edit `$game` in the guard script to target a different executable.

## Status bar

- `komorebi_workspaces` with `hide_if_offline: false` and
  `hide_empty_workspaces: false` — all 4 workspaces are always shown.
- `active_window` shows only the app icon (no title).
- Custom `pause_status` widget polls `komorebic state` every second and shows
  `PAUSED` while tiling is paused; clicking it toggles pause.
- Custom `fullscreen_status` widget (`yasb/fullscreen-status.ps1`) polls the
  focused workspace and shows `⛶` while it is monocle/fullscreen.
- Clock uses 12-hour time (`%I:%M %p`) on the bar and in the hover label.
- GPU utilization widget.

## Stream Deck — Game Hub (Windows)

The Windows Stream Deck replaces the macOS work deck with a gaming deck. The source project
lives at `C:\Users\Brandon\Documents\Main\streamdeck`; this section records the setup steps.

1. Requirements: Stream Deck 7.1+, Steam, Discord, Spotify, the **Hue Sync desktop app**, and
   Node.js/npm for rebuilding.

2. Build and install the plugin/profile:

   ```powershell
   cd C:\Users\Brandon\Documents\Main\streamdeck
   .\build.ps1
   ```

   This builds the icons/profile, installs the plugin, restarts Stream Deck, and switches to the
   *Game Hub* profile automatically.

3. Hue Sync: make sure `C:\Program Files\Hue Sync\HueSync.exe` is running, then confirm
   `%APPDATA%\HueSync\config.json` has:

   ```json
   "App": {
     "PublicControlEnabled": true,
     "PublicControlPort": 24851
   }
   ```

   Restart Hue Sync, then Stream Deck, so the Elgato Hue Sync plugin reconnects. A backup of the
   original config is saved as `config.json.gamehub-backup`.

4. Spotify (one time): an existing Spotify app Client ID can be reused, but add this exact
   redirect URI to that app in the Spotify dashboard first:

   ```text
   http://127.0.0.1:4202
   ```

   Then log in:

   ```powershell
   cd $env:APPDATA\Elgato\StreamDeck\Plugins\com.bschur.gamehub.sdPlugin
   node bin\spotify-api.js login <client id>
   ```

   The token is stored in `%APPDATA%\streamdeck-spotify\token.json` and renews automatically.
   The playlist picker works from `playlists.json` before login; the song picker needs the token.

5. Keys: **Discord** press = open/focus, hold = mute, double-tap = deafen; **Games** = Steam
   recents; **Refresh** = rescan games; **WoW Forever** is pinned; **♪ Music** tap = song picker
   and hold ≥ 0.5 s = playlist picker. Hue Sync is the top-row 4th key and is unrelated to Refresh.
