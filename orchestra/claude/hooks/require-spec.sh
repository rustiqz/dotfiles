#!/usr/bin/env bash
# PreToolUse hook — blocks a codex-task delegation whose spec file is missing.
#
# WHY: if the spec path is wrong, Codex still starts, reads nothing useful, and
# improvises an implementation. That costs a full delegation plus the review
# that catches it. Blocking here costs nothing.
#
# Claude Code passes the tool call as JSON on stdin. Exit 2 blocks the call and
# feeds stderr back to the agent as the reason.
set -euo pipefail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

# Only interested in ACTUAL codex-task invocations.
#
# The first version matched "codex-task" anywhere in the command string, so a
# harmless `ls .design/runs/*codex-task*` or a grep for the word got blocked.
# A gate that fires on unrelated commands trains you to work around it, which
# is worse than not having it.
#
# Match only where a command can legitimately start: beginning of line, or
# after a pipe, semicolon, &&, ||, or an opening paren/brace. Anything inside
# a path, a quoted string, or an argument is left alone.
if ! printf '%s' "$CMD" | grep -qE '(^|[|;&(){]|&&|\|\|)[[:space:]]*(env [^|;&]*)?codex-task([[:space:]]|$)'; then
  exit 0
fi

# Extract the argument following --spec.
SPEC=$(printf '%s' "$CMD" | grep -oP '(?<=--spec )\S+' || true)

if [[ -z "$SPEC" ]]; then
  echo "Blocked: codex-task requires --spec <path>. Delegation without a written spec is not permitted." >&2
  exit 2
fi

if [[ ! -f "$SPEC" ]]; then
  echo "Blocked: spec file '$SPEC' does not exist. Write the LLD first, then delegate." >&2
  exit 2
fi

# Cheap sanity check: a spec with no Acceptance section gives the verifier
# nothing to run, so the task can never be proven done.
if ! grep -qi '^#\+ *acceptance' "$SPEC"; then
  echo "Blocked: '$SPEC' has no '## Acceptance' section. Add the literal commands that prove the task works." >&2
  exit 2
fi

exit 0
