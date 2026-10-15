# dotfiles

Reproducible Arch Linux setup: coding environment first, Hyprland desktop
second. Built on one laptop, meant to be replayed on others —
one command re-provisions a fresh machine to the same state.

TokyoNight everywhere by default, with a wallpaper-driven theme generated
on demand and a pixel-art breakaway theme for notifications.

## Quick start

HTTPS, not SSH: a fresh machine has no SSH key registered with GitHub
yet, so an SSH clone fails before anything else can run. (Private repo:
`gh auth login` first, or use a token.) Works for any account and any
username — nothing in the repo bakes in a home path.

```sh
git clone https://github.com/rustiqz/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

`bootstrap.sh` is idempotent — safe to re-run any time (after pulling new
changes, after adding a package to a manifest, whatever). It:

1. Installs base tooling (`git`, `stow`, `base-devel`)
2. Installs `paru` (AUR helper) if missing
3. Installs everything listed in `packages/*.txt`
4. Symlinks every app config into `$HOME` via GNU Stow
5. Runs the hooks in `hooks/` (systemd units, shell change, git identity
   seed, theme default, etc. — anything that isn't just a file)

Verify any phase is actually working with its own script:

```sh
./scripts/verify-phase1.sh   # base system
./scripts/verify-phase2.sh   # shell & terminal
./scripts/verify-phase3.sh   # dev toolchain
./scripts/verify-phase4.sh   # editor
./scripts/verify-phase5.sh   # Hyprland desktop
```

Each is read-only and reports pass/fail/warn per check — nothing to
interpret, just run it.

## What's inside

| Phase | Status | Covers |
|---|---|---|
| 0 — Scaffolding | ✅ | Stow layout, `bootstrap.sh`, `.gitignore`, host overrides |
| 1 — Base system | ✅ | pacman tuning, mirrors, zram, PipeWire, bluetooth, fonts, Intel graphics, microcode, power management |
| 2 — Shell & terminal | ✅ | kitty, zsh, starship, fzf/ripgrep/fd/bat/eza/zoxide/delta/btop/lazygit, TokyoNight theming |
| 3 — Dev toolchain | ✅ | git, SSH, Node (mise), Docker, psql, valkey-cli, Temporal CLI, direnv, Bruno |
| 4 — Editor | ✅ | Neovim + lazy.nvim, LSP via mason, tmux (TPM), `~/bin/work` sessionizer |
| 5 — Hyprland | ✅ | Compositor, waybar, rofi, notifications, lock/idle/wallpaper, screenshots, theming, quick-access keybinds |
| 6 — Finalize | ⏳ | This README. Clean-machine bootstrap gets validated by hand on each new machine rather than a disposable VM. |

## Highlights

### Whole-desktop theme switcher

```sh
theme tokyonight   # default
theme f1           # pixel-art breakaway (currently: notifications only)
theme wallpaper    # generated from whatever wallpaper is set
theme              # interactive picker (rofi)
```

One command re-themes kitty, waybar, rofi, Hyprland borders/hyprlock,
swaync, wlogout, Qt (qt6ct/qt5ct), GTK/icon/cursor, yazi, Obsidian, and
the desktop widget sidebar together. Each theme lives in `themes/<name>/` and can be
partial — a theme that only defines one app's file leaves everything
else on whatever was active before.

`theme wallpaper` is the interesting one: it doesn't have a
hand-written `themes/wallpaper/` directory at all. Running it invokes
[matugen](https://github.com/InioX/matugen) against the current
wallpaper (`matugen/config.toml` + `matugen/templates/*.tpl`), extracts
a Material You palette, and regenerates every themed app's colors from
it on the spot — never automatically, only when you ask.

### Bar and dev hub

The bar is [Quickshell](https://quickshell.org) (`quickshell/`): three
floating islands, with a centre "dev island" showing the focused
project's branch and dirty state, running agents, containers and CI —
and briefly expanding for events (CI red/green, an agent needing input,
a long command finishing) and as the volume/brightness OSD.

`$mod + Space` opens the dev hub: a keyboard-driven drawer with agents
(`a`), CI and PRs (`c`), compose services with up/down/logs (`s`),
listening dev servers (`p`) and watch-mode builders (`w`), plus volume,
brightness, mic, Wi-Fi/Bluetooth/Do-not-disturb/Caffeine toggles and
now-playing. All data comes from `bin/bin/devstat`, which prints the same
thing as JSON in a terminal.

### Keybinds

Everything below assumes `$mod` = Super.

| Bind | Action |
|---|---|
| `Return` | Terminal |
| `D` | App launcher (rofi) |
| `Q` | Close window |
| `Shift+E` | Exit session |
| `B` | Firefox |
| `E` | Files (nautilus) |
| `M` | Spotify |
| `S` | SSH picker (`~/.ssh/config` hosts) |
| `P` | Power menu (wlogout) |
| `.` | Emoji picker |
| `` ` `` | Toggle desktop widget sidebar |
| `Shift+T` | Theme picker |
| `W` | Wallpaper picker |
| `Escape` | Lock screen |
| `h/j/k/l` | Focus movement (vim-style) |
| `Shift+h/j/k/l` | Move window |
| `Ctrl+h/j/k/l` | Resize window |
| `Tab` / `Shift+Tab` | Cycle windows forward/back |
| `1-9`, `0` | Switch workspace |
| `Shift+1-9`, `Shift+0` | Move window to workspace |
| `Ctrl+V` / `Ctrl+Shift+V` | Clipboard history / wipe history |

Screenshot binds are the one exception to the `$mod`-everywhere rule above —
listed here with the modifier spelled out in full each time:

| Bind | Action |
|---|---|
| `Print` | Screenshot region |
| `$mod+Ctrl+Print` | Screenshot region, then edit |
| `$mod+Print` | Screenshot window |
| `$mod+Alt+Print` | Screenshot window, then edit |
| `$mod+Shift+Print` | Screenshot full screen |
| `$mod+Shift+Ctrl+Print` | Screenshot full screen, then edit |

## Repo layout

```
bootstrap.sh          idempotent provisioner; safe to re-run any time
packages/
  pacman.txt           official repos, shared across every machine
  aur.txt              AUR, shared
  host-<hostname>.txt  official repos, this machine only
hooks/                 post-install scripts, run in filename order
host/<hostname>/       per-machine config fragments, stowed separately
scripts/
  verify-phase<N>.sh   read-only assertions, exit criterion per phase
  dump-repo.sh         dump structure + contents for handoff
themes/<name>/         per-theme color/config files (bin/bin/theme reads these)
matugen/               templates + config for the generated wallpaper theme
orchestra/             optional agent workflow; installed with orchestra/install.sh
<app>/                 stow packages, e.g. kitty/.config/kitty/kitty.conf
```

Every other top-level directory is a stow package — its inner tree
mirrors `$HOME` exactly, and `bootstrap.sh` symlinks it in automatically.
Adding a new app's config needs no changes to `bootstrap.sh` itself,
just a new directory shaped like `<app>/.config/<app>/...`.

## Conventions

- **Every config change lands in this repo.** Nothing configured only
  through a GUI or left in shell history. If it can't be a file, it's a
  hook.
- **Everything is idempotent.** Safe to re-run `bootstrap.sh` or any
  hook at any time.
- **Machine differences** go one of two places only: a
  `packages/host-<hostname>.txt` entry, or a config fragment in
  `host/<hostname>/`. Never a hostname conditional inside a shared file.
- **No secrets.** SSH keys, `.env`, tokens are gitignored. Any config
  needing an untracked local value sources a sibling `*.local` file
  (git identity, SSH hosts, shell PATH tweaks from third-party
  installers — anything machine- or person-specific).
- **Font:** JetBrainsMono Nerd Font, everywhere icons show up.

## Multi-machine notes

Nothing in this repo is host-specific yet beyond `packages/host-<hostname>.txt`
(CPU microcode — hardware-dependent, doesn't belong in the shared
manifest). Everything else — including the coding/media tooling, the
theme switcher, and the desktop widgets — installs the same way on any
machine that bootstraps from this repo.

If you're cloning onto a machine that already has its own configs for
something this repo manages, `bootstrap.sh` moves each conflicting file to
`<name>.pre-dotfiles.bak` before stowing. Review those backups after the
first run. It leaves a conflict in place if that backup name already exists.
