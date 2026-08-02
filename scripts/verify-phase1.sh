#!/usr/bin/env bash
#
# verify-phase1.sh — assert that Phase 1 (base system) is fully applied.
#
# Read-only: makes no changes, so it is safe to run any time. Intended as
# the exit criterion for Phase 1 on this machine and as the first thing to
# run after bootstrapping a new one.
#
# Exit code 0 = all checks passed, 1 = at least one failure.
#
# Deliberately NOT using `set -e`: a failing check is data, not a reason
# to abort. We want the full report every run.

set -uo pipefail

PASS=0; FAIL=0; WARN=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$(hostnamectl --static 2>/dev/null || hostname)"

# --- reporting helpers -------------------------------------------------------
# ok/no/wa print a coloured status line and tally the result. `wa` is for
# things that are suboptimal but not broken (e.g. missing optional driver).
ok() { printf '  \033[1;32m✓\033[0m %s\n' "$*"; ((PASS++)); }
no() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; ((FAIL++)); }
wa() { printf '  \033[1;33m!\033[0m %s\n' "$*"; ((WARN++)); }
hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

# Assert a package is installed.
chk_pkg() {
  pacman -Qq "$1" &>/dev/null && ok "package $1" || no "package $1 MISSING"
}

# Assert a command resolves on PATH.
chk_cmd() {
  command -v "$1" &>/dev/null && ok "command $1" || no "command $1 NOT FOUND"
}

# Assert a systemd unit is active. Scope: --system (default) or --user.
chk_unit() {
  local scope=${2:---system}
  if systemctl "$scope" is-active --quiet "$1"; then
    ok "unit $1 active"
  else
    no "unit $1 not active ($(systemctl "$scope" is-active "$1" 2>&1))"
  fi
}

# Assert a unit is enabled (will start at boot / login). Separate from
# is-active because socket-activated services are active-but-disabled by
# design — those are checked via their .socket instead.
chk_enabled() {
  local scope=${2:---system}
  local state
  state=$(systemctl "$scope" is-enabled "$1" 2>&1)
  [[ $state == enabled* ]] && ok "unit $1 enabled" || no "unit $1 not enabled ($state)"
}

# ---------------------------------------------------------------------------
hdr "Repo & host"
# ---------------------------------------------------------------------------
[[ $HOST == rustiq ]] && ok "hostname is $HOST" || wa "hostname is $HOST (manifests key off this)"
[[ -d $DOTFILES/.git ]] && ok "dotfiles is a git repo" || no "dotfiles is not a git repo"
# An uncommitted working tree means this machine's state isn't reproducible
# elsewhere yet — the whole point of the repo.
if [[ -d $DOTFILES/.git ]]; then
  git -C "$DOTFILES" diff --quiet && git -C "$DOTFILES" diff --cached --quiet \
    && ok "working tree clean" || wa "uncommitted changes in dotfiles"
  git -C "$DOTFILES" remote get-url origin &>/dev/null \
    && ok "remote 'origin' configured" || wa "no git remote — can't clone to other PCs"
fi
[[ -x $DOTFILES/bootstrap.sh ]] && ok "bootstrap.sh executable" || no "bootstrap.sh not executable"

# ---------------------------------------------------------------------------
hdr "pacman configuration"
# ---------------------------------------------------------------------------
grep -q '^Color'                  /etc/pacman.conf && ok "Color enabled"            || no "Color not enabled"
grep -q '^ParallelDownloads = 10' /etc/pacman.conf && ok "ParallelDownloads = 10"   || no "ParallelDownloads not set"
grep -q '^ILoveCandy'             /etc/pacman.conf && ok "ILoveCandy"               || wa "ILoveCandy absent (cosmetic)"
grep -q '^\[multilib\]'           /etc/pacman.conf && ok "multilib enabled"         || no "multilib not enabled"
# !debug in makepkg OPTIONS prevents the stale -debug package conflicts
# that blocked the paru rebuild.
grep -q '^OPTIONS=.*!debug'       /etc/makepkg.conf && ok "makepkg !debug"          || no "makepkg still builds debug packages"

