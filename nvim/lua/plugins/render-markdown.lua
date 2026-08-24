-- render-markdown.nvim: in-editor rendering of markdown (headings, code blocks,
-- bullets, tables, callouts). Requires treesitter markdown parsers.
-- Docs: https://github.com/MeanderingProgrammer/render-markdown.nvim

---@type LazySpec
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "markdown", "markdown_inline" })
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    ft = { "markdown", "markdown.mdx", "quarto", "rmd" },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {},
  },
}
