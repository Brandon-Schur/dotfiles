-- AstroNvim entry point — bootstraps lazy.nvim then hands off to lazy_setup.lua
-- This file is part of the AstroNvim template; edit with care.
local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
  local result = vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { ("Error cloning lazy.nvim:\n%s\n"):format(result), "ErrorMsg" },
      { "Press any key to exit...", "MoreMsg" },
    }, true, {})
    vim.fn.getchar()
    vim.cmd.quit()
  end
end
vim.opt.rtp:prepend(lazypath)

if not pcall(require, "lazy") then
  vim.api.nvim_echo({
    { ("Unable to load lazy from: %s\n"):format(lazypath), "ErrorMsg" },
    { "Press any key to exit...", "MoreMsg" },
  }, true, {})
  vim.fn.getchar()
  vim.cmd.quit()
end

-- Buffer navigation (Ctrl+Tab / Ctrl+Shift+Tab)
vim.keymap.set("n", "<C-Tab>",   ":bn<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<C-S-Tab>", ":bp<CR>", { desc = "Previous buffer" })

require "lazy_setup"
require "polish"
