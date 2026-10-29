#!/bin/bash
# Move a newly detected window to its role's workspace for the current
# profile (see workspaces.sh). Called via exec-and-forget from
# on-window-detected, which sets $AEROSPACE_WINDOW_ID.
#
# Usage: route.sh <role>

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/workspaces.sh"

ROLE="${1:?usage: route.sh <role>}"
WS=$(ws_for "$ROLE")
[ -n "$WS" ] && [ -n "$AEROSPACE_WINDOW_ID" ] || exit 0
"$AEROSPACE" move-node-to-workspace --window-id "$AEROSPACE_WINDOW_ID" "$WS"
