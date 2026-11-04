#!/usr/bin/env bash
# install.sh — install dependencies + link configs (tmux, nvim, Alacritty) and,
# on Linux, translate the Karabiner key remaps to keyd.
#
# Usage:
#   bash install.sh                 # deps, tmux, nvim, Alacritty, keyboard remap
#   bash install.sh --no-deps       # skip dependency installation (configs only)
#   bash install.sh --no-keyboard   # skip the Linux keyd remap (it needs sudo)
#   bash install.sh --tmux-only     # deps + tmux config + sesh picker only
#   bash install.sh --nvim-only     # deps + nvim config only
#
# Windows (native): dependency install is separate — run in PowerShell:
#   .\scripts\install-deps-windows.ps1
#   then: bash scripts/install-nvim.sh

set -e
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DO_DEPS=true
DO_TMUX=true
DO_NVIM=true
DO_ALACRITTY=true
DO_KEYBOARD=true
# The sesh picker is tmux-only, so it follows DO_TMUX rather than getting its own flag.

for arg in "$@"; do
  case "$arg" in
    --no-deps)     DO_DEPS=false ;;
    --no-keyboard) DO_KEYBOARD=false ;;
    --tmux-only)   DO_NVIM=false; DO_ALACRITTY=false; DO_KEYBOARD=false ;;
    --nvim-only)   DO_TMUX=false; DO_ALACRITTY=false; DO_KEYBOARD=false ;;
  esac
done

echo "=========================================="
echo "  Brandon's dotfiles installer"
echo "=========================================="

OS="$(uname -s)"

# On native Windows (Git Bash / MSYS), redirect to the PowerShell script.
case "$OS" in
  MINGW*|MSYS*|CYGWIN*)
    echo ""
    echo "Native Windows detected."
    echo "Please install dependencies via PowerShell first:"
    echo "    .\\scripts\\install-deps-windows.ps1"
    echo "Then re-run:  bash scripts/install-nvim.sh"
    echo "(tmux is not supported on native Windows — use WSL for tmux.)"
    exit 0
    ;;
esac

if $DO_DEPS; then
  echo ""
  echo "--- Installing dependencies ---"
  bash "$DOTFILES_DIR/scripts/install-deps.sh"
fi

if $DO_TMUX; then
  echo ""
  echo "--- Installing tmux config ---"
  bash "$DOTFILES_DIR/scripts/install-tmux.sh"
fi

if $DO_TMUX; then
  echo ""
  echo "--- Installing sesh session picker ---"
  # Non-fatal: a missing sesh/fzf should not abort the rest of the install, and the
  # tmux config works without it (you just lose <prefix> s).
  bash "$DOTFILES_DIR/scripts/install-sesh.sh" || \
    echo "  [!] sesh picker skipped — see scripts/install-sesh.sh output above"
fi

if $DO_NVIM; then
  echo ""
  echo "--- Installing Neovim config ---"
  bash "$DOTFILES_DIR/scripts/install-nvim.sh"
fi

if $DO_ALACRITTY; then
  echo ""
  echo "--- Installing Alacritty config ---"
  bash "$DOTFILES_DIR/scripts/install-alacritty.sh"
fi

# Linux only (the script exits early on macOS, where Karabiner does this).
# Non-fatal: the configs above are still usable without the remap.
if $DO_KEYBOARD && [ "$OS" = "Linux" ]; then
  echo ""
  echo "--- Translating Karabiner key remaps to keyd ---"
  bash "$DOTFILES_DIR/scripts/install-keyboard.sh" || \
    echo "  [!] keyboard remap skipped — see scripts/install-keyboard.sh output above"
fi

echo ""
echo "=========================================="
echo "  All done!"
echo "  - Start tmux, then press  Ctrl-a  Shift-I  to install plugins"
echo "  - Open nvim — plugins auto-install on first launch"
echo "  - Press  Ctrl-a  s  for the sesh session picker"
echo "=========================================="
