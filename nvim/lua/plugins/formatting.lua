-- conform.nvim: formatter integration.
-- Format manually : <Leader>lf  (normal or visual mode)
-- Toggle auto-fmt  : <Leader>lF  or  :AutoFormatToggle
-- Format-on-save is ON by default.
-- Docs: https://github.com/stevearc/conform.nvim

---@type LazySpec
return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = { "ConformInfo", "AutoFormatToggle" },
  keys = {
    {
      "<Leader>lf",
      function() require("conform").format({ async = true, lsp_fallback = true }) end,
      mode = { "n", "v" },
      desc = "Format buffer (or selection)",
    },
    { "<Leader>lF", "<Cmd>AutoFormatToggle<CR>", desc = "Toggle format-on-save" },
  },
  init = function()
    -- Set to false to disable format-on-save by default.
    vim.g.autoformat = true
  end,
  ---@module "conform"
  ---@type conform.setupOpts
  opts = {
    formatters_by_ft = {
      lua        = { "stylua" },
      python     = { "isort", "black" },
      json       = { "prettier" },
      jsonl      = { "jq_jsonl" },     -- jq processes each JSONL line independently
      markdown   = { "prettier" },
      yaml       = { "prettier" },
      html       = { "prettier" },
      css        = { "prettier" },
      javascript = { "prettier" },
      typescript = { "prettier" },
      sql        = { "sql-formatter" },
      cpp        = { "clang-format" },
      c          = { "clang-format" },
      java       = { "google-java-format" },
    },
    formatters = {
      -- prettier and sql-formatter are expected on PATH (installed via brew/npm/scoop).
      prettier = { command = "prettier" },
      -- JSONL: prettier's JSON parser rejects multi-object files, so use jq.
      -- `jq -R 'fromjson | .'` reads each line as a string and pretty-prints it.
      jq_jsonl = {
        command = "jq",
        args    = { "-R", "fromjson | ." },
        stdin   = true,
      },
      ["sql-formatter"] = { command = "sql-formatter" },
    },
    format_on_save = function(bufnr)
      if not vim.g.autoformat then return end
      -- Skip files larger than 1 MB.
      if vim.api.nvim_buf_get_offset(bufnr, vim.api.nvim_buf_line_count(bufnr)) > 1024 * 1024 then
        return
      end
      return { timeout_ms = 2000, lsp_fallback = true }
    end,
  },
  config = function(_, opts)
    local conform = require("conform")
    conform.setup(opts)
    vim.api.nvim_create_user_command("AutoFormatToggle", function()
      vim.g.autoformat = not vim.g.autoformat
      vim.notify(
        "Format-on-save " .. (vim.g.autoformat and "enabled" or "disabled"),
        vim.log.levels.INFO,
        { title = "conform.nvim" }
      )
    end, { desc = "Toggle format-on-save" })
  end,
}
