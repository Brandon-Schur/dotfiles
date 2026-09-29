#!/bin/bash
# Force AeroSpace to re-apply every tiled window's frame on visible workspaces.
#
# Why: right after AeroSpace starts, some apps (e.g. Outlook) keep a stale frame
# that spans monitors, apparently ignoring the frame AeroSpace sent while
# everything was starting up. Moving the window to another workspace and back
# (so it gets a DIFFERENT frame, then the right one again) fixed it by hand.
# This does the same automatically: flip each visible workspace's root
# orientation and flip it back. These are separate CLI calls, so each is a real
# layout pass with a changed frame. Invisible workspaces get laid out when you
# switch to them.
#
# Usage: relayout-all.sh [delay-seconds ...]
#   With no args it runs once immediately. With args, it runs once after each
#   delay; after-startup-command uses '3 10' to also catch slow-launching apps.

AEROSPACE=/opt/homebrew/bin/aerospace

relayout_once() {
    local ws root flipped
    for ws in $("$AEROSPACE" list-workspaces --monitor all --visible); do
        root=$("$AEROSPACE" list-windows --workspace "$ws" \
                   --format '%{workspace-root-container-layout}' 2>/dev/null | head -1)
        case "$root" in
            h_tiles) flipped=v_tiles ;;
            v_tiles) flipped=h_tiles ;;
            h_accordion) flipped=v_accordion ;;
            v_accordion) flipped=h_accordion ;;
            *) continue ;;  # empty workspace
        esac
        "$AEROSPACE" layout --workspace "$ws" --root "$flipped" >/dev/null 2>&1
        sleep 0.15
        "$AEROSPACE" layout --workspace "$ws" --root "$root" >/dev/null 2>&1
    done
}

if [ "$#" -eq 0 ]; then
    relayout_once
else
    elapsed=0
    for t in "$@"; do
        sleep "$((t - elapsed))"; elapsed=$t
        relayout_once
    done
fi
