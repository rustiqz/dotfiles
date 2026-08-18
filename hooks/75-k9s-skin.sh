#!/usr/bin/env bash
#
# Point k9s at the theme switcher's skin symlink, by ensuring
# `k9s.ui.skin: active-theme` in ~/.config/k9s/config.yaml.
#
# Why a hook instead of just tracking config.yaml, like every other
# app's config in this repo: **k9s rewrites that file itself**. It
# reserialises its whole config (all defaults expanded) on exit, which
# includes `screenDumpDir: /home/<user>/.local/state/k9s/screen-dumps`
# — an absolute path with a username baked into it. Tracking the file
# would therefore reintroduce exactly the bug the qt5ct/qt6ct configs
# hit on the second machine, just via a different mechanism (there Qt
# couldn't expand $HOME; here k9s helpfully expands it *for* us and
# writes it back). So config.yaml is gitignored runtime state, and this
# hook owns the single key that actually matters, the same way
# hooks/74-qt-conf.sh owns only color_scheme_path.
#
# Idempotent, and deliberately surgical: it rewrites the skin line or
# inserts it, never regenerates the file — anything else k9s or the
# user has set in there survives untouched.

set -euo pipefail

CONF="$HOME/.config/k9s/config.yaml"
SKIN="active-theme"

# The stow package (k9s/.config/k9s/) supplies this directory, so a
# missing one means k9s was never stowed — bail loudly rather than
# creating a plain directory that the next `stow k9s` would then
# conflict with.
if [[ ! -d $(dirname "$CONF") ]]; then
  echo "~/.config/k9s does not exist — is the k9s stow package stowed? Skipping." >&2
  exit 0
fi

if [[ ! -f $CONF ]]; then
  # Minimal seed. k9s merges a partial config against its own defaults,
  # so there's no need to enumerate everything else — and not doing so
  # keeps this file free of machine-specific paths until k9s itself
  # chooses to write them.
  cat > "$CONF" <<EOF
k9s:
  ui:
    skin: $SKIN
EOF
  echo "Created $CONF with skin: $SKIN"
  exit 0
fi

# Existing file: replace the skin value if the key is already there,
# otherwise insert it directly under the `ui:` block. Anchored on the
# real indentation (4 spaces, since ui: sits at 2 under k9s:) so this
# can't accidentally match some other `skin:` at another nesting level.
if grep -qE '^    skin:' "$CONF"; then
  current=$(grep -E '^    skin:' "$CONF" | head -1 | awk '{print $2}')
  if [[ $current == "$SKIN" ]]; then
    echo "$CONF already set to skin: $SKIN"
  else
    sed -i -E "s|^    skin:.*|    skin: $SKIN|" "$CONF"
    echo "Set skin: $SKIN in $CONF (was: $current)"
  fi
elif grep -qE '^  ui:' "$CONF"; then
  sed -i -E "0,/^  ui:/s|^  ui:|  ui:\n    skin: $SKIN|" "$CONF"
  echo "Added skin: $SKIN under ui: in $CONF"
else
  echo "$CONF has no 'ui:' block — leaving it alone, set skin manually" >&2
  exit 0
fi
