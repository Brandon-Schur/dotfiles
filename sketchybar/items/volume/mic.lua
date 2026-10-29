-- Microphone (input) volume + input device picker.
-- Sits immediately left of the speaker (widgets.volume) item.
-- macOS has no input-volume event, so the level is polled (and refreshed on interaction).
local popup_width = 240

-- Virtual/loopback inputs that shouldn't be picked as the system default mic.
-- "Preferred Mic" and "Meeting Capture" are published by audio-priority/Loopback and
-- wrap the default input, so selecting them would feed the device back into itself.
local hidden_inputs = {
  "BlackHole",
  "Preferred Mic",
  "Meeting Capture",
  "Loopback",
  "ZoomAudioDevice",
  "Microsoft Teams Audio",
  "Hue Sync Audio",
}

local function is_hidden(device)
  for _, pattern in ipairs(hidden_inputs) do
    if device:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

local mic_icon = SBAR.add("item", "widgets.mic", {
  position = "right",
  update_freq = 300,
  icon = {
    string = ICONS.mic.on,
    width = 0,
    align = "left",
    color = COLORS.yellow,
  },
  label = {
    width = 25,
    align = "left",
    color = COLORS.yellow,
  },
})

local mic_slider = SBAR.add("slider", popup_width, {
  position = "popup." .. mic_icon.name,
  background = { color = COLORS.base, height = 2, y_offset = -20 },
  click_script = 'osascript -e "set volume input volume $PERCENTAGE" && sketchybar --trigger mic_change',
})

local function mic_update()
  SBAR.exec('osascript -e "input volume of (get volume settings)"', function(result)
    local volume = tonumber(tostring(result):match("%d+"))
    if not volume then
      return
    end
    mic_icon:set({ icon = volume > 0 and ICONS.mic.on or ICONS.mic.off })
    mic_slider:set({ slider = { percentage = volume } })
  end)
end

SBAR.add("event", "mic_change")
mic_icon:subscribe({ "routine", "forced", "system_woke", "mic_change" }, mic_update)

local function mic_collapse_details()
  if mic_icon:query().popup.drawing ~= "on" then
    return
  end
  mic_icon:set({ popup = { drawing = false } })
  SBAR.remove("/mic.device\\..*/")
end

local function mic_toggle_details(env)
  if env.BUTTON == "right" then
    SBAR.exec("open 'x-apple.systempreferences:com.apple.Sound-Settings.extension?input'")
    return
  end

  if mic_icon:query().popup.drawing == "on" then
    mic_collapse_details()
    return
  end

  mic_icon:set({ popup = { drawing = true } })
  mic_update()
  SBAR.exec("SwitchAudioSource -t input -c", function(result)
    local current = tostring(result):gsub("%s+$", "")
    SBAR.exec("SwitchAudioSource -a -t input", function(available)
      local counter = 0
      for device in string.gmatch(available, "[^\r\n]+") do
        if not is_hidden(device) or device == current then
          SBAR.add("item", "mic.device." .. counter, {
            position = "popup." .. mic_icon.name,
            width = popup_width,
            align = "center",
            label = {
              string = device,
              color = device == current and COLORS.text or COLORS.grey,
              font = { size = 13.0 },
            },
            click_script = 'SwitchAudioSource -t input -s "'
                .. device
                .. '" && sketchybar --set /mic.device\\..*/ label.color='
                .. COLORS.grey
                .. " --set $NAME label.color="
                .. COLORS.text
                .. " --trigger mic_change",
          })
          counter = counter + 1
        end
      end
    end)
  end)
end

local function mic_scroll(env)
  local delta = env.INFO.delta
  if env.INFO.modifier ~= "ctrl" then
    delta = delta * 10.0
  end
  SBAR.exec('osascript -e "set volume input volume (input volume of (get volume settings) + ' .. delta .. ')"',
    mic_update)
end

mic_icon:subscribe("mouse.clicked", mic_toggle_details)
mic_icon:subscribe("mouse.scrolled", mic_scroll)
