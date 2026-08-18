#!/usr/bin/env bash
#
# Create ~/.config/digitalocean/ — the untracked home for DigitalOcean
# cluster credentials (kubeconfigs downloaded from the control panel or
# written by `doctl kubernetes cluster kubeconfig save`).
#
# Why a dedicated directory rather than just leaving them in ~/.kube:
# these are *account* artifacts, not desktop config — they're issued
# per cluster, they're revocable, and they get replaced wholesale
# rather than edited. Keeping them in one place makes "what credentials
# does this machine hold" a single `ls`, and makes them trivial to wipe.
#
# Why outside the repo, not a gitignored directory inside it: a
# credential sitting under ~/dotfiles is one `git add -f`, one `git
# clean` mishap, or one "let me just back up the whole repo directory"
# away from being published. The repo's rule is that secrets live
# *outside* it and are reached via a *.local-style indirection — this
# is that same pattern, one directory up in scale.
#
# The indirection here is a symlink: ~/.kube/config points into this
# directory. Deliberately not a KUBECONFIG env var — the $mod+C keybind
# runs `kitty -e k9s`, which execs k9s directly without a login shell,
# so anything exported from .zshrc simply wouldn't be there. A symlink
# is visible to every tool with no environment at all, and swapping
# clusters becomes a repoint, exactly like bin/bin/theme's
# active-theme.* links.
#
# This hook deliberately only *creates* the directory. It does not move
# an existing ~/.kube/config into it: on a machine where that file was
# written by some other tool, silently relocating a working credential
# is not a thing a bootstrap script should do behind your back. The
# README it drops explains the convention; wiring is a manual, one-time
# step per machine.

set -euo pipefail

DO_DIR="$HOME/.config/digitalocean"

# 700: these are bearer tokens with cluster-admin rights. The default
# umask would leave the directory group/world-readable.
mkdir -p "$DO_DIR"
chmod 700 "$DO_DIR"

README="$DO_DIR/README"
if [[ ! -f $README ]]; then
  cat > "$README" <<'EOF'
DigitalOcean credentials — untracked, machine-local, never in ~/dotfiles.

Contents: one kubeconfig per cluster, chmod 600, named after the
cluster, e.g. <cluster-name>.yaml.

~/.kube/config is a symlink to whichever one is currently active:

    ln -sfn ~/.config/digitalocean/<cluster>.yaml ~/.kube/config

Switching clusters is repointing that symlink. Every tool (kubectl,
k9s, stern, lazydocker) reads ~/.kube/config with no environment
variable set, which matters because the $mod+C keybind runs k9s
without a login shell.

These files hold revocable bearer tokens with cluster-admin rights.
Revoke from the DO control panel, not by deleting the file.
EOF
  chmod 600 "$README"
  echo "Created $DO_DIR (0700) with README"
else
  echo "$DO_DIR already exists, leaving it alone"
fi
