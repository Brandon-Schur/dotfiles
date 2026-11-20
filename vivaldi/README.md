# Vivaldi

Vivaldi UI tweaks. Tabs use Vivaldi's own vertical tab bar, workspaces, and
tab stacks (Accordion style) for groups.

## Files

| File | Where it goes | What it does |
|---|---|---|
| `mods/Import.css` | Vivaldi CSS mods folder | Entry point; `@import`s the other files |
| `mods/HidePanelBar.css` | Vivaldi CSS mods folder | Hides the vertical panel icon strip |
| `mods/StackFolders.css` | Vivaldi CSS mods folder | Accordion tab stacks look like folders: folder icon and bold name on the header, indented tabs with a guide line, quieter expand/collapse strip. Needs Tab Stacking set to Accordion and a left/right tab bar |
| `js/StackFolderClick.js` | Inside Vivaldi.app (via `~/VivaldiMods/reapply.sh`) | Left-click on a stack header expands/collapses it instead of switching to its tab; Alt+drag moves the stack |
| `js/TabBarAutoCollapse.js` | Inside Vivaldi.app (via `~/VivaldiMods/reapply.sh`) | Makes "Expand Tab Bar on Hover" collapse about 1 s after the cursor moves onto the page (macOS often misses that exit, leaving the bar open) |
| `reapply.sh` | `~/VivaldiMods/` | Puts the JS mods back into Vivaldi.app after updates |

## Install

1. Copy `mods/` to a folder of your choice (e.g. `~/VivaldiMods/`).
2. Vivaldi → Settings → Appearance → Custom UI Modifications → select that folder.
3. Quit Vivaldi completely (Cmd+Q) and reopen it. CSS mods only reload on a full restart.

## Caveats

- Vivaldi's Panel Toggle command shows the panel icon strip again.
