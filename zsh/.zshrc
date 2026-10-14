# ~/.zshrc
#
# Sourced for every interactive shell. Kept flat (no framework like
# oh-my-zsh/zinit) — plugins are Arch packages sourced directly from
# /usr/share/zsh/plugins, so there's nothing here to update or vendor.

# --- PATH ----------------------------------------------------------------------
# Personal scripts (bin/bin/work — the tmux sessionizer). Not something
# Arch adds to PATH by default the way it does ~/.local/bin for some
# packages, so it needs to be explicit here.
export PATH="$HOME/bin:$PATH"

# pnpm global installs (hooks/61-node-globals.sh, e.g. prettier) land in
# $PNPM_HOME/bin — confirmed by actually running `pnpm add -g` and
# reading its error, not from pnpm's docs, which are ambiguous about
# whether PNPM_HOME itself or PNPM_HOME/bin is the right PATH entry.
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"

# --- Editor --------------------------------------------------------------------
# Any tool that shells out to "the editor" (kubectl edit, git commit,
# systemctl edit, crontab) reads $EDITOR. Left unset, kubectl's own
# fallback is the literal command `vi` — which does NOT exist on Arch:
# the `vim` package installs /usr/bin/vim only, and /usr/bin/vi comes
# from the separate `vi` package that nothing here installs. So `e` on
# any resource in k9s ran `kubectl edit`, kubectl exec'd a missing
# binary, and k9s just flashed "Edit command failed" and dropped
# straight back to the table — reading as "k9s closed the editor
# instantly" rather than "no editor is configured".
#
# Also set in uwsm/.config/uwsm/env, deliberately duplicated: this file
# only covers interactive shells, and the $mod+C keybind runs k9s via
# `kitty -e k9s` with no login shell at all (same reasoning as the
# ~/.kube/config symlink in hooks/54-do-config.sh).
export EDITOR="nvim"
export VISUAL="$EDITOR"

# --- History -------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS      # don't record a line if it's a dupe of the previous one
setopt HIST_IGNORE_ALL_DUPS  # ...and drop the older dupe elsewhere in the file
setopt HIST_IGNORE_SPACE     # lines starting with a space aren't recorded
setopt HIST_REDUCE_BLANKS    # trim superfluous whitespace before recording
setopt SHARE_HISTORY         # append+reload live, so parallel shells share history
setopt APPEND_HISTORY

# --- Completion ------------------------------------------------------------
autoload -Uz compinit
# Only re-scan for new completion functions once a day — dumping and
# reparsing the completion cache on every shell start is the single
# biggest cause of slow zsh startup.
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
zstyle ':completion:*' menu select              # arrow-key menu instead of cycling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # case-insensitive matching

# --- Keybindings -----------------------------------------------------------
bindkey -e   # emacs-style bindings (Ctrl-A/E/W etc.) — the terminal default

# --- Plugins -----------------------------------------------------------------
# Installed by packages/pacman.txt. Paths are Arch's standard
# /usr/share/zsh/plugins/<name>/<name>.zsh layout.
#
# zsh-syntax-highlighting MUST be sourced last: it wraps the line-editor
# widgets in use at source time, so anything sourced after it (including
# history-substring-search's bindkeys below) won't get highlighted input.
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up      # Up
bindkey '^[[B' history-substring-search-down    # Down
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- fzf -----------------------------------------------------------------------
# Ctrl-R (history), Ctrl-T (file), Alt-C (cd) fuzzy pickers.
[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh   ]] && source /usr/share/fzf/completion.zsh
# TokyoNight colors so the fzf popup matches everything else instead of
# falling back to the raw terminal defaults.
export FZF_DEFAULT_OPTS="
  --color=bg+:#292e42,bg:#1a1b26,spinner:#9ece6a,hl:#7aa2f7
  --color=fg:#c0caf5,header:#7aa2f7,info:#e0af68,pointer:#9ece6a
  --color=marker:#9ece6a,fg+:#c0caf5,prompt:#e0af68,hl+:#7aa2f7
  --height=40% --layout=reverse --border
"

# --- zoxide ------------------------------------------------------------------
# Replaces `cd`: `z foo` jumps to the frecency-ranked directory matching
# "foo" instead of requiring a full path.
eval "$(zoxide init zsh)"

# --- mise --------------------------------------------------------------------
# Puts the mise-managed Node (version pinned in
# mise/.config/mise/config.toml) on PATH and hooks `cd` to switch
# versions per-project. Installing the pinned versions themselves
# happens once, at bootstrap time, in hooks/51-mise-tools.sh.
eval "$(mise activate zsh)"

# --- direnv ------------------------------------------------------------------
# Auto-loads/unloads .envrc on `cd`. A project has to be explicitly
# `direnv allow`-ed once before its .envrc takes effect — that's direnv
# refusing to blind-execute shell code from a directory you just entered.
eval "$(direnv hook zsh)"

