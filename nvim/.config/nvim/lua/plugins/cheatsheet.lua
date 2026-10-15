-- <leader>? (or :Cheat) floats CHEATSHEET.md, which sits next to init.lua
-- so it's edited together with the keymaps it describes. Kept as a curated
-- file rather than generated: which-key already shows the live keymaps
-- after <leader>, this is the "what can I even do" overview.
-- Also reachable from outside nvim: $mod+shift+/ opens it in kitty (read-only; :q to close).
local function open()
  local path = vim.fn.stdpath("config") .. "/CHEATSHEET.md"
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.bo[buf].modifiable = false
  local w, h = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.85)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = w, height = h,
    row = math.floor((vim.o.lines - h) / 2), col = math.floor((vim.o.columns - w) / 2),
    style = "minimal", border = "rounded", title = " nvim cheatsheet ", title_pos = "center",
  })
  vim.wo[win].wrap = false
  for _, k in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", k, "<cmd>close<cr>", { buffer = buf, nowait = true })
  end
end

vim.api.nvim_create_user_command("Cheat", open, {})
vim.keymap.set("n", "<leader>?", open, { desc = "Cheatsheet" })
return {}
