require("settings")
SBAR = require("sketchybar")
LOG = require("helpers.debug_info")
COLORS = require("themes.init")
ICONS = require("icons")
GRAPH_UTILS = require("helpers.graph_utils")
SBAR.begin_config()

local preset_conf = PRESET_OPTIONS[PRESET] or PRESET_OPTIONS["gnix"]

SBAR.bar({
  color = COLORS.base,
  height = preset_conf.HEIGHT,
  border_width = preset_conf.BORDER_WIDTH,
  border_color = COLORS.surface0,
  corner_radius = preset_conf.CORNER_RADIUS,
  blur_radius = 15,
  shadow = { drawing = true },
  sticky = true,
  font_smoothing = true,
  padding_right = PADDINGS,
  padding_left = PADDINGS,
  y_offset = preset_conf.Y_OFFSET,
  margin = preset_conf.MARGIN,
  notch_width = 200,
  -- Render above the native menu bar. Required by sketchybar-toggle so the bar
  -- isn't drawn behind the menu bar. ("window" is distinct from "on".)
  topmost = "window",
  -- Draw only on the macOS Main display (your laptop). Using "main" instead of a
  -- numeric index keeps the bar on the laptop even when monitors are plugged in
  -- and macOS reshuffles display indices.
  display = "main",
})

-- Coordinate with the native menu bar: hide SketchyBar when the mouse nears the
-- top so the menu bar appears cleanly (no overlap), then slide it back.
-- Requires the sketchybar-toggle binary (brew install malpern/tap/sketchybar-toggle).
SBAR.exec("pkill -x sketchybar-toggle 2>/dev/null; command -v sketchybar-toggle >/dev/null 2>&1 && sketchybar-toggle --debounce 30 >/tmp/sketchybar-toggle.log 2>&1 &")

SBAR.default({
  updates = "when_shown",
  padding_left = PADDINGS,
  padding_right = PADDINGS,
  icon = {
    font = { family = FONT.icon_font, style = FONT.style_map["Bold"], size = 19.0 },
    color = COLORS.text,
    padding_left = PADDINGS,
    padding_right = PADDINGS,
    background = { image = { corner_radius = 9 } },
  },
  label = {
    font = { family = FONT.label_font, style = FONT.style_map["Bold"], size = 15.0 },
    color = COLORS.text,
    padding_left = PADDINGS,
    padding_right = PADDINGS,
    shadow = { drawing = false },
  },
  background = {
    height = 34,
    corner_radius = 9,
    border_width = 2,
    border_color = COLORS.surface1,
    image = { corner_radius = 9, border_color = COLORS.grey, border_width = 1 },
  },
  popup = {
    background = {
      border_width = 2,
      corner_radius = 9,
      border_color = COLORS.surface0,
      color = COLORS.base,
      shadow = { drawing = true },
    },
    blur_radius = 50,
    align = "center",
  },
  slider = {
    background = {
      height = 6,
      corner_radius = 3,
      color = COLORS.surface1,
    },
    highlight_color = COLORS.blue,
    knob = {
      string = "􀀁",
      drawing = true,
      color = COLORS.lavender,
    },
  },
  scroll_texts = true,
})

-- Use an absolute path: SketchyBar reloads triggered by launchd or the
-- sketchybar-toggle daemon run with a minimal PATH that lacks /opt/homebrew/bin,
-- so a bare `stats_provider` restart fails silently and the CPU/RAM counters
-- freeze. `pkill -x` avoids killing unrelated processes.
local STATS_PROVIDER_CMD =
  "/opt/homebrew/bin/stats_provider --cpu usage --memory ram_usage --network en0 --interval 1 --no-units >/dev/null 2>&1 &"

SBAR.exec("pkill -x stats_provider >/dev/null 2>&1; " .. STATS_PROVIDER_CMD, function()
  LOG:info("Started stats_provider_rust")
end)

-- Watchdog: stats_provider can die or stop emitting (e.g. around sleep/wake)
-- while SketchyBar keeps running, which freezes the CPU/RAM/network widgets.
-- The launch above also doesn't reliably survive `sketchybar --reload`.
-- At startup, every 10s, and on wake: relaunch it if it's not running, and
-- force-restart it if no system_stats event has arrived for 15s (hung).
local STATS_STALE_SECS = 15
local last_stats_at = os.time()

local stats_watchdog = SBAR.add("item", "stats_provider.watchdog", {
  drawing = false,
  updates = "on",
  update_freq = 10,
})

stats_watchdog:subscribe("system_stats", function()
  last_stats_at = os.time()
end)

stats_watchdog:subscribe({ "forced", "routine", "system_woke" }, function()
  if os.time() - last_stats_at > STATS_STALE_SECS then
    LOG:info("stats_provider stale; restarting")
    last_stats_at = os.time()
    SBAR.exec("pkill -x stats_provider >/dev/null 2>&1; " .. STATS_PROVIDER_CMD)
  else
    SBAR.exec("pgrep -x stats_provider >/dev/null 2>&1 || { " .. STATS_PROVIDER_CMD .. " }")
  end
end)

require("items")

SBAR.end_config()
SBAR.event_loop()
