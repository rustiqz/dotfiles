-- trouble.nvim: one list of every diagnostic/reference, instead of
-- hopping ]d through files one error at a time. Most useful right after
-- a big refactor or a dependency bump, where rust-analyzer/vtsls report
-- dozens of errors across a workspace at once.
--
-- Keys (<leader>x, "problems"):
--   xx  whole workspace    xb  current buffer only
--   xr  LSP references/definitions for the word under the cursor
return {
  -- Diagnostics inline at the end of the line, wrapped and coloured by
  -- severity, instead of Neovim's single-line virtual text. Replaces the
  -- built-in virtual_text so each problem isn't shown twice.
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    config = function()
      require("tiny-inline-diagnostic").setup()
      vim.diagnostic.config({ virtual_text = false })
    end,
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Problems: workspace" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Problems: buffer" },
      { "<leader>xr", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "Problems: LSP refs" },
    },
  },
}
