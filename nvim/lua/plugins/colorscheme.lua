-- Active default colorscheme selector.
--
-- >>> To change your default colorscheme, edit the one string below. <<<
-- Available values (both theme plugins are installed):
--   tokyonight, tokyonight-storm, tokyonight-night, tokyonight-moon, tokyonight-day
--   catppuccin, catppuccin-macchiato, catppuccin-mocha, catppuccin-frappe, catppuccin-latte
--   astrodark (AstroNvim default)

---@type LazySpec
return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  opts = {
    colorscheme = "tokyonight-storm",
  },
}
