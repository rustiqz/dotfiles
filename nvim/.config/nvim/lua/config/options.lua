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

-- Filetypes
-- Compose files are plain YAML to Neovim by default, but the compose
-- language server (plugins/lsp.lua) only attaches to the compound
-- filetype `yaml.docker-compose`. yamlls still attaches too (it lists
-- that filetype), so this adds compose-aware completion/hover on top of
-- schema validation rather than replacing it. Treesitter then needs
-- telling that this filetype is parsed as yaml — a compound filetype
-- doesn't map to a parser by itself.
vim.filetype.add({
  pattern = {
    [".*/docker%-compose[%w%.%-]*%.ya?ml"] = "yaml.docker-compose",
    [".*/compose[%w%.%-]*%.ya?ml"] = "yaml.docker-compose",
  },
})
vim.treesitter.language.register("yaml", "yaml.docker-compose")

-- Agents edit files while they're open here. Without this the buffer goes
-- stale and the next :w clobbers the agent's work (or prompts "file changed").
-- checktime on focus/idle reloads clean buffers silently.
opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  group = vim.api.nvim_create_augroup("autoread-checktime", { clear = true }),
  callback = function()
    if vim.fn.mode() ~= "c" then vim.cmd("silent! checktime") end
  end,
})
