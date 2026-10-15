# nvim cheatsheet        (leader = Space · `q` closes this · `<leader>?` reopens)

## Find (fzf-lua)
  <leader>ff files   fg live grep   fb buffers   fr recent   fh help
## Move
  s{2 chars}  flash jump anywhere        S  pick treesitter node
  -           parent dir as a buffer (oil: edit names, :w applies)
  <C-h/j/k/l> move between windows
  af/if  function   ac/ic  class   aa/ia  argument     (mini.ai)
  ys{motion}{c} add surround   ds{c} delete   cs{old}{new} change
## LSP (only where a server attached)
  gd definition   gr references   K hover
  <leader>rn rename   <leader>ca code action
  [d / ]d  prev/next diagnostic
  <leader>xx workspace problems   xb buffer   xr LSP refs      (trouble)
## Review agent changes
  ]c / [c  next/prev hunk          <leader>hp preview   hs stage   hr reset
  <leader>hb blame line            <leader>hd diff file vs index
  <leader>gd working tree diff     gm branch vs main    gh file history
  <leader>gq close diffview        <leader>gg lazygit float
  shell: `review` (diff in nvim)  `checks` (typecheck/lint/test)  `wt new <branch>`
## Popups & errors
  <leader>un notification history (what flashed by)   ud dismiss
  :messages · :checkhealth · :Lazy · :Mason · :LspInfo
## Test (neotest) / Rust
  see plugins/testing.lua · rustaceanvim: :RustLsp codeAction / runnables
## Misc
  <Esc> clear search highlight · which-key: press <leader> and wait
  files changed on disk (by an agent) reload automatically
