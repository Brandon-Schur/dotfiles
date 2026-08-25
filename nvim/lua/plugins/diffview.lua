-- diffview.nvim: diff viewer, file history, and merge-conflict resolution.
-- Docs: https://github.com/sindrets/diffview.nvim

---@type LazySpec
return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = {
    "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles",
    "DiffviewFocusFiles", "DiffviewRefresh", "DiffviewFileHistory",
  },
  keys = {
    { "<Leader>gd", "<Cmd>DiffviewOpen<CR>",            desc = "Diffview: open (working tree)" },
    { "<Leader>gD", "<Cmd>DiffviewClose<CR>",           desc = "Diffview: close" },
    { "<Leader>gh", "<Cmd>DiffviewFileHistory %<CR>",   desc = "Diffview: file history (current file)" },
    { "<Leader>gH", "<Cmd>DiffviewFileHistory<CR>",     desc = "Diffview: repo history" },
    { "<Leader>gh", ":'<,'>DiffviewFileHistory<CR>", mode = "v", desc = "Diffview: history (selection)" },
  },
  opts = {
    enhanced_diff_hl = true,
    view = {
      merge_tool = { layout = "diff3_mixed", disable_diagnostics = true },
    },
  },
  config = function(_, opts) require("diffview").setup(opts) end,
}
