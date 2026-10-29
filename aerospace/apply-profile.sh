#!/bin/bash
# Re-sort already-open windows into the current profile's workspaces
# (see workspaces.sh). New windows are handled by route.sh; this covers
# docking/undocking.
#
# Usage: apply-profile.sh [--if-changed]
#   --if-changed  only act when the profile differs from the last run
#                 (used by SketchyBar's display_change hook).
#   no args       always apply (alt-shift-p).
#
# Alacritty: only moved when exactly one terminal is open (extra terminals
# stay where you put them). Zoom meeting windows follow the "meeting" role.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/workspaces.sh"

STATE=/tmp/aerospace-profile
LOCK=/tmp/aerospace-apply-profile.lock

# Single run at a time; display_change fires several times while docking.
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK"' EXIT

# Let monitors settle before counting them.
[ "$1" = "--if-changed" ] && sleep 2

PROFILE=$(ws_profile)
if [ "$1" = "--if-changed" ] && [ "$(cat "$STATE" 2>/dev/null)" = "$PROFILE" ]; then
    exit 0
fi
echo "$PROFILE" > "$STATE"

move() { "$AEROSPACE" move-node-to-workspace --window-id "$1" "$2" >/dev/null 2>&1; }

for role in slack vivaldi dashboard outlook spotify alacritty; do
    ws=$(ws_for "$role" "$PROFILE")
    app=$(app_for "$role")
    ids=($("$AEROSPACE" list-windows --monitor all --app-bundle-id "$app" --format '%{window-id}' 2>/dev/null))
    [ "$role" = alacritty ] && [ "${#ids[@]}" -ne 1 ] && continue
    for id in "${ids[@]}"; do move "$id" "$ws"; done
done

meeting_ws=$(ws_for meeting "$PROFILE")
"$AEROSPACE" list-windows --monitor all --app-bundle-id us.zoom.xos \
    --format '%{window-id}|%{window-title}' 2>/dev/null |
while IFS='|' read -r id title; do
    [[ "$title" =~ "Zoom Meeting" ]] && move "$id" "$meeting_ws"
done

/bin/bash "$DIR/relayout-all.sh"
