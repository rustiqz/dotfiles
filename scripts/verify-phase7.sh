#!/usr/bin/env bash
#
# verify-phase7.sh — assert that Phase 7 (developer toolchain) is fully
# applied: Rust toolchain + build-speed wiring, cargo tools, just, and the
# Neovim language/test/diagnostics setup.
#
# Read-only as far as the system goes. Two checks build a throwaway crate
# under a mktemp dir (deleted on exit) — the only honest way to prove mold
# and sccache are actually *used*, not just installed, and that
# rust-analyzer really attaches in Neovim rather than merely existing.
#
# Exit code 0 = all checks passed, 1 = at least one failure.

set -uo pipefail

PASS=0; FAIL=0; WARN=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Plain assignment, not `((PASS++))` — see verify-phase1.sh for why the
# postfix form causes a false failure on each counter's first increment.
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
wa() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

chk_pkg() {
  pacman -Qq "$1" &>/dev/null && ok "package $1" || no "package $1 MISSING"
}

# realpath, not -L — see verify-phase2.sh (stow tree-folding).
chk_link() {
  local path=$1
  if [[ -e $path || -L $path ]]; then
    local target
    target=$(realpath -e "$path" 2>/dev/null) || { no "$path is a broken symlink"; return; }
    [[ $target == "$DOTFILES"/* ]] && ok "linked: $path" \
                                    || no "$path exists but resolves outside this repo ($target) — stray file?"
  else
    no "$path missing"
  fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
hdr "Packages"
# ---------------------------------------------------------------------------
for p in rustup mold sccache bacon cargo-nextest cargo-binstall cargo-audit \
         cargo-ndk git-cliff mdbook just tree-sitter-cli; do
  chk_pkg "$p"
done

# ---------------------------------------------------------------------------
hdr "Rust toolchain (hooks/55-rust-toolchain.sh)"
# ---------------------------------------------------------------------------
if default=$(rustup default 2>/dev/null); then
  ok "default toolchain: ${default%% *}"
else
  no "no default rustup toolchain — run hooks/55-rust-toolchain.sh"
fi

# Captured into a variable, then grepped — never `producer | grep -q`
# under pipefail (CLAUDE.md, Known gotchas: SIGPIPE false failure).
components=$(rustup component list --installed 2>/dev/null)
for c in rust-analyzer rust-src clippy rustfmt; do
  grep -q "^$c" <<<"$components" && ok "component $c" \
                                 || no "component $c missing — run hooks/55-rust-toolchain.sh"
done

targets=$(rustup target list --installed 2>/dev/null)
for t in x86_64-unknown-linux-musl wasm32-unknown-unknown aarch64-linux-android x86_64-linux-android; do
  grep -qx "$t" <<<"$targets" && ok "target $t" \
                              || no "target $t missing — run hooks/55-rust-toolchain.sh"
done

# The proxy exists whether or not the component does; only a real run
# proves it resolves (pre-Phase-7 it exited "unknown binary").
if ra=$(rust-analyzer --version 2>/dev/null); then
  ok "rust-analyzer resolves ($ra)"
else
  no "rust-analyzer proxy doesn't resolve to a binary"
fi

# ---------------------------------------------------------------------------
hdr "Cargo config: mold + sccache actually in use"
# ---------------------------------------------------------------------------
chk_link "$HOME/.cargo/config.toml"

if command -v cargo &>/dev/null && command -v sccache &>/dev/null; then
  before=$(sccache --show-stats --stats-format json 2>/dev/null | jq '.stats.compile_requests // 0' 2>/dev/null || echo 0)
  if (cd "$TMP" && cargo new -q --vcs none probe && cd probe && cargo build -q) &>"$TMP/build.log"; then
    ok "throwaway crate builds through the cargo config"

    comment=$(readelf -p .comment "$TMP/probe/target/debug/probe" 2>/dev/null)
    grep -qi mold <<<"$comment" && ok "binary linked by mold (.comment section names it)" \
                                || no "binary NOT linked by mold — check rustflags in cargo/.cargo/config.toml"

    after=$(sccache --show-stats --stats-format json 2>/dev/null | jq '.stats.compile_requests // 0' 2>/dev/null || echo 0)
    (( after > before )) && ok "rustc went through sccache ($before → $after compile requests)" \
                         || no "sccache saw no compile requests — check rustc-wrapper in cargo/.cargo/config.toml"
  else
    no "throwaway crate failed to build: $(tail -3 "$TMP/build.log" | tr '\n' ' ')"
  fi
else
  no "cargo/sccache not available — can't test the build wiring"
fi

# ---------------------------------------------------------------------------
hdr "PATH"
# ---------------------------------------------------------------------------
# pacman's copy must win over any older hand-installed one in ~/.cargo/bin.
nextest=$(zsh -ic 'command -v cargo-nextest' 2>/dev/null)
[[ $nextest == /usr/bin/cargo-nextest ]] && ok "cargo-nextest resolves to pacman's /usr/bin copy" \
                                         || no "cargo-nextest resolves to '$nextest', expected /usr/bin/cargo-nextest"
path=$(zsh -ic 'echo $PATH' 2>/dev/null)
[[ $path == *"$HOME/.cargo/bin"* ]] && ok "~/.cargo/bin on \$PATH (appended)" \
                                    || no "~/.cargo/bin not on \$PATH — check zsh/.zshrc"

# ---------------------------------------------------------------------------
hdr "Neovim"
# ---------------------------------------------------------------------------
NVIM_LUA="$DOTFILES/nvim/.config/nvim/lua"
# Code lines only — the config's own comments explain the old API by name.
legacy=$(grep -rn 'require("lspconfig")\|require(.nvim-treesitter.configs.)' "$NVIM_LUA" 2>/dev/null \
         | grep -v ':[[:space:]]*--')
[[ -z $legacy ]] && ok "no deprecated lspconfig framework / treesitter.configs calls" \
                 || no "legacy API still used: $legacy"

PARSERS="$HOME/.local/share/nvim/site/parser"
for lang in rust typescript tsx yaml toml dockerfile just; do
  [[ -f $PARSERS/$lang.so ]] && ok "treesitter parser: $lang" \
                             || no "treesitter parser missing: $lang — needs tree-sitter-cli, then :TSUpdate"
done

# Files on disk, not a headless probe — mason-lspconfig skips
# ensure_installed when nvim is headless (platform.is_headless check in
# its init.lua), so these only appear after a first *real* launch.
MASON_BIN="$HOME/.local/share/nvim/mason/bin"
for server in vtsls lua-language-server vscode-eslint-language-server \
              tailwindcss-language-server vscode-json-language-server \
              yaml-language-server docker-langserver \
              docker-compose-langserver taplo; do
  [[ -x $MASON_BIN/$server ]] && ok "mason server: $server" \
                               || wa "mason server not yet installed: $server — open nvim once (installs on first real launch)"
done

# End to end: does rust-analyzer actually attach to a .rs buffer?
if [[ -d $TMP/probe ]]; then
  attached=$(cd "$TMP/probe" && timeout 60 nvim --headless src/main.rs \
    "+lua vim.defer_fn(function() local n = #vim.lsp.get_clients({ bufnr = 0, name = 'rust-analyzer' }); io.stdout:write('RA=' .. n .. '\n'); vim.cmd('qa!') end, 10000)" 2>&1)
  [[ $attached == *"RA=1"* ]] && ok "rust-analyzer attaches to a .rs buffer (via rustaceanvim)" \
                              || no "rust-analyzer did not attach — check :checkhealth rustaceanvim"
fi

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 7 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 7 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
