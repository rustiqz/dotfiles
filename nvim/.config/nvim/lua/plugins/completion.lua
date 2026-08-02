return {
  "saghen/blink.cmp",
  -- Prebuilt binaries are published per version tag, so pinning to the
  -- latest release (rather than main) avoids needing a local Rust
  -- toolchain to build blink's fuzzy-matcher.
  version = "*",
  event = "InsertEnter",
  opts = {
    keymap = { preset = "default" }, -- <C-space> trigger, <Tab>/<C-n>/<C-p> to cycle, <CR> to accept
    appearance = {
      nerd_font_variant = "mono", -- matches JetBrainsMono Nerd Font
    },
    completion = {
      documentation = { auto_show = true },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
  },
}
