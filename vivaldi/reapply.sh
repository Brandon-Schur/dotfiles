#!/bin/bash
# Re-apply Vivaldi UI JS mods after
# Vivaldi updates wipe them. Idempotent: does nothing if already applied.
# Triggered by ~/Library/LaunchAgents/com.bschur.vivaldi-mods.plist, which runs
# it through ~/Applications/VivaldiModsReapply.app: macOS App Management only lets
# that app (granted in System Settings) write into Vivaldi.app, not plain bash.

set -u
MODS="$HOME/VivaldiMods"
R="${VIVALDI_RES:-/Applications/Vivaldi.app/Contents/Frameworks/Vivaldi Framework.framework/Versions/Current/Resources/vivaldi}"
JS_FILES=(StackFolderClick.js TabBarAutoCollapse.js)   # load order matters
# Retired mods; step 2 removes their files and <script> tags from Vivaldi.app.
# VividPeek (archive/vividpeek/) was uninstalled Nov 2026. PanelFocusReturn.js
# (archive/sharptabs/) only existed for the Sharp Tabs panel, removed Nov 2026.
REMOVED_JS=(VividAI.js VividMarkdown.js VividPeek.js PanelFocusReturn.js)
log() { echo "$(date '+%F %T') $*"; }
notify() { osascript -e "display notification \"$1\" with title \"Vivaldi mods\"" >/dev/null 2>&1; }
errors=0
fail() { log "ERROR: $*"; errors=1; }

# Let an in-progress update finish writing files.
sleep "${REAPPLY_DELAY:-5}"
[ -d "$R" ] || { log "Vivaldi resources dir not found; skipping"; exit 0; }

changed=0

# 0. Can we write into the app bundle? (Blocked unless App Management is granted.)
probe="$R/.vivaldi-mods-probe"
if ! { : > "$probe" && rm -f "$probe"; } 2>/dev/null; then
  log "ERROR: no write access to Vivaldi.app (grant VivaldiModsReapply App Management)"
  notify "Can't update Vivaldi.app. Allow VivaldiModsReapply in Privacy & Security > App Management."
  exit 1
fi

# 1. JS mod files
for f in "${JS_FILES[@]}"; do
  if ! cmp -s "$MODS/js/$f" "$R/$f"; then
    if cp "$MODS/js/$f" "$R/$f"; then log "copied $f"; changed=1; else fail "copy $f"; fi
  fi
done

# 2. <script> tags in window.html (stock copy saved once before the first edit)
[ -f "$R/window.html.bak-stock" ] || grep -q '<script src="' "$R/window.html" || cp "$R/window.html" "$R/window.html.bak-stock"
for f in "${REMOVED_JS[@]}"; do
  if grep -q "src=\"$f\"" "$R/window.html"; then
    F="$f" perl -0pi -e 's|[ \t]*<script src="\Q$ENV{F}\E"></script>\n?||g' "$R/window.html"
    if grep -q "src=\"$f\"" "$R/window.html"; then fail "remove $f tag"; else log "removed $f tag"; changed=1; fi
  fi
  [ -f "$R/$f" ] && rm -f "$R/$f" && { log "removed $f"; changed=1; }
done
for f in "${JS_FILES[@]}"; do
  if ! grep -q "src=\"$f\"" "$R/window.html"; then
    TAG="  <script src=\"$f\"></script>"$'\n' perl -0pi -e 's|</body>|$ENV{TAG}</body>|' "$R/window.html"
    if grep -q "src=\"$f\"" "$R/window.html"; then
      log "added $f to window.html"; changed=1
    else
      fail "add $f to window.html"
    fi
  fi
done

if [ "$errors" = 1 ]; then
  notify "Some Vivaldi mods failed to apply. See ~/.local/log/vivaldi-mods.log"
  exit 1
fi
if [ "$changed" = 1 ]; then
  ver=$(defaults read /Applications/Vivaldi.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null)
  log "mods re-applied for Vivaldi $ver"
  notify "Mods re-applied after update. Quit (Cmd+Q) and reopen Vivaldi."
else
  log "all mods already in place"
fi
exit 0
