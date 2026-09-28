#!/bin/bash
# Route a newly detected Zoom window once its title is known.
#
# Why: Zoom creates the meeting window BEFORE it sets the "Zoom Meeting" title,
# so the title-based on-window-detected rule usually misses it and the window
# falls through to the "park on 9" rule. This script (run via exec-and-forget
# from that rule) polls the title for a few seconds; if it turns into a
# meeting window it goes to workspace 2 tiled side-by-side (h_tiles), then workspace 9 is
# re-gridded.
#
# AeroSpace passes the detected window as $AEROSPACE_WINDOW_ID; if that isn't
# set we fall back to scanning all Zoom windows.

AEROSPACE=/opt/homebrew/bin/aerospace
DIR="$(cd "$(dirname "$0")" && pwd)"
MEETING_WS=2
PARK_WS=9
MEETING_RE='Zoom Meeting'

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
