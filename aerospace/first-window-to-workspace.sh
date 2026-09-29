#!/bin/bash
# Move an app's window to a workspace ONLY if it's the app's first/only window.
#
# Usage: first-window-to-workspace.sh <app-bundle-id> <workspace>
#
# Used for Alacritty: the first terminal belongs on workspace 3, but extra
# terminals opened later (alt-shift-enter) should stay on whatever workspace
# they were opened from. Called via exec-and-forget from on-window-detected.
# When the app has exactly one window, that window is the one just detected,
# so no window id is needed.

AEROSPACE=/opt/homebrew/bin/aerospace
APP="${1:?usage: first-window-to-workspace.sh <app-bundle-id> <workspace>}"
WS="${2:?usage: first-window-to-workspace.sh <app-bundle-id> <workspace>}"

ids=($("$AEROSPACE" list-windows --monitor all --app-bundle-id "$APP" --format '%{window-id}'))
if [ "${#ids[@]}" -eq 1 ]; then
    "$AEROSPACE" move-node-to-workspace --window-id "${ids[0]}" "$WS"
fi
