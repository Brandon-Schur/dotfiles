-- AstroCommunity: import any community modules here.
-- This file is loaded before plugins/ to ensure specs are processed first.
-- Uncomment or add packs as needed: https://github.com/AstroNvim/astrocommunity

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
}
