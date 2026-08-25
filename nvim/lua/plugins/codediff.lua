-- codediff.nvim: VSCode-style diff viewer (side-by-side/inline, git integration,
-- file history, merge-conflict resolution). Auto-downloads a prebuilt C binary
-- on first use — no compiler needed.
-- Docs: https://github.com/esmuellert/codediff.nvim

---@type LazySpec
return {
  "esmuellert/codediff.nvim",
  cmd = "CodeDiff",
  keys = {
    { "<Leader>gv", "<Cmd>CodeDiff<CR>",         desc = "CodeDiff: changed files (git)" },
    { "<Leader>gV", "<Cmd>CodeDiff history<CR>", desc = "CodeDiff: commit history" },
  },
  opts = {},
}
