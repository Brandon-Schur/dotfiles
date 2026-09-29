# audio-priority

Automatic audio device selection and meeting capture for macOS. Moving between the
home desk, the work desk, the laptop alone, and Bluetooth headphones needs no changes
in Audio MIDI Setup, Loopback, or any app, and only one output and one input are active
at a time.

A small LaunchAgent daemon does three things:

1. **Picks the default devices.** When a device listed in `priority.conf` connects or
   disconnects, it sets the default output, alert-sound output, and input to the first
   one present. A device you pick by hand in Control Center sticks until the hardware
   changes again.
2. **Mirrors all system audio into BlackHole 2ch.** A Core Audio process tap captures
   every app's output, whatever device it plays to, and copies it into BlackHole.
3. **Publishes a "Preferred Mic" input** that always wraps the current default input.

Loopback's **Meeting Capture** device combines BlackHole (everything you hear) with
Preferred Mic (your voice), and a transcription/recording app records Meeting Capture.

```
apps ──> default output (WooAudio / ODAC / Buds / speakers)     <- you hear this
  └──> [tap, audio-priority] ──> BlackHole 2ch ──┐
default input ──> "Preferred Mic" ───────────────┼──> Loopback "Meeting Capture" ──> recorder
```

## Current configuration

**Output**, first one present wins:

| # | Pattern | Device | Where |
|---|---|---|---|
| 1 | `bluetooth` | any Bluetooth headphones (Buds4 Pro) | anywhere |
| 2 | `WooAudio` | WooAudio amp/DAC (XMOS USB) | home desk hub |
| 3 | `ODAC` | O2 amp + JDS Labs ODAC (reports as `ODAC-revB`) | work desk |
| 4 | `MacBook Pro Speakers` | built-in | fallback |

**Input**, first one present wins:

| # | Pattern | Device | Where |
|---|---|---|---|
| 1 | `Plugable` | Plugable USB Audio Device (mic interface) | work desk |
| 2 | `USB Audio CODEC` | Burr-Brown USB codec (`USB AUDIO  CODEC`) | home desk hub |
| 3 | `bluetooth` | Buds mic (drops the headphones into call mode) | anywhere |
| 4 | `MacBook Pro Microphone` | built-in | fallback |

The daemon never selects the monitors (LG, Odyssey), BlackHole, Loopback devices,
Zoom/Teams virtual devices, or its own devices.

**Loopback: Meeting Capture** (a snapshot is in `loopback/Devices.plist`)

| Source | Wiring |
|---|---|
| BlackHole 2ch | 1 → Channel 1 (L), 2 → Channel 2 (R) |
| Preferred Mic | 1 → Channel 1 (L) **and** Channel 2 (R) (most mics are mono) |

It has no other sources: no per-app sources and no specific mics. There is no
Multi-Output Device; delete it if one exists, because it would feed BlackHole twice.

**Apps**
- Transcription/recording app: input = **Meeting Capture**.
- Chime / Zoom / Teams / Slack / Webex: speaker and mic = **Same as System** / **Default**,
  so they follow the daemon.

## Set up on a new Mac

1. **Prerequisites**
   ```bash
   xcode-select --install          # swiftc
   brew install blackhole-2ch      # mirror target (reboot or restart coreaudiod if it doesn't appear)
   ```
   Install [Loopback](https://rogueamoeba.com/loopback/) (license in the Rogue Amoeba
   account) and let it install ARK and grant its permissions.
2. **Install the daemon**
   ```bash
   bash ~/dotfiles/audio-priority/install.sh
   ```
