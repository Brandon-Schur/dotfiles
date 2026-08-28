-- Dynamic "folder" of macOS menu-bar extras, aliased into SketchyBar.
--
-- REQUIREMENT: SketchyBar must be granted Screen Recording permission
--   (System Settings > Privacy & Security > Screen Recording).
--   Without it, `default_menu_items` returns nothing and the folder is empty.
--
-- Behavior: a folder/chevron item on the right. Click it to expand a
-- horizontal popup that shows a live alias (mirror) of each third-party
-- menu-bar item. It re-scans on a timer and on app switches, so items you
-- add/remove appear/disappear automatically (no config edits needed).
--
-- Note: Control Center / system items (Wi-Fi, battery, sound, Bluetooth,
-- display, clock, ...) generally cannot be aliased on modern macOS and are
-- denied below; this config already renders Wi-Fi/volume/battery/clock.

local REFRESH_FREQ = 10 -- seconds between background re-scans

-- Never alias these (system/Control Center items that don't mirror on modern
-- macOS, plus ones already rendered natively by this config).
local DENY = {
  ["Clock"] = true,
  ["Control Center"] = true,
  ["ControlCenter"] = true,
  ["BentoBox"] = true,
  ["WiFi"] = true,
  ["Wi-Fi"] = true,
  ["Battery"] = true,
  ["Sound"] = true,
  ["Volume"] = true,
  ["Bluetooth"] = true,
  ["NowPlaying"] = true,
  ["Now Playing"] = true,
  ["AudioVideoModule"] = true,
  ["FocusModes"] = true,
  ["ScreenMirroring"] = true,
  ["Display"] = true,
  ["UserSwitcher"] = true,
  ["Siri"] = true,
  ["Spotlight"] = true,
  ["TextInput"] = true,
  ["KeyboardBrightness"] = true,
  ["WindowManagement"] = true,
  ["items"] = true, -- guard in case the query is wrapped in an object
}

-- Folder anchor with a horizontal popup that holds the aliases.
local folder = SBAR.add("item", "menu_extras.folder", {
  position = "right",
  icon = {
    -- Nerd Font folder glyph (U+F07B). Change if it renders as a box.
    string = "\239\129\187",
    color = COLORS.lavender,
    font = { size = 16.0 },
  },
  label = { drawing = false },
  padding_left = PADDINGS,
  padding_right = PADDINGS,
  popup = {
    horizontal = true,
    align = "center",
  },
})

local popup_pos = "popup." .. folder.name

-- Raw menu-item names we've created aliases for (so we can tear them down).
local created = {}
local last_sig = nil

-- Extract quoted strings from the `default_menu_items` query output.
local function parse_names(s)
  local names = {}
  for tok in s:gmatch('"(.-)"') do
    table.insert(names, tok)
  end
  return names
end

local function rebuild(kept)
  -- tear down existing aliases
  for _, name in ipairs(created) do
    pcall(function()
      SBAR.remove(name)
    end)
  end
  created = {}

  for _, name in ipairs(kept) do
    local ok = pcall(function()
      SBAR.add("alias", name, {
        position = popup_pos,
        click_script = "", -- clicking the alias forwards to the real item
        label = { drawing = false },
        background = { drawing = false },
        padding_left = 4,
        padding_right = 4,
      })
    end)
    if ok then
      table.insert(created, name)
    end
  end
end

local function discover()
  SBAR.exec("sketchybar --query default_menu_items", function(result)
    if not result or result == "" then
      return
    end
    local names = parse_names(result)
    -- filter
    local kept = {}
    for _, name in ipairs(names) do
      if type(name) == "string" and name ~= "" and not DENY[name] then
        table.insert(kept, name)
      end
    end
    -- only rebuild when the set actually changed (avoids flicker)
    table.sort(kept)
    local sig = table.concat(kept, "|")
    if sig == last_sig then
      return
    end
    last_sig = sig
    pcall(rebuild, kept)
  end)
end

folder:subscribe("mouse.clicked", function()
  folder:set({ popup = { drawing = "toggle" } })
end)

-- Re-scan when the frontmost app changes (apps often add/remove menu items).
folder:subscribe("front_app_switched", function()
  discover()
end)

-- Background re-scan on a timer, so add/remove is picked up even without a
-- focus change.
local watcher = SBAR.add("item", "menu_extras.watcher", {
  drawing = false,
  updates = true,
  update_freq = REFRESH_FREQ,
})
watcher:subscribe("routine", function()
  discover()
end)

-- Initial population (async; safe if permission is missing -> empty folder).
discover()

return folder
