-- ~/.config/nvim/init.lua
--
-- Must be set before anything else loads: plugins/keymaps defined during
-- lazy.nvim's setup can reference <leader>, and a leader changed after
-- they're registered doesn't retroactively apply to them.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")
require("config.lazy")
