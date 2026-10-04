#!/usr/bin/env bash
# PostToolUse hook — typecheck after Claude edits a TypeScript file.
#
# WHY: deterministic beats probabilistic. Asking the model to "remember to
# typecheck" works most of the time; a hook works every time. Catching a type
# error one turn after it is introduced costs ~2 lines of context. Catching it
# three tasks later costs a debugging session.
#
# THE MONOREPO PROBLEM (this hook's first version got this wrong)
#   Running `tsc -p tsconfig.json` from the repo root typechecks EVERY package
#   after every single edit, and the agent waits for it. In a monorepo that is
#   several seconds per edit, which is a tax on every turn for a signal about
#   one file.
#
#   Three fixes, all applied below:
#     1. Scope to the NEAREST tsconfig.json walking up from the edited file, so
#        editing apps/api only checks apps/api.
#     2. --incremental with a per-package build-info cache, so only the first
#        run in a package pays full cost and later runs are near-instant.
#     3. A hard timeout. A hook that hangs is worse than a hook that is silent,
#        so past the budget it gives up and says so rather than blocking.
#
# Non-blocking by design (always exit 0): this informs, it does not gate.
set -uo pipefail

# Seconds before giving up. Tune per machine; the incremental cache means this
# is normally only hit on the first edit in a package after a cold checkout.
BUDGET="${ORCHESTRA_TSC_TIMEOUT:-12}"

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

case "$FILE" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac
[[ -f "$FILE" ]] || exit 0

# Opt out per repo without disabling every hook: touch .no-typecheck-hook.
[[ -f .no-typecheck-hook ]] && exit 0

# --- 1. Find the nearest tsconfig.json, walking up from the edited file ------
dir="$(cd "$(dirname "$FILE")" 2>/dev/null && pwd)" || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null || echo /)"
cfg=""
while [[ "$dir" == "$root"* && "$dir" != "/" ]]; do
  if [[ -f "$dir/tsconfig.json" ]]; then cfg="$dir/tsconfig.json"; break; fi
  dir="$(dirname "$dir")"
done
[[ -n "$cfg" ]] || exit 0
pkg="$(dirname "$cfg")"

# --- 2. Incremental build info, kept out of the repo ------------------------
# One cache per package, keyed by path so parallel packages don't collide.
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/orchestra/tsc"
mkdir -p "$cache_dir"
key="$(printf '%s' "$pkg" | tr '/' '_' | tail -c 120)"
info="$cache_dir/$key.tsbuildinfo"

# --- 3. Run, bounded -------------------------------------------------------
# --noEmit and --incremental are mutually exclusive in older tsc, so pass
# --emitDeclarationOnly false via tsBuildInfoFile only; if tsc rejects the
# combination it falls back to a plain --noEmit run inside the same budget.
out=$(cd "$pkg" && timeout "$BUDGET" \
  pnpm exec tsc --noEmit --incremental --tsBuildInfoFile "$info" -p tsconfig.json 2>&1) \
  || rc=$?
rc=${rc:-0}

if [[ $rc -eq 124 ]]; then
  echo "typecheck: skipped (exceeded ${BUDGET}s in $(basename "$pkg")); run it manually"
  exit 0
fi

if [[ $rc -ne 0 && "$out" == *"not compatible"* || "$out" == *"Unknown compiler option"* ]]; then
  out=$(cd "$pkg" && timeout "$BUDGET" pnpm exec tsc --noEmit -p tsconfig.json 2>&1) || true
fi

# Report only errors in the file that was just edited. Errors elsewhere are
# either pre-existing or someone else's problem; surfacing them here trains the
# agent to ignore this hook.
rel="${FILE#"$pkg"/}"
errs=$(printf '%s' "$out" | grep -F "$rel" | head -n 5)

if [[ -n "$errs" ]]; then
  echo "Type errors in $rel:"
  echo "$errs"
fi

exit 0
