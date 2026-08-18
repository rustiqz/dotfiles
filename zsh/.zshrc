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

# --- Local overrides -------------------------------------------------------
# Untracked, machine-specific tweaks (work aliases, secrets loaded into
# env, whatever). See .gitignore for the *.local convention.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
export PATH="$HOME/.local/bin:$PATH"
