#!/usr/bin/env bash
#
# verify-agents.sh — assert agent launching and plan-limit display work:
# `devstat statusline` (snapshot, 80/95% alerts once per window, never
# fails), `devstat usage` (Claude snapshot + Codex logs, reset windows
# reported as reset), the status line set in the active settings without
# a baked-in home path, `agent-start` argument handling, the launcher's
# `+` mode, the hub's n/x keys and the island's usage chip.
#
# Never starts an agent and never sends a notification: write paths run
# against a scratch XDG_STATE_HOME with notify-send shadowed by a no-op.
#
# Exit code 0 = all checks passed, 1 = at least one failure.

set -uo pipefail

PASS=0; FAIL=0; WARN=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="$DOTFILES/quickshell/.config/quickshell"

# Plain assignment, not `((PASS++))` — see verify-phase1.sh.
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
wa() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DS="$HOME/bin/devstat"
mkdir -p "$TMP/shim"
printf '#!/bin/sh\necho "$@" >>"%s/notified"\n' "$TMP" >"$TMP/shim/notify-send"
chmod +x "$TMP/shim/notify-send"

# ---------------------------------------------------------------------------
hdr "devstat statusline"
# ---------------------------------------------------------------------------
R=$(( $(date +%s) + 7200 )); W=$(( $(date +%s) + 400000 ))
mk() { printf '{"model":{"display_name":"Test"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":30},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":40,"resets_at":%s}}}' "$DOTFILES" "$1" "$R" "$W"; }
sl() { mk "$1" | PATH="$TMP/shim:$PATH" XDG_STATE_HOME="$TMP/st" "$DS" statusline; }
line=$(sl 70 | sed 's/\x1b\[[0-9;]*m//g')
[[ $line == *"5h 70%"* && $line == *"wk 40%"* && $line == *"ctx 30%"* ]] && ok "line: $line" || no "unexpected line: '$line'"
[[ -s $TMP/st/devstat/claude-limits.json ]] && ok "rate_limits snapshot written" || no "no snapshot written"
sl 85 >/dev/null; sl 86 >/dev/null
n=$(grep -c 'limit-warning' "$TMP/st/devstat/events.jsonl" 2>/dev/null || echo 0)
[[ $n == 1 ]] && ok "80% crossing alerts exactly once (70 → 85 → 86)" || no "limit-warning events: $n (expected 1)"
sl 96 >/dev/null
n=$(grep -c '"level": 95' "$TMP/st/devstat/events.jsonl" 2>/dev/null || echo 0)
[[ $n == 1 ]] && ok "95% crossing alerts separately" || no "95% alert count: $n"
out=$(printf 'not json' | "$DS" statusline); rc=$?
[[ $rc -eq 0 && -n $out ]] && ok "garbage input → still prints, exit 0 (never breaks the session's bar)" || no "garbage input → rc=$rc out='$out'"

# ---------------------------------------------------------------------------
hdr "devstat usage"
# ---------------------------------------------------------------------------
u=$(XDG_STATE_HOME="$TMP/st" "$DS" usage)
jq -e '.claude.available and .claude.session.used == 96 and .claude.week.used == 40' >/dev/null <<<"$u" \
  && ok "claude limits read back from the snapshot" || no "claude usage: $(jq -c .claude <<<"$u")"
# A snapshot whose window has already reset must report 0, flagged reset.
printf '{"ts": 1, "rate_limits": {"five_hour": {"used_percentage": 90, "resets_at": 2}}}' >"$TMP/st/devstat/claude-limits.json"
u=$(XDG_STATE_HOME="$TMP/st" "$DS" usage)
jq -e '.claude.session.used == 0 and .claude.session.reset == true' >/dev/null <<<"$u" \
  && ok "a window past its reset time reports 0%, flagged reset" || no "stale window: $(jq -c .claude.session <<<"$u")"
real=$("$DS" usage)
jq -e 'has("claude") and has("codex")' >/dev/null <<<"$real" && ok "real usage: claude=$(jq -r '.claude.available' <<<"$real") codex=$(jq -r '.codex.available' <<<"$real")" \
                                                       || no "real usage malformed"
grep -q 'AGENT_DAEMON_ARGS' "$DS" && ok "codex's app-server daemon excluded from sessions" || no "no daemon exclusion in devstat"

# ---------------------------------------------------------------------------
hdr "Status line configured"
# ---------------------------------------------------------------------------
SETTINGS=$(readlink -f "$HOME/.claude/settings.json" 2>/dev/null)
if [[ -f $SETTINGS ]]; then
  cmd=$(jq -r '.statusLine.command // empty' "$SETTINGS")
  [[ $cmd == *"devstat"*"statusline"* ]] && ok "active settings ($SETTINGS) run devstat statusline" \
                                           || wa "statusLine is '$cmd' — someone else's status line wins (by design); no Claude limits then"
  [[ $cmd != *"$HOME"* ]] && ok "status-line command has no baked-in home path" || no "status line bakes in $HOME"
else
  wa "no ~/.claude/settings.json — agent CLI not set up here"
fi

# ---------------------------------------------------------------------------
hdr "Starting agents"
# ---------------------------------------------------------------------------
AS="$HOME/bin/agent-start"
"$AS" bogus /tmp &>/dev/null; rc=$?
[[ $rc -eq 2 ]] && ok "agent-start rejects an unknown agent (rc=2)" || no "agent-start bogus → rc=$rc"
PATH="$TMP/shim:$PATH" "$AS" claude /nonexistent-dir &>/dev/null; rc=$?
[[ $rc -eq 1 ]] && ok "agent-start refuses a missing directory (and says so)" || no "missing dir → rc=$rc"
grep -q '"+": agentRows' "$QS/modules/launcher/Launcher.qml" && ok "launcher has the + agents mode" || no "launcher + mode missing"
grep -q 'hub.newAgent(k === "n" ? "claude" : "codex")' "$QS/modules/hub/Hub.qml" && ok "hub Party: n / x start agents" || no "hub n/x keys missing"
grep -q 'DevStat.claudeSession' "$QS/modules/bar/DevIsland.qml" && ok "island shows the 5h usage chip" || no "island usage chip missing"
timeout 3 qs ipc call launcher openWith "+" &>/dev/null; sleep 0.8
mapped=$(hyprctl layers -j | jq -r '.[].levels[][] | .namespace' | grep -cx quickshell-launcher)
timeout 3 qs ipc call launcher toggle &>/dev/null
(( mapped == 1 )) && ok "launcher opens straight into + mode via IPC" || no "launcher didn't open for '+'"

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mAgents + limits OK.\033[0m\n' \
                || printf '\033[1;31mAgents + limits incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
