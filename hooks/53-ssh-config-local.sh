#!/usr/bin/env bash
#
# Seed ~/.ssh/config.local — untracked (matches the repo's *.local
# convention), Include'd by the tracked ssh/.ssh/config.
#
# Why a hook at all, when the file is by definition machine-specific and
# can't be tracked: without one, a clean clone gets a config.local that
# doesn't exist, which makes `bin/bin/ssh-connect` ($mod+S) a silent
# no-op with nothing anywhere to explain why. The escape hatch has to be
# *discoverable* — a commented placeholder file sitting at the path the
# picker reads is the discovery mechanism. Same reasoning, and the same
# create-only-if-missing shape, as hooks/50-git-identity.sh.
#
# Idempotent: only ever created when missing, never overwritten, so real
# host entries survive every re-run of bootstrap.sh.

set -euo pipefail

LOCAL_CONF="$HOME/.ssh/config.local"

if [[ -f $LOCAL_CONF ]]; then
  echo "$LOCAL_CONF already exists, leaving it alone"
  exit 0
fi

# 700 on ~/.ssh, 600 on the file: ssh refuses to use a config that's
# group- or world-writable, and mkdir/cat would otherwise inherit the
# umask. Set explicitly rather than assuming the directory already
# exists with the right mode.
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

cat > "$LOCAL_CONF" <<'EOF'
# ~/.ssh/config.local — untracked, machine-specific.
#
# Real hostnames/IPs go here, never in the dotfiles repo. Included from
# the tracked ~/.ssh/config, and read by `ssh-connect` ($mod+S) to build
# its rofi picker list.
#
# Entries look like this — uncomment and edit, one block per machine:
#
# Host work
#   HostName 10.0.0.5
#   User rakshith
#   IdentityFile ~/.ssh/id_ed25519
EOF
chmod 600 "$LOCAL_CONF"

echo "Wrote $LOCAL_CONF (placeholder — add real Host entries to enable \$mod+S)"
