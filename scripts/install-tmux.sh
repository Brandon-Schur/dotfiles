#!/usr/bin/env bash
# scripts/install-tmux.sh
# Installs tmux config and TPM on macOS, Linux, or WSL (Windows).
# Usage: bash scripts/install-tmux.sh

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_CONF_SRC="$DOTFILES_DIR/tmux/.tmux.conf"
TMUX_CONF_DST="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"

echo "==> Checking tmux installation..."
if ! command -v tmux &>/dev/null; then
  echo "tmux not found. Install it first:"
  echo "  macOS:   brew install tmux"
  echo "  Linux:   sudo apt install tmux  OR  brew install tmux"
  echo "  Windows: scoop install tmux  OR  use WSL"
  exit 1
fi
echo "    tmux $(tmux -V) found."

echo "==> Installing formatter dependencies..."
echo "    prettier and sql-formatter must be on PATH for formatting to work."
if ! command -v prettier &>/dev/null; then
  echo "    WARNING: prettier not found."
  echo "      Install: brew install prettier  OR  npm install -g prettier"
fi
if ! command -v sql-formatter &>/dev/null; then
  echo "    WARNING: sql-formatter not found."
  echo "      Install: brew install sql-formatter  OR  npm install -g sql-formatter"
fi

echo "==> Installing lazygit (optional but recommended)..."
if ! command -v lazygit &>/dev/null; then
  echo "    WARNING: lazygit not found."
  echo "      Install: brew install lazygit"
  echo "               OR see https://github.com/jesseduffield/lazygit#installation"
fi

echo "==> Linking ~/.tmux.conf..."
if [ -f "$TMUX_CONF_DST" ] && [ ! -L "$TMUX_CONF_DST" ]; then
  BACKUP="$TMUX_CONF_DST.backup.$(date +%Y%m%d-%H%M%S)"
  echo "    Existing ~/.tmux.conf found — backing up to $BACKUP"
  mv "$TMUX_CONF_DST" "$BACKUP"
fi
ln -sf "$TMUX_CONF_SRC" "$TMUX_CONF_DST"
echo "    ~/.tmux.conf -> $TMUX_CONF_SRC"

echo "==> Installing TPM (Tmux Plugin Manager)..."
if [ -d "$TPM_DIR" ]; then
  echo "    TPM already installed at $TPM_DIR — pulling latest..."
  git -C "$TPM_DIR" pull --quiet
else
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
  echo "    TPM installed."
fi

echo ""
echo "==> Done! Next steps:"
echo "    1. Start a new tmux session:  tmux"
echo "    2. Press <prefix> I  (Ctrl-a then Shift-i) to install plugins."
echo "    3. Reload config if needed:  <prefix> r  or  tmux source ~/.tmux.conf"
echo ""
echo "    NOTE: Nerd Fonts are required for catppuccin icons to render correctly."
echo "    Download from https://www.nerdfonts.com and set in your terminal."
