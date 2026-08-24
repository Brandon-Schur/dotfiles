-- Tokyo Night colorscheme.
-- Active flavor is set in lua/plugins/colorscheme.lua.
-- Docs: https://github.com/folke/tokyonight.nvim

---@type LazySpec
return {
  "folke/tokyonight.nvim",
  lazy = false,
  priority = 1000,
  ---@type tokyonight.Config
  opts = {
    style = "storm",         -- storm | night | moon | day
    terminal_colors = true,
  },
}
