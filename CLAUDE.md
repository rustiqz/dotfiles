# dotfiles — project context

Reproducible Arch Linux setup: coding environment first, Hyprland desktop
second. Built on one laptop, then replayed on other machines.

## Current state

- **Machine:** primary laptop — Intel Comet Lake-U, UHD Graphics (Gen9.5)
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
  LSP on 0.11+'s native `vim.lsp.config`/`vim.lsp.enable` (lspconfig is
  a data-only plugin now). Mason installs the server binaries (vtsls,
  eslint, lua_ls, tailwindcss, jsonls, yamlls, dockerls, compose, taplo)
  on nvim's first real launch, not at bootstrap time — needs mise's node
  active in the launching shell (npm-based installs fail silently
  otherwise). rust-analyzer is the exception: rustup component, driven by
  rustaceanvim (`plugins/rust.lua`), never mason.
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
- **The bar is Quickshell, not waybar** (Phase 9). `qs ipc show` lists
  its IPC: `theme reload|name`, `bar brightness|flash <title> <detail>`
  — any script can flash the dev island. waybar's config is kept in the
  repo, unused, as the rollback.
- **Launcher** (`$mod+D`) is the Pokédex in `quickshell/.../modules/
  launcher/`; `qs ipc call launcher openWith /` opens straight into a
  mode. Launch counts ("caught") live in Quickshell's state dir
  (`launcher.json`) and drive ranking. The click-outside scrim shared
  with the hub is `widgets/Scrim.qml`.
- **Dev hub** (`$mod+Space`, also `$mod+grave`): Quickshell drawer,
  `quickshell/.config/quickshell/modules/hub/`. Sections by letter — `a`
  agents (Enter jumps to the window/tmux pane), `c` CI + PRs (Enter
  opens, `l` failed log in a terminal), `s` compose services (Enter logs,
  `u`/`d` up/down via `devstat act`, `z` lazydocker), `p` listening dev
  servers, `w` watchers — plus volume/brightness/mic sliders,
  Wi-Fi/Bluetooth/Silence/Caffeine toggles and now-playing. It replaced
  the ags sidebar (Docker + now-playing); ags is gone from the repo and
  manifests. `qs ipc call hub openSection <letter>` opens a section from
  a script.
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
- Obsidian (notes): vault lives at `~/vault`, its own git repo — not a
  stow package and not this repo, since it's synced separately via the
  `obsidian-git` community plugin. `hooks/62-obsidian-vault.sh` creates
  it (or clones it, if `~/.config/git/obsidian-vault.local` holds a
  remote URL — same `*.local` escape hatch as git identity/ssh config)
  and seeds `.obsidian/appearance.json` so the theme switcher's CSS
  snippet is enabled by default, but only when that run is the one
  creating `.obsidian/` in the first place — never clobbers a real
  cloned vault's existing settings. Themed via a CSS *snippet*
  (`.obsidian/snippets/active-theme.css`), not a full Obsidian theme
  package (`.obsidian/themes/<name>/theme.css` + manifest) — matches
  every other app's "one file, switcher repoints it" shape far better.
  Since the vault isn't stow-managed, `bin/bin/theme` symlinks straight
  into `~/vault/.obsidian/snippets/` instead of through the usual
  `$DOTFILES/<app>/.config/...` stow hop — the one themed app that
  skips that indirection. `theme wallpaper` covers it too, via
  `matugen/templates/obsidian.css.tpl`. Installing the `obsidian-git`
  plugin itself is a one-time manual step (Settings → Community
  plugins → Browse) — community plugins can't be installed headlessly,
  same reasoning as Mason installing LSP binaries on Neovim's first
  real launch, not at bootstrap time.
