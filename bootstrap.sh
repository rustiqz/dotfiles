#!/usr/bin/env bash
#
# bootstrap.sh — provision an Arch machine from this dotfiles repo.
#
# Safe to run repeatedly: every step is idempotent, so this doubles as
# the "apply my latest changes" command, not just first-time setup.
#
# Usage:  ./bootstrap.sh
#
# What it does, in order:
#   1. installs base tooling (git, stow, build deps)
#   2. installs the AUR helper (paru) if missing
#   3. installs packages listed in packages/*.txt
#   4. symlinks every config package into $HOME via stow
#   5. runs any scripts in hooks/

# -e  abort on the first failing command, so a broken step can't cascade
# -u  treat unset variables as errors (catches typo'd var names)
# -o pipefail  a pipeline fails if ANY stage fails, not just the last one
set -euo pipefail

# Resolve this script's own directory, so the script works no matter
# where it is invoked from (`./bootstrap.sh`, `~/dotfiles/bootstrap.sh`, etc).
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Static hostname is the key for all per-machine behaviour below.
# Set it before first run:  sudo hostnamectl set-hostname laptop
HOST="$(hostnamectl --static 2>/dev/null || hostname)"

# Blue "==>" progress lines, so it's obvious which phase failed if one does.
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# Guard: this script makes Arch-specific assumptions (pacman, AUR, paru).
command -v pacman >/dev/null || { echo "This script targets Arch Linux."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Base dependencies
# ---------------------------------------------------------------------------
# base-devel: compilers + makepkg, required to build anything from the AUR
# git:        cloning this repo and AUR packages
# stow:       the symlinking itself
# --needed:   skip packages already installed (keeps re-runs fast and quiet)
log "Base dependencies"
sudo pacman -S --needed --noconfirm base-devel git stow

# ---------------------------------------------------------------------------
# 2. AUR helper
# ---------------------------------------------------------------------------
# paru wraps pacman and adds AUR support with the same flags, which is why
# install_list() below can call `pacman` and `paru` interchangeably.
# paru-bin ships a prebuilt binary — avoids a multi-minute Rust compile.
# Built in a temp dir because the source tree is disposable after install.
if ! command -v paru >/dev/null; then
  log "Installing paru (AUR helper)"
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
  (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

# Reads a manifest file and feeds it to the given installer command.
#   $1        = path to manifest
#   $2..      = installer command (e.g. `sudo pacman`, `paru`)
#
# Manifest format: one package per line. Both full-line comments and
# trailing inline comments are supported, e.g.
#     pipewire-alsa    # ALSA apps route through PipeWire
#
# Parsing, in order:
#   sed 's/#.*//'         strip everything from the first # onward
#   sed 's/[[:space:]]//g' strip all remaining whitespace (package names
#                          never contain any, so this is safe and also
#                          removes the indentation left behind above)
#   grep -v '^$'          drop lines that are now empty
install_list() {
  local file=$1; shift
  [[ -f $file ]] || return 0                 # manifest is optional
  log "Packages: $(basename "$file")"
  # -r on xargs: do nothing if the manifest is empty rather than running
  #              the installer with no arguments (which would error)
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$file" \
    | grep -v '^$' \
    | xargs -r "$@" -S --needed --noconfirm
}

install_list "$DOTFILES/packages/pacman.txt"      sudo pacman   # official repos
install_list "$DOTFILES/packages/aur.txt"         paru          # AUR
install_list "$DOTFILES/packages/host-$HOST.txt"  paru          # this machine only

# ---------------------------------------------------------------------------
# 4. Stow config packages
# ---------------------------------------------------------------------------
# Every top-level directory is treated as a stow package, except the
# non-config dirs. New app configs are picked up automatically — you
# never have to edit this script to add one.
#
# themes/ added here alongside the original three: its inner structure
# (themes/<name>/kitty.conf etc.) doesn't mirror $HOME at all — it's
# data bin/bin/theme reads from, not something to symlink in directly.
# Stowing it would create bogus top-level symlinks like ~/tokyonight.
# scripts/ also added: CLAUDE.md's own documented repo layout already
# listed it as a non-package dir alongside these three, but it was
# missing from this exclusion list — same bogus-symlink risk (would
# have created e.g. ~/verify-phase1.sh directly in $HOME), just never
# hit because scripts/ happened not to be tried until now.
# matugen/ same reasoning as themes/: matugen/config.toml and
# matugen/templates/*.tpl are generation input bin/bin/theme reads
# from directly (via `matugen --config`), never symlinked into $HOME.
log "Stowing configs"
mkdir -p "$HOME/.config"     # stow links INTO this; it must exist first
cd "$DOTFILES"
for pkg in */; do
  pkg=${pkg%/}                                                # strip trailing slash
  case $pkg in packages|hooks|host|themes|scripts|matugen) continue ;; esac  # not config packages
  stow -R -t "$HOME" "$pkg"                          # -R = idempotent restow
done

# Host-specific fragments live one level deeper, so stow is pointed at
# host/ as its package directory and asked for the package named after
# this machine. Absent on machines without overrides — hence the guard.
if [[ -d "$DOTFILES/host/$HOST" ]]; then
  log "Stowing host overrides for $HOST"
  stow -R -d "$DOTFILES/host" -t "$HOME" "$HOST"
fi

# ---------------------------------------------------------------------------
# 5. Post-install hooks
# ---------------------------------------------------------------------------
# For state that isn't a file or a package: systemd units, chsh, gsettings.
# Glob order = execution order, so prefix with numbers (10-, 20-) to sequence.
# Each hook must be idempotent for the same reason this script is.
for hook in "$DOTFILES"/hooks/*.sh; do
  [[ -e $hook ]] || continue    # glob stays literal when hooks/ is empty
  log "Hook: $(basename "$hook")"
  bash "$hook"
done

log "Bootstrap complete."
