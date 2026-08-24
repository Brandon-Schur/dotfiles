#!/usr/bin/env bash
# scripts/install-nvim.sh
# Links the Neovim (AstroNvim) config and lazygit config.
# Dependencies (neovim, formatters, runtimes) are handled by install-deps.sh
# (macOS/Linux) or install-deps-windows.ps1 (Windows).
# Usage: bash scripts/install-nvim.sh

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NVIM_SRC="$DOTFILES_DIR/nvim"
NVIM_DST="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

if ! command -v nvim &>/dev/null; then
  echo "  [!] Neovim not found. Run scripts/install-deps.sh first (or install nvim)."
  exit 1
fi
echo "  [•] $(nvim --version | head -1) found"

if ! command -v git &>/dev/null; then
  echo "  [!] git not found — required for lazy.nvim plugin installation."
  exit 1
fi

echo "==> Linking Neovim config to $NVIM_DST..."
if [ -d "$NVIM_DST" ] && [ ! -L "$NVIM_DST" ]; then
  BACKUP="${NVIM_DST}.backup.$(date +%Y%m%d-%H%M%S)"
  echo "  [•] Backing up existing config to $BACKUP"
  mv "$NVIM_DST" "$BACKUP"
fi
# Symlink so repo edits take effect immediately. Use `cp -r` for a copy instead.
ln -sfn "$NVIM_SRC" "$NVIM_DST"
echo "  [✓] $NVIM_DST -> $NVIM_SRC"

echo "==> Linking lazygit config..."
LAZYGIT_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit"
mkdir -p "$LAZYGIT_CFG_DIR"
if [ -f "$LAZYGIT_CFG_DIR/config.yml" ] && [ ! -L "$LAZYGIT_CFG_DIR/config.yml" ]; then
  cp "$LAZYGIT_CFG_DIR/config.yml" "$LAZYGIT_CFG_DIR/config.yml.backup.$(date +%Y%m%d-%H%M%S)"
fi
ln -sf "$DOTFILES_DIR/lazygit/config.yml" "$LAZYGIT_CFG_DIR/config.yml"
echo "  [✓] $LAZYGIT_CFG_DIR/config.yml -> dotfiles/lazygit/config.yml"

echo ""
echo "  Done. Open nvim — lazy.nvim installs plugins, Mason installs formatters."
echo "  Check formatters with :ConformInfo   |   Check LSP with :LspInfo"
echo "  NOTE: a Nerd Font must be set in your terminal for icons to render."
