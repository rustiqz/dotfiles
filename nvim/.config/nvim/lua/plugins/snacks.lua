-- snacks.nvim: the "no more surprise popups" and "git without leaving nvim"
-- pieces.
--   notifier   routes vim.notify (what lazy, mason, LSPs and plugins use to
--              report errors) into small stacked toasts that expire, and
--              keeps history: <leader>un shows everything you missed, so
--              "it threw an error on open" is always inspectable.
--   lazygit    <leader>gg floats lazygit (themed in its own config) over the
--              current buffer — stage hunks of an agent's diff, then close.
--   bigfile    skips treesitter/LSP on huge generated files instead of
--              freezing the editor.
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    notifier = { enabled = true, timeout = 4000 },
    lazygit = { enabled = true },
    bigfile = { enabled = true },
    quickfile = { enabled = true },
  },
  keys = {
    { "<leader>gg", function() Snacks.lazygit() end, desc = "lazygit" },
    { "<leader>un", function() Snacks.notifier.show_history() end, desc = "Notification history" },
    { "<leader>ud", function() Snacks.notifier.hide() end, desc = "Dismiss notifications" },
  },
}
