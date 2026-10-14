-- trouble.nvim: one list of every diagnostic/reference, instead of
-- hopping ]d through files one error at a time. Most useful right after
-- a big refactor or a dependency bump, where rust-analyzer/vtsls report
-- dozens of errors across a workspace at once.
--
-- Keys (<leader>x, "problems"):
--   xx  whole workspace    xb  current buffer only
--   xr  LSP references/definitions for the word under the cursor
return {
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
