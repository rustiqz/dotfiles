#!/usr/bin/env bash
# SubagentStop hook — appends one line per delegation to a token ledger.
#
# WHY: neither agent can reliably report its own spend, and Claude Code's
# /cost only covers the Claude side. This gives you a single file showing what
# each delegation actually cost on the Codex side, so "manage tokens across
# both agents" becomes a number rather than a vibe.
set -uo pipefail

LEDGER="${AGENT_LEDGER:-$HOME/.local/share/orchestra/ledger.tsv}"
mkdir -p "$(dirname "$LEDGER")"
[[ -f "$LEDGER" ]] || printf 'ts\tagent\trun_id\tstatus\tinput_tok\toutput_tok\n' > "$LEDGER"

INPUT=$(cat)
AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // "unknown"')

# Find the most recent codex-task run directory and read the usage it extracted.
LATEST=$(ls -1dt .design/runs/*/ 2>/dev/null | head -n 1 || true)
[[ -z "$LATEST" ]] && exit 0

RUN_ID=$(basename "$LATEST")
USAGE="$LATEST/usage.json"
REPORT="$LATEST/report.json"

IN_TOK=$(jq -r '.. | .input_tokens? // empty' "$USAGE" 2>/dev/null | tail -n1)
OUT_TOK=$(jq -r '.. | .output_tokens? // empty' "$USAGE" 2>/dev/null | tail -n1)
STATUS=$(jq -r '.status // "unknown"' "$REPORT" 2>/dev/null || echo unknown)

printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(date -u +%FT%TZ)" "$AGENT" "$RUN_ID" "$STATUS" "${IN_TOK:-?}" "${OUT_TOK:-?}" \
  >> "$LEDGER"

exit 0
