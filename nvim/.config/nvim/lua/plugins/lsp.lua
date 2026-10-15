-- LSP servers, on Neovim 0.11+'s native API (vim.lsp.config/enable).
--
-- Why not `require("lspconfig").X.setup{}` any more: on 0.11+ that
-- "framework" is deprecated (nvim-lspconfig's own lspconfig.lua calls
-- vim.deprecate on it, removal slated for v3). nvim-lspconfig is still
-- installed, but only as a *data* plugin — it ships the per-server
-- defaults under lsp/<name>.lua that vim.lsp.config merges our overrides
-- onto. So each server below is: defaults from lspconfig + the few
-- settings we change + vim.lsp.enable.
--
-- Servers:
--   vtsls       TypeScript/JavaScript — wraps the real VS Code TS server
--   eslint      lint rules (vtsls does types/completion, not lint)
--   lua_ls      this config is Lua, so it edits itself
--   tailwindcss class completion/hover (arcana web, Vaultiq extension);
--               only attaches in projects that actually use tailwind
--   jsonls      package.json/tsconfig etc., with SchemaStore schemas
--   yamlls      GitHub workflows, compose files, k8s — SchemaStore again
--   dockerls    Dockerfiles; docker_compose_language_service for compose
--   taplo       TOML (Cargo.toml, mise config, matugen config)
--   rust-analyzer is deliberately NOT here — rustaceanvim owns it (see
--               plugins/rust.lua). Enabling it here too would attach two
--               rust-analyzer clients to every .rs buffer.
--
-- mason.nvim installs the server binaries into ~/.local/share/nvim/mason
-- on first launch. Most are npm packages under the hood, so nvim has to
-- be launched from a shell where mise has already activated node (see
-- zsh/.zshrc's `mise activate zsh` line) — otherwise those installs fail
-- with "could not find executable npm" (CLAUDE.md, Known gotchas).

local servers = {
  "vtsls", "eslint", "lua_ls", "tailwindcss",
  "jsonls", "yamlls", "dockerls", "docker_compose_language_service", "taplo",
}

return {
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = servers,
      -- mason-lspconfig v2 calls vim.lsp.enable itself for every server
      -- mason installed. We enable explicitly below instead, so the list
      -- of active servers is this file, not "whatever mason has on disk"
      -- (a stray manual `:MasonInstall rust-analyzer` would otherwise
      -- start fighting rustaceanvim).
      automatic_enable = false,
    },
  },
  -- JSON/YAML schemas for jsonls/yamlls: package.json, tsconfig, GitHub
  -- workflows, compose files, ... picked by filename automatically.
  { "b0o/SchemaStore.nvim", lazy = true, version = false },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim", "b0o/SchemaStore.nvim" },
    config = function()
      -- Applies to every server, including rust-analyzer via rustaceanvim
      -- ('*' is merged under each server's own config).
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            -- Otherwise lua_ls flags `vim` as an undefined global in
            -- every file in this very config.
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
          },
        },
      })

      vim.lsp.config("jsonls", {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      })

      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            -- yamlls has its own built-in store; turn it off so it doesn't
            -- compete with SchemaStore.nvim's (same catalogue, but this way
            -- there's exactly one source).
            schemaStore = { enable = false, url = "" },
            schemas = require("schemastore").yaml.schemas(),
          },
        },
      })

      -- tailwindcss: upstream's root_dir falls back to the `.git` root (so
      -- tailwind v4, which has no tailwind.config.*, still works) — which
      -- means it attached to *every* JS/TS buffer in *every* repo,
      -- including Vaultiq's server, which has no tailwind at all (seen in
      -- a headless attach probe). Narrowed: attach only where a tailwind/
      -- postcss config exists, or a package.json on the way up to the
      -- repo root mentions tailwind (covers v4's `@tailwindcss/vite`).
      -- Not calling on_dir = don't attach.
      vim.lsp.config("tailwindcss", {
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          local config = vim.fs.find(function(name)
            return name:match("^tailwind%.config%.") or name:match("^postcss%.config%.")
          end, { path = fname, upward = true, stop = vim.fs.root(fname, ".git") })[1]
          if config then
            return on_dir(vim.fs.dirname(config))
          end
          for dir in vim.fs.parents(fname) do
            local pkg = vim.fs.joinpath(dir, "package.json")
            if vim.uv.fs_stat(pkg) then
              local ok, lines = pcall(vim.fn.readfile, pkg)
              if ok and table.concat(lines, "\n"):find("tailwindcss", 1, true) then
                return on_dir(dir)
              end
            end
            if vim.uv.fs_stat(vim.fs.joinpath(dir, ".git")) then
              return
            end
          end
        end,
      })

      -- taplo fetches the schema catalog on every initialize and logs a
      -- decode error (the catalog format outran this taplo build). Cargo.toml
      -- etc. don't need remote schemas for syntax/format support.
      vim.lsp.config("taplo", {
        settings = { evenBetterToml = { schema = { enabled = false } } },
      })

      vim.lsp.enable(servers)

      -- Buffer-local, and only set where a server actually attached —
      -- the alternative (global keymaps defined once at startup) would
      -- make e.g. gd a no-op error in buffers with no LSP at all.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
        callback = function(args)
          local opts = { buffer = args.buf }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          -- vim.diagnostic.goto_prev/next are deprecated on 0.11+;
          -- jump() is the replacement.
          vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, opts)
          vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, opts)

          -- ESLint's own fixer on save — separate from conform.nvim's
          -- prettier formatting (plugins/formatting.lua): this fixes lint
          -- rule violations, prettier fixes style. The command is
          -- `LspEslintFixAll` — what lspconfig's lsp/eslint.lua defines
          -- today; the old `EslintFixAll` name this used to call no longer
          -- exists. Hooked from LspAttach rather than an `on_attach`
          -- override, because overriding on_attach would replace the
          -- default one that creates that very command.
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "eslint" then
            vim.api.nvim_create_autocmd("BufWritePre", {
              buffer = args.buf,
              group = vim.api.nvim_create_augroup("eslint-fix-" .. args.buf, { clear = true }),
              command = "silent! LspEslintFixAll",
            })
          end
        end,
      })
    end,
  },
}
