-- Bootstraps lazy.nvim itself (clones it on first run — this is the
-- verbatim snippet from lazy.nvim's own README, since it's the one
-- piece of this config that has to exist before lazy.nvim is available
-- to manage anything, including itself), then hands off to every spec
-- file under lua/plugins/.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  install = { colorscheme = { "tokyonight" } },
  -- Update checks require a network call on every startup; off by
  -- default, run `:Lazy check` when actually looking for updates.
  checker = { enabled = false },
  -- No plugin here needs luarocks; with rocks on, lazy's health check
  -- errors about a hererocks/luarocks install that doesn't exist.
  rocks = { enabled = false },
})
