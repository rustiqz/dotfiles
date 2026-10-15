<div align="center">

# dotfiles

**Arch Linux + Hyprland, built around one question: what is my code doing right now?**

![Dev hub over Neovim](docs/screenshots/hub.jpg)

Hyprland · Quickshell · Neovim · kitty + zsh · matugen · GNU Stow

</div>

## What you get

- **Dev status everywhere.** CI, PRs, agents, compose services, dev servers and watchers, surfaced in the bar, a hub drawer and notifications. Notifications only fire when you aren't already looking at the source.
- **Agent-aware.** Claude and Codex sessions report *working / needs input / finished*; <kbd>Enter</kbd> jumps to the window or tmux pane. When a long turn ends, project checks run and a Review action opens Neovim + diffview against `main`.
- **Neovim 0.11+** on the native LSP API (lazy.nvim, Mason, treesitter `main`, blink.cmp, neotest, trouble), with rust-analyzer through rustaceanvim.
- **One theme switch** for the whole desktop, including a palette generated from the current wallpaper (matugen).
- **Reproducible.** `bootstrap.sh` is idempotent; every config is a stow package, everything else a numbered hook.

## Dev hub — `$mod+Space`

Keyboard-first drawer, one letter per section: `a` agents, `c` CI + PRs, `s` compose services, `p` listening dev servers, `w` watchers. Plus volume/brightness/mic, Wi-Fi/Bluetooth/DND toggles, power profile and now-playing.

| Key | In the section |
|---|---|
| `↵` | jump to the agent, open the CI run, show service logs |
| `l` | failed CI log in a terminal |
| `u` / `d` / `z` | services up / down (uses a project's `just up/down`) / lazydocker |

All data comes from `bin/bin/devstat`, which prints the same thing as JSON, so every piece is testable from a terminal. A section that can't be gathered (Docker stopped, `gh` offline) reports why instead of failing. `qs ipc call hub openSection <letter>` opens a section from a script.

## Launcher — `$mod+D`

![Launcher](docs/screenshots/launcher.jpg)

Frecency-ranked apps, with prefix modes: `/` projects (tmux via `work`), `>` run, `@` windows, `=` calculator, `:` emoji, `?` help.

## Terminal and editor

![Terminal workspace](docs/screenshots/terminal.jpg)

- `work` — tmux sessionizer over `~/projects`; `wt new <branch>` — one git worktree per agent task
- `review` / `checks` — the review loop; `queues` — BullMQ status over `valkey-cli`; `ssh-connect` (`$mod+S`) — picker over `~/.ssh/config`
- zsh notifies when a command that ran 30s+ finishes while you're elsewhere
- `$mod+/` opens a live cheatsheet of every Hyprland bind; <kbd>Tab</kbd> flips to a curated Vim/Neovim tab

![Vim cheatsheet](docs/screenshots/cheatsheet.jpg)

## Theming

```sh
theme tokyonight   # default
theme f1           # pixel-art breakaway (partial)
theme wallpaper    # generated from the current wallpaper
theme              # picker
```

Covers kitty, Quickshell, Hyprland, rofi, GTK/Qt, cursor, yazi, k9s, Obsidian, hyprlock and wlogout. Themes can be partial: one that defines a single app leaves the rest alone. `$mod+W` is the wallpaper picker; <kbd>Shift+Enter</kbd> also recolours the desktop.

![Wallpaper picker](docs/screenshots/wallpapers.jpg)

## Install

Arch Linux only. Read `bootstrap.sh` and `hooks/` first: they install packages, enable services and change your login shell.

```sh
git clone https://github.com/rustiqz/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```

It runs `pacman -Syu`, builds `paru`, installs `packages/*.txt`, stows every config into `$HOME` (conflicts move to `*.pre-dotfiles.bak`), then runs `hooks/` in order. Safe to re-run.

Private values live in untracked `*.local` files (git identity, `~/.ssh/config.local`); the matching hook seeds a placeholder. Machine differences go in `packages/host-<hostname>.txt` or `host/<hostname>/`, never a hostname `if` in a shared file.

Verify with the read-only scripts in `scripts/` (`verify-*.sh`); `verify-portability.sh` fails if anything machine-specific is tracked.

## Keybinds

`$mod` = Super; the live list is `$mod+/`.

| | | | |
|---|---|---|---|
| `Return` terminal | `D` launcher | `Space` hub | `/` cheatsheet |
| `B` Firefox | `E` files | `Y` yazi | `C` k9s |
| `S` SSH picker | `N` notifications | `.` emoji | `M` Spotify |
| `W` wallpapers | `Shift+T` themes | `P` power menu | `Escape` lock |
| `h/j/k/l` focus | `Shift+` move | `Ctrl+` resize | `Tab` cycle |

## Layout

```
bootstrap.sh   packages/   hooks/   host/<hostname>/   scripts/
bin/           devstat, theme, work, wt, review, checks, queues, ssh-connect
quickshell/    bar, hub, launcher, popovers, notifications (QML)
themes/        per-app colour files that bin/theme repoints
matugen/       templates for the wallpaper theme
agent-hooks/   plugin that reports agent state to devstat
<app>/         stow packages mirroring $HOME (kitty/, nvim/, hypr/, zsh/ …)
```

Developed on an Intel laptop (Comet Lake-U, integrated graphics, systemd-boot + UKI) and replayed on a second machine. Expect to adjust `packages/host-*.txt`, display and fingerprint setup elsewhere.

## Licence

MIT, see [`LICENSE`](LICENSE) (configs and scripts only). Images in `wallpapers/` are third-party and keep their own terms. TokyoNight, matugen, Quickshell, Hyprland, pokeget and other tools belong to their authors; the Pokémon theming is a homage, not an affiliated project.