3. **Permission** (one time, required): without it the mirror silently records silence.
   macOS may not prompt, so add it by hand:
   System Settings → Privacy & Security → Screen & System Audio Recording → scroll to
   **System Audio Recording Only** → **+** → press Cmd-Shift-G, type `~/bin/audio-priority`,
   Return → **Open**, and make sure it's switched on. Use the bottom list's **+**, not the
   top one, which would also grant screen recording. Then restart the daemon:
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.bschur.audio-priority
   ```
   Audio Routing Kit (ARK) should already be in that same list (Loopback does that).
4. **Loopback**: create a device named **Meeting Capture**, remove its Pass-Thru source,
   and add the two sources with the wiring in the table above. (Copying
   `loopback/Devices.plist` to `~/Library/Application Support/Loopback/` while Loopback
   is quit may also work, but the format is undocumented; recreating it in the UI is safer.)
5. **Transcription/recording app** → input **Meeting Capture**; meeting apps → system default devices.
6. **Verify** (see below). If the new Mac's devices have different names, run
   `audio-priority --list` and adjust `priority.conf`.

## Day-to-day

```bash
audio-priority --list      # devices: name, [in/out, transport], uid
audio-priority --once      # re-apply priorities now (e.g. after editing priority.conf)
tail -f ~/.local/log/audio-priority.log
launchctl kickstart -k gui/$(id -u)/com.bschur.audio-priority   # restart
```

**Editing priorities**: `~/.config/audio-priority/priority.conf` is a symlink to
`priority.conf` here. Patterns are `bluetooth`, `uid:<exact UID>`, or a case-insensitive
name substring (runs of spaces are ignored). Changes apply on the next device change, or
right away with `--once`.

**Talking on the Buds away from the desk**: pick the Buds as input in Control Center.
Preferred Mic follows automatically, so the recording picks you up too.

**Code changes**: edit `audio-priority.swift`, then re-run `install.sh`. A rebuild has kept
the permission so far. If recordings go silent after a rebuild, repeat step 3.

## Verify

```bash
tail -n 5 ~/.local/log/audio-priority.log
# expect: "mirroring all system audio into BlackHole2ch_UID"
#         "published \"Preferred Mic\" -> <your mic>"
```
Then play a video, speak, and check that the recorder shows both. Loopback's meters on the
BlackHole and Preferred Mic tiles should move.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Recording has no system audio, no errors | Permission missing (step 3), or BlackHole not installed. Check the log for "mirroring…". |
| Recording has audio twice / echo | A Multi-Output Device containing BlackHole is the output. Delete it. |
| Output stays on speakers at home | WooAudio sometimes doesn't re-enumerate after the hub is replugged. Power-cycle the DAC; the daemon switches to it when it appears. |
| Voice only in the left channel | Preferred Mic's channel 1 isn't wired to Channel 2 (R) in Loopback. |
| Buds sound bad while recording | The Buds are the input (call mode). Pick another mic, or accept it while away from the desk. |
| `install.sh`: "Bootstrap failed: 5" | launchd race; the script retries. If it still fails, re-run the printed `launchctl bootstrap` command. |
| Loopback shows Preferred Mic "missing" | The daemon isn't running (it creates the device). Check `launchctl print gui/$(id -u)/com.bschur.audio-priority`. |

## Design notes

- **Why not a Multi-Output Device?** A Multi-Output Device is a fixed device list, so every
  location change meant editing it by hand. It also disables the volume keys.
- **Why mirror into BlackHole instead of publishing the tap directly?** Loopback's ARK engine
  opens only an aggregate device's hardware sub-devices and ignores taps, so a tap-only
  aggregate is silent in Loopback. The daemon runs a *private* aggregate of
  [BlackHole + global tap] and copies tap input → BlackHole output in one IO callback on a
  shared clock. It excludes itself from the tap to avoid feedback, and rebuilds the mirror
  if BlackHole disappears and comes back.
- **Why Preferred Mic works**: ARK opens the aggregate's single sub-device, and it follows
  when the daemon swaps that sub-device on a default-input change.
- **Permission plumbing**: taps need `kTCCServiceAudioCapture`. `install.sh` embeds
  `Info.plist` (bundle ID + `NSAudioCaptureUsageDescription`) into the binary's
  `__TEXT,__info_plist` section and ad-hoc signs it as `com.bschur.audio-priority`. It must run
  under launchd; started from a terminal, macOS checks the terminal's permission instead.
  When the permission is missing, capture silently yields zeros.
- **Cost**: device selection is event-driven (no polling). The mirror runs a continuous
  stereo 48 kHz copy (light, but not zero).

## Files

| File | Purpose |
|---|---|
| `audio-priority.swift` | the daemon (`--list`, `--once`, or no args = daemon) |
| `priority.conf` | output/input priority lists (symlinked into `~/.config/audio-priority/`) |
| `Info.plist` | embedded into the binary for the audio-capture permission |
| `install.sh` | builds `~/bin/audio-priority`, links config, installs `~/Library/LaunchAgents/com.bschur.audio-priority.plist` |
| `loopback/Devices.plist` | reference snapshot of Loopback's Meeting Capture device |
