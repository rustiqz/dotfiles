-- Runs system `prettier` on save — deliberately not mason-installed:
-- prettier is a formatter/CLI tool, not a language server, so it's
-- installed the same way as every other global CLI tool in this repo
-- (hooks/61-node-globals.sh, `pnpm add -g prettier`) rather than mixing
-- in a second package manager for something outside mason's actual job.
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    formatters_by_ft = {
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      css = { "prettier" },
      html = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },
    },
    format_on_save = {
      timeout_ms = 1000,
      lsp_fallback = true, -- e.g. lua_ls's own formatter, for filetypes above with no entry
    },
  },
}
