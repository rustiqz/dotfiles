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
- Wallpaper-driven theme: `theme wallpaper` is a third theme alongside
  tokyonight/f1, except generated instead of hand-written —
  `matugen/config.toml` + `matugen/templates/*.tpl` (Material You
  scheme-tonal-spot, dark mode) regenerate `themes/wallpaper/*`
  (gitignored, derived data) from whatever wallpaper is currently set,
  every time that command runs. Never automatic on a wallpaper pick —
  a deliberate separate step. The 16-color ANSI terminal palette isn't
  extracted from the image directly (matugen's base16 backend
  degenerates to near-monochrome on low-chroma wallpapers, confirmed
  by testing) — it's synthesized by hue-rotating the generated
  `primary` color to fixed target hues instead, guaranteeing 6
  distinguishable colors regardless of source image.
- Coding/media tooling (shared across every machine, not host-specific
  — see below): `playerctl`, `spotify`, `lazydocker`, `k9s`, `stern`,
  `pgcli`, `kubectl`, `yazi` (+ `ffmpegthumbnailer`/`p7zip` for
  previews). `bin/bin/ssh-connect` (`$mod+S`) is a rofi picker over
  `~/.ssh/config` `Host` entries — real hostnames/IPs live in untracked
  `~/.ssh/config.local` (`ssh/.ssh/config`'s tracked base just has an
  `Include`), same `*.local` pattern as git identity.
- Now-playing and Docker status live in the ags desktop widget sidebar
  (`$mod+grave`), not waybar — waybar's `mpris`/`custom/docker` modules
  were removed once the sidebar covered both in more detail (see the
  "desktop widget sidebar" note below).
- yazi (`$mod+Y`, opens in a kitty window) is themed through the same
  switcher as everything else — flavors are looked up by *directory*
  name (`~/.config/yazi/flavors/<name>.yazi/`), so `bin/bin/theme`
  symlinks a whole directory here (`ln -sfrT`) rather than one file
  like every other app. `themes/tokyonight/yazi-flavor/` was vendored
  from the real `BennyOe/tokyo-night.yazi` flavor (installed via
  `ya pkg add` into a scratch config to confirm the real schema first)
  — its hex values already matched this repo's palette exactly, so
  it's that file verbatim. `theme wallpaper` covers it too, via
  `matugen/templates/yazi-flavor.toml.tpl`.
- A work PC is planned but not yet bootstrapped from this repo — no
  `host-<hostname>.txt`/`host/<hostname>/` exists for it yet since
  nothing added so far has turned out to be genuinely host-specific
  (everything above is wanted on every machine). That mechanism is
  still there for whenever something actually does differ machine to
  machine (see Conventions).

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
- [ ] **6 — Finalize.** `README.md` written. Clean-machine proof of
      `bootstrap.sh` deliberately done by hand on a real second machine
      instead of a disposable VM (no virtualization tooling on `rustiq`
      yet, and a real clone is a more honest test of the actual
      multi-machine goal anyway) — phase stays open until that's
      actually happened once.

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
- Never partially upgrade — `bootstrap.sh` now runs `pacman -Syu`
  before installing anything named, specifically because a second
  machine hit "installing aquamarine breaks dependency
  libaquamarine.so=12-64 required by hyprtoolkit": pacman tried to
  pull in a newer `aquamarine` while the already-installed
  `hyprtoolkit` (a dependency of the explicitly-tracked `hyprpaper`)
  still needed the old soname, since neither package is named directly
  in any manifest and each was only getting resolved against whatever
  the local package database happened to say at that moment.
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

## Clean-machine findings (second machine, `rakshith`, 2026-08-15)

The Phase 6 clean-machine replay finally happened, onto an existing
GNOME/SDDM Arch box (hostname `rakshith`, user `rakshith` — note the
username is *not* `rustiq`). It found four bugs, all the same shape:
**state that existed on `rustiq` because it was created by hand during
Phase 5, and that nothing in the repo actually reproduces.** Worth
re-reading before adding anything themeable or session-related.

- **A config can reference a binary no manifest installs, and every
  layer still reports success.** `uwsm` was never in `packages/*.txt`
  (it had been installed by hand on `rustiq`), yet every `exec-once` in
  `hypr/autostart.conf` and every app keybind in `hypr/keybinds.conf` is
  written `uwsm app -- <cmd>`. Hyprland parses those fine whether or not
  the binary exists, and a bind whose command isn't on `$PATH` silently
  does nothing. Result on a clean machine: compositor starts, no bar, no
  wallpaper, no notifications, no working keybinds — indistinguishable
  from "Hyprland came up unconfigured", with nothing logged anywhere.
  `bootstrap.sh` step 8 now derives the referenced-command list straight
  from the stowed hypr configs and warns about any that won't resolve.
