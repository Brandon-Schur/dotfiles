#!/bin/bash
# Move an app's window to a workspace ONLY if it's the app's first/only window.
#
# Usage: first-window-to-workspace.sh <app-bundle-id> <workspace-or-role>
#   The second arg is a workspace number, or a role name from workspaces.sh
#   (e.g. "alacritty") resolved for the current laptop/desk profile.
#
# Used for Alacritty: the first terminal belongs on its home workspace, but
# extra terminals opened later (alt-shift-enter) should stay on whatever
# workspace they were opened from. Called via exec-and-forget from
# on-window-detected. When the app has exactly one window, that window is the
# one just detected, so no window id is needed.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/workspaces.sh"
APP="${1:?usage: first-window-to-workspace.sh <app-bundle-id> <workspace-or-role>}"
WS="${2:?usage: first-window-to-workspace.sh <app-bundle-id> <workspace-or-role>}"
[[ "$WS" =~ ^[0-9]+$ ]] || WS=$(ws_for "$WS")
[ -n "$WS" ] || exit 0

ids=($("$AEROSPACE" list-windows --monitor all --app-bundle-id "$APP" --format '%{window-id}'))
if [ "${#ids[@]}" -eq 1 ]; then
    "$AEROSPACE" move-node-to-workspace --window-id "${ids[0]}" "$WS"
fi
