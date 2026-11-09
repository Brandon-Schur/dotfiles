#!/usr/bin/env bash
# scripts/install-ghostty.sh
# Links the Ghostty config and theme into ~/.config/ghostty, plus the Linux
# key bindings (keys-linux.ghostty -> keys-os.ghostty) on Linux. Existing
# regular files are backed up first.
# Usage: bash scripts/install-ghostty.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DOTFILES_DIR/ghostty"
DST="$HOME/.config/ghostty"

case "$(uname -s)" in
  Darwin) KEYS="" ;;  # Ghostty's macOS defaults already use Cmd
  Linux)  KEYS="keys-linux.ghostty" ;;
  *) echo "  [!] Unsupported OS $(uname -s); skipping Ghostty config."; exit 0 ;;
esac

command -v ghostty &>/dev/null || [ -d /Applications/Ghostty.app ] || \
  echo "  [!] ghostty not found; linking the config anyway."

mkdir -p "$DST/themes"

link() {  # link <file in ghostty/> <name in ~/.config/ghostty>
  local src="$SRC/$1" dst="$DST/$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="$dst.backup.$(date +%Y%m%d-%H%M%S)"
    echo "  [•] Backing up $dst to $backup"
    mv "$dst" "$backup"
  fi
  ln -sfn "$src" "$dst"
  echo "  [✓] $dst -> $src"
}

echo "==> Linking Ghostty config..."
link config.ghostty        config.ghostty
link themes/bschur_custom  themes/bschur_custom
[ -n "$KEYS" ] && link "$KEYS" keys-os.ghostty
exit 0
