-- neotest: run tests from the editor, results inline next to each test.
--
-- Adapters cover the three active projects' test runners:
--   vitest  arcana packages, Vaultiq server/extension
--   jest    Vaultiq mobile (React Native)
--   rust    rustaceanvim's own adapter — uses cargo-nextest when it's on
--           $PATH (packages/pacman.txt), plain `cargo test` otherwise
-- Each adapter only claims files in projects that actually depend on its
-- runner, so having all three loaded costs nothing in the others.
--
-- Keys (all under <leader>t, "test"):
--   tt nearest test   tf whole file    tl re-run last
--   ts summary panel  to output float  tw watch file (re-run on save)
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-jest",
      "mrcjkb/rustaceanvim",
    },
    keys = {
      { "<leader>tt", function() require("neotest").run.run() end, desc = "Test: nearest" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Test: file" },
      { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Test: re-run last" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test: summary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true }) end, desc = "Test: output" },
      { "<leader>tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Test: watch file" },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-vitest"),
          require("neotest-jest"),
          require("rustaceanvim.neotest"),
        },
      })
    end,
  },
}
