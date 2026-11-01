# Vivaldi + Sharp Tabs

Vivaldi UI tweaks for using the [Sharp Tabs](https://github.com/maddada/sharptabs)
extension as a vertical tab sidebar, themed with the bschur_custom palette.

The sidebar auto-hides to a narrow rail. Collapsed, it still shows each tab's
favicon and the start of its title, and each tab group as a colored pill with
the start of its name and its tab count. Hovering opens the full panel over the
page, with every tab at the same height in both states so the one under the
cursor stays under the cursor.

## Files

| File | Where it goes | What it does |
|---|---|---|
| `mods/Import.css` | Vivaldi CSS mods folder | Entry point; `@import`s the other files |
| `mods/HidePanelBar.css` | Vivaldi CSS mods folder | Hides the vertical panel icon strip |
| `mods/SharpTabsAutoHide.css` | Vivaldi CSS mods folder | Collapses the side panel to a rail, expands on hover, removes the web panel toolbar |
| `sharptabs/bschur_custom.css` | Sharp Tabs → Settings → Advanced → Custom CSS | Palette, plus the compact "Rail mode" layout used while collapsed |

`Import.css` also imports `VividPeek.css` from
[Awesome-Vivaldi](https://github.com/PaRr0tBoY/Awesome-Vivaldi), which isn't
included here. Remove that line if you don't use it.

## Install

1. Copy `mods/` to a folder of your choice (e.g. `~/VivaldiMods/`).
2. Vivaldi → Settings → Appearance → Custom UI Modifications → select that folder.
   On older versions, enable `vivaldi://experiments` → "Allow CSS modifications" first.
3. Open Sharp Tabs as a side panel, then paste `sharptabs/bschur_custom.css`
   into Sharp Tabs → Settings → Advanced → Custom CSS and enable it.
4. Quit Vivaldi completely (Cmd+Q) and reopen it. CSS mods only reload on a
   full restart; the Sharp Tabs CSS applies immediately.

## Tuning

- Collapsed and expanded widths, and the hover delays: the `--st-*` variables
  at the top of `SharpTabsAutoHide.css`.
- Item width inside the rail: `--rail` / `--rail-gap` in the Rail mode section
  of `bschur_custom.css`. Keep `--rail + 2 * --rail-gap` close to `--st-rail`.
- Rail mode turns on at a page width of 160px or less. It also overrides Sharp
  Tabs' own narrow mode (84px or less), which would otherwise hide titles and
  group names.

## Caveats

- Drag-resizing the panel no longer works; change `--st-expanded` instead.
- The panel collapses as soon as the mouse leaves, even with a Sharp Tabs menu open.
- Compact pinned tabs fit fewer icons per row in the rail, so rows below them
  shift slightly between collapsed and expanded.
- Vivaldi's Panel Toggle command turns the auto-hide off (the panel stays open
  and the icon strip comes back).
