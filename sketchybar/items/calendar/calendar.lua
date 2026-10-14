-- Padding item required because of bracket
SBAR.add("item", { position = "right", width = PADDINGS + 6 })

local cal_date = SBAR.add("item", {
  position = "right",
  padding_left = -5,
  width = 0,
  label = {
    color = COLORS.lavender,
    font = {
      size = 13.0,
    },
  },
  y_offset = 6,
})

local cal_time = SBAR.add("item", {
  position = "right",
  padding_left = -5,
  label = {
    color = COLORS.lavender,
    font = {
      size = 12.0,
    },
  },
  y_offset = -6,
})

-- Double border for calendar using a single item bracket
local cal_bracket = SBAR.add("bracket", { cal_date.name, cal_time.name }, {
  update_freq = 1,
})

-- Padding item required because of bracket
SBAR.add("item", { position = "right", width = PADDINGS })

cal_bracket:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal_date:set({ label = { string = os.date("%a %b %d") } })
  -- 12-hour clock; strip the leading zero from the hour (e.g. "1:05:03 PM").
  local time_str = os.date("%I:%M:%S %p"):gsub("^0", "")
  cal_time:set({ label = { string = time_str } })
end)

local function click_event()
  -- Open Outlook's calendar (deep link), falling back to just launching Outlook.
  SBAR.exec("open 'ms-outlook://calendar' 2>/dev/null || open -b com.microsoft.Outlook")
end

cal_date:subscribe("mouse.clicked", click_event)
cal_time:subscribe("mouse.clicked", click_event)