# ---------------------------------------------------------------------------
hdr "Mirrors"
# ---------------------------------------------------------------------------
chk_pkg reflector
chk_enabled reflector.timer
# Mirrorlist should be recent and non-empty. A list older than ~2 weeks
# suggests the timer never ran.
if [[ -s /etc/pacman.d/mirrorlist ]]; then
  count=$(grep -c '^Server' /etc/pacman.d/mirrorlist)
  age=$(( ( $(date +%s) - $(stat -c %Y /etc/pacman.d/mirrorlist) ) / 86400 ))
  (( count > 0 )) && ok "mirrorlist has $count servers (${age}d old)" \
                  || no "mirrorlist has no Server lines"
else
  no "mirrorlist empty or missing"
fi

# ---------------------------------------------------------------------------
hdr "Memory / zram"
# ---------------------------------------------------------------------------
chk_pkg zram-generator
[[ -f /etc/systemd/zram-generator.conf ]] && ok "zram-generator.conf present" || no "zram-generator.conf missing"
if swapon --show=NAME --noheadings 2>/dev/null | grep -q zram; then
  ok "zram swap active ($(swapon --show=NAME,SIZE --noheadings | grep zram | tr -s ' '))"
else
  no "zram swap not active"
fi

# ---------------------------------------------------------------------------
hdr "Audio (PipeWire)"
# ---------------------------------------------------------------------------
for p in pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber rtkit pavucontrol; do chk_pkg "$p"; done
chk_unit pipewire.service --user       # socket-activated: active but "disabled" is correct
chk_unit wireplumber.service --user
chk_enabled pipewire.socket --user
# Confirm the PulseAudio shim is what applications actually reach.
if pactl info 2>/dev/null | grep -q 'PipeWire'; then
  ok "pactl reports PipeWire backend"
else
  no "pactl not reporting PipeWire"
fi
# rtkit grants realtime priority to audio threads; without it PipeWire
# falls back to priority 1 and can produce xruns under CPU load.
if journalctl --user -u pipewire --since "today" 2>/dev/null | grep -q "RTKit error"; then
  # Errors may predate the rtkit install — only flag if still occurring.
  last=$(journalctl --user -u pipewire --since "today" | grep "RTKit error" | tail -1)
  wa "RTKit errors in today's log (restart pipewire if recent): ${last##* }"
else
  ok "no RTKit errors today"
fi

# ---------------------------------------------------------------------------
hdr "Networking & Bluetooth"
# ---------------------------------------------------------------------------
chk_unit NetworkManager.service
chk_unit bluetooth.service
chk_unit systemd-timesyncd.service
timedatectl show -p NTPSynchronized --value | grep -q yes \
  && ok "clock NTP-synchronised" || wa "clock not yet NTP-synchronised"
# DNS resolution — this broke the paru build earlier, so it's worth asserting.
getent hosts archlinux.org &>/dev/null && ok "DNS resolves archlinux.org" || no "DNS resolution failing"
getent hosts codeload.github.com &>/dev/null && ok "DNS resolves codeload.github.com" \
  || wa "codeload.github.com not resolving (AUR source downloads will fail)"

# ---------------------------------------------------------------------------
hdr "Maintenance timers"
# ---------------------------------------------------------------------------
chk_pkg pacman-contrib
chk_enabled fstrim.timer       # weekly SSD TRIM — relevant on ext4
chk_enabled paccache.timer     # prunes old package cache versions

# ---------------------------------------------------------------------------
hdr "Fonts"
# ---------------------------------------------------------------------------
# A Nerd Font is a hard requirement for starship, eza icons, lazygit and
# most Neovim statuslines — without it those render as tofu boxes.

