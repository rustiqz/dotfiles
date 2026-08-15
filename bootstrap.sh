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

# makepkg !debug, before anything ever calls makepkg: paru itself gets
# built via makepkg two steps from here, and any AUR package installed
# later also goes through it — both happen before hooks/ ever runs
# (hooks are the *last* thing bootstrap.sh does), so this can't be a
# hook the way pacman.conf tuning is (hooks/10-pacman-conf.sh). Without
# it, a fresh machine builds a paru-debug package alongside paru, which
# then collides with any stale -debug package still on disk from a
# previous install attempt — hit for real on a second machine
# bootstrapped from this exact repo ("paru-debug: .../paru.debug
# exists in filesystem, owned by paru-bin-debug"). CLAUDE.md already
# documented !debug as a known gotcha, but nothing actually enforced it
# until now — it was just coincidentally already the case on rustiq.
#
# Three-way check instead of a single sed, since a truly fresh
# /etc/makepkg.conf's default OPTIONS array isn't guaranteed to already
# mention debug at all, and blindly substituting a token that might not
# exist would silently no-op instead of fixing anything:
#   1. !debug already present — nothing to do.
#   2. bare `debug` present — flip it to `!debug`.
#   3. neither present — append `!debug` before the closing paren.
MAKEPKG_CONF=/etc/makepkg.conf
if grep -qE '^OPTIONS=\([^)]*!debug' "$MAKEPKG_CONF"; then
  :
elif grep -qE '^OPTIONS=\([^)]*\bdebug\b' "$MAKEPKG_CONF"; then
  sudo sed -i -E 's/^(OPTIONS=\([^)]*)\bdebug\b/\1!debug/' "$MAKEPKG_CONF"
else
  sudo sed -i -E 's/^(OPTIONS=\([^)]*)\)/\1 !debug)/' "$MAKEPKG_CONF"
fi

# ---------------------------------------------------------------------------
# 2. AUR helper
# ---------------------------------------------------------------------------
# paru wraps pacman and adds AUR support with the same flags, which is why
# install_list() below can call `pacman` and `paru` interchangeably.
# Source paru, NOT paru-bin: the prebuilt binary is linked against
# whatever libalpm soname was current on the AUR build server at
# packaging time, and breaks outright ("error while loading shared
# libraries: libalpm.so.N: cannot open shared object file") the next
# time pacman itself bumps that soname — hit for real on a second
# machine bootstrapped from this exact repo. Source paru rebuilds
# against whatever libalpm is actually installed, so it can't drift
# out of sync the same way. Built in a temp dir because the source
# tree is disposable after install.
#
# `paru --version` as the guard, not `command -v paru`: the latter
# passes even for a binary with unresolvable shared libraries — which
# is exactly how the libalpm breakage above went unnoticed by this
# script (it saw *a* paru on $PATH and skipped straight past the
# install step) — same reasoning already applied in verify-phase1.sh's
# own AUR check, just never carried over to this one until now. This
# also makes bootstrap.sh self-healing: re-running it on a machine
# with a currently-broken paru rebuilds it instead of silently
# skipping past the problem again.
if ! paru --version &>/dev/null; then
  log "Installing paru (AUR helper)"
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
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
