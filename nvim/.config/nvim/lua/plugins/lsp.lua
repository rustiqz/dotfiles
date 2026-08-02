-- LSP servers: vtsls (TypeScript/JavaScript — wraps the actual VS Code
-- TS server rather than reimplementing it, better auto-imports/inlay
-- hints than the older ts_ls), lua_ls (this config is Lua, so it edits
-- itself), eslint (linting — separate from vtsls, which only does
-- language-service things like types/completion, not lint rules).
--
-- mason.nvim installs the actual server binaries into
-- ~/.local/share/nvim/mason on first launch; this file just configures
-- lspconfig to talk to them once installed.
--
-- vtsls and eslint are npm packages under the hood, so mason needs a
-- working `node`/`npm` on $PATH to install them — i.e. nvim has to be
-- launched from a shell where mise has already activated (see
-- zsh/.zshrc's `mise activate zsh` line). Launching nvim from a raw,
-- non-login environment (some GUI launchers) can fail mason installs
-- for exactly this reason.

return {
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "vtsls", "lua_ls", "eslint" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- Buffer-local, and only set where a server actually attached —
      -- the alternative (global keymaps defined once at startup) would
      -- make e.g. gd a no-op error in buffers with no LSP at all.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        end,
      })

      lspconfig.vtsls.setup({ capabilities = capabilities })

      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            -- Otherwise lua_ls flags `vim` as an undefined global in
            -- every file in this very config.
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
          },
        },
      })

      lspconfig.eslint.setup({
        capabilities = capabilities,
        -- ESLint's own fixer, run on every save — separate from
        -- conform.nvim's prettier formatting (lua/plugins/formatting.lua):
        -- this fixes lint rule violations, prettier fixes style.
        on_attach = function(_, bufnr)
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            command = "EslintFixAll",
          })
        end,
      })
    end,
  },
}
