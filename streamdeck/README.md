# Stream Deck (Zoom Call Deck)

A custom Stream Deck plugin for a 15-key Stream Deck (5×3) on macOS. Outside meetings the
deck shows notifications and Spotify; when a Zoom meeting starts it switches to call
controls on its own and switches back when the meeting ends. Nothing on the deck is an
app launcher.

The plugin (`com.bschur.zoomcall`) talks to the Stream Deck app over the SDK's WebSocket
protocol. Anything an app doesn't expose to scripting is done through the macOS
Accessibility API by a small Swift helper, `zoomctl`.

## Layouts

**Home page** (the Default Profile's main page):

| Slack | Outlook | Next meeting | Slack focus 🔭 | Slack DnD 🍅 |
|---|---|---|---|---|
| Album art | Album art | ⏮ | ⏯ | ⏭ |
| Album art | Album art | 🔀 | 🎵 Playlists | *(empty)* |

**Zoom Call page** (switches in automatically during a meeting):

| Share | Raise Hand | Mute | Video | Leave |
|---|---|---|---|---|
| 👍 | 👏 | ❤️ | 😂 | 🎉 |
| 🔥 | 👀 | 🙌 | 🏠 Home | More ▸ |

**More page:** 🐱 `:gr_meow_thinking:`, 😮, 💯 / Record, Chat, Participants / 🏠 Home, ◀ Back.

**Playlist picker:** ◀ Back plus 14 playlists. Picking one plays it and returns to the
home page; during a meeting, Back returns to the call page instead.

## What each key does

| Key | How it works |
|---|---|
| Slack / Outlook badges | Read the Dock badge with `lsappinfo info -only StatusLabel <App>` (no permissions). Slack shows the badge total (DMs + mentions) plus a blue **DM n** pill read from Slack's "DMs, N unread" label. Outlook shows mail that's new since you last pressed the key, with the total underneath. Pressing opens the app. |
| Next meeting | Parses today's events from Zoom Workplace's calendar side panel. Countdown turns amber at 15 min and green at 5 min or once Zoom offers **Join**; pressing joins. Skips holds and all-day entries. During a meeting it shows **📞 Call** and takes you back to the call page. |
| Slack focus 🔭 | Presses Slack's own "Turn on / Exit focus mode" button. |
| Slack DnD 🍅 | **On:** turns focus mode off, picks the recent status "🍅 Focus", ticks "Pause notifications until status is cleared" (VIPs still get through), saves. **Off:** clears the status and resumes notifications. State is read from Slack every 5 s. |
| Album art | The current Spotify cover split across a 2×2 block, with track and artist. Pressing opens Spotify. |
| ⏮ ⏯ ⏭ 🔀 | Elgato's Spotify plugin. |
| Playlists | Plays via AppleScript `play track "spotify:playlist:<id>"` (Liked Songs: `spotify:user:<user id>:collection`). Covers come from Spotify's public oEmbed endpoint; no login. |
| Zoom call keys | Mute, Video, Share, Leave, Record, Raise Hand and 👍👏❤️😂🎉😮 use Elgato's Zoom plugin. |
| Extra reactions | 🔥 👀 🙌 💯 and custom emoji drive Zoom's **React → More reactions** picker: search by shortcode, click the result (~1–2 s). |
| Chat / Participants | Zoom's **View → Show/Hide** menu items. |
| Home / Back | Leaves the plugin's profile and returns to the previously active (home) profile. |

### Meeting detection

Every 2 s the plugin checks for Zoom's "Zoom Meeting" window (Accessibility) or open UDP
media sockets from `zoom.us` (`lsof`). Two positive checks switch to the call page; three
negative checks switch back, unless you already went home with 🏠.

## Requirements

- macOS 12+, Stream Deck app 6.6+ (tested on 7.4), Xcode command-line tools (`swiftc`), Node/npm.
- Elgato's **Zoom** and **Spotify** plugins (from the Marketplace).
- **Accessibility** permission for *Elgato Stream Deck* (System Settings → Privacy & Security →
  Accessibility). The plugin prompts on first run.
- **Automation** permission for Stream Deck → Spotify (macOS asks the first time).
- Slack DnD: set the status "🍅 Focus" by hand once so it's in Slack's **Recent** statuses.

## Layout of this directory

```
build.sh                    builds the helper binaries, node deps, icons and the bundled profile
src/zoomctl.swift           Accessibility helper: Zoom reactions/panels/meetings, Slack focus/DnD/status
src/deckart.swift           renders dynamic key images (badges, album art, covers, text) as PNG data URIs
src/make-icons.swift        renders static emoji icons
src/build_profile.py        builds the bundled "Zoom Call" profile (call, More, playlist pages)
src/build_home_page.py      rewrites the Default Profile's home page
src/playlists_page.py       installs the playlist picker + home Playlists key
src/playlists.json          the playlist list (edit this)
src/update_main_profile.py  one-time cleanup of the old folders (historical)
com.bschur.zoomcall.sdPlugin/
  manifest.json             plugin + action definitions
  bin/plugin.js             the plugin (meeting switching, keys, polling)
```

## Install on a new Mac

```bash
cd ~/dotfiles/streamdeck
./build.sh
ln -sfn "$PWD/com.bschur.zoomcall.sdPlugin" \
  ~/Library/Application\ Support/com.elgato.StreamDeck/Plugins/com.bschur.zoomcall.sdPlugin
```

Then quit Stream Deck (`kill -TERM $(pgrep -x "Stream Deck")`; AppleScript quit isn't
allowed), and with it quit:

```bash
python3 src/build_home_page.py    # home page
python3 src/playlists_page.py     # Playlists key + picker page
open -a "Elgato Stream Deck"
```

On first launch the plugin installs the "Zoom Call" profile. The scripts expect the
Default Profile and the "Zoom Call" profile to exist and edit them in place; back up
`~/Library/Application Support/com.elgato.StreamDeck/ProfilesV3` first.

## Changing things

- **Always quit Stream Deck before editing profile files**, or it overwrites them on exit.
- **Playlists:** edit `src/playlists.json` (id from the share link, or `uri` for Liked Songs), then
  re-run `src/playlists_page.py` with Stream Deck quit. 14 slots.
- **Reactions / call layout:** edit `src/build_profile.py`, run `./build.sh`. The installed copy of
  the "Zoom Call" profile isn't replaced automatically; edit it in `ProfilesV3/` or reinstall the plugin.
- **Plugin code:** edit `bin/plugin.js`, then restart Stream Deck.
- `zoomctl` is also handy from a shell: `zoomctl status`, `meetings`, `slack-status`,
  `slack-status-dnd on|off`, `react 🔥 fire`, `dump all` (prints Zoom's Accessibility tree).

## Troubleshooting

- Log: `com.bschur.zoomcall.sdPlugin/logs/zoomcall.log`. Failed Zoom actions also log Zoom's
  Accessibility tree, which helps after a Zoom UI update.
- A key showing ⚠️ or a warning triangle means the helper couldn't find the Zoom/Slack control it
  expected; check the log.
- **Next meeting** says "No more meetings" while you have one: open the Zoom Workplace window once.
- Slack DnD shows ⚠️: make sure "🍅 Focus" is still in Slack's Recent statuses.

### Dead ends

- Elgato's **Slack** plugin needs a Slack app approved for the workspace, which may not be allowed.
- macOS Do Not Disturb via Shortcuts was unreliable: `shortcuts run` hung, and the URL scheme only
  sometimes worked.
- Spotify's app exposes no Accessibility tree and AppleScript can't list playlists. Playlist IDs were
  found in Spotify's local cache (`PersistentCache/Users/*/primary.ldb`).
