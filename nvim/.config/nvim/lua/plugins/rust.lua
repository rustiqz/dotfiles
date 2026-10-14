-- Rust: rustaceanvim owns rust-analyzer (no lspconfig/mason entry for it
-- — see plugins/lsp.lua's header for why that would double-attach).
--
-- rust-analyzer itself comes from rustup (`rustup component add
-- rust-analyzer`, hooks/55-rust-toolchain.sh), NOT mason: the rustup
-- proxy at /usr/bin/rust-analyzer resolves to the analyzer matching each
-- project's own toolchain (rust-toolchain.toml or the default), so it
-- always agrees with the `cargo` that project actually builds with.
-- A mason-installed copy is pinned to whatever version mason fetched.
--
-- Before this phase the rustup component was simply never installed:
-- /usr/bin/rust-analyzer existed (rustup ships the proxy) but errored
-- with "unknown binary" — so Rust buffers had no LSP at all.
return {
  {
    "mrcjkb/rustaceanvim",
    lazy = false, -- the plugin lazy-loads itself on the rust filetype
    init = function()
      vim.g.rustaceanvim = {
        server = {
          default_settings = {
            ["rust-analyzer"] = {
              -- clippy instead of plain `cargo check` on save: the lints
              -- CI would fail on show up in the editor first.
              check = { command = "clippy" },
              -- Build proc-macros and run build scripts so derive-heavy
              -- crates (serde, clap, sqlx-style) resolve properly.
              cargo = { buildScripts = { enable = true } },
              procMacro = { enable = true },
            },
          },
        },
      }
    end,
  },
}
