#!/usr/bin/env bash
#
# verify-phase8.sh — assert that Phase 8 (devstat data layer) is applied:
# devstat itself, its failure modes, the agent hook plugin, the
# long-command shell hook, the CI timer, and `work`'s project lookup.
#
# Read-only for real state: every write-path test (agent hook, cmd-done)
# runs against a mktemp XDG_STATE_HOME/XDG_CACHE_HOME, deleted on exit.
# No notifications are sent — the write-path tests run from this script's
# own process tree, and notify-send is shadowed by a no-op on $PATH.
#
# Exit code 0 = all checks passed, 1 = at least one failure.

set -uo pipefail

PASS=0; FAIL=0; WARN=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Plain assignment, not `((PASS++))` — see verify-phase1.sh.
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
wa() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

# realpath, not -L — see verify-phase2.sh (stow tree-folding).
chk_link() {
  local path=$1
  if [[ -e $path || -L $path ]]; then
    local target
    target=$(realpath -e "$path" 2>/dev/null) || { no "$path is a broken symlink"; return; }
    [[ $target == "$DOTFILES"/* ]] && ok "linked: $path" \
                                    || no "$path resolves outside this repo ($target)"
  else
    no "$path missing"
  fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DEVSTAT="$HOME/bin/devstat"

# A PATH where notify-send is a no-op, so write-path tests stay silent.
mkdir -p "$TMP/shim"
printf '#!/bin/sh\nexit 0\n' >"$TMP/shim/notify-send"
chmod +x "$TMP/shim/notify-send"
QUIET_PATH="$TMP/shim:$PATH"

# ---------------------------------------------------------------------------
hdr "devstat sections (real data)"
# ---------------------------------------------------------------------------
chk_link "$DEVSTAT"
for s in focus services ports agents watchers projects; do
  out=$(timeout 30 "$DEVSTAT" "$s" 2>"$TMP/err")
  if jq -e . >/dev/null 2>&1 <<<"$out"; then
    if jq -e 'type == "object" and has("error") and (keys | length) == 1' >/dev/null <<<"$out"; then
      no "section $s raised: $(jq -r .error <<<"$out")"
    else
      ok "section $s → valid JSON"
    fi
  else
    no "section $s → not JSON: $(head -c 200 "$TMP/err")"
  fi
done
ci=$(timeout 60 "$DEVSTAT" ci 2>/dev/null)
if jq -e '.available == true' >/dev/null 2>&1 <<<"$ci"; then
  ok "section ci → $(jq -r '[.repos[] | "\(.slug | split("/")[1])=\(.state)"] | join(" ")' <<<"$ci")"
elif jq -e . >/dev/null 2>&1 <<<"$ci"; then
  wa "section ci unavailable: $(jq -r .error <<<"$ci") (gh offline/unauthenticated?)"
else
  no "section ci → not JSON"
fi

# ---------------------------------------------------------------------------
hdr "devstat failure modes"
# ---------------------------------------------------------------------------
out=$(DOCKER_HOST=unix:///nonexistent.sock timeout 20 "$DEVSTAT" services)
jq -e '.available == false and .projects == []' >/dev/null 2>&1 <<<"$out" \
  && ok "docker unreachable → services available:false (not an error)" \
  || no "docker unreachable → unexpected: $out"

# PATH with everything devstat needs except gh.
mkdir -p "$TMP/nogh"
for b in git ss docker hyprctl tmux; do
  p=$(command -v "$b") && ln -sf "$p" "$TMP/nogh/$b"
done
py=$(command -v python3)
# Resolved up front: `PATH=... timeout` would look timeout up in the
# narrowed PATH too, and fail with "command not found".
to=$(command -v timeout)
out=$(PATH="$TMP/nogh" XDG_CACHE_HOME="$TMP/emptycache" "$to" 20 "$py" "$DEVSTAT" ci)
jq -e '.available == false' >/dev/null 2>&1 <<<"$out" \
  && ok "gh missing, no cache → ci available:false" \
  || no "gh missing, no cache → unexpected: $out"
if [[ -f $HOME/.cache/devstat/ci.json ]]; then
  mkdir -p "$TMP/cache/devstat" && cp "$HOME/.cache/devstat/ci.json" "$TMP/cache/devstat/"
  out=$(PATH="$TMP/nogh" XDG_CACHE_HOME="$TMP/cache" "$to" 20 "$py" "$DEVSTAT" ci --refresh)
  jq -e '.stale == true and (.repos | length) > 0' >/dev/null 2>&1 <<<"$out" \
    && ok "gh missing, cache present → last result served, marked stale" \
    || no "gh missing, cache present → unexpected: $(head -c 200 <<<"$out")"
fi
"$DEVSTAT" nope &>/dev/null && no "unknown section accepted" || ok "unknown section rejected"

# ---------------------------------------------------------------------------
hdr "agent hook (devstat agent-event)"
# ---------------------------------------------------------------------------
export_state() { XDG_STATE_HOME="$TMP/state" PATH="$QUIET_PATH" "$DEVSTAT" agent-event "$@"; }
ev() { printf '{"hook_event_name":"%s","session_id":"verify","cwd":"%s"%s}' "$1" "$DOTFILES" "${2:-}"; }
SF="$TMP/state/devstat/agents/verify.json"

out=$(ev SessionStart | export_state); rc=$?
[[ $rc -eq 0 && -z $out ]] && ok "SessionStart: exit 0, nothing on stdout" \
                          || no "SessionStart printed '$out' / rc=$rc (stdout becomes model context)"
[[ $(jq -r .status "$SF" 2>/dev/null) == idle ]] && ok "SessionStart → idle" || no "SessionStart did not record idle"
ev UserPromptSubmit | export_state
[[ $(jq -r .status "$SF" 2>/dev/null) == working ]] && ok "UserPromptSubmit → working" || no "UserPromptSubmit did not record working"
ev SessionStart | export_state
[[ $(jq -r .status "$SF" 2>/dev/null) == working ]] && ok "late SessionStart doesn't reset a live session" \
                                                    || no "late SessionStart reset status to $(jq -r .status "$SF")"
ev Notification ',"message":"Permission needed"' | export_state needs-input
[[ $(jq -r .status "$SF" 2>/dev/null) == needs-input ]] && ok "Notification(permission) → needs-input" \
                                                        || no "Notification did not record needs-input"
ev UserPromptSubmit | export_state; ev Stop | export_state
grep -q '"agent-done"' "$TMP/state/devstat/events.jsonl" 2>/dev/null \
  && ok "working → Stop records an agent-done event" || no "no agent-done event after Stop"
ev SessionEnd | export_state
[[ ! -e $SF ]] && ok "SessionEnd removes the state file" || no "state file survived SessionEnd"
out=$(printf 'not json at all' | export_state); rc=$?
[[ $rc -eq 0 && -z $out ]] && ok "garbage stdin → still exit 0, silent" || no "garbage stdin → rc=$rc out='$out'"

# ---------------------------------------------------------------------------
hdr "Agent hook plugin"
# ---------------------------------------------------------------------------
HJ="$DOTFILES/agent-hooks/.local/share/agent-hooks/devstat-hooks/hooks/hooks.json"
chk_link "$HOME/.local/share/agent-hooks/.claude-plugin/marketplace.json"
sync=$(jq -r '[.hooks.UserPromptSubmit[0].hooks[0].async, .hooks.Stop[0].hooks[0].async] | map(. // false) | @tsv' "$HJ" 2>/dev/null)
[[ $sync == $'false\tfalse' ]] && ok "UserPromptSubmit + Stop handlers synchronous (ordering / not killed on exit)" \
                               || no "UserPromptSubmit/Stop async flags: $sync — see agent-hooks README"
baked=$(grep -c "/home/" "$HJ")
[[ $baked -eq 0 ]] && ok "hooks.json has no absolute home path baked in" || no "hooks.json contains /home/ paths"
if command -v claude &>/dev/null; then
  plugins=$(claude plugin list 2>/dev/null)
  if grep -A4 'devstat-hooks@dotfiles-local' <<<"$plugins" | grep -q 'enabled'; then
    ok "devstat-hooks@dotfiles-local installed and enabled"
  else
    no "devstat-hooks not enabled — run hooks/63-agent-hooks.sh (see its symlink note)"
  fi
else
  wa "agent CLI not installed — plugin not checked"
fi

# ---------------------------------------------------------------------------
hdr "Long-command shell hook"
# ---------------------------------------------------------------------------
fns=$(zsh -ic 'print -l $preexec_functions $precmd_functions' 2>/dev/null)
grep -q _devstat_preexec <<<"$fns" && grep -q _devstat_precmd <<<"$fns" \
  && ok "zsh preexec/precmd hooks registered" || no "zsh hooks not registered — check zsh/.zshrc"
XDG_STATE_HOME="$TMP/cmd" PATH="$QUIET_PATH" "$DEVSTAT" cmd-done --elapsed 45 --status 2 --cmd "cargo test" --cwd "$DOTFILES"
XDG_STATE_HOME="$TMP/cmd" PATH="$QUIET_PATH" "$DEVSTAT" cmd-done --elapsed 900 --status 0 --cmd "nvim x" --cwd "$DOTFILES"
evs=$(cat "$TMP/cmd/devstat/events.jsonl" 2>/dev/null)
[[ $(grep -c cmd-done <<<"$evs") -eq 1 ]] && grep -q '"status": 2' <<<"$evs" \
  && ok "cmd-done records a failed build, skips an interactive nvim session" \
  || no "cmd-done events unexpected: $evs"

# ---------------------------------------------------------------------------
hdr "CI timer"
# ---------------------------------------------------------------------------
chk_link "$HOME/.config/systemd/user/devstat-ci.timer"
[[ $(systemctl --user is-enabled devstat-ci.timer 2>/dev/null) == enabled ]] && ok "devstat-ci.timer enabled" || no "devstat-ci.timer not enabled (hooks/64-devstat.sh)"
[[ $(systemctl --user is-active devstat-ci.timer 2>/dev/null) == active ]] && ok "devstat-ci.timer active" || no "devstat-ci.timer not active"
res=$(systemctl --user show devstat-ci.service -p Result --value 2>/dev/null)
[[ $res == success ]] && ok "last CI refresh succeeded" || wa "last CI refresh result: ${res:-never ran}"

# ---------------------------------------------------------------------------
hdr "Projects"
# ---------------------------------------------------------------------------
n=$("$DEVSTAT" projects | jq length)
(( n > 0 )) && ok "devstat finds $n project(s)" || no "devstat finds no projects (~/projects or ~/Projects)"
out=$(PROJECTS_DIR=/nonexistent "$HOME/bin/work" 2>&1); rc=$?
[[ $rc -ne 0 && $out == *"not a directory"* ]] && ok "work: bad PROJECTS_DIR is an error, not an empty picker" \
                                                || no "work: bad PROJECTS_DIR → rc=$rc '$out'"
[[ ! -d $DOTFILES/bin/bin/__pycache__ ]] && ok "no __pycache__ beside bin/bin/devstat" \
                                         || wa "bin/bin/__pycache__ exists (gitignored, harmless — delete it)"

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 8 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 8 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
