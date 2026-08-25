-- Custom key mappings via AstroCore (integrates with which-key).
-- Docs: https://docs.astronvim.com/configuration/mappings/

---@type LazySpec
return {
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          -- Buffer navigation
          ["<Tab>"]   = { "<Cmd>bnext<CR>",     desc = "Next buffer",     noremap = true },
          ["<S-Tab>"] = { "<Cmd>bprevious<CR>", desc = "Previous buffer", noremap = true },
          -- Window navigation
          ["<Leader><Left>"]  = { "<C-w>h", desc = "Move to left window" },
          ["<Leader><Right>"] = { "<C-w>l", desc = "Move to right window" },
        },
        v = {
          -- Yank selection to system clipboard
          ["<C-c>"] = { '"+y', desc = "Yank to system clipboard", noremap = true, silent = true },
        },
      },
    },
  },
}