- **`swaync-client` blocks forever when swaync isn't running.** It
  D-Bus-activates, fails, prints "Will wait for connection..." and never
  returns — `command -v swaync-client` does not guard against this.
  `bin/bin/theme` called it unguarded, and `hooks/73-theme.sh` (the last
  hook) calls that script, so **`bootstrap.sh` hung one step from the end
  on every single run** — far enough in to look finished and get Ctrl-C'd.
  Everything in `theme` after the swaync block (the Qt colour links, the
  uwsm `env-theme` link) therefore never ran. Now guarded on `pidof
  swaync` plus a `timeout`. General lesson: anything in a hook that talks
  to a session daemon must assume that daemon is *not* running, because
  bootstrap is by definition run from some other session.
- **git does not track empty directories.** `qt6ct/.config/qt6ct/colors/`
  and the qt5ct equivalent only ever contain `active-theme.conf`, which
  is gitignored — so they simply don't exist after a clean clone, and
  `bin/bin/theme`'s `ln -sfr` into a missing directory fails silently
  (that script is deliberately `set -uo pipefail`, not `-e`). Both now
  carry a `.gitkeep`. Any directory whose only contents are gitignored
  needs one.
- **A shared config may only depend on a shared manifest.**
  `brightnessctl` lived in `packages/host-rustiq.txt`, but
  `hypr/hypridle.conf` and `hypr/keybinds.conf` — shared by every machine
  — reference it unconditionally. Moved to `packages/pacman.txt`. A
  `host-<hostname>.txt` entry can only ever cover packages that nothing
  in a shared package refers to.

- **Qt config can't reference `$HOME` at all.** `qt5ct.conf`/`qt6ct.conf`
  store the palette as `color_scheme_path=`, and Qt's QSettings INI
  format expands nothing — not `$HOME`, not `~`. So a tracked copy
  necessarily bakes in one machine's username, and it did:
  `/home/rustiq/.config/...`, which meant Qt theming silently did nothing
  on any other machine (qt6ct just ignores a path that doesn't resolve).
  Now the `__DOTFILES__` pattern from `matugen/config.toml`: tracked
  `qt{5,6}ct.conf.in` with a `__HOME__` placeholder, generated `.conf`
  gitignored, `hooks/74-qt-conf.sh` expands it. That hook seeds the file
  when missing but otherwise *only* rewrites the `color_scheme_path`
  line — qt6ct rewrites this file itself whenever its GUI is used, so
  regenerating wholesale would discard the user's own settings. Same
  reason `[SettingsWindow]` is not in the template.
- **The login manager was never tracked either.** CLAUDE.md has claimed
  GDM + a permanent GNOME fallback since Phase 5, but neither `gdm` nor
  `gnome-shell` (nor `nautilus`, bound to `$mod+E`) was in any manifest —
  all three were already installed on `rustiq`. A clean machine would get
  Hyprland and no way to log into it. All now in `packages/pacman.txt`.
- **A `*.local` escape hatch nothing seeds is invisible on a clean
  machine.** `$mod+S` did nothing on `rakshith`: `~/.ssh/config.local`
  never existed there, so `ssh-connect`'s host list was empty and it
  exited 1 — into a Hyprland keybind, whose stderr goes nowhere. Same
  shape as the four above (hand-made `rustiq` state), but the file
  genuinely *can't* be tracked, so the fix is discoverability, not
  tracking: `hooks/53-ssh-config-local.sh` seeds a commented placeholder
  (create-only-if-missing, like `50-git-identity.sh`), and `ssh-connect`
  now also reports the empty-host case via `notify-send`. Anything a
  keybind calls has to surface its own failures — nothing else will.

**Display manager is now an explicit decision, not an accident.**
`rustiq` ran GDM because its GNOME install had enabled it; `rakshith` ran
SDDM for the same accidental reason — and that is *why* the second
machine got the plain `hyprland.desktop` session instead of the uwsm one
(`hyprland-uwsm.desktop` carries `TryExec=uwsm`, so any DM correctly
hides it until `uwsm` is installed). `hooks/20-services.sh` now disables
whatever display manager it finds enabled and enables `gdm.service`.
Deliberately **without** `--now`: switching display manager live kills the
running session, including the terminal running `bootstrap.sh`. It takes
effect at the next boot.
