return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  opts = {
    options = {
      -- tokyonight.nvim ships a matching lualine theme directly, so this
      -- doesn't need its own copy of the palette.
      theme = "tokyonight",
      globalstatus = true,
      icons_enabled = true,
    },
  },
}
