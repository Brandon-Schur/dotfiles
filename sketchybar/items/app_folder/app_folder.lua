-- A "folder" of specific apps I care about, shown as launcher items with real
-- app icons. This is NOT menu-bar aliasing (which macOS 26 blocks) — each item
-- launches/activates the app on click. Cisco VPN additionally shows a live
-- connected (green) / disconnected (red) status border.

local ICON_DIR = (os.getenv("HOME") or "~") .. "/.config/sketchybar/items/app_folder/icons/"

-- key, label, bundle id, image (or glyph), optional custom left `click`, and a
-- `right`-click action. NOTE: macOS doesn't allow triggering an app's real
-- menu-bar context menu from here, so right-click runs a useful secondary
-- action instead (quit for most; VPN disconnect; AeroSpace opens the app so we
-- never quit the window manager).
local APPS = {
  { key = "vpn", label = "Cisco VPN", bundle = "com.cisco.secureclient.gui", image = ICON_DIR .. "cisco.png", vpn = true,
    right = "/opt/cisco/secureclient/bin/vpn disconnect" },
  { key = "zoom", label = "Zoom", bundle = "us.zoom.xos", image = ICON_DIR .. "zoom.png",
    right = "osascript -e 'quit app id \"us.zoom.xos\"'" },
  -- Shottr's icon lives in Assets.car (not extractable), so use a Nerd Font camera glyph.
  { key = "shottr", label = "Shottr", bundle = "cc.ffitch.shottr", glyph = "\239\128\176", -- U+F030
    right = "osascript -e 'quit app id \"cc.ffitch.shottr\"'" },
  { key = "betterdisplay", label = "BetterDisplay", bundle = "pro.betterdisplay.BetterDisplay", image = ICON_DIR .. "betterdisplay.png",
    right = "osascript -e 'quit app id \"pro.betterdisplay.BetterDisplay\"'" },
  { key = "displaylink", label = "DisplayLink", bundle = "com.displaylink.DisplayLinkUserAgent", image = ICON_DIR .. "displaylink.png",
    right = "osascript -e 'quit app id \"com.displaylink.DisplayLinkUserAgent\"'" },
  { key = "aerospace", label = "AeroSpace", bundle = "bobko.aerospace", image = ICON_DIR .. "aerospace.png",
    click = "aerospace reload-config", right = "open -b bobko.aerospace" },
}

-- Folder anchor with a horizontal popup holding the app launchers.
local folder = SBAR.add("item", "app_folder.anchor", {
  position = "right",
  icon = {
    string = "\239\129\187", -- Nerd Font folder U+F07B
    color = COLORS.lavender,
    font = { size = 16.0 },
  },
  label = { drawing = false },
  padding_left = PADDINGS,
  padding_right = PADDINGS,
  popup = { horizontal = true, align = "center" },
})

local popup_pos = "popup." .. folder.name
local vpn_item = nil

for _, app in ipairs(APPS) do
  local props = {
    position = popup_pos,
    label = { drawing = false },
    padding_left = 6,
    padding_right = 6,
    width = 34,
    background = {
      drawing = true,
      color = 0x00000000,
      corner_radius = 6,
      border_width = 0,
    },
  }

  if app.image then
    props.icon = { drawing = false }
    props.background.image = { string = app.image, scale = 0.5, drawing = true }
  else
    props.icon = { string = app.glyph or "?", color = COLORS.text, font = { size = 16.0 } }
  end

  if app.vpn then
    props.background.border_width = 2
    props.background.border_color = COLORS.grey -- until first status check
  end

  local it = SBAR.add("item", "app_folder." .. app.key, props)
  local left_action = app.click or ("open -b " .. app.bundle)

  it:subscribe("mouse.clicked", function(env)
    if env and env.BUTTON == "right" and app.right then
      SBAR.exec(app.right)
    else
      SBAR.exec(left_action)
    end
    folder:set({ popup = { drawing = false } }) -- close folder after acting
  end)

  if app.vpn then
    vpn_item = it
  end
end

-- Toggle the folder open/closed.
folder:subscribe("mouse.clicked", function()
  folder:set({ popup = { drawing = "toggle" } })
end)

-- Live Cisco VPN status: green border = connected, red = disconnected.
if vpn_item then
  local function refresh_vpn()
    -- `timeout` comes from coreutils (gnubin is on PATH); guards against a hang.
    SBAR.exec("timeout 3 /opt/cisco/secureclient/bin/vpn state 2>/dev/null | tr '\\n' ' '", function(out)
      if type(out) ~= "string" then
        return
      end
      local low = out:lower()
      local connected = low:find("connected", 1, true) ~= nil and low:find("disconnected", 1, true) == nil
      vpn_item:set({ background = { border_color = connected and COLORS.green or COLORS.red } })
    end)
  end

  local vpn_watch = SBAR.add("item", "app_folder.vpnwatch", {
    drawing = false,
    updates = true,
    update_freq = 15,
  })
  vpn_watch:subscribe("routine", refresh_vpn)
  refresh_vpn()
end

return folder
