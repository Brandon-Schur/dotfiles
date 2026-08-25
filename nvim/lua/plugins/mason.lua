-- Mason tool installer: auto-installs LSP servers, formatters, and other tools.
-- Add any Mason package name to ensure_installed.
-- Browse packages at :Mason or https://mason-registry.dev/
--
-- NOTE: prettier and sql-formatter are NOT listed here because Mason installs
-- them via npm. If your npm registry requires authentication (corporate proxy,
-- private registry, etc.), install them via your system package manager instead:
--   macOS/Linux: brew install prettier sql-formatter
--   Windows:     scoop install nodejs  then  npm install -g prettier sql-formatter
-- conform.nvim will find them automatically as long as they are on your PATH.

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        -- language servers
        "lua-language-server",

        -- formatters
        "stylua",             -- Lua
        "black",              -- Python
        "isort",              -- Python import sorting
        "jq",                 -- JSON / JSONL
        "clang-format",       -- C, C++
        "google-java-format", -- Java

        -- debuggers / other
        "debugpy",
        "tree-sitter-cli",
      },
    },
  },
}
