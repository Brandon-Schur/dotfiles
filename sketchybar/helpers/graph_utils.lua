M = {}

M.update_graph = function(percentage_str, sketchybar_item, label_string)
  local percentage_int = tonumber(percentage_str)
  -- Ignore malformed values instead of erroring inside the event loop.
  if not percentage_int then
    return
  end
  sketchybar_item:push({ percentage_int / 100. })
  local color = COLORS.blue
  if percentage_int > 30 then
    if percentage_int < 60 then
      color = COLORS.yellow
    elseif percentage_int < 80 then
      color = COLORS.peach
    else
      color = COLORS.red
    end
  end
  sketchybar_item:set({
    graph = { color = color },
    label = { string = string.format("%s %s%%", label_string, percentage_str) },
  })
end

return M
