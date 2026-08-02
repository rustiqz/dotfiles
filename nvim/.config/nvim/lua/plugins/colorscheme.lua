return {
  "folke/tokyonight.nvim",
  -- Load and apply before anything else, so no plugin briefly renders
  -- with Neovim's default colorscheme before this takes over.
  priority = 1000,
  opts = {
    style = "night", -- matches kitty/.config/kitty/tokyonight.conf and starship.toml
  },
  config = function(_, opts)
    require("tokyonight").setup(opts)
    vim.cmd.colorscheme("tokyonight")
  end,
}
