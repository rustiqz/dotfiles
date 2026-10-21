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
#   1. full system sync + upgrade
#   2. installs base tooling (git, stow, build deps)
#   3. installs the AUR helper (paru) if missing
#   4. installs packages listed in packages/*.txt
#   5. backs up any pre-existing real file that would conflict with stow
#   6. symlinks every config package into $HOME via stow
#   7. runs any scripts in hooks/
#   8. warns about commands the session config references but can't find

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
# 1. Full system sync + upgrade
# ---------------------------------------------------------------------------
# Arch's own rule, not just a nice-to-have: never partially upgrade.
# Every later step here installs only the *specific* packages it names
# (`pacman -S <pkgs> --needed`), never the whole system — if the local
# package database is even slightly stale when that happens, pacman
# can end up pulling in a newer version of some library while an
# already-installed package that depends on the *old* one hasn't
# moved yet, since neither side of that pair was named explicitly.
# Hit for real on a second machine: pacman tried to install a newer
# `aquamarine` while the already-installed `hyprtoolkit` (a dependency
# of hyprpaper, which *is* explicitly tracked) still required the old
# libaquamarine soname — "installing aquamarine breaks dependency
# libaquamarine.so=12-64 required by hyprtoolkit". A full sync+upgrade
# first means every package that resolves later in this script resolves
# against one consistent, fully-updated snapshot instead of a mix of
# "whatever was already installed" and "whatever's newest in the repos
# today" — the exact combination that produced this conflict.
log "Full system sync + upgrade"
sudo pacman -Syu --noconfirm

# ---------------------------------------------------------------------------
# 2. Base dependencies
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
# until now — it was just coincidentally already the case on the original machine.
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
# 3. AUR helper
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

# Drop the `rust` package that building paru pulled in. paru's makedepends
# include cargo, so `makepkg -s` installs the repo `rust` package to satisfy
# it — and `rustup` (packages/pacman.txt) conflicts with `rust`. pacman's
# "remove rust?" conflict prompt defaults to No under --noconfirm, so the
# manifest install below aborted on exactly this, on a clean machine. paru
# only needs cargo to build, not to run, so removing it is safe; rustup (plus
# hooks/55-rust-toolchain.sh) is the single source of the toolchain here.
# -Rns without -dd: if something genuinely depends on rust, fail loudly.
if pacman -Qq rust &>/dev/null && ! pacman -Qq rustup &>/dev/null; then
  log "Removing makedepend 'rust' (conflicts with rustup)"
  sudo pacman -Rns --noconfirm rust
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
# 5. Back up pre-existing files that would conflict with stow
# ---------------------------------------------------------------------------
# stow refuses to overwrite a real file with a symlink rather than
# silently clobbering it — the right default, but it means bootstrap.sh
# used to just abort on the first machine that already had its own
# ~/bin/work or ~/.tmux.conf from before this repo existed (hit for
# real cloning onto a second machine that had old manually-created
# dotfiles lying around). This makes that self-healing instead of a
# manual "inspect, mv aside, re-run" loop per file per machine.
#
# `stow -n` (simulate — no real changes yet) against every package
# reports every conflict as a line shaped like:
#   * cannot stow dotfiles/bin/bin/work over existing target bin/work
#     since neither a link nor a directory and --adopt not specified
# The path after "over existing target " and before " since" is the
# conflicting path, relative to $HOME — same regardless of *why* stow
# is refusing (unowned file, wrong-target symlink, etc.), since the
# sed only anchors on the "over existing target ... since" wrapper
# text common to all of them, not the specific reason.
#
# Backs up, never deletes — same reversible-by-default reasoning as
# everywhere else this matters. .pre-dotfiles.bak, not .bak: specific
# enough that a future you finds it and immediately knows why it's
# there, rather than guessing what created a bare ".bak".
#
# NOT --adopt: that flag resolves the conflict the other direction —
# it moves the machine's existing file *into* the repo, overwriting
# whatever this repo already tracks at that path. This backs the old
# file out of the way instead, so the repo's own tracked version is
# what actually ends up live — the correct direction for "replay this
# repo onto a new machine," not "merge whatever this machine already
# had into the repo."
log "Checking for pre-existing files that would conflict with stow"
cd "$DOTFILES"
for pkg in */; do
  pkg=${pkg%/}
  case $pkg in packages|hooks|host|themes|scripts|matugen|orchestra) continue ;; esac
  # Same tracked-only rule as step 6 — never move a file aside to make
  # room for a directory that isn't going to be stowed.
  [[ -z $(git -C "$DOTFILES" ls-files -- "$pkg" | head -1) ]] && continue
  while IFS= read -r rel; do
    [[ -z $rel ]] && continue
    target="$HOME/$rel"
    backup="$target.pre-dotfiles.bak"
    if [[ -e $backup ]]; then
      log "  $target already backed up as $backup — leaving both as-is"
    else
      log "  backing up $target -> $backup"
      mv "$target" "$backup"
    fi
  done < <(stow -n -t "$HOME" "$pkg" 2>&1 \
    | grep "cannot stow" \
    | sed -E 's/.*over existing target ([^ ]+) since.*/\1/')