# --- Long-command notifications ------------------------------------------------
# A command that ran >= 30s reports when it finishes — `cargo build
# --release`, `pnpm install`, a test suite — so you can look away and get
# called back. The decision of *whether* to notify lives in `devstat
# cmd-done` (bin/bin/devstat), not here: it skips interactive programs
# (nvim, ssh, lazygit, ...) and stays silent when this terminal is the
# focused window, or the active tmux pane in a focused client — you're
# already watching it. It also logs a cmd-done event for the bar island.
#
# preexec records the start; precmd fires before the next prompt. `&!`
# runs devstat in the background *and* disowns it, so the prompt never
# waits on it and there's no "[1] Done" job noise. $? must be read first
# thing in precmd, before any other command overwrites it.
zmodload zsh/datetime   # $EPOCHSECONDS
autoload -Uz add-zsh-hook
_devstat_preexec() { _devstat_start=$EPOCHSECONDS; _devstat_cmd=$1 }
_devstat_precmd() {
  local st=$?
  [[ -n ${_devstat_start:-} ]] || return 0
  local elapsed=$(( EPOCHSECONDS - _devstat_start ))
  unset _devstat_start
  (( elapsed >= 30 )) && (( $+commands[devstat] )) &&
    devstat cmd-done --elapsed $elapsed --status $st --cmd "$_devstat_cmd" \
      --cwd "$PWD" --pid $$ &!
  return 0
}
add-zsh-hook preexec _devstat_preexec
add-zsh-hook precmd _devstat_precmd

# --- starship ----------------------------------------------------------------
# Must be the last shell-init line — starship's own docs call this out,
# since it needs to observe the prompt state other inits may have set.
eval "$(starship init zsh)"

# --- Aliases -----------------------------------------------------------------
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -l'
alias la='eza --icons --group-directories-first -la'
alias lt='eza --icons --group-directories-first --tree'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias top='btop'
alias lg='lazygit'
alias diff='delta'
alias c='clear'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'

# git: quick status/diff/log checks that don't warrant opening lazygit
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate'

# docker
alias lzd='lazydocker'
alias dc='docker compose'

# kubernetes: k9s covers interactive use, these are for quick one-offs
alias k='kubectl'
alias kgp='kubectl get pods'
alias kctx='kubectl config get-contexts'

# tmux: complements ~/bin/work, the project sessionizer
alias ta='tmux attach'
alias tls='tmux ls'

# pnpm is the default target for global installs (hooks/61-node-globals.sh)
alias pn='pnpm'

# ssh from inside kitty only. kitty advertises TERM=xterm-kitty, whose
# terminfo entry exists on this machine and nowhere else — ssh forwards
# the TERM *name* but not the terminfo database, so remote curses
# programs (vi, nvim, less, top) hit "unknown terminal type" or degrade
# to a broken fallback. `kitten ssh` ships the compiled terminfo into
# the remote's ~/.terminfo, then execs the real ssh.
#
# An alias, not a binary on $PATH: aliases apply to interactive shells
# only, so git-over-ssh, rsync, scp and any script still resolve
# /usr/bin/ssh — the exact breakage bin/bin/ssh-connect's header warns
# about. Guarded on TERM so a non-kitty terminal (or a login over a
# serial/tty console) is untouched, and on kitten existing at all.
if [[ $TERM == xterm-kitty ]] && command -v kitten &>/dev/null; then
  alias ssh='kitten ssh'
fi

