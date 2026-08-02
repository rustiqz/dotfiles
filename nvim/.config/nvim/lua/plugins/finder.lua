-- Shells out to the real `fzf` binary (installed + themed in
-- zsh/.zshrc's FZF_DEFAULT_OPTS) instead of a separate Lua-native fuzzy
-- matcher — one fuzzy-finder, matching everywhere it's used, in the
-- shell and in the editor alike. live_grep uses ripgrep, also already
-- installed for the shell (packages/pacman.txt, Phase 2).
return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    winopts = {
      height = 0.85,
      width = 0.85,
    },
  },
  keys = {
    { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Live grep" },
    { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
    { "<leader>fh", "<cmd>FzfLua help_tags<cr>", desc = "Help tags" },
    { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent files" },
  },
}
