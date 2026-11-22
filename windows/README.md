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
komorebi/komorebi.json -> C:\Users\Brandon\komorebi.json
whkd/whkdrc            -> C:\Users\Brandon\.config\whkdrc
yasb/config.yaml       -> C:\Users\Brandon\.config\yasb\config.yaml
yasb/styles.css        -> C:\Users\Brandon\.config\yasb\styles.css
```

Komorebi's static config path can be confirmed with `komorebic configuration`.

## Startup

Two shortcuts in the Startup folder:

| Shortcut | Target | Arguments |
| --- | --- | --- |
| `komorebi.lnk` | `C:\Program Files\komorebi\bin\komorebic-no-console.exe` | `start --whkd` |
| `yasb.lnk` | `C:\Program Files\YASB\yasb.exe` | — |

YASB is the only bar, so `--bar` is deliberately omitted from the Komorebi
shortcut to avoid a duplicate bar.

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
- Secondary monitor: 2560x1440 @ 100% scaling. Windows does **not** reserve
  app-bar space there, so `komorebi.json` sets
  `work_area_offset.top = 35` for monitor index 1 (bar bottom is at 35px).
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
| `alt+1` / `alt+2` | Focus workspace 1 / 2 on monitor 0 |
| `alt+3` / `alt+4` | Focus workspace 3 / 4 on monitor 1 |
| `alt+shift+1..4` | Move window to the matching workspace/monitor |
| `ctrl+shift+q`, `alt+shift+z` | Close window |
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

`alt+p` is used for resizing rather than pause, so pause is `alt+shift+p` only.
Komorebi's Grid layout ignores `resize-axis`, so all resize keys call
`whkd/resize-grid.ps1`, which adjusts the focused workspace's grid column/row
ratios in small steps. The old `+`/`-` resize bindings are still available as
aliases. Stacking and the shortcuts overlay are also bound in `whkdrc`.

## Startup

- `Startup\komorebi.lnk` runs `komorebic-no-console start --whkd`, which starts
  Komorebi and whkd at logon.
- `Startup\yasb.lnk` starts the status bar.
- `whkd/watch-whkd.ps1` is launched by `Startup\watch-whkd.lnk` and restarts
  whkd if it exits mid-session (only once Komorebi is running), so hotkeys
  recover without a logout.

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
