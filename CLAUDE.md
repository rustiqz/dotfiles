# dotfiles — project context

Reproducible Arch Linux setup: coding environment first, Hyprland desktop
second. Built on one laptop, then replayed on other machines.

## Current state

- **Machine:** `rustiq` — laptop, Intel Comet Lake-U, UHD Graphics (Gen9.5)
  iGPU, ~8GB RAM, ext4, systemd-boot with a UKI, no discrete GPU.
- **Session:** Hyprland (uwsm-managed, `hyprland-uwsm.desktop` in GDM) is
  now the primary session. GNOME stays installed permanently as a fallback.
- **Shell:** zsh (login shell switched in `hooks/40-shell.sh`).
- **Node:** managed by mise, not a system package — see
  `mise/.config/mise/config.toml`.
- **Docker group membership** requires a re-login on this machine before
  `docker` works without `sudo` — see `hooks/52-docker.sh`.
- **Git identity** lives in untracked `~/.config/git/config.local`, not
  in this repo — see `hooks/50-git-identity.sh`.
- **Editor:** Neovim/lazy.nvim, plugin specs under `nvim/.config/nvim/lua/plugins/`.
  Mason installs LSP binaries (vtsls, lua_ls, eslint) on nvim's first
  real launch, not at bootstrap time — needs mise's node active in the
  launching shell (npm-based installs fail silently otherwise).
- **`~/bin/work`** — tmux project sessionizer, searches `~/projects`.
- **Phase 4 and Phase 5 complete and verified** (`scripts/verify-phase4.sh`,
  `scripts/verify-phase5.sh`, 0 failures each). Confirmed via a full
  logout/login, not just a live reload, that session-start-only state
  (cursor theme, `QT_QPA_PLATFORMTHEME`, `PATH` in Hyprland's own
  environment) survives a cold start.
- Whole-desktop theme switcher (`bin/bin/theme`) covers kitty, waybar,
  rofi, Hyprland, swaync, Qt, GTK, cursor, uwsm-env, and wlogout.
  `themes/tokyonight/` is the full default; `themes/f1/` is a
  deliberately partial pixel-art breakaway (swaync only so far —
  `bin/bin/theme f1` leaves everything else on TokyoNight's styling
  until the rest of f1/ is filled in).
- Quick-access keybinds added on top of Phase 5: theme picker
  (`$mod shift+T`), app launchers (`$mod+B` Firefox, `$mod+E` nautilus),
  power menu (`$mod+P`, wlogout, TokyoNight-styled), emoji picker
  (`$mod+.`, rofimoji), window cycling (`$mod+Tab`).
- Known small gap, not blocking: `dolphin` is installed but unused
  (`nautilus` won the `$mod+E` decision).

## Phases

- [x] **0 — Scaffolding.** Stow layout, `bootstrap.sh`, hostname-keyed
      host overrides, `.gitignore`.
- [x] **1 — Base system.** pacman.conf tuning, reflector mirrors, zram,
      PipeWire + rtkit, bluetooth, fonts, Intel graphics stack, microcode,
      thermald, power-profiles-daemon, maintenance timers.
- [x] **2 — Shell & terminal.** kitty, zsh + plugins, starship, core CLI
      (fzf, ripgrep, fd, bat, eza, zoxide, delta, btop, lazygit, jq).
      TokyoNight theming. *First phase with actual stow packages.*
