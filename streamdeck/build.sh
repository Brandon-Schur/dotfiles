#!/usr/bin/env bash
# Builds the Zoom Call Deck plugin in place: helper binary, node deps, icons, bundled profile.
set -euo pipefail
cd "$(dirname "$0")"
P=com.bschur.zoomcall.sdPlugin
mkdir -p "$P/bin" "$P/imgs" build/icons

swiftc -O -o "$P/bin/zoomctl" src/zoomctl.swift
swiftc -O -o "$P/bin/deckart" src/deckart.swift
(cd "$P" && npm install --omit=dev --no-audit --no-fund --silent)

BG=""  # transparent: matches the Elgato Zoom keys (deck default black)
# Plugin/action icons (stem, px, glyph, caption, bg); @2x variants rendered from the same spec.
spec() {
  printf '%s\t%s\t%s\t%s\t%s\n' \
    plugin 256 "📞" "" "$BG"          "plugin@2x" 512 "📞" "" "$BG" \
    category 28 "📞" "" ""             "category@2x" 56 "📞" "" "" \
    action-react 20 "😀" "" ""         "action-react@2x" 40 "😀" "" "" \
    action-panel 20 "💬" "" ""         "action-panel@2x" 40 "💬" "" "" \
    action-page 20 "⋯" "" ""           "action-page@2x" 40 "⋯" "" "" \
    action-open 20 "📞" "" ""          "action-open@2x" 40 "📞" "" "" \
    key-react 72 "😀" "" "$BG"         "key-react@2x" 144 "😀" "" "$BG" \
    key-chat 72 "💬" "Chat" "$BG"      "key-chat@2x" 144 "💬" "Chat" "$BG" \
    key-more 72 "😀" "More" "$BG"      "key-more@2x" 144 "😀" "More" "$BG" \
    key-open 72 "📞" "Zoom Call" "$BG" "key-open@2x" 144 "📞" "Zoom Call" "$BG"
}
spec | swift src/make-icons.swift "$P/imgs"

# Per-key images embedded in the profile (144px).
{
  printf '%s\t144\t%s\t%s\t%s\n' \
    k-chat "💬" "Chat" "$BG"  k-people "👥" "People" "$BG" \
    k-more "😀" "More ▸" "$BG"  k-back "◀️" "Back" "$BG"  k-home "🏠" "Home" "$BG"
  while IFS=$'\t' read -r stem glyph cap; do printf '%s\t144\t%s\t%s\t%s\n' "$stem" "$glyph" "$cap" "$BG"; done <<'EOF'
e-fire	🔥	
e-100	💯	
e-eyes	👀	
e-raise	🙌	
e-meow	🐱	thinking
EOF
} | swift src/make-icons.swift build/icons

python3 src/build_profile.py build/icons "$P/Zoom Call.streamDeckProfile"
echo "build ok"
