#!/usr/bin/env bash
#
# Registers the local `devstat-hooks` agent plugin (agent-hooks/, stowed to
# ~/.local/share/agent-hooks) so agent sessions report their state to
# devstat — see agent-hooks/.local/share/agent-hooks/README.md for why
# this is a plugin rather than hooks in ~/.claude/settings.json.
#
# Idempotent: the marketplace and the plugin are each only added when the
# CLI doesn't already list them. Skips quietly on a machine without the
# agent CLI installed — nothing else in the repo depends on it.

set -euo pipefail

MARKET="$HOME/.local/share/agent-hooks"
NAME=dotfiles-local
PLUGIN=devstat-hooks

if ! command -v claude &>/dev/null; then
  echo "agent CLI not installed — skipping agent hooks"
  exit 0
fi
if [[ ! -f $MARKET/.claude-plugin/marketplace.json ]]; then
  echo "$MARKET not stowed yet (bootstrap stows before running hooks)" >&2
  exit 1
fi

# `claude plugin marketplace add` / `install` record the plugin in
# ~/.claude/settings.json (extraKnownMarketplaces + enabledPlugins). When
# that path is orchestra's symlink into its own source tree, the CLI would
# write *through* it into another project's file — so in that case don't
# run the CLI at all; only check the keys are there and say so if not.
SETTINGS="$HOME/.claude/settings.json"
has_keys() {
  jq -e --arg m "$NAME" --arg p "$PLUGIN@$NAME" \
    '(.extraKnownMarketplaces[$m] != null) and (.enabledPlugins[$p] == true)' "$1" &>/dev/null
}
if [[ -L $SETTINGS ]]; then
  target=$(readlink -f "$SETTINGS")
  if has_keys "$target"; then
    echo "Agent hooks: enabled via $target"
  else
    echo "warning: $SETTINGS is a symlink to $target, which doesn't enable" >&2
    echo "  $PLUGIN@$NAME. Add to that file:" >&2
    echo "  \"extraKnownMarketplaces\": {\"$NAME\": {\"source\": {\"source\": \"directory\", \"path\": \"$MARKET\"}}}," >&2
    echo "  \"enabledPlugins\": {\"$PLUGIN@$NAME\": true}" >&2
  fi
  exit 0
fi

# Captured, then grepped — no `producer | grep -q` under pipefail
# (CLAUDE.md, Known gotchas).
markets=$(claude plugin marketplace list 2>/dev/null || true)
if ! grep -q "$NAME" <<<"$markets"; then
  claude plugin marketplace add "$MARKET"
fi

installed=$(claude plugin list 2>/dev/null || true)
if ! grep -q "$PLUGIN@$NAME" <<<"$installed"; then
  claude plugin install "$PLUGIN@$NAME"
fi

echo "Agent hooks: $PLUGIN@$NAME installed"
