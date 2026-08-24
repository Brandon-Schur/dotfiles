#!/usr/bin/env bash
# scripts/install-tmux.sh
# Links the tmux config and installs TPM + plugins.
# Dependencies (tmux, lazygit, formatters) are handled by install-deps.sh.
# Usage: bash scripts/install-tmux.sh

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_CONF_SRC="$DOTFILES_DIR/tmux/.tmux.conf"
TMUX_CONF_DST="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"

if ! command -v tmux &>/dev/null; then
  echo "  [!] tmux not found. Run scripts/install-deps.sh first (or install tmux)."
  exit 1
fi
echo "  [•] tmux $(tmux -V) found"

echo "==> Linking ~/.tmux.conf..."
if [ -f "$TMUX_CONF_DST" ] && [ ! -L "$TMUX_CONF_DST" ]; then
  BACKUP="$TMUX_CONF_DST.backup.$(date +%Y%m%d-%H%M%S)"
  echo "  [•] Backing up existing ~/.tmux.conf to $BACKUP"
  mv "$TMUX_CONF_DST" "$BACKUP"
fi
ln -sf "$TMUX_CONF_SRC" "$TMUX_CONF_DST"
echo "  [✓] ~/.tmux.conf -> $TMUX_CONF_SRC"

echo "==> Installing TPM (Tmux Plugin Manager)..."
if [ -d "$TPM_DIR" ]; then
  git -C "$TPM_DIR" pull --quiet && echo "  [✓] TPM updated"
else
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
  echo "  [✓] TPM installed"
fi

echo "==> Installing tmux plugins..."
# Install plugins non-interactively (equivalent to prefix + I)
if [ -x "$TPM_DIR/bin/install_plugins" ]; then
  "$TPM_DIR/bin/install_plugins" || \
    echo "  [!] Plugin install had issues — open tmux and press <prefix> I to retry"
  echo "  [✓] tmux plugins installed"
fi

echo ""
echo "  Done. Start tmux; reload anytime with <prefix> r (prefix is Ctrl-a)."
echo "  NOTE: a Nerd Font must be set in your terminal for icons to render."
