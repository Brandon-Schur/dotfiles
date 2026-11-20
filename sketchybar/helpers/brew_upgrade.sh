#!/bin/zsh -l
# Run by right-clicking the SketchyBar brew item (items/brew/brew.lua).
# Upgrades all outdated formulae and casks in the background, with no window
# and no prompts. stdin is /dev/null, so a cask that needs an admin password
# fails instead of waiting forever; the rest still upgrade, and whatever is
# left stays in the bar's outdated count.
# Output: ~/Library/Logs/brew_upgrade.log

LOG="$HOME/Library/Logs/brew_upgrade.log"
LOCK="/tmp/brew_upgrade_${USER}.lock"

# One run at a time (a second right-click while running does nothing).
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK"' EXIT

{
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') brew upgrade ==="
  brew update
  brew upgrade
  echo "=== exit $? ==="
} </dev/null >"$LOG" 2>&1

/opt/homebrew/bin/sketchybar --trigger brew_update
