#!/usr/bin/env bash
# install.sh — install dependencies + link configs (tmux + nvim).
#
# Usage:
#   bash install.sh                 # install deps, then tmux + nvim configs
#   bash install.sh --no-deps       # skip dependency installation (configs only)
#   bash install.sh --tmux-only     # deps + tmux config only
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

for arg in "$@"; do
  case "$arg" in
    --no-deps)   DO_DEPS=false ;;
    --tmux-only) DO_NVIM=false ;;
    --nvim-only) DO_TMUX=false ;;
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

if $DO_NVIM; then
  echo ""
  echo "--- Installing Neovim config ---"
  bash "$DOTFILES_DIR/scripts/install-nvim.sh"
fi

echo ""
echo "=========================================="
echo "  All done!"
echo "  - Start tmux, then press  Ctrl-a  Shift-I  to install plugins"
echo "  - Open nvim — plugins auto-install on first launch"
echo "=========================================="