# yazi runs as a subprocess, so it can't change its parent shell's directory
# on exit by itself — plain `yazi` always leaves you back where you started
# even after navigating somewhere else inside it. This wrapper (yazi's own
# recommended pattern) has it write the final directory to a temp file on
# quit, then `cd`s the shell there. A function, not an alias, since it needs
# the intermediate variable/cleanup logic.
function y() {
  local tmp
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  local cwd
  if cwd="$(cat -- "$tmp")" && [[ -n $cwd && $cwd != "$PWD" ]]; then
    cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# --- base64, for editing Secrets ---------------------------------------------
# Values under a Secret's `data:` are base64, so adding one in k9s (`e`)
# means encoding it by hand first. Two things make the obvious
# `echo foo | base64` wrong, both of which cost an afternoon:
#
#   - `echo` appends a newline that gets encoded into the value. dHJ1ZQ== is
#     "true", dHJ1ZQo= is "true\n" — the API server accepts both, and the
#     trailing byte then fails string comparisons in the app with nothing
#     anywhere to point at. Hence printf '%s'.
#   - GNU base64 wraps at 76 columns, so anything long (a URL, a JWT, a
#     cert) comes back as multiple lines, and that embedded newline is
#     exactly what kubectl rejects as "illegal base64 data at input byte N".
#     Hence -w0.
#
# b64kv emits the full `  KEY: value` line already indented for a data:
# block, so it pastes into the editor as-is. Quote the argument in all
# three: ?, *, & and $ are live in zsh, and a cron expression like
# '0 8 * * *' glob-expands against the cwd unquoted.
#
# For anything non-trivial, prefer `stringData:` in the same edit — the API
# server encodes it on write and merges it into data:, no base64 involved.
b64()   { printf '%s' "$1" | base64 -w0; echo; }
d64()   { printf '%s' "$1" | base64 -d;  echo; }
b64kv() { printf '  %s: %s\n' "$1" "$(printf '%s' "$2" | base64 -w0)"; }
#
# b64env is the bulk version: hand it a block of env vars, get the whole
# encoded data: block back. Accepts the shapes these values actually
# arrive in — KEY=value from a .env, KEY: value from a manifest, and
# "KEY": "value", from a JSON config — since a paste out of a ticket is
# usually a mix. `export ` prefixes, trailing commas, surrounding quotes,
# blank lines and # comments are all handled; anything it can't parse is
# reported on stderr rather than silently dropped.
#
# With no argument it reads the CLIPBOARD, not the terminal, which is not
# the obvious design but is the only one that works. Pasting into a plain
# `read` loop doesn't: zsh's line editor is what implements bracketed
# paste, and ZLE is not running once the function has started, so kitty
# falls back to sending each newline as ESC E (NEL). The block then
# arrives as a single line and encodes to one enormous bogus value.
# Reading the clipboard sidesteps the terminal entirely. Files and pipes
# are unaffected: `b64env .env.local`, `something | b64env`.
#
# The sed normalisation is belt-and-braces for input that went through a
# terminal anyway — CR endings, NEL from a paste captured to a file, and
# the literal three characters ^[E, which is how that ESC renders if you
# copy a mangled line back out of the scrollback.
#
# `command cat` deliberately: cat is aliased to bat above, and zsh
# expands aliases when a function is *parsed*, so a bare `cat` here would
# resolve to bat and decorate the input.
b64env() {
  local src line key val
  if (( $# == 0 )) && [[ -t 0 ]]; then
    if command -v wl-paste &>/dev/null; then
      print -u2 "b64env: reading clipboard"
      src="$(wl-paste 2>/dev/null)"
    else
      print -u2 "b64env: paste then Ctrl-D — newlines may mangle, prefer a file"
      src="$(command cat)"
    fi
  else
    src="$(command cat -- "$@")"
  fi
  printf '%s\n' "$src" \
    | sed -e 's/\x1bE/\n/g' -e 's/\^\[E/\n/g' -e 's/\xc2\x85/\n/g' -e 's/\r/\n/g' \
    | while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"   # ltrim
    line="${line%"${line##*[![:space:]]}"}"   # rtrim
    [[ -z $line || $line == '#'* ]] && continue
    line="${line#export }"
    line="${line%,}"
    # The key charset excludes : and =, so the first separator after it is
    # unambiguously the delimiter — values containing either (a URL with a
    # scheme and a ?id= query, say) survive intact.
    if [[ $line =~ '^"?([A-Za-z_][A-Za-z0-9_]*)"?[[:space:]]*[:=][[:space:]]*(.*)$' ]]; then
      key="${match[1]}"; val="${match[2]}"
    else
      print -u2 "b64env: skipped unparseable line: $line"
      continue
    fi
    val="${val%,}"
    [[ $val == \"*\" ]] && { val="${val#\"}"; val="${val%\"}"; }
    [[ $val == \'*\' ]] && { val="${val#\'}"; val="${val%\'}"; }
    printf '  %s: %s\n' "$key" "$(printf '%s' "$val" | base64 -w0)"
  done
}

# --- Local overrides -------------------------------------------------------
# Untracked, machine-specific tweaks (work aliases, secrets loaded into
# env, whatever). See .gitignore for the *.local convention.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
export PATH="$HOME/.local/bin:$PATH"

# Cargo-installed binaries (`cargo install` / `cargo binstall`). Appended,
# not prepended: every cargo tool this repo cares about comes from pacman
# (packages/pacman.txt, Phase 7) into /usr/bin, and an older hand-installed
# copy left in ~/.cargo/bin must not shadow it. Anything *only* installed
# via cargo is still found, just last.
export PATH="$PATH:$HOME/.cargo/bin"

# --- Pokémon greeter ----------------------------------------------------------
# A random Pokémon beside system + dev info (bin/bin/pokefetch) — only for
# a brand-new terminal window: the shell's parent must be kitty itself.
# That rules out tmux panes (parent: tmux), Neovim's :terminal, subshells,
# `zsh -c` scripts and SSH sessions without needing a list of exceptions —
# more reliable than $SHLVL, which inherits whatever the session started
# with. POKEFETCH_OFF=1 (e.g. in ~/.zshrc.local) turns it off.
if [[ -o interactive && -z ${POKEFETCH_OFF:-} && $(ps -o comm= -p $PPID 2>/dev/null) == kitty ]] \
   && (( $+commands[pokefetch] )); then
  pokefetch
fi
