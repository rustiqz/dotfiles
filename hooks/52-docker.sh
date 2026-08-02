#!/usr/bin/env bash
#
# Enable the Docker daemon and add the current user to the `docker`
# group so `docker` works without `sudo`.
#
# Security note, not just convenience trivia: membership in the docker
# group is root-equivalent on this machine. The daemon runs as root and
# its socket has no further authorization checks, so anything able to
# talk to it can bind-mount / and get an unrestricted root shell.
# Acceptable tradeoff on a personal workstation; wouldn't ship this hook
# unchanged on a shared or multi-user box.
#
# Idempotent: `enable --now` on an already-enabled unit is a no-op, and
# the group add is guarded on current membership.

set -euo pipefail

sudo systemctl enable --now docker.service

if ! groups "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  echo "Added $USER to the docker group — log out and back in for it to take effect."
else
  echo "$USER already in the docker group."
fi
