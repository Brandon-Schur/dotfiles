#!/bin/bash
# Put two windows side by side again after a window leaves a smart-tile grid.
#
# Why: smart-tile.sh lays out 3 windows as  A | [B / C]  (a v_tiles column
# on the right). If A closes or moves away, the root holds only that column,
# and AeroSpace's flatten normalization makes the column THE ROOT. Then B and C
# are stacked top/bottom across the whole wide screen. (2x2 does the same when
# both windows of one column go.) AeroSpace has no window-closed callback,
# so this runs from on-focus-changed: closing or moving a window moves focus.
#
# It acts only when the workspace's set of tiled windows CHANGED since the last
# run, so a deliberate ctrl-v / alt-v stack of 2 windows is left alone.
# Skips workspace 9 (grid-workspace.sh owns it).

AEROSPACE=/opt/homebrew/bin/aerospace
STATE_DIR=/tmp/aerospace-pair
mkdir -p "$STATE_DIR"

info=$("$AEROSPACE" list-windows --workspace "${1:-focused}" \
    --format '%{workspace}|%{window-id}|%{window-layout}|%{workspace-root-container-layout}' 2>/dev/null)
[ -n "$info" ] || exit 0

ws=$(echo "$info" | head -1 | cut -d'|' -f1)
[ "$ws" = "9" ] && exit 0

sig=$(echo "$info" | awk -F'|' '$3 != "floating" { print $2 }' | sort -n | tr '\n' ' ')
sig_file="$STATE_DIR/ws-$ws.sig"
[ "$sig" = "$(cat "$sig_file" 2>/dev/null)" ] && exit 0
echo "$sig" > "$sig_file"

n=$(echo "$sig" | wc -w | tr -d ' ')
root=$(echo "$info" | head -1 | cut -d'|' -f4)
# All his monitors are landscape. On a portrait monitor this would be wrong.
if [ "$n" -eq 2 ] && [ "$root" = "v_tiles" ]; then
    "$AEROSPACE" layout --workspace "$ws" --root h_tiles >/dev/null 2>&1
fi
