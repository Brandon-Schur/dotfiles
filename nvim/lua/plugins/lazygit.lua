-- lazygit.nvim: open the lazygit TUI in a Neovim floating window.
-- Requires the `lazygit` CLI — install via your system package manager:
--   macOS:  brew install lazygit
--   Linux:  brew install lazygit  OR  see https://github.com/jesseduffield/lazygit
--   Windows: scoop install lazygit  OR  winget install lazygit
-- Docs: https://github.com/kdheepak/lazygit.nvim

---@type LazySpec
return {
  "kdheepak/lazygit.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = {
    "LazyGit", "LazyGitConfig", "LazyGitCurrentFile",
    "LazyGitFilter", "LazyGitFilterCurrentFile",
  },
  keys = {
    { "<Leader>gg", "<Cmd>LazyGit<CR>",                desc = "LazyGit (repo)" },
    { "<Leader>gG", "<Cmd>LazyGitCurrentFile<CR>",     desc = "LazyGit (current file's repo)" },
    { "<Leader>gl", "<Cmd>LazyGitFilterCurrentFile<CR>", desc = "LazyGit: commits for current file" },
  },
  init = function()
    vim.g.lazygit_floating_window_scaling_factor = 0.9
    vim.g.lazygit_use_neovim_remote = 0
  end,
}
