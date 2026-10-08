#!/bin/bash
# Route a newly detected Zoom window once its title is known.
#
# Why: Zoom creates the meeting window BEFORE it sets the "Zoom Meeting" title,
# so the title-based on-window-detected rule usually misses it and the window
# falls through to the "park on 9" rule. This script (run via exec-and-forget
# from that rule) polls the title for a few seconds; if it turns into a
# meeting window it goes to workspace 2 tiled side-by-side (h_tiles) as the
# LEFT window at MEETING_WIDTH_PCT of the monitor width, then workspace 9 is
# re-gridded.
#
# AeroSpace passes the detected window as $AEROSPACE_WINDOW_ID; if that isn't
# set we fall back to scanning all Zoom windows.

AEROSPACE=/opt/homebrew/bin/aerospace
DIR="$(cd "$(dirname "$0")" && pwd)"
MEETING_WS=2
PARK_WS=9
MEETING_RE='Zoom Meeting'
# Default width of the meeting window, as a % of its monitor's width.
# 28% ≈ 860pt on the 3072pt-wide Odyssey G7. Vivaldi gets the rest.
MEETING_WIDTH_PCT=28

# Width in points of the monitor with the given name (NSScreen via JXA; no
# Accessibility permission needed, ~0.2s).
monitor_width() {
    /usr/bin/osascript -l JavaScript -e "ObjC.import('AppKit');
        var s = \$.NSScreen.screens, w = '';
        for (var i = 0; i < s.count; i++) {
            var sc = s.objectAtIndex(i);
            if (sc.localizedName.js === '$1') { w = Math.round(sc.frame.size.width); }
        }
        w" 2>/dev/null
}

# Shrink the meeting window to MEETING_WIDTH_PCT of its monitor. No-op when it
# is alone on the workspace (resize fails harmlessly).
size_meeting() {
    local id="$1" mon mw
    mon=$("$AEROSPACE" list-windows --workspace "$MEETING_WS" \
              --format '%{window-id}|%{monitor-name}' | awk -F'|' -v id="$id" '$1 == id { print $2 }')
    mw=$(monitor_width "$mon")
    [ -n "$mw" ] || return
    "$AEROSPACE" resize --window-id "$id" width $((mw * MEETING_WIDTH_PCT / 100)) >/dev/null 2>&1
}

route_meetings() {
    # Reads "id workspace title" for candidate Zoom windows, moves meeting ones.
    # A freshly detected window ($AEROSPACE_WINDOW_ID) is placed even if the
    # title rule already put it on workspace 2 (it still needs to go left).
    local moved=1 id ws title
    while read -r id ws title; do
        [ -z "$id" ] && continue
        [ -n "$AEROSPACE_WINDOW_ID" ] && [ "$id" != "$AEROSPACE_WINDOW_ID" ] && continue
        if [[ "$title" =~ $MEETING_RE ]] && { [ "$ws" != "$MEETING_WS" ] || [ -n "$AEROSPACE_WINDOW_ID" ]; }; then
            "$AEROSPACE" layout --window-id "$id" tiling >/dev/null 2>&1
            "$AEROSPACE" move-node-to-workspace --window-id "$id" "$MEETING_WS" >/dev/null 2>&1
            "$AEROSPACE" layout --window-id "$id" h_tiles >/dev/null 2>&1
            # New windows land on the right; push it to the far left.
            for _ in $(seq 1 10); do
                "$AEROSPACE" move --window-id "$id" --boundaries workspace \
                    --boundaries-action fail left >/dev/null 2>&1 || break
            done
            size_meeting "$id"
            moved=0
        fi
    done < <("$AEROSPACE" list-windows --monitor all --app-bundle-id us.zoom.xos \
                 --format '%{window-id} %{workspace} %{window-title}' 2>/dev/null)
    return $moved
}

# Poll ~6s for the title to appear.
for _ in $(seq 1 20); do
    if route_meetings; then break; fi
    sleep 0.3
done

"$DIR/grid-workspace.sh" "$PARK_WS"
