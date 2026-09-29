#!/usr/bin/env bash
# install.sh — build audio-priority, link its config, and (re)load the LaunchAgent.
#
# Usage: bash audio-priority/install.sh      (safe to re-run after editing the code)
#
# Prerequisites: Xcode Command Line Tools (swiftc), BlackHole 2ch, Loopback. See README.md
# for the one-time manual steps (System Audio Recording permission, Loopback device).
#
# Result:
#   ~/bin/audio-priority                                   compiled binary
#   ~/.config/audio-priority/priority.conf  -> this repo   priority list (symlink)
#   ~/Library/LaunchAgents/com.bschur.audio-priority.plist runs at login, restarts if it dies
#   ~/.local/log/audio-priority.log                        what it switched and why

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="com.bschur.audio-priority"
BIN="$HOME/bin/audio-priority"
CONF_DIR="$HOME/.config/audio-priority"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/.local/log/audio-priority.log"

mkdir -p "$HOME/bin" "$CONF_DIR" "$HOME/.local/log" "$HOME/Library/LaunchAgents"

# Prerequisites (see README.md). BlackHole is where system audio is mirrored for Loopback.
command -v swiftc >/dev/null || { echo "swiftc not found: run xcode-select --install" >&2; exit 1; }
if [ ! -d /Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver ]; then
  echo "warning: BlackHole 2ch not installed (brew install blackhole-2ch);" \
       "device switching works, but the system-audio mirror stays off" >&2
fi

echo "Building $BIN"
# Embed Info.plist and sign with a fixed identifier so the System Audio Recording
# permission is shown for, and remembered as, "audio-priority".
swiftc -O -o "$BIN" "$DIR/audio-priority.swift" \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$DIR/Info.plist"
codesign --force --sign - --identifier com.bschur.audio-priority "$BIN"

# Link the config so edits land in the dotfiles repo; don't clobber a local real file.
if [ -e "$CONF_DIR/priority.conf" ] && [ ! -L "$CONF_DIR/priority.conf" ]; then
  echo "Keeping existing $CONF_DIR/priority.conf (not a symlink)"
else
  ln -sfn "$DIR/priority.conf" "$CONF_DIR/priority.conf"
fi

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
EOF

# Reload: bootout fails harmlessly if it wasn't loaded yet. bootout returns before the old
# process has fully exited, so retry bootstrap briefly ("Bootstrap failed: 5" otherwise).
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
for attempt in 1 2 3 4 5; do
  if launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then break; fi
  if [ "$attempt" = 5 ]; then
    echo "launchctl bootstrap failed; run: launchctl bootstrap gui/$(id -u) $PLIST" >&2
    exit 1
  fi
  sleep 1
done

echo "Loaded $LABEL. Recent log:"
sleep 4
tail -n 8 "$LOG" 2>/dev/null || true
cat <<'EOF'

First install on a Mac: grant the System Audio Recording permission, or the
system-audio mirror records silence (no error). See README.md "Permission":
  System Settings > Privacy & Security > Screen & System Audio Recording >
  "System Audio Recording Only" > + > Cmd-Shift-G > ~/bin/audio-priority > Open
then: launchctl kickstart -k gui/$(id -u)/com.bschur.audio-priority
EOF
