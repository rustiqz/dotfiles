#!/usr/bin/env bash
#
# Rust toolchain via rustup: default toolchain, components, cross targets.
#
# rustup itself is a pacman package (packages/pacman.txt, Phase 7), but a
# fresh rustup has *no toolchain at all* — `cargo` errors with "no default
# toolchain configured" until one is installed. On the first machine all
# of this was done by hand and never recorded, so a clean machine got a
# rustup with nothing behind it. This hook is that missing record.
#
# Components:
#   rust-analyzer  the LSP rustaceanvim talks to (nvim/.../plugins/rust.lua).
#                  /usr/bin/rust-analyzer is only rustup's *proxy* — without
#                  this component it exits "unknown binary", which is
#                  exactly how Rust buffers had no LSP before Phase 7.
#   rust-src       std source; rust-analyzer needs it for go-to-definition
#                  into std and for std completions
#   clippy rustfmt rust-analyzer runs clippy on save (check.command) and
#                  formats via rustfmt
#
# Targets — what the projects actually cross-compile for:
#   x86_64-unknown-linux-musl  monitra's static release binary
#   wasm32-unknown-unknown     Vaultiq crypto core (browser extension)
#   aarch64-linux-android,
#   x86_64-linux-android       Vaultiq crypto core via cargo-ndk (device +
#                              emulator ABIs)
#
# Idempotent: `rustup component/target add` no-op when already installed,
# and the default toolchain is only set when none exists — a machine
# deliberately pinned to something else keeps its choice.

set -euo pipefail

if ! command -v rustup &>/dev/null; then
  echo "rustup not installed — skipping (packages/pacman.txt installs it)" >&2
  exit 0
fi

if ! rustup default &>/dev/null; then
  echo "No default Rust toolchain — installing stable"
  rustup default stable
fi

rustup component add rust-analyzer rust-src clippy rustfmt

rustup target add \
  x86_64-unknown-linux-musl \
  wasm32-unknown-unknown \
  aarch64-linux-android \
  x86_64-linux-android

echo "Rust toolchain: $(rustup default)"
