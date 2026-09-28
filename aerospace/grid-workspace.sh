#!/bin/bash
# Arrange every TILED window on a workspace into a near-square grid.
#   4 windows -> 2x2, 6 -> 3x2, 3 -> 2 cols (2 + 1), 5 -> 3 cols (2 + 2 + 1), ...
#
# Usage: grid-workspace.sh <workspace> [--if-changed]
#   --if-changed  only re-grid when the set of tiled windows on the workspace
#                 changed since the last run (cheap enough to call from
#                 on-focus-changed / exec-on-workspace-change).
#
# How: AeroSpace has no native grid layout, so we build one from the tree:
#   root h_tiles  ->  one v_tiles column per grid column.
# flatten-workspace-tree resets to a flat list, then for each column we
# join-with the first two windows (creates a v container thanks to the
# opposite-orientation normalization) and 'move left' any further windows
# into that column container.

AEROSPACE=/opt/homebrew/bin/aerospace
WS="${1:?usage: grid-workspace.sh <workspace> [--if-changed]}"
MODE="$2"

STATE_DIR="/tmp/aerospace-grid"
LOCK="$STATE_DIR/ws-$WS.lock"
PENDING="$STATE_DIR/ws-$WS.pending"
SIG_FILE="$STATE_DIR/ws-$WS.sig"
mkdir -p "$STATE_DIR"

tiled_ids() {
    "$AEROSPACE" list-windows --workspace "$WS" --format '%{window-id} %{window-layout}' \
        | awk '$2 != "floating" { print $1 }'
}

signature() { tiled_ids | sort -n | tr '\n' ' '; }

if [ "$MODE" = "--if-changed" ] && [ "$(signature)" = "$(cat "$SIG_FILE" 2>/dev/null)" ]; then
    exit 0
fi

# Serialize: callbacks can fire several times in quick succession. If a run is
# already in progress, flag it to run once more when it finishes.
if ! mkdir "$LOCK" 2>/dev/null; then
    # Stale lock guard (e.g. a crashed run): older than 10s -> take it over.
    if [ -n "$(find "$LOCK" -maxdepth 0 -mtime +10s 2>/dev/null)" ]; then
        rmdir "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || exit 0
    else
        touch "$PENDING"; exit 0
    fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

build_grid() {
    local ids n cols base extra i c k start size
    "$AEROSPACE" flatten-workspace-tree --workspace "$WS"
    ids=($(tiled_ids))
    n=${#ids[@]}
    [ "$n" -eq 0 ] && return

    # Root: side-by-side tiles (overrides the global accordion default).
    "$AEROSPACE" layout --workspace "$WS" --root h_tiles >/dev/null 2>&1

    # list-windows does NOT return tree order (it's sorted by app), so impose
    # our order: push each window, in list order, all the way to the right.
    # Afterwards the left-to-right tree order equals ${ids[@]}.
    for id in "${ids[@]}"; do
        for ((k = 0; k < n; k++)); do
            "$AEROSPACE" move --window-id "$id" --boundaries workspace \
                --boundaries-action fail right >/dev/null 2>&1 || break
        done
    done

    # cols = ceil(sqrt(n)); distribute windows evenly, extras go to left columns.
    cols=1
    while [ $((cols * cols)) -lt "$n" ]; do cols=$((cols + 1)); done
    base=$((n / cols)); extra=$((n % cols))

    i=0
    for ((c = 0; c < cols; c++)); do
        size=$base; [ "$c" -lt "$extra" ] && size=$((base + 1))
        start=$i
        if [ "$size" -ge 2 ]; then
            "$AEROSPACE" join-with --window-id "${ids[$start]}" right
            for ((k = start + 2; k < start + size; k++)); do
                "$AEROSPACE" move --window-id "${ids[$k]}" left
            done
            "$AEROSPACE" layout --window-id "${ids[$start]}" v_tiles >/dev/null 2>&1
        fi
        i=$((start + size))
    done
    "$AEROSPACE" balance-sizes --workspace "$WS" 2>/dev/null
    signature > "$SIG_FILE"
}

sleep 0.2  # let AeroSpace finish placing a just-detected window
build_grid
while [ -e "$PENDING" ]; do
    rm -f "$PENDING"
    sleep 0.2
    build_grid
done