- k9s is themed through the switcher like everything else
  (`themes/tokyonight/k9s-skin.yaml`, plus
  `matugen/templates/k9s-skin.yaml.tpl` for `theme wallpaper`). k9s
  resolves skins by *filename stem* — same indexing rule as bat's
  themes — so the symlink has to stay `skins/active-theme.yaml`,
  matching `ui.skin: active-theme`. That key is written by
  `hooks/75-k9s-skin.sh` rather than tracked in a config file, because
  **k9s reserialises its own `config.yaml` on exit**, expanding
  defaults including a `screenDumpDir` under an absolute `/home/<user>/`
  path — tracking it would replay the qt5ct/qt6ct username bug through
  a different mechanism. So `k9s/.config/k9s/config.yaml` is gitignored
  and the hook owns only the one key, exactly like `hooks/74-qt-conf.sh`
  and `color_scheme_path`. Verified the skin actually loads by running
  k9s at `-l debug` and reading `~/.local/state/k9s/k9s.log` for
  `Loading skin file`, with a deliberately bogus skin name as the
  negative control (it logs `No custom skin found. Using stock skin`
  and otherwise says nothing at default log level — a broken skin is
  silent).
- **Cluster access is local-only state, deliberately.**
  `~/.config/digitalocean/` (0700, created by `hooks/54-do-config.sh`,
  outside the repo) is the single home for DO cluster credentials, and
  `~/.kube/config` is a **symlink** into it — swapping clusters is a
  repoint, the same active-theme idiom used everywhere else here.
  Deliberately a symlink and not a `KUBECONFIG` env var: `$mod+C` runs
  `kitty -e k9s`, which execs k9s with no login shell, so nothing from
  `.zshrc` exists at that point. Verified by running k9s under `env -i`
  and confirming it still resolved the cluster. These files hold a
  DigitalOcean admin bearer token, so they're never in this repo — same
  class as `~/.ssh/config.local`, one directory up in scale. The specific
  DOKS cluster name, region and namespaces are deliberately not recorded
  here — this repo is public, and naming a live cluster and the platform
  services running on it is reconnaissance, not documentation. It's a
  single-node DOKS cluster running argocd behind an ingress controller. A
  The widely-repeated "kubeconfig expires in 7 days" applies to DO's
  *legacy certificate* flow ("valid for 7 days that cannot be revoked");
  a modern cluster like this one gets a **revocable OAuth token** with
  no such clock, which is what this kubeconfig holds. `doctl` is
  therefore convenience (auto-renewed credentials, easy re-add,
  revocation) rather than a deadline — and it costs a long-lived DO API
  token in plaintext at `~/.config/doctl/config.yaml`, i.e. *more* blast
  radius than a cluster-scoped token unless that DO token is itself
  scoped. Not installed, not in any manifest, deliberately.
  The cluster has no metrics-server, so k9s's CPU/MEM columns read n/a
  (logged as `Fail to locate metrics-server`, not a config problem).
  ArgoCD manages the cluster, so anything edited live in k9s gets
  reverted on next sync — k9s is a read/debug tool here.
- **`bin/bin/devstat`** — what's running/building/waiting across
  projects, as JSON: the data layer the Phase 9/10 bar and hub render.
  Every section degrades to a value that says why (docker stopped →
  `available:false`, gh offline → last result marked `stale`), never an
  exception. Three feeders keep it live without any UI open:
  `devstat-ci.timer` (user unit, every 3 min — notifies when a repo's
  default-branch CI turns red or green), the `devstat-hooks` agent plugin
  (`agent-hooks/`, registered by `hooks/63-agent-hooks.sh` — session
  state + "needs input"/"finished" notifications), and a zsh precmd hook
  (commands >= 30s). All three notify only when you're *not* looking at
  the source — focused window, or the active pane of a focused tmux
  client. Events land in `~/.local/state/devstat/events.jsonl`;
  `DEVSTAT_DEBUG=1` in an agent's environment traces every hook call.
  Projects are `~/projects` *or* `~/Projects` (machines differ; whichever
  is non-empty, or `$PROJECTS_DIR`) — same rule in `bin/bin/work`.
- **`bin/bin/queues`** — BullMQ queue status over `valkey-cli`
  (localhost:6379 by default, `REDIS_HOST`/`REDIS_PORT` to override).
  `queues` prints every queue busiest-first, `queues <name>` adds recent
  failures with their `failedReason`. BullMQ keeps no registry of
  queues, so enumeration is a `SCAN` for `bull:*:meta` — the same thing
  bull-board does internally. Job states span two Redis types and the
  counts must match: `wait`/`active`/`paused` are lists (`LLEN`),
  `delayed`/`failed`/`completed`/`prioritized` are sorted sets
  (`ZCARD`). A never-used state has no key at all, so 0 always means
  "none", never "wrong command". Counts are gathered by piping all
  commands into a single `valkey-cli` rather than one process per
  queue — 20+ queues makes that difference visible.
