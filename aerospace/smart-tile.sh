#!/bin/bash
# "Smart" default tiling: never line up 3+ windows in a single row/column.
# When a new window brings a workspace to 3+ tiled windows, rebuild it as a
# near-square grid, with the fuller columns on the RIGHT:
#
#   3 windows:          4 windows:          5 windows:
#   +------+------+     +------+------+     +----+----+----+
#   |      |  B   |     |  A   |  C   |     |    | B  | D  |
#   |  A   +------+     +------+------+     | A  +----+----+
#   |      |  C   |     |  B   |  D   |     |    | C  | E  |
#   +------+------+     +------+------+     +----+----+----+
#
# On a portrait monitor (v_tiles root) the same grid is built in rows.
# Windows are placed oldest -> newest (lowest window id first).
#
# It runs ONLY when a window is detected (or on alt-shift-m), never on focus
# or move, so after it lays things out you can freely move/resize windows
# (ctrl-shift-h/l etc.) and it won't snap them back. The next new window on
# that workspace re-grids it.
#
# Usage: smart-tile.sh [workspace]
#   Called from a catch-all on-window-detected rule, which sets
#   $AEROSPACE_WINDOW_ID; the workspace is looked up from that window.
#   With an explicit workspace arg (alt-shift-m) it re-grids that workspace.
#
# Left alone (other scripts own these layouts):
#   - workspace 9 (grid-workspace.sh parking grid)
#   - any workspace with a Zoom window (zoom-route.sh sizes the meeting window)
#   - workspaces with a fullscreen window or an accordion root

AEROSPACE=/opt/homebrew/bin/aerospace
SKIP_WS="9"
SKIP_APP="us.zoom.xos"

# Let earlier/later on-window-detected rules (move-node-to-workspace, the
# async Alacritty first-window move) finish placing the window.
sleep 0.3

WS="$1"
if [ -z "$WS" ] && [ -z "$AEROSPACE_WINDOW_ID" ]; then
    WS=$("$AEROSPACE" list-workspaces --focused)
fi
if [ -z "$WS" ]; then
    line=$("$AEROSPACE" list-windows --all --format '%{window-id}|%{workspace}|%{window-layout}' \
               | awk -F'|' -v id="$AEROSPACE_WINDOW_ID" '$1 == id')
    [ -n "$line" ] || exit 0
    WS=$(echo "$line" | cut -d'|' -f2)
    # A new floating window (e.g. the Flameshot overlay) doesn't change tiling.
    [ "$(echo "$line" | cut -d'|' -f3)" = "floating" ] && exit 0
fi
for s in $SKIP_WS; do [ "$WS" = "$s" ] && exit 0; done

# Serialize per workspace: several windows can be detected at once (e.g. at
# startup). If a run is in progress, flag it to run once more when done.
LOCK="/tmp/aerospace-smart-tile-$WS.lock"
PENDING="/tmp/aerospace-smart-tile-$WS.pending"
if ! mkdir "$LOCK" 2>/dev/null; then
    # Stale lock (crashed run) older than 10s -> take it over.
    if [ -n "$(find "$LOCK" -maxdepth 0 -mtime +10s 2>/dev/null)" ]; then
        rmdir "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || exit 0
    else
        touch "$PENDING"; exit 0
    fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

build_grid() {
    local info root fwd back stack_layout ids n cols base extra i c k size cmds
    info=$("$AEROSPACE" list-windows --workspace "$WS" --format \
        '%{window-id}|%{window-layout}|%{workspace-root-container-layout}|%{window-is-fullscreen}|%{app-bundle-id}')
    [ -n "$info" ] || return

    echo "$info" | awk -F'|' -v app="$SKIP_APP" '$4 == "true" || $5 == app { f = 1 } END { exit !f }' && return

    root=$(echo "$info" | head -1 | cut -d'|' -f3)
    case "$root" in
        h_tiles) fwd=right; back=left; stack_layout=v_tiles ;;
        v_tiles) fwd=down;  back=up;   stack_layout=h_tiles ;;
        *) return ;;  # accordion root: leave it
    esac

    # Tiled windows, oldest first.
    ids=($(echo "$info" | awk -F'|' '$2 != "floating" { print $1 }' | sort -n))
    n=${#ids[@]}
    [ "$n" -ge 3 ] || return

    # One 'aerospace eval' = one layout pass, so the rebuild doesn't jitter.
    # ';' keeps going past commands that fail (e.g. a move at the edge).
    cmds="flatten-workspace-tree --workspace $WS"
    cmds+="; layout --workspace $WS --root $root"
    # list-windows isn't in tree order: push each window to the far end in id
    # order, so the tree order becomes ids[0], ids[1], ...
    for id in "${ids[@]}"; do
        for ((k = 1; k < n; k++)); do
            cmds+="; move --window-id $id --boundaries workspace --boundaries-action fail $fwd"
        done
    done

    # cols = ceil(sqrt(n)); the extra windows go to the RIGHT-most columns.
    cols=1
    while [ $((cols * cols)) -lt "$n" ]; do cols=$((cols + 1)); done
    base=$((n / cols)); extra=$((n % cols))

    # Each column: join its first two windows (creates an opposite-orientation
    # container), then 'move back' any further windows into that container.
    i=0
    for ((c = 0; c < cols; c++)); do
        size=$base; [ "$c" -ge $((cols - extra)) ] && size=$((base + 1))
        if [ "$size" -ge 2 ]; then
            cmds+="; join-with --window-id ${ids[$i]} $fwd"
            for ((k = i + 2; k < i + size; k++)); do
                cmds+="; move --window-id ${ids[$k]} $back"
            done
            cmds+="; layout --window-id ${ids[$i]} $stack_layout"
        fi
        i=$((i + size))
    done
    cmds+="; balance-sizes --workspace $WS"

    "$AEROSPACE" eval "$cmds" >/dev/null 2>&1
}

build_grid
while [ -e "$PENDING" ]; do
    rm -f "$PENDING"
    sleep 0.2
    build_grid
done
