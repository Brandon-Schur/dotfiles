-- Minimal AeroSpace workspace UI:
--   1) a box with the CURRENT workspace number
--   2) a box with the app icons of the windows on the current workspace
-- Both update on workspace change (aerospace_workspace_change event) and the
-- app-icons box also refreshes on a short timer to catch windows opening/closing.

local app_icons = require("helpers.spaces_util.app_icons")

local function get_current_workspace()
  local f = io.popen("aerospace list-workspaces --focused")
  local r = f:read("*a")
  f:close()
  return (r:gsub("%s+", ""))
end

local function icon_for(app)
  local glyph = app_icons[app]
  if glyph == nil then
    glyph = app_icons["default"]
  end
  return glyph
end

local Window_Manager = {
  events = {
    focus_change = "aerospace_workspace_change",
  },
}

local number_box = nil
local apps_box = nil

local function update_apps(ws)
  ws = (ws and ws ~= "") and ws or get_current_workspace()
  SBAR.exec("aerospace list-windows --workspace " .. ws .. " --format '%{app-name}'", function(out)
    local strip = ""
    if type(out) == "string" then
      for line in out:gmatch("[^\r\n]+") do
        local name = line:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then
          strip = strip .. " " .. icon_for(name)
        end
      end
    end
    if strip == "" then
      strip = "—"
    end
    if apps_box then
      apps_box:set({ label = strip })
    end
  end)
end

function Window_Manager:init()
  -- Current workspace number
  number_box = SBAR.add("item", "workspace.current", {
    position = "left",
    padding_left = 6,
    padding_right = 4,
    icon = {
      string = get_current_workspace(),
      font = { family = FONT.label_font, style = FONT.style_map["Bold"], size = 15.0 },
      color = COLORS.lavender,
      padding_left = 12,
      padding_right = 12,
    },
    label = { drawing = false },
    background = {
      color = COLORS.surface0,
      border_color = COLORS.lavender,
      border_width = 2,
      corner_radius = 6,
      height = 26,
    },
  })

  -- App icons on the current workspace
  apps_box = SBAR.add("item", "workspace.apps", {
    position = "left",
    padding_left = 4,
    padding_right = 6,
    icon = { drawing = false },
    label = {
      string = "—",
      font = "sketchybar-app-font:Regular:16.0",
      color = COLORS.text,
      padding_left = 12,
      padding_right = 12,
    },
    background = {
      color = COLORS.surface0,
      border_color = COLORS.surface1,
      border_width = 2,
      corner_radius = 6,
      height = 26,
    },
  })

  number_box:subscribe(self.events.focus_change, function(env)
    local ws = env and env.FOCUSED_WORKSPACE
    if not ws or ws == "" then
      ws = get_current_workspace()
    end
    number_box:set({ icon = { string = ws } })
    update_apps(ws)
  end)

  -- Click the number box to cycle workspaces (right-click = previous).
  number_box:subscribe("mouse.clicked", function(env)
    if env and env.BUTTON == "right" then
      SBAR.exec("aerospace workspace --wrap-around prev")
    else
      SBAR.exec("aerospace workspace --wrap-around next")
    end
  end)

  -- initial population
  update_apps()
end

function Window_Manager:start_watcher()
  -- Refresh app icons periodically so windows opened/closed on the current
  -- workspace are reflected without a workspace switch.
  local watcher = SBAR.add("item", "workspace.apps.watcher", {
    drawing = false,
    updates = true,
    update_freq = 3,
  })
  watcher:subscribe("routine", function()
    update_apps()
  end)
end

return Window_Manager
