-- Catppuccin colorscheme (installed alongside Tokyo Night so you can switch).
-- Active colorscheme is set in lua/plugins/colorscheme.lua.
-- Docs: https://github.com/catppuccin/nvim

---@type LazySpec
return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  ---@type CatppuccinOptions
  opts = {
    flavour = "macchiato",   -- latte | frappe | macchiato | mocha
    background = { light = "latte", dark = "macchiato" },
    term_colors = true,
    integrations = {
      cmp = true,
      gitsigns = true,
      treesitter = true,
      mason = true,
      native_lsp = { enabled = true },
      diffview = true,
      which_key = true,
    },
  },
}
