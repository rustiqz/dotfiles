-- General, plugin-independent keymaps. LSP keymaps (gd, K, <leader>rn, ...)
-- are set per-buffer in an LspAttach autocmd instead — see
-- lua/plugins/lsp.lua — since they should only exist where a language
-- server actually attached.

local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Window navigation with the same h/j/k/l used for everything else,
-- instead of the <C-w> prefix + arrow/hjkl two-step.
map("n", "<C-h>", "<C-w><C-h>", { desc = "Move to left window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move to right window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move to upper window" })
