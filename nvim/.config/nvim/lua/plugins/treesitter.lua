-- Treesitter: parser installer + queries. Highlighting itself is built
-- into Neovim (vim.treesitter.start), this plugin just supplies parsers.
--
-- Written for nvim-treesitter's `main` branch — the rewrite lazy.nvim
-- resolves to now. It is NOT the old `master` API: there is no
-- `nvim-treesitter.configs` module and no `ensure_installed`/
-- `highlight = { enable = true }` options any more. The previous version
-- of this file still called `require("nvim-treesitter.configs")`, which
-- threw "module not found" on every file open and silently left every
-- buffer on regex highlighting (`vim.treesitter.highlighter.active` was
-- empty) — confirmed headless before this rewrite, not assumed.
--
-- `main` builds parsers locally, so it needs `tree-sitter-cli` (the
-- pacman package — the plugin README explicitly says not the npm one)
-- and a C compiler on $PATH. Both are in packages/pacman.txt.
local parsers = {
  -- editor / shell / config
  "lua", "vim", "vimdoc", "query", "bash", "regex",
  "json", "yaml", "toml", "markdown", "markdown_inline",
  "diff", "gitcommit", "git_rebase", "gitignore",
  -- web / TS monorepos (arcana, Vaultiq)
  "javascript", "typescript", "tsx", "css", "html", "sql",
  -- Rust (monitra, Vaultiq's crypto core) + infra
  "rust", "dockerfile", "just",
}

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- `main` does not support lazy-loading (plugin README)
  build = ":TSUpdate",
  config = function()
    -- No-op for already-installed parsers; async, so startup isn't blocked
    -- on a fresh machine — the first session just gets regex highlighting
    -- until each parser finishes compiling.
    require("nvim-treesitter").install(parsers)

    -- Start highlighting for *any* filetype that has a parser, rather than
    -- a hand-kept pattern list that drifts from `parsers` above.
    -- vim.treesitter.start() errors when no parser exists for the buffer's
    -- language, hence pcall — plain text/unknown filetypes just keep
    -- Neovim's regex syntax.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
      callback = function(args)
        if not pcall(vim.treesitter.start, args.buf) then
          return
        end
        -- Experimental per the README, but more accurate than cindent for
        -- TSX/Rust. Only set where highlighting actually started, so a
        -- parser-less buffer keeps its normal indentexpr.
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
