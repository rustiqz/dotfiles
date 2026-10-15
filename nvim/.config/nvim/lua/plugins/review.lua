-- Review tooling for a workflow where agents write most of the code and
-- you read most of it: see what changed, hunk by hunk, then accept/revert.
--
-- gitsigns: per-hunk gutter marks + stage/reset/preview, blame on demand.
--   ]c / [c   next/prev hunk       <leader>hp  preview hunk
--   <leader>hs stage hunk          <leader>hr  reset (revert) hunk
--   <leader>hb blame line          <leader>hd  diff this file vs index
-- diffview: whole-branch review in tabs.
--   <leader>gd  working tree vs HEAD (what the agent just did)
--   <leader>gm  branch vs main (the PR as a reviewer sees it)
--   <leader>gh  history of current file     <leader>gq  close
return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
        end
        -- Fall back to vim's own diff motions inside :diffthis windows.
        map("]c", function()
          if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else gs.nav_hunk("next") end
        end, "Next hunk")
        map("[c", function()
          if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else gs.nav_hunk("prev") end
        end, "Prev hunk")
        map("<leader>hp", gs.preview_hunk, "Preview hunk")
        map("<leader>hs", gs.stage_hunk, "Stage hunk")
        map("<leader>hr", gs.reset_hunk, "Reset hunk")
        map("<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("<leader>hd", gs.diffthis, "Diff file vs index")
      end,
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Review: working tree" },
      { "<leader>gm", "<cmd>DiffviewOpen origin/main...HEAD<cr>", desc = "Review: branch vs main" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Review: file history" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Review: close" },
    },
    opts = {},
  },
}