- **A second machine (a work PC) is now bootstrapped from this repo** —
  see "Clean-machine findings" below for what that replay found and
  fixed, all merged into `main`. Still no `host-<hostname>.txt`/
  `host/<hostname>/` for it: nothing added so far has turned out to be
  genuinely host-specific (everything above is wanted on every
  machine). That mechanism is still there for whenever something
  actually does differ machine to machine (see Conventions).

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
      Fingerprint login: the repo side is done (`hyprlock.conf` ships it
      enabled and self-guarding); whether it actually works is per-machine
      hardware/driver work — see Known gotchas.
- [x] **6 — Finalize.** `README.md` written. Clean-machine proof of
      `bootstrap.sh` done by hand on a real second machine (a work PC)
      instead of a disposable VM (no virtualization tooling on the first
      machine, and a real clone is a more honest test of the actual
      multi-machine goal anyway) — see "Clean-machine findings" below
      for what that replay found and fixed, all now merged into `main`.

Phases 7–12: developer-focused shell + rice, on branch `dev-shell`.
Design borrowed (not copied) from the Prism and surface-dots Quickshell
setups; everything stays wired into `bin/bin/theme` + matugen. Priority
is development speed — anything in those references that isn't for
developers (weather, screen time, pomodoro, phone, shaders) is out.

- [x] **7 — Developer toolchain.** rustup + components/targets
      (`hooks/55-rust-toolchain.sh`), mold + sccache via stowed
      `cargo/.cargo/config.toml`, cargo tools and `just` from pacman,
      Neovim: treesitter `main`-branch rewrite, native LSP API, Rust/
      tailwind/YAML/JSON/Docker/TOML servers, neotest, trouble.
