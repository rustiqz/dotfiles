#!/usr/bin/env bash
#
# Generate qt5ct.conf / qt6ct.conf from their tracked .in templates.
#
# Why these two files can't just be tracked directly, unlike every other
# config in this repo: qt5ct/qt6ct store the palette location as
# `color_scheme_path=`, and Qt's own .conf (QSettings INI) format has no
# variable expansion at all — not $HOME, not ~, not $XDG_CONFIG_HOME.
# It has to be a literal absolute path, which means a tracked qt6ct.conf
# necessarily bakes in one machine's username. It did: the tracked copy
# read /home/rustiq/.config/... and Qt theming therefore did nothing at
# all on the second machine (user `rakshith`), silently — qt6ct just
# ignores a color_scheme_path that doesn't resolve.
#
# Same shape as matugen/config.toml's __DOTFILES__ placeholder (see
# bin/bin/theme): track the template, generate the real file, gitignore
# the generated one. The generated file has to be written inside the
# stow package rather than straight to ~/.config, because stow
# tree-folds ~/.config/qt6ct into a single symlink back to this repo
# directory — there is no runtime path outside the repo to write to.
# Same reasoning as bat/.config/bat/themes/ and the active-theme.*
# symlinks, both already gitignored for exactly this.
#
# Idempotent in two directions, deliberately:
#   * file missing  -> seed it from the template
#   * file present  -> only correct color_scheme_path, leave everything
#                      else alone. qt6ct rewrites this file itself
#                      whenever its GUI is used (window geometry, style
#                      tweaks), so regenerating wholesale on every
#                      bootstrap would quietly discard the user's own
#                      settings. That's also why [SettingsWindow] is not
#                      in the template — it's runtime state qt6ct owns.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for app in qt5ct qt6ct; do
  template="$DOTFILES/$app/.config/$app/$app.conf.in"
  target="$DOTFILES/$app/.config/$app/$app.conf"
  want="$HOME/.config/$app/colors/active-theme.conf"

  [[ -f $template ]] || continue

  if [[ ! -f $target ]]; then
    echo "  generating $app.conf from template"
    sed "s|__HOME__|$HOME|g" "$template" > "$target"
    continue
  fi

  # Already exists — is the palette path pointing at this machine's $HOME?
  current=$(sed -n 's/^color_scheme_path=//p' "$target" | head -1)
  if [[ $current == "$want" ]]; then
    echo "  $app.conf color_scheme_path already correct"
  else
    echo "  fixing $app.conf color_scheme_path: $current -> $want"
    # In-place, anchored to the key, so nothing else in the file moves.
    # Uses | as the delimiter because the value is a path full of /.
    sed -i "s|^color_scheme_path=.*|color_scheme_path=$want|" "$target"
  fi
done
