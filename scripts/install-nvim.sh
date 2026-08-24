#!/usr/bin/env bash
# scripts/install-nvim.sh
# Installs Neovim config (AstroNvim-based) on macOS, Linux, or WSL.
# Usage: bash scripts/install-nvim.sh

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NVIM_SRC="$DOTFILES_DIR/nvim"
NVIM_DST="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

echo "==> Checking Neovim installation..."
if ! command -v nvim &>/dev/null; then
  echo "Neovim not found. Install it first:"
  echo "  macOS:   brew install neovim"
  echo "  Linux:   brew install neovim  OR  see https://github.com/neovim/neovim/releases"
  echo "  Windows: scoop install neovim  OR  winget install Neovim.Neovim"
  exit 1
fi
echo "    $(nvim --version | head -1) found."

echo "==> Checking git..."
if ! command -v git &>/dev/null; then
  echo "git not found — required for lazy.nvim and plugin installation."
  exit 1
fi

echo "==> Checking optional formatter dependencies..."
for tool in prettier sql-formatter; do
  if ! command -v "$tool" &>/dev/null; then
    echo "    WARNING: $tool not found on PATH."
    echo "      macOS/Linux: brew install $tool"
    echo "      Windows:     npm install -g $tool  (requires Node.js)"
  fi
done

echo "==> Installing nvim config to $NVIM_DST..."
if [ -d "$NVIM_DST" ] && [ ! -L "$NVIM_DST" ]; then
  BACKUP="${NVIM_DST}.backup.$(date +%Y%m%d-%H%M%S)"
  echo "    Existing config found — backing up to $BACKUP"
  mv "$NVIM_DST" "$BACKUP"
fi

# Symlink so edits in the dotfiles repo take effect immediately.
# To use a copy instead: replace with  cp -r "$NVIM_SRC" "$NVIM_DST"
ln -sfn "$NVIM_SRC" "$NVIM_DST"
echo "    $NVIM_DST -> $NVIM_SRC"

echo "==> Installing lazygit config..."
LAZYGIT_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit"
LAZYGIT_CFG_SRC="$DOTFILES_DIR/lazygit/config.yml"
mkdir -p "$LAZYGIT_CFG_DIR"
if [ -f "$LAZYGIT_CFG_DIR/config.yml" ] && [ ! -L "$LAZYGIT_CFG_DIR/config.yml" ]; then
  echo "    Existing lazygit config found — backing up"
  cp "$LAZYGIT_CFG_DIR/config.yml" "$LAZYGIT_CFG_DIR/config.yml.backup.$(date +%Y%m%d-%H%M%S)"
fi
ln -sf "$LAZYGIT_CFG_SRC" "$LAZYGIT_CFG_DIR/config.yml"
echo "    $LAZYGIT_CFG_DIR/config.yml -> $LAZYGIT_CFG_SRC"

echo ""
echo "==> Done! Next steps:"
echo "    1. Open Neovim:  nvim"
echo "    2. Lazy.nvim will auto-install all plugins on first launch."
echo "    3. Mason will install LSP servers and formatters (may take ~1 min)."
echo "    4. Check formatter status with:  :ConformInfo"
echo ""
echo "    NOTE: A Nerd Font is required for icons."
echo "    Download from https://www.nerdfonts.com and set in your terminal."
echo ""
echo "    To switch colorscheme: edit nvim/lua/plugins/colorscheme.lua"
echo "    Options: tokyonight-storm | tokyonight-night | catppuccin-macchiato | etc."