# Captured once and grepped in-process: piping fc-list straight into
# `grep -q` lets grep exit (and close the pipe) the instant it matches,
# which SIGPIPEs fc-list before it finishes writing. Under `pipefail`
# that SIGPIPE (141) outranks grep's 0, so the whole pipeline reports
# failure even though the match succeeded.
fonts=$(fc-list)
for f in "JetBrainsMono Nerd Font:nerd font" "Noto Sans:noto" "Noto Color Emoji:emoji" "Noto Sans CJK:CJK"; do
  name=${f%%:*}; label=${f##*:}
  grep -qi "${name}" <<<"$fonts" && ok "font: $label" || no "font: $label MISSING"
done

# ---------------------------------------------------------------------------
hdr "Graphics (Intel Comet Lake-U)"
# ---------------------------------------------------------------------------
for p in mesa vulkan-intel intel-media-driver libva-utils mesa-utils; do chk_pkg "$p"; done
# Mesa must be working for Hyprland to render at all in Phase 5.
if renderer=$(glxinfo -B 2>/dev/null | grep 'OpenGL renderer'); then
  ok "${renderer#*: }"
else
  no "glxinfo failed — Mesa not working"
fi
# VA-API hardware video decode. Affects battery life on video playback only;
# not a blocker for Hyprland, hence a warning rather than a failure.
if vainfo &>/dev/null; then
  drv=$(vainfo 2>/dev/null | grep -i 'Driver version' | head -1)
  [[ $drv == *iHD* ]] && ok "VA-API: iHD driver" || wa "VA-API loaded but not iHD: ${drv#*: }"
else
  wa "vainfo failing — no hardware video decode"
fi

# ---------------------------------------------------------------------------
hdr "Laptop hardware"
# ---------------------------------------------------------------------------
chk_pkg intel-ucode
chk_pkg thermald
chk_unit thermald.service
chk_cmd brightnessctl        # Hyprland brightness keybinds shell out to this
chk_cmd powerprofilesctl
chk_unit power-profiles-daemon.service
chk_pkg upower               # waybar battery module consumes this in Phase 5
# Microcode must be loaded by the initramfs. This system boots a UKI, so it
# comes from the mkinitcpio `microcode` hook rather than a bootloader entry.
grep -q '^HOOKS=.*\bmicrocode\b' /etc/mkinitcpio.conf \
  && ok "microcode in mkinitcpio HOOKS" || no "microcode hook missing"
journalctl -k -b 2>/dev/null | grep -q 'microcode: Updated early' \
  && ok "microcode applied at boot" || wa "no early microcode update this boot"
[[ -d /sys/class/power_supply/BAT0 ]] && ok "battery detected" || wa "no BAT0 (desktop?)"

# ---------------------------------------------------------------------------
hdr "AUR"
# ---------------------------------------------------------------------------
# `command -v paru` passes even for a binary with unresolvable shared
# libraries, which is exactly how the libalpm.so.15 breakage hid. Run it
# instead of just locating it.
if paru --version &>/dev/null; then
  ok "paru works ($(paru --version | head -1))"
else
  no "paru broken or missing"
fi
pacman -Qq paru-bin &>/dev/null && wa "paru-bin still installed (should be source paru)" \
                                || ok "no stale paru-bin"

# ---------------------------------------------------------------------------
hdr "Manifest coverage"
# ---------------------------------------------------------------------------
# Every package named in the manifests should actually be installed.
# This is the real test that bootstrap.sh ran to completion.
for m in pacman.txt "host-$HOST.txt"; do
  f="$DOTFILES/packages/$m"
  [[ -f $f ]] || { wa "manifest $m absent"; continue; }
  missing=()
  while read -r pkg; do
    [[ -n $pkg ]] && ! pacman -Qq "$pkg" &>/dev/null && missing+=("$pkg")
  done < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$f" | grep -v '^$')
  if (( ${#missing[@]} == 0 )); then
    ok "$m: all packages installed"
  else
    no "$m: missing ${missing[*]}"
  fi
done

# Orphans: installed as dependencies but no longer required by anything.
orphans=$(pacman -Qtdq 2>/dev/null | wc -l)
(( orphans == 0 )) && ok "no orphaned packages" || wa "$orphans orphaned packages (pacman -Qtdq)"

# ---------------------------------------------------------------------------
printf '\n\033[1m── %d passed, %d failed, %d warnings ──\033[0m\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && printf '\033[1;32mPhase 1 complete.\033[0m\n' \
                || printf '\033[1;31mPhase 1 incomplete — see ✗ above.\033[0m\n'
exit $(( FAIL > 0 ))