- [x] **3 — Dev toolchain.** git config, SSH keys, Node via mise, pnpm,
      Docker, psql (postgresql), valkey-cli (redis-cli's Arch successor),
      Temporal CLI, direnv, Bruno.
- [x] **4 — Editor.** Neovim + lazy.nvim, LSP (vtsls, eslint, prettier,
      lua_ls) via mason, blink.cmp completion, fzf-lua finder
      (reuses the real `fzf`/`rg` binaries), tmux (TPM: resurrect +
      continuum), `~/bin/work` launcher.
- [x] **5 — Hyprland.** Compositor, waybar, rofi launcher, notifications,
      hyprlock/hypridle/hyprpaper, clipboard, screenshots, portals,
      polkit agent, GTK/Qt/icon/cursor theming, whole-desktop theme
      switcher (`bin/bin/theme`), quick-access keybinds (theme picker,
      app launchers, power menu, emoji picker, window cycling).
      **Session switch complete: Hyprland is primary, GNOME is fallback.**
      Optional follow-up: fingerprint login (see Known gotchas — no
      official package, AUR `libfprint-ft9201` is the option).
- [ ] **6 — Finalize.** Prove `bootstrap.sh` on a clean VM. Write README.

## Repo layout

```
bootstrap.sh          idempotent provisioner; safe to re-run any time
packages/
  pacman.txt          official repos, shared across machines
  aur.txt             AUR, shared
  host-<hostname>.txt official repos, this machine only
hooks/                post-install scripts, run in filename order
host/<hostname>/      per-machine config fragments, stowed separately
scripts/
  verify-phase<N>.sh  read-only assertions; exit criterion per phase
  dump-repo.sh        dump structure + contents for handoff
<app>/                stow packages, e.g. kitty/.config/kitty/kitty.conf
```

## Conventions — follow these

- **Every config change lands in this repo.** Nothing configured only via
  a GUI or only in shell history. If it can't be a file, it's a hook.
- **Stow packages** are top-level dirs whose inner tree mirrors `$HOME`.
  `bootstrap.sh` stows all of them except `packages/`, `hooks/`, `host/`,
  `scripts/`. Adding an app config requires no script change.
- **Everything is idempotent.** Hooks and `bootstrap.sh` must be safe to
  re-run. Guard mutations; prefer `--needed`, `enable --now`, and seds
  that match both the pre- and post-change state.
- **Machine differences** are expressed two ways only: a
  `packages/host-<hostname>.txt` entry, or a config fragment in
  `host/<hostname>/` sourced by the shared config. Never `if hostname`
  branches in shared files.
- **Comment generously.** Every script and config explains what each
  block does and why, not just what it runs. This repo doubles as
  documentation.
- **Manifests support inline comments.** `install_list` strips from `#`
  onward, then all whitespace.
- **No secrets.** SSH keys, `.env`, tokens are gitignored. `*.local`
  files are the untracked escape hatch; shared configs source them
  conditionally.
- **Theme:** TokyoNight, applied consistently across terminal, fzf, bat,
  delta, Neovim, and later GTK/Qt.
- **Font:** JetBrainsMono Nerd Font.

## Working agreement

- Explain what each component does while building it — not just commands.
- I run privileged commands (`sudo pacman`, `systemctl enable`) myself.
  You write and edit the repo files.
- End each phase with a `scripts/verify-phase<N>.sh` following the
  pass/fail/warn pattern in `verify-phase1.sh`.
- Commit per phase with a descriptive message.

## Known gotchas hit so far

- `paru-bin` breaks on libalpm soname bumps — use source `paru`.
- `makepkg.conf` has `!debug` set; stale `-debug` packages caused file
  conflicts on reinstall.
- Microcode comes from the mkinitcpio `microcode` hook (UKI boot), not a
  bootloader entry. No loader edits needed.
- PipeWire services are socket-activated: `is-enabled` reports `disabled`
  while the service is active. That's correct.
- In verify scripts, never pipe a producer straight into `grep -q` under
  `set -o pipefail`: `grep -q` exits on first match and closes the pipe,
  SIGPIPE-ing the producer, and pipefail reports that as pipeline
  failure even though the match succeeded. Capture into a variable first
  and grep the variable.
- Same scripts: use `PASS=$((PASS+1))`, not `((PASS++))`, for the
  pass/fail/warn counters. Postfix `++` evaluates to the *old* value, so
  the first increment (0 -> 1) evaluates to 0, which `((...))` reports
  as failure — silently flipping whichever `&&`/`||` chain called it.
- `stow` tree-folds: a brand-new target directory gets one symlink for
  the whole directory, not one per file inside it. Don't assert `-L` on
  individual file paths — resolve with `realpath` and check it lands
  inside the repo instead.
- bat indexes custom (non-bundled) themes by **filename stem**, not the
  `name` key inside the `.tmTheme` XML. The downloaded TokyoNight file's
  internal name is `TokyoNight`, but `bat --list-themes` / `--theme=`
  and delta's `syntax-theme` both need `tokyonight_night` (the filename).
  Confirmed by actually installing it and running `--list-themes`, not
  by reading the XML.
- `git config --global --get <key>` only reads the literal `~/.gitconfig`
  file — it does *not* follow into `~/.config/git/config` (the XDG
  fallback) even though that file is genuinely part of the "global"
  precedence tier for normal, unscoped resolution. This is why
  `git/.config/git/config`'s identity `[include]` (see
  `hooks/50-git-identity.sh`) has to be checked with unscoped
  `git config <key>`, not `--global`, when verifying it actually
  resolves — `--global` is still the right flag for confirming
  `~/.gitconfig` itself stays clean, since that's specifically what it reads.
- pnpm global installs (`pnpm add -g`) go to `$PNPM_HOME/bin`, and pnpm
  refuses to install at all if that exact directory isn't on `$PATH` —
  confirmed by actually running it and reading the error, not from docs
  (which are ambiguous about whether `PNPM_HOME` itself or `PNPM_HOME/bin`
  is the right entry). Set in zsh/.zshrc and hooks/61-node-globals.sh.
- mason.nvim's npm-based LSP installs (vtsls, eslint-lsp) spawn `npm` as
  a subprocess and fail silently-ish ("could not find executable npm")
  if the shell that launched Neovim never activated mise — lua_ls has no
  such dependency (standalone binary asset, not an npm package), which
  is why only two of the three servers failed the first time this was
  tried headless without `eval "$(mise activate bash)"` first.
- The laptop's fingerprint sensor is a FocalTech FT9201 (USB `2808:9338`,
  visible via `/sys/bus/usb/devices/*/product` since `lsusb`/`usbutils`
  isn't installed) with no official Arch package and no upstream
  libfprint support. AUR `libfprint-ft9201` (proprietary TOD driver,
  drop-in `libfprint-2-2` replacement) is the only option — it conflicts
  with `extra/libfprint` on install. Deferred; see Phase 5 follow-up.