done

# ---------------------------------------------------------------------------
# 6. Stow config packages
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
# Directories that must be REAL before stowing, never symlinks into this
# repo. stow tree-folds: when a target directory doesn't exist yet, it
# links the whole directory instead of the files inside it. On a fresh
# account that turned out to mean (simulated with `stow -n` against an
# empty $HOME):
#   ~/.local              -> agent-hooks/.local       every app's data and
#                                                      state written into the repo
#   ~/.cargo              -> cargo/.cargo             cargo's registry and
#                                                      build cache (GBs) in the repo
#   ~/.config/systemd     -> systemd/.config/systemd  `systemctl --user enable`
#                                                      writing *.wants/ links into the repo
#   ~/.ssh                -> ssh/.ssh                 the first `ssh-keygen` writing the
#                                                      private key into the repo tree, and
#                                                      known_hosts (not gitignored) one
#                                                      `git add -A` from being committed
# None of it showed on the first machine only because these all already
# existed there — the same "state that exists by accident" shape as the
# clean-machine findings in CLAUDE.md. Creating them first makes stow
# link individual files into real directories, on any machine/account.
for d in .config .config/systemd/user .local/share .local/state .local/bin .cargo .ssh; do
  mkdir -p "$HOME/$d"
done
chmod 700 "$HOME/.ssh"   # ssh refuses keys in a group/world-readable dir
cd "$DOTFILES"
for pkg in */; do
  pkg=${pkg%/}                                                # strip trailing slash
  case $pkg in packages|hooks|host|themes|scripts|matugen|orchestra) continue ;; esac  # not config packages
  # Only stow directories git tracks. An untracked top-level directory
  # (a project parked here, an experiment) would otherwise be symlinked
  # into $HOME wholesale — its README.md becoming ~/README.md. `git add`
  # a new package to have bootstrap pick it up.
  if [[ -z $(git -C "$DOTFILES" ls-files -- "$pkg" | head -1) ]]; then
    log "  skipping untracked directory $pkg/ (not a stow package until committed)"
    continue
  fi
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
# 7. Post-install hooks
# ---------------------------------------------------------------------------
# For state that isn't a file or a package: systemd units, chsh, gsettings.
# Glob order = execution order, so prefix with numbers (10-, 20-) to sequence.
# Each hook must be idempotent for the same reason this script is.
for hook in "$DOTFILES"/hooks/*.sh; do
  [[ -e $hook ]] || continue    # glob stays literal when hooks/ is empty
  log "Hook: $(basename "$hook")"
  bash "$hook"
done

# ---------------------------------------------------------------------------
# 8. Preflight: does the session config reference anything that isn't here?
# ---------------------------------------------------------------------------
# Everything above can succeed completely — every package installed, every
# config stowed, every hook run, exit status 0 — and still leave a desktop
# that comes up looking like a fresh, unconfigured Hyprland. That happens
# whenever a *config* references a binary that no *manifest* installs:
# Hyprland parses `exec-once = uwsm app -- waybar` fine whether or not
# `uwsm` exists, and a bind whose command isn't on $PATH just silently
# does nothing when pressed. There is no error anywhere to notice.
#
# That is exactly how this repo shipped for several commits: `uwsm` was
# never listed in packages/pacman.txt (it had been installed by hand on
# the original machine while Phase 5 was being built, so nothing local ever needed the
# entry), and every exec-once plus every app keybind is written as
# `uwsm app -- <cmd>`. The first machine bootstrapped from a clean clone
# got a compositor with no bar, no wallpaper, no notifications and no
# working keybinds — with bootstrap.sh reporting success each time.
#
# So: derive the list of commands the stowed session config actually
# depends on straight from the config files themselves, rather than
# maintaining a second hardcoded list here that could drift out of sync
# with them, and report any that won't resolve at session start.
session_commands() {
  # `uwsm` is emitted first and separately: every other command below is
  # written as `uwsm app -- <cmd>`, so the wrapper's own name gets stripped
  # off while building the list — and it's precisely the one whose absence
  # takes the whole desktop down rather than one feature.
  grep -lqE 'uwsm[[:space:]]+app[[:space:]]+--' "$DOTFILES"/hypr/.config/hypr/*.lua 2>/dev/null \
    && echo uwsm

  # The compositor config is Lua (hyprland.lua + modules): a command is the
  # string in `hl.exec_cmd("...")`, or the second string argument of the
  # keybinds.lua `exec(keys, "cmd", ...)` helper (the first is the key
  # combo). Both may carry a `uwsm app -- ` prefix, stripped as below.
  # Whole-line comments only are dropped: a trailing `--` is also the
  # `uwsm app --` separator. `|| true`: no match must not trip pipefail.
  sed -E 's/^[[:space:]]*--.*//' "$DOTFILES"/hypr/.config/hypr/*.lua 2>/dev/null \
    | perl -ne 'print "$1\n" while /hl\.exec_cmd\("([^"]*)"/g;
                if (/^\s*exec\(/) { my @s = /"((?:[^"\\]|\\.)*)"/g; print "$s[1]\n" if defined $s[1]; }' \
    | sed -E 's/^uwsm[[:space:]]+app[[:space:]]+--[[:space:]]*//' \
    | awk '{print $1}' \
    | grep -vE '^(\$|$)' || true

  # hypridle's `lock_cmd =` / `on-timeout =` / `on-resume =` (still hyprlang).
  sed -e 's/#.*//' "$DOTFILES"/hypr/.config/hypr/*.conf 2>/dev/null \
    | grep -oE '(exec-once|exec|lock_cmd|on-timeout|on-resume)[[:space:]]*[=,][^#]*' \
    | sed -E 's/^[a-z_-]+[[:space:]]*[=,][[:space:]]*//' \
    | sed -E 's/^pidof[[:space:]]+[^|]*\|\|[[:space:]]*//' \
    | sed -E 's/^uwsm[[:space:]]+app[[:space:]]+--[[:space:]]*//' \
    | awk '{print $1}' \
    | grep -vE '^(\$|$)'    # drop Hyprland variables ($terminal etc.)
}

log "Checking session dependencies"
missing=()
while read -r cmd; do
  [[ -z $cmd ]] && continue
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done < <(session_commands 2>/dev/null | sort -u || true)

# Warn rather than abort: a missing command degrades one feature in almost
# every case, and failing the whole run would leave the machine less
# provisioned than letting it finish. The uwsm case is the exception that
# motivated this block, hence how loud it is. `${missing[@]+...}` because
# `set -u` treats expanding an empty array as an unbound variable.
if (( ${#missing[@]} )); then
  printf '\033[1;33m==> WARNING: %d command(s) referenced by hypr/ are not installed:\033[0m\n' "${#missing[@]}"
  printf '      %s\n' ${missing[@]+"${missing[@]}"}
  printf '    The session will start but these will silently do nothing.\n'
  printf '    Add them to packages/pacman.txt (or aur.txt) — note that a\n'
  printf '    host-<hostname>.txt entry is not enough for anything a shared\n'
  printf '    config references.\n'
fi

log "Bootstrap complete."
