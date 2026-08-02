-- Editor defaults. Plugin-specific options live with their plugin specs
-- in lua/plugins/, not here — this file is only vim.opt/vim.g state that
-- isn't owned by any one plugin.

local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.scrolloff = 8
opt.splitright = true
opt.splitbelow = true
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
-- Live-preview :s substitutions in a split as you type the pattern.
opt.inccommand = "split"

-- Editing
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.breakindent = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.ignorecase = true
opt.smartcase = true -- ...unless the search pattern has a capital letter

-- Persistence
opt.undofile = true
opt.updatetime = 250 -- default (4000ms) is noticeably laggy for LSP diagnostics/CursorHold
