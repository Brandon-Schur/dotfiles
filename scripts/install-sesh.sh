#!/usr/bin/env bash
# scripts/install-sesh.sh
# Links the sesh session picker into ~/.local/bin and checks its dependencies.
# Usage: bash scripts/install-sesh.sh

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DOTFILES_DIR/sesh"
DST="$HOME/.local/bin"

# fzf and sesh are required; zoxide only supplies the "uses" (frecency) column, so a
# missing zoxide degrades one column rather than breaking the picker.
missing=()
for cmd in sesh fzf tmux; do
  command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "  [!] missing required: ${missing[*]}"
  echo "      sesh:   go install github.com/joshmedeski/sesh/v2@latest"
  echo "      fzf:    https://github.com/junegunn/fzf"
  exit 1
fi
echo "  [•] sesh $(sesh --version 2>/dev/null | head -1), fzf $(fzf --version | cut -d' ' -f1), tmux $(tmux -V | cut -d' ' -f2)"
command -v zoxide &>/dev/null || \
  echo "  [!] zoxide not found — the 'uses' column will be blank (everything else works)"

# gawk, not any awk: the fast path uses strftime(), a GNU extension.
if ! awk 'BEGIN{ if (strftime("%Y", 0) == "") exit 1 }' 2>/dev/null; then
  echo "  [!] awk lacks strftime() — install gawk, or the fast path will fail"
fi

echo "==> Linking the picker into $DST..."
mkdir -p "$DST"
for f in sesh-popup sesh-picker-list sesh-picker-fast check-picker-parity; do
  if [ -e "$DST/$f" ] && [ ! -L "$DST/$f" ]; then
    BACKUP="$DST/$f.backup.$(date +%Y%m%d-%H%M%S)"
    echo "  [•] Backing up existing $f to $BACKUP"
    mv "$DST/$f" "$BACKUP"
  fi
  ln -sf "$SRC/$f" "$DST/$f"
  echo "  [✓] $DST/$f -> $SRC/$f"
done

case ":$PATH:" in
  *":$DST:"*) ;;
  *) echo "  [!] $DST is not on PATH — add it in your shell rc" ;;
esac

echo ""
echo "  Done. The tmux binding is in tmux/.tmux.conf:"
echo "      bind-key \"s\" display-popup -B -h 75% -w 82% -E \"~/.local/bin/sesh-popup\""
echo "  Reload tmux (<prefix> r) and press <prefix> s."
echo "  If you edit the row layout, run check-picker-parity — sesh-picker-list and"
echo "  sesh-picker-fast must produce byte-identical output."
