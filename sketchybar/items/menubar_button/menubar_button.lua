-- Button that swaps SketchyBar out for the native macOS menu bar. SketchyBar
-- comes back once the mouse leaves the menu bar (see helpers/menubar_toggle).
local toggle = HELPERS_HOME .. "menubar_toggle/bin/menubar_toggle"

SBAR.add("item", "menubar_button", {
  position = "right",
  icon = {
    string = "󰍜", -- nf-md-menu
    color = COLORS.lavender,
    font = { size = 20.0 },
    padding_left = 6,
    padding_right = 6,
  },
  label = { drawing = false },
  -- Detach so the watcher keeps running after the click handler returns.
  -- ("[m]" keeps pkill -f from matching this shell's own command line.)
  click_script = "pkill -f '[m]enubar_toggle native' 2>/dev/null; nohup '"
    .. toggle
    .. "' native >/dev/null 2>&1 &",
})
