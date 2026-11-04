#!/usr/bin/env bash
# scripts/install-keyboard.sh
# Makes the same physical keys do the same thing on Linux as on the Mac.
#
#   macOS: Karabiner-Elements does the remapping from karabiner/karabiner.json
#          (copy it to ~/.config/karabiner/). Nothing to install here.
#   Linux: translates karabiner.json into keyd configs and installs keyd, which
#          remaps below X11/Wayland, so it covers every app and the console.
#
# Result on Linux, for the PC keyboards in karabiner.json and any unlisted one:
#   key next to space (Alt)  -> Control   (tmux prefix C-a, shell C-r, ...)
#   Windows key              -> Alt       (what Option is on the Mac)
#   corner Ctrl key          -> Super     (what Cmd is on the Mac; Alacritty's
#                                          keys-linux.toml binds Super+C/V/etc.)
#   Caps Lock <-> Escape, plus the per-keyboard F10-F12 media keys.
#
# Re-run after editing karabiner.json. Needs sudo.
# If a bad config ever locks up the keyboard, press Backspace+Escape+Enter
# together: keyd's panic sequence stops the daemon.
#
# Usage: bash scripts/install-keyboard.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KARABINER_JSON="$DOTFILES_DIR/karabiner/karabiner.json"
GENERATOR="$DOTFILES_DIR/keyboard/karabiner-to-keyd.py"
KEYD_DIR="/etc/keyd"
KEYD_VERSION="v2.6.0"   # used only when building from source

info()    { echo "  [•] $*"; }
success() { echo "  [✓] $*"; }
warning() { echo "  [!] $*"; }

if [ "$(uname -s)" = "Darwin" ]; then
  info "macOS: Karabiner-Elements handles key remapping."
  info "Config lives in $KARABINER_JSON (live copy: ~/.config/karabiner/karabiner.json)."
  exit 0
fi

if [ "$(uname -s)" != "Linux" ]; then
  warning "Unsupported OS $(uname -s); skipping keyboard remapping."
  exit 0
fi

if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
  warning "WSL detected: Windows owns the keyboard, so keyd can't remap it. Skipping."
  exit 0
fi

command -v python3 &>/dev/null || { warning "python3 is required to translate karabiner.json"; exit 1; }

# ---------------------------------------------------------------------------
# 1. Generate the configs first, so a bad karabiner.json fails before any install.
# ---------------------------------------------------------------------------
echo "==> Translating karabiner.json to keyd configs..."
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
python3 "$GENERATOR" "$KARABINER_JSON" "$STAGE" | sed 's/^/  [•] generated /'

# ---------------------------------------------------------------------------
# 2. Install keyd if missing: distro package first, then build from source.
# ---------------------------------------------------------------------------
build_keyd_from_source() {
  info "Building keyd $KEYD_VERSION from source..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y git make gcc linux-libc-dev
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y git make gcc kernel-headers
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm git make gcc linux-api-headers
  fi
  local src
  src="$(mktemp -d)"
  git clone --quiet --depth 1 --branch "$KEYD_VERSION" https://github.com/rvaiya/keyd "$src"
  make -C "$src"
  sudo make -C "$src" install
  rm -rf "$src"
  # The source install ships a sysusers.d entry for the keyd group; create it now.
  command -v systemd-sysusers &>/dev/null && sudo systemd-sysusers || true
  command -v systemctl &>/dev/null && sudo systemctl daemon-reload || true
}

# Prints e.g. "2 5" for keyd v2.5.0; empty if keyd is missing.
keyd_major_minor() {
  command -v keyd &>/dev/null || return 0
  keyd --version 2>/dev/null | sed -nE 's/.*v([0-9]+)\.([0-9]+).*/\1 \2/p' | head -1
}
# keyd >= 2.5 is required: older versions only accept full vendor:product ids,
# and the generated Apple config matches on the vendor alone (k:05ac).
keyd_new_enough() {
  local v; v="$(keyd_major_minor)"
  [ -n "$v" ] && set -- $v && { [ "$1" -gt 2 ] || { [ "$1" -eq 2 ] && [ "$2" -ge 5 ]; }; }
}

echo "==> Checking for keyd..."
if keyd_new_enough; then
  success "keyd already installed ($(keyd --version 2>/dev/null | head -1))"
else
  if command -v keyd &>/dev/null; then
    warning "$(keyd --version | head -1) is older than v2.5; installing a newer one."
  elif command -v apt-get &>/dev/null && apt-cache show keyd &>/dev/null; then
    sudo apt-get install -y keyd
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm keyd
  elif command -v dnf &>/dev/null && dnf info keyd &>/dev/null; then
    sudo dnf install -y keyd
  fi
  keyd_new_enough || build_keyd_from_source
  keyd_new_enough || { warning "could not install keyd >= v2.5"; exit 1; }
  success "keyd installed ($(keyd --version 2>/dev/null | head -1))"
fi

# ---------------------------------------------------------------------------
# 3. Validate, then swap in the new configs.
# ---------------------------------------------------------------------------
# `keyd check` only exists from v2.6.0.
if [ "$(keyd_major_minor)" != "2 5" ]; then
  echo "==> Validating generated configs..."
  keyd check "$STAGE"/*.conf >/dev/null || { keyd check "$STAGE"/*.conf; exit 1; }
  success "keyd check passed"
fi

echo "==> Installing configs into $KEYD_DIR..."
sudo mkdir -p "$KEYD_DIR"
# Our files all start with dotfiles-, so stale ones (a keyboard removed from
# karabiner.json) are cleaned up without touching configs you added by hand.
sudo find "$KEYD_DIR" -maxdepth 1 -name 'dotfiles-*.conf' -delete
sudo install -m 644 "$STAGE"/*.conf "$KEYD_DIR"/
success "installed $(ls "$STAGE" | wc -l | tr -d ' ') configs"

# keyd lets only one wildcard ([ids] *) config win; warn if someone else's exists.
for f in "$KEYD_DIR"/*.conf; do
  case "$(basename "$f")" in dotfiles-*) continue ;; esac
  if sudo awk '/^\[ids\]/{s=1;next} /^\[/{s=0} s && $1=="*"{found=1} END{exit !found}' "$f"; then
    warning "$f also matches every keyboard ([ids] *) and may override dotfiles-default.conf."
    warning "Move its bindings into karabiner.json or delete it, then re-run."
  fi
done

echo "==> Starting keyd..."
if command -v systemctl &>/dev/null && [ -d /run/systemd/system ]; then
  sudo systemctl enable keyd &>/dev/null || true
  if systemctl is-active --quiet keyd; then
    sudo keyd reload
  else
    sudo systemctl start keyd
  fi
  systemctl is-active --quiet keyd && success "keyd running" || {
    warning "keyd did not start; see: sudo journalctl -eu keyd"; exit 1; }
else
  warning "No systemd: add 'keyd' to your init system, then run 'sudo keyd reload'."
fi

echo ""
echo "  Done. Verify with:  sudo keyd monitor   (press keys, Ctrl-C to quit)"
echo "  Unlisted keyboard? Its vendor:product id is shown by keyd monitor; add it"
echo "  to karabiner.json on the Mac (Karabiner shows the same ids in decimal)."
