-- vim-rooter: auto-changes cwd to the project root when opening a file.
-- Docs: https://github.com/airblade/vim-rooter
--
-- NOTE: Only list markers that reliably sit at a *project root*.
-- Avoid Makefile/package.json — those appear in subdirectories and cause
-- rooter to stop too early.

---@type LazySpec
return {
  "airblade/vim-rooter",
  lazy = false,
  init = function()
    vim.g.rooter_patterns = {
      ".git",        -- git repo root
      "Cargo.toml",  -- Rust workspace
      ".svn",
      ".hg",
      -- Add project-specific root markers here, e.g.:
      -- "pyproject.toml", "go.mod", "package.json" (only if it's always at the root)
    }
    vim.g.rooter_cd_cmd = "cd"        -- use "lcd" for window-local cd
    vim.g.rooter_silent_chdir = 1     -- set to 0 to see directory change messages
  end,
}
