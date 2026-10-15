-- nvim-lint: linters that aren't language servers. eslint is already an LSP
-- here (plugins/lsp.lua), so this covers the rest: shell scripts. A linter
-- whose binary isn't installed is skipped
-- shellcheck is in packages/pacman.txt; add more linters here as needed.
return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufWritePost" },
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      sh = { "shellcheck" },
      bash = { "shellcheck" },
      zsh = {},
    }
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
      group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
      callback = function()
        local names = vim.tbl_filter(function(n)
          local l = lint.linters[n]
          local cmd = type(l) == "table" and l.cmd or n
          if type(cmd) == "function" then cmd = cmd() end
          return vim.fn.executable(cmd) == 1
        end, lint.linters_by_ft[vim.bo.filetype] or {})
        if #names > 0 then lint.try_lint(names) end
      end,
    })
  end,
}
