-- Editing motions that cut keystrokes. All lazy-loaded on first use.
--   flash     s{2 chars} jumps anywhere on screen; S picks a treesitter node
--   surround  ys{motion}{char} add, ds{char} delete, cs{old}{new} change
--   mini.ai   extra text objects: `af`/`if` function, `ac`/`ic` class,
--             `aa`/`ia` argument, plus `a(`-style objects that look ahead
--   oil       edit a directory like a buffer (rename/move/delete = :w); `-`
--   which-key shows pending keymaps after <leader> — discoverability for
--             everything in this config without memorising it
return {
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash treesitter" },
    },
  },
  { "kylechui/nvim-surround", version = "*", event = "VeryLazy", opts = {} },
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    opts = function()
      local ai = require("mini.ai")
      return {
        n_lines = 500,
        custom_textobjects = {
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
        },
      }
    end,
  },
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Oil",
    keys = { { "-", "<cmd>Oil<cr>", desc = "Parent directory (oil)" } },
    opts = { view_options = { show_hidden = true } },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git / review" },
        { "<leader>h", group = "hunks" },
        { "<leader>x", group = "problems" },
        { "<leader>t", group = "test" },
      },
    },
  },
}
