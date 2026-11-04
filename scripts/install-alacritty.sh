#!/usr/bin/env bash
# scripts/install-alacritty.sh
# Links the Alacritty config, theme, and the OS-specific key bindings into
# ~/.config/alacritty. Existing regular files are backed up first.
# Usage: bash scripts/install-alacritty.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DOTFILES_DIR/alacritty"
DST="$HOME/.config/alacritty"

case "$(uname -s)" in
  Darwin) KEYS="keys-macos.toml" ;;
  Linux)  KEYS="keys-linux.toml" ;;
  *) echo "  [!] Unsupported OS $(uname -s); skipping Alacritty config."; exit 0 ;;
esac

command -v alacritty &>/dev/null || [ -d /Applications/Alacritty.app ] || \
  echo "  [!] alacritty not found; linking the config anyway."

mkdir -p "$DST"

link() {  # link <file in alacritty/> <name in ~/.config/alacritty>
  local src="$SRC/$1" dst="$DST/$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="$dst.backup.$(date +%Y%m%d-%H%M%S)"
    echo "  [•] Backing up $dst to $backup"
    mv "$dst" "$backup"
  fi
  ln -sfn "$src" "$dst"
  echo "  [✓] $dst -> $src"
}

echo "==> Linking Alacritty config..."
link alacritty.toml     alacritty.toml
link bschur_custom.toml bschur_custom.toml
link "$KEYS"            keys-os.toml
