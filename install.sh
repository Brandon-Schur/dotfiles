#!/usr/bin/env bash
# install.sh — install everything (tmux + nvim) in one shot.
# Usage: bash install.sh [--tmux-only] [--nvim-only]

set -e
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DO_TMUX=true
DO_NVIM=true

for arg in "$@"; do
  case "$arg" in
    --tmux-only) DO_NVIM=false ;;
    --nvim-only) DO_TMUX=false ;;
  esac
done

echo "=========================================="
echo "  Brandon's dotfiles installer"
echo "=========================================="
echo ""

if $DO_TMUX; then
  echo "--- Installing tmux config ---"
  bash "$DOTFILES_DIR/scripts/install-tmux.sh"
  echo ""
fi

if $DO_NVIM; then
  echo "--- Installing Neovim config ---"
  bash "$DOTFILES_DIR/scripts/install-nvim.sh"
  echo ""
fi

echo "=========================================="
echo "  All done!"
echo "=========================================="