- [x] **8 — `devstat` data layer.** `bin/bin/devstat` (Python stdlib,
      JSON out): focus, ci, services, ports, agents, watchers, projects.
      Agent-state hooks (local plugin, `agent-hooks/`), long-command
      notifications (zsh), CI timer that notifies on red/green
      transitions. Per-project layouts use `work`'s existing hooks
      (`~/.tmux/sessions/<name>.sh` or a repo's `.tmux-session`) rather
      than a new convention; `just` recipes live in each project's repo.
- [x] **9 — Quickshell base + bar.** `quickshell/.config/quickshell/`
      replaces waybar (`uwsm app -- qs` in autostart; waybar stays
      installed as the one-line rollback). Three islands: workspaces with
      app icons + window title; the dev island (focused project/branch/
      dirty, agents, containers, CI — flashes events and doubles as the
      volume/brightness OSD); status (load, net, bt, audio, battery
      capsule, bell, clock, tray, power). Themed via
      `themes/<name>/quickshell.json` + matugen template, cross-fading
      live. `scripts/verify-phase9.sh` 21/21 in the live session;
      **cold-start check (full logout/login) still pending.**
- [x] **10 — Dev hub.** `$mod+Space` right drawer, keyboard-first
      (`a` agents, `c` CI, `s` services, `p` ports, `w` watchers) +
      quick controls + now-playing. `devstat act up|down` for services
      (a project's `just up/down` when present). Retired the ags sidebar
      everywhere. `scripts/verify-phase10.sh` 24/24.
- [x] **11 — Pokédex launcher.** `$mod+D` (and the bar's Arch button;
      right-click → projects). Quickshell `modules/launcher/`: a red
      device with lens + LEDs, a dex "screen" for the selected entry
      (No., type badges from desktop categories via `common/Dex.qml`,
      "caught" launch stats), numbered list. Modes: apps (frecency),
      `/` projects → `work`, `>` run (Shift+Enter in a terminal), `@`
      windows, `=` qalc, `:` emoji (rofimoji's data), `?` help. Apps
      launch as `uwsm app -- <id>.desktop`. Replaced rofi drun; rofi
      stays for the pickers. `scripts/verify-phase11.sh` 19/19.
- [x] **12 — Wallpaper cards + polish.** `$mod+/` cheatsheet (live
      from `hyprctl binds -j`), `$mod+P` power menu (Cassini style; reboot/
      shutdown need a second press; wlogout kept as fallback), `$mod+W`
      Pokémon-card wallpaper picker (type/HP/attacks from each image's own
      palette via ColorQuantizer; Enter sets via `bin/bin/wallpaper NAME`,
      Shift+Enter also `theme wallpaper`), blurred backdrop behind centred
      popups, hyprlock restyle (big clock, spaced date, `@$USER`, pill
      input, battery/now-playing corners), swaync floating under the bar
      at 14px radius. `scripts/verify-phase12.sh` 26/26 — config-level for
      hyprlock: it has no check-only mode and a killed lock strands the
      session, so its first real look is a manual `$mod+Escape`.

Parked: Vaultiq mobile (adb/Metro), monitra uptime row, cluster/queue
sections.

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
- **kitty over ssh needs `kitten ssh`, not `ssh`.** kitty sets
  `TERM=xterm-kitty`; ssh forwards the TERM *name* but not the terminfo
  database behind it, and no remote host has an `xterm-kitty` entry
  unless kitty is installed there. Remote curses programs then fail
  with "unknown terminal type" or silently degrade (broken arrow keys,
  no colors, no clear-screen) — which reads as "kitty is unsupported"
  rather than a missing-file problem. `kitten ssh` copies the compiled
  terminfo into the remote's `~/.terminfo` and execs the real ssh.
  Wired in two places: `bin/bin/ssh-connect` invokes it directly, and
  `zsh/.zshrc` aliases `ssh` to it *only* when `$TERM == xterm-kitty`.
  It has to be a shell alias and never a binary on `$PATH` — aliases
  don't apply to git-over-ssh, rsync, scp or any script, which is the
  breakage `ssh-connect`'s own header warns about. Escape hatch for a
  remote that can't run the wrapper (restricted shell, embedded box):
  `TERM=xterm-256color ssh <host>` — worse, but universally understood.
- Fingerprint sensors differ per machine, so this repo deliberately names
  no specific reader — an earlier version of this note hardcoded one
  machine's sensor and was simply wrong on the next one. Always derive
  the actual device on the box from `/sys/bus/usb/devices/*/idVendor` and
  `idProduct` (`lsusb`/`usbutils` isn't installed), never from notes.
  Most readers have no upstream libfprint driver and only a proprietary
  vendor TOD module, so expect: TOD-enabled libfprint (AUR
  `libfprint-tod-git`, which provides *and* conflicts with `libfprint`),
  then the vendor's TOD driver, then `fprintd`. Install the TOD libfprint
  **before** `fprintd`, or pacman pulls `extra/libfprint` in to satisfy
  `libfprint-2.so` and the two collide — that ordering, not the driver
  itself, is what makes this look unsupportable at first. Nothing about
  any of this belongs in the repo: `hyprlock.conf` enables fingerprint
  unconditionally and self-disables wherever there's no reader, and PAM
  wiring (`/etc/pam.d/*`) is machine-local by nature.

- **nvim-treesitter's `main` branch is a different plugin from
  `master`.** No `nvim-treesitter.configs` module, no `ensure_installed`/
  `highlight.enable` options, no lazy-loading; parsers are compiled
  locally and need `tree-sitter-cli` (pacman, not npm) + a C compiler.
  lazy.nvim moved this repo onto `main` without anyone noticing: the old
  config threw "module not found" on every file open and every buffer
  silently fell back to regex highlighting. Caught by a headless probe
  reading `vim.treesitter.highlighter.active`, not by eye — regex
  highlighting looks close enough to pass casually.
- **mason-lspconfig skips `ensure_installed` when nvim is headless**
  (`not platform.is_headless` in its init.lua). That's the real reason
  servers only appear "on first real launch". To install headlessly for
  testing, call `require("mason-lspconfig.features.ensure_installed")()`
  directly.
- **Upstream tailwindcss LSP config attaches in every git repo** — its
  root_dir falls back to `.git` to support tailwind v4 (no config file).
  Narrowed in `plugins/lsp.lua` to config files or a `package.json`
  mentioning tailwind, with both a negative (Vaultiq server) and a
  positive (throwaway v4 project) control.
- **Compose files need the compound filetype `yaml.docker-compose`** for
  the compose language server to attach; Neovim assigns plain `yaml`.
  Set in `config/options.lua`, plus `vim.treesitter.language.register`
  so the compound filetype still gets the yaml parser.
- **`~/.cargo/config.toml` must not be stowed before mold + sccache
  exist.** It names both as the linker/rustc wrapper, so linking it
  early makes *every* cargo build on the machine fail. bootstrap.sh
  installs packages before stowing, which is the right order; by hand,
  install first.

- **An installed agent plugin is only enabled via settings.json.** The
  plugin docs say a plugin with no `enabledPlugins` entry starts enabled
  (`defaultEnabled`); with `~/.claude/settings.json` moved aside,
  `claude plugin list` reported `devstat-hooks` as `✘ disabled`. And that
  file is orchestra's: `orchestra on` does a plain `mv` of its parked
  symlink over whatever is there. So the plugin's two keys
  (`extraKnownMarketplaces.dotfiles-local`,
  `enabledPlugins["devstat-hooks@dotfiles-local"]`) must exist in
  whichever settings file is active; `hooks/63-agent-hooks.sh` checks,
  and never writes through orchestra's symlink.
- **Async agent hooks still starting when a session exits are killed.**
  In a headless run, Stop and SessionEnd launched together and only
  SessionEnd's code ran (found with `DEVSTAT_DEBUG=1` after a silent
  `except: pass` hid it), so finished turns were never recorded. Stop and
  UserPromptSubmit are synchronous (~80ms once per turn); the rest stay
  async.
- **`PATH=<narrowed> timeout ...` looks `timeout` up in the narrowed PATH**
  — resolve helpers with `command -v` *before* narrowing PATH in a test.

- **A file watch on a symlink doesn't see the symlink being repointed.**
  `ln -sf` replaces the *link*; Quickshell's FileView (`watchChanges`)
  keeps watching the file it originally resolved to. So `theme <name>`
  silently left the bar on the old palette — found by pointing the link
  at a red test palette and screenshotting a still-blue bar. Fixed with an
  explicit `qs ipc call theme reload` from `bin/bin/theme`, the same
  "the switcher tells each app" pattern as swaync/waybar. Any future
  watcher on an `active-theme.*` link needs the same.
- **QML property names can collide with built-ins.** `console` is
  reserved ("Illegal property name"), and `Text` already defines a FINAL
  `top` ("Cannot override FINAL property"). Both surfaced only as a load
  failure chain naming the outermost type ("Type Bar unavailable") — read
  the *last* "caused by" line, it names the real file and line.

- **Quickshell IPC function names: avoid CLI words and JS reserved
  words.** A function named `show` can't take arguments from the CLI —
  `qs ipc call hub show c` is parsed against the `qs ipc show`
  subcommand. Renamed to `goto`, the reload logged "Configuration
  Loaded" yet `qs ipc show` still listed the *old* handler: `goto` is
  reserved in JS, the new handler silently didn't register. Check `qs
  ipc show` after adding a function, not just the log.
- **Animate layer-panel slides with a `Translate`, not `x`.** `x: open ?
  0 : width + gap` on the hub's content was a binding loop (the window
  sizes from its content) — warned on every open, caught by the verify
  script's clean-log check.

- **`HyprlandFocusGrab` never clears on a layer with exclusive keyboard
  focus.** The hub's grab went active on open but never fired `cleared`
  — not on an outside click (reported by use), not even when focus moved
  to another window via `hyprctl dispatch focuswindow` (traced with
  console.info). Click-outside-to-close is a full-screen transparent
  scrim layer one level under the hub instead; it needs nothing from
  the compositor. There's no input simulator installed (ydotool/wtype),
  so verify-phase10 asserts the scrim's geometry and stacking, not the
  click itself.

- **Quickshell needs the icon theme set explicitly** —
  `//@ pragma IconTheme Papirus-Dark` in `shell.qml` (startup-only, a
  live reload won't apply it). Without it Qt looked in bare hicolor:
  launcher icons logged "Could not load icon" and the `?fallback=` in
  `Quickshell.iconPath` didn't help, since the fallback name has to
  resolve through the same theme.
- **Hover selection must ignore a pointer that isn't moving.** List rows
  appearing or reordering under a still pointer fire both `onEntered`
  and position events; either way the launcher opened with the wrong
  row selected. Compare `mapToGlobal` coordinates against the last
  event and only follow real movement.
- **A missing binary gives a Quickshell `Process` no exit code to
  read** — it never starts. Check presence up front (`sh -c 'command -v
  x'`) instead of waiting for a 127 that never comes.

- **Portability is checked, not assumed: `scripts/verify-portability.sh`.**
  Run it before committing anything that adds a dependency or a stow
  package. It fails on a tracked file containing this account's home
  path/username, on any command the shell/scripts call whose package
  isn't in a manifest (or base/base-devel), and on stow tree-folding
  `~/.local`, `~/.cargo`, `~/.ssh` or `~/.config/systemd` into the repo
  on an empty `$HOME`. Its first run (2026-10-14) found all three kinds:
  `gh` hand-installed and required by nothing, `python`/`libnotify`/
  `xdg-utils`/`less` only present via GNOME's dependencies, and on a
  fresh account stow would have folded `~/.local` (every app's data),
  `~/.cargo` (cargo's registry) and `~/.ssh` (the first private key)
  into the repo. bootstrap.sh now pre-creates those as real directories
  (`~/.ssh` at 0700) and stows only directories git tracks — an
  untracked `orchestra/` would otherwise have landed in `$HOME`.

## Clean-machine findings (second machine, 2026-08-15)

The Phase 6 clean-machine replay finally happened, onto an existing
GNOME/SDDM Arch box with a different hostname *and* a different username
from the first machine — which is itself what surfaced several of these,
since anything that had quietly baked in the original username broke.
It found four bugs, all the same shape:
**state that existed on the first machine because it was created by hand during
Phase 5, and that nothing in the repo actually reproduces.** Worth
re-reading before adding anything themeable or session-related.

- **A config can reference a binary no manifest installs, and every
  layer still reports success.** `uwsm` was never in `packages/*.txt`
  (it had been installed by hand on the first machine), yet every `exec-once` in
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
  `brightnessctl` lived in the host-specific manifest, but
  `hypr/hypridle.conf` and `hypr/keybinds.conf` — shared by every machine
  — reference it unconditionally. Moved to `packages/pacman.txt`. A
  `host-<hostname>.txt` entry can only ever cover packages that nothing
  in a shared package refers to.

- **Qt config can't reference `$HOME` at all.** `qt5ct.conf`/`qt6ct.conf`
  store the palette as `color_scheme_path=`, and Qt's QSettings INI
  format expands nothing — not `$HOME`, not `~`. So a tracked copy
  necessarily bakes in one machine's username, and it did:
  `/home/<other-user>/.config/...`, which meant Qt theming silently did nothing
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
  all three were already installed on the first machine. A clean machine would get
  Hyprland and no way to log into it. All now in `packages/pacman.txt`.
- **A `*.local` escape hatch nothing seeds is invisible on a clean
  machine.** `$mod+S` did nothing on the second machine: `~/.ssh/config.local`
  never existed there, so `ssh-connect`'s host list was empty and it
  exited 1 — into a Hyprland keybind, whose stderr goes nowhere. Same
  shape as the four above (hand-made first-machine state), but the file
  genuinely *can't* be tracked, so the fix is discoverability, not
  tracking: `hooks/53-ssh-config-local.sh` seeds a commented placeholder
  (create-only-if-missing, like `50-git-identity.sh`), and `ssh-connect`
  now also reports the empty-host case via `notify-send`. Anything a
  keybind calls has to surface its own failures — nothing else will.

**Display manager is now an explicit decision, not an accident.**
The first machine ran GDM because its GNOME install had enabled it; the second ran
SDDM for the same accidental reason — and that is *why* the second
machine got the plain `hyprland.desktop` session instead of the uwsm one
(`hyprland-uwsm.desktop` carries `TryExec=uwsm`, so any DM correctly
hides it until `uwsm` is installed). `hooks/20-services.sh` now disables
whatever display manager it finds enabled and enables `gdm.service`.
Deliberately **without** `--now`: switching display manager live kills the
running session, including the terminal running `bootstrap.sh`. It takes
effect at the next boot.
