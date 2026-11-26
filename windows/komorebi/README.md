# Komorebi

- `komorebi.json` — static configuration (`%USERPROFILE%\komorebi.json`).
- `patch-applications.ps1` — run after `komorebic fetch-app-specific-configuration`.

```powershell
powershell -ExecutionPolicy Bypass -File .\patch-applications.ps1
```

The upstream `applications.json` marks Spotify as a `tray_and_multi_window` app,
which leaves a minimized Spotify window occupying a tile (an empty half of the
monitor). The patch removes just that rule so Spotify tiles normally when open
and drops out of the layout when minimized. It is safe to run repeatedly.
