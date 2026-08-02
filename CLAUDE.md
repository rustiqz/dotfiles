# dotfiles — project context

Reproducible Arch Linux setup: coding environment first, Hyprland desktop
second. Built on one laptop, then replayed on other machines.

## Current state

- **Machine:** `rustiq` — laptop, Intel Comet Lake-U, UHD Graphics (Gen9.5)
  iGPU, ~8GB RAM, ext4, systemd-boot with a UKI, no discrete GPU.
- **Session:** GNOME. Hyprland is not installed yet. GNOME stays installed
  permanently as a fallback session.
- **Phase 1 complete and verified.** Phase 2 is next.

## Phases

- [x] **0 — Scaffolding.** Stow layout, `bootstrap.sh`, hostname-keyed
      host overrides, `.gitignore`.
- [x] **1 — Base system.** pacman.conf tuning, reflector mirrors, zram,
      PipeWire + rtkit, bluetooth, fonts, Intel graphics stack, microcode,
      thermald, power-profiles-daemon, maintenance timers.
- [ ] **2 — Shell & terminal.** kitty, zsh + plugins, starship, core CLI
      (fzf, ripgrep, fd, bat, eza, zoxide, delta, btop, lazygit, jq).
      TokyoNight theming. *First phase with actual stow packages.*
- [ ] **3 — Dev toolchain.** git config, SSH keys, Node via fnm/mise,
      pnpm, Docker, psql, redis-cli, Temporal CLI, direnv, Bruno.
- [ ] **4 — Editor.** Neovim + lazy.nvim, LSP (vtsls/ts_ls, eslint,
      prettier, lua_ls), tmux, `~/bin/work` launcher.
- [ ] **5 — Hyprland.** Compositor, waybar, launcher, notifications,
      hyprlock/hypridle, clipboard, screenshots, portals, polkit agent,
      GTK/Qt theming. **This is where the session switch happens.**
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
  verify-phase1.sh    read-only assertions; exit criterion per phase
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
