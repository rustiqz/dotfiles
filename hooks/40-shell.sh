#!/usr/bin/env bash
#
# Set zsh as the login shell. Guarded on the current value in /etc/passwd
# so re-running bootstrap.sh doesn't call chsh (and re-prompt for a
# password) once it's already set.

set -euo pipefail

ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

if [[ $CURRENT_SHELL != "$ZSH_PATH" ]]; then
  echo "Changing login shell to $ZSH_PATH (current: $CURRENT_SHELL)"
  chsh -s "$ZSH_PATH"
else
  echo "Login shell already zsh."
fi
