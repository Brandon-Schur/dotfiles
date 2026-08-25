-- tokyonight.nvim colorscheme, installed via lazy.nvim.
-- This file installs the plugin AND applies a custom "bschur_custom" palette on
-- top of the `storm` style. The ACTIVE colorscheme is still selected in
-- lua/plugins/colorscheme.lua (keep it as "tokyonight-storm").
-- Docs: https://github.com/folke/tokyonight.nvim
--
-- ── bschur_custom theme ─────────────────────────────────────────────────────
-- Cool near-black backgrounds, blue-gray neutrals, a royal-blue primary accent
-- (#1a6ce7 / #5999f8) and a brand cyan (#29b5e8). Layered onto tokyonight's
-- `storm` engine via `on_colors` so all of tokyonight's derived colors (diffs,
-- borders, terminal, visual) stay coherent.
--
-- To revert to stock storm: delete the `on_colors`/`on_highlights` lines below
-- (or the whole `bschur_custom` block). To try a light variant, set style = "day"
-- and swap in the light values noted at the bottom of this file.

-- bschur_custom dark-mode source colors.
local bschur_custom = {
  -- Backgrounds (cool, near-black → charcoal)
  bg = "#1e252f", -- main editor background (docs dark scrollbar track / surface)
  bg_dark = "#191e24", -- darkest: sidebars, statusline, floats, popups
  bg_dark1 = "#12171c", -- even darker (used by some borders)
  bg_highlight = "#2c2f34", -- cursorline / current-line surface

  -- Foregrounds & muted blue-grays
  fg = "#dee3ea", -- primary text (near-white, cool)
  fg_dark = "#bdc4d5", -- secondary text
  fg_gutter = "#3a4453", -- inactive gutter / whitespace
  comment = "#5d6a85", -- comments (docs muted blue-gray)
  dark3 = "#70819a", -- muted
  dark5 = "#8a96ad", -- muted (docs secondary text)

  -- Blues & cyans (the signature accents)
  blue = "#5999f8", -- primary readable accent → functions
  blue0 = "#1a6ce7", -- docs primary royal blue → search/visual base
  blue1 = "#29b5e8", -- brand cyan → border highlight
  blue2 = "#249edc", -- docs blue-primary → info
  blue5 = "#93c5fd", -- light blue
  blue6 = "#d6e6ff", -- very light blue fill
  blue7 = "#1f2c4a", -- deep navy → diff-change / selection base
  cyan = "#5cc6ef", -- brightened brand cyan

  -- Keyword hues: gentle indigo/violet so code stays readable (not mono-blue)
  purple = "#8f7bea",
  magenta = "#b48ef0",
  magenta2 = "#e0559a",

  -- Greens / teal (docs emerald family)
  green = "#34d399", -- strings
  green1 = "#5be0b8",
  green2 = "#10b981", -- docs green → diff-add base
  teal = "#2dd4bf", -- hints

  -- Amber / orange (docs warning amber)
  yellow = "#fccf54",
  orange = "#f0a35e",

  -- Reds (docs error/pink family)
  red = "#f76a86", -- warm pink-red, easy on dark
  red1 = "#ef405e", -- error / diff-delete base

  terminal_black = "#374151", -- docs dark border

  git = {
    add = "#10b981",
    change = "#5999f8",
    delete = "#ef405e",
  },
}

---@type LazySpec
return {
  "folke/tokyonight.nvim",
  lazy = false, -- a colorscheme should be available at startup
  priority = 1000, -- ...and load before other UI plugins
  ---@type tokyonight.Config
  opts = {
    style = "storm", -- storm, night, moon, day
    terminal_colors = true, -- color the built-in :terminal

    -- Remap the storm palette to the bschur_custom dark palette. tokyonight then
    -- derives borders, diffs, visual, search and terminal colors from these.
    ---@param c ColorScheme
    on_colors = function(c)
      local util = require "tokyonight.util"
      for key, value in pairs(bschur_custom) do
        c[key] = value
      end

      -- IMPORTANT: tokyonight computes these derived colors from the ORIGINAL
      -- palette *before* on_colors runs, so they'd otherwise keep stock storm's
      -- blueish navy (#1f2335) — this is what tinted the neo-tree panel. Re-derive
      -- them from the bschur_custom base values now.
      c.bg_sidebar = c.bg_dark -- neo-tree & other sidebars
      c.bg_popup = c.bg_dark
      c.bg_statusline = c.bg_dark
      c.bg_float = c.bg_dark
      c.fg_sidebar = c.fg_dark
      c.fg_float = c.fg
      c.black = util.blend_bg(c.bg, 0.8, "#000000")
      c.border = c.black
      c.border_highlight = util.blend_bg(c.blue1, 0.8)
      c.bg_visual = util.blend_bg(c.blue0, 0.4)
      c.bg_search = c.blue0

      -- The :terminal palette is also built before on_colors — remap it too.
      if c.terminal then
        c.terminal.black, c.terminal.black_bright = c.black, c.terminal_black
        c.terminal.red, c.terminal.red_bright = c.red, util.brighten(c.red)
        c.terminal.green, c.terminal.green_bright = c.green, util.brighten(c.green)
        c.terminal.yellow, c.terminal.yellow_bright = c.yellow, util.brighten(c.yellow)
        c.terminal.blue, c.terminal.blue_bright = c.blue, util.brighten(c.blue)
        c.terminal.magenta, c.terminal.magenta_bright = c.magenta, util.brighten(c.magenta)
        c.terminal.cyan, c.terminal.cyan_bright = c.cyan, util.brighten(c.cyan)
        c.terminal.white, c.terminal.white_bright = c.fg_dark, c.fg
      end
    end,

    -- A few touch-ups to reinforce the accent identity.
    ---@param hl tokyonight.Highlights
    ---@param c ColorScheme
    on_highlights = function(hl, c)
      -- Royal-blue search, cool selection.
      hl.Search = { bg = c.blue0, fg = c.fg }
      hl.IncSearch = { bg = c.blue1, fg = c.bg }
      hl.CurSearch = { bg = c.blue1, fg = c.bg }
      -- Current line number in accent blue.
      hl.CursorLineNr = { fg = c.blue, bold = true }
      -- Cyan window/float borders (matches docs' blue-tinted rules).
      hl.FloatBorder = { fg = c.blue1, bg = c.bg_float }
      hl.WinSeparator = { fg = c.terminal_black, bold = true }
      -- Visual selection: muted royal blue.
      hl.Visual = { bg = c.bg_visual }
    end,
  },
}

-- ── Light "day" variant (optional) ──────────────────────────────────────────
-- If you prefer the docs' primary light look (white bg, #1a6ce7 links), set
-- style = "day" above, point colorscheme.lua at "tokyonight-day", and use
-- these values in the `bschur_custom` table instead:
--   bg = "#ffffff", bg_dark = "#f7f7f7", bg_highlight = "#eef2f8",
--   fg = "#2c2f34", fg_dark = "#5d6a85", comment = "#8a96ad",
--   blue = "#1a6ce7", blue0 = "#004cbe", blue1 = "#249edc", blue2 = "#1a6ce7",
--   green2 = "#047857", red1 = "#d3132f", yellow = "#ecb700"
