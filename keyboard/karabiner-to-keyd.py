#!/usr/bin/env python3
"""Translate karabiner/karabiner.json into keyd configs for Linux.

On macOS, Karabiner-Elements remaps keys per keyboard. On Linux, keyd does the
same job below X11/Wayland. This script reads the selected Karabiner profile
and writes one keyd .conf per Karabiner device block, so a physical key gives
the same logical key on both systems. karabiner.json stays the single source
of truth: edit it on the Mac, re-run scripts/install-keyboard.sh on Linux.

Modifier names line up 1:1 at the USB HID level, which is what both tools see:

    Karabiner       keyd (Linux)
    left_command    leftmeta     (Super / Windows key)
    left_option     leftalt
    left_control    leftcontrol

So a PC keyboard listed by vendor/product id translates literally.

Karabiner's catch-all block ("is_keyboard": true with no ids) targets the
MacBook's built-in Apple-layout keyboard. The Linux machine's own keyboard is
PC layout, where the keys left of the space bar sit in a different order:

    position (from space bar)   1             2             3
    Apple keyboard              left_command  left_option   left_control
    PC keyboard                 left_option   left_command  left_control

For the keyd wildcard (any keyboard not listed by id) the catch-all block is
translated by POSITION: whatever logical modifier the Apple key at position N
produces on the Mac, the PC key at position N produces on Linux. Apple
keyboards plugged into Linux (vendor 05ac) get the literal catch-all mapping.

Usage: karabiner-to-keyd.py <karabiner.json> <output-dir> [--profile NAME]
"""

import argparse
import json
import pathlib
import sys

PREFIX = "dotfiles-"  # every generated file starts with this, so reinstalls can clean up
APPLE_VENDOR_ID = 0x05AC

KEY_CODES = {
    "caps_lock": "capslock",
    "escape": "esc",
    "tab": "tab",
    "spacebar": "space",
    "return_or_enter": "enter",
    "delete_or_backspace": "backspace",
    "delete_forward": "delete",
    "grave_accent_and_tilde": "grave",
    "hyphen": "minus",
    "equal_sign": "equal",
    "open_bracket": "leftbrace",
    "close_bracket": "rightbrace",
    "backslash": "backslash",
    "non_us_backslash": "102nd",
    "semicolon": "semicolon",
    "quote": "apostrophe",
    "comma": "comma",
    "period": "dot",
    "slash": "slash",
    "left_arrow": "left",
    "right_arrow": "right",
    "up_arrow": "up",
    "down_arrow": "down",
    "home": "home",
    "end": "end",
    "page_up": "pageup",
    "page_down": "pagedown",
    "left_shift": "leftshift",
    "right_shift": "rightshift",
    "left_control": "leftcontrol",
    "right_control": "rightcontrol",
    "left_option": "leftalt",
    "right_option": "rightalt",
    "left_command": "leftmeta",
    "right_command": "rightmeta",
    "application": "compose",
}
KEY_CODES.update({c: c for c in "abcdefghijklmnopqrstuvwxyz0123456789"})
KEY_CODES.update({f"f{n}": f"f{n}" for n in range(1, 25)})

CONSUMER_KEY_CODES = {
    "play_or_pause": "playpause",
    "scan_next_track": "nextsong",
    "scan_previous_track": "previoussong",
    "fast_forward": "fastforward",
    "rewind": "rewind",
    "mute": "mute",
    "volume_increment": "volumeup",
    "volume_decrement": "volumedown",
    "display_brightness_increment": "brightnessup",
    "display_brightness_decrement": "brightnessdown",
}

# A key remapped TO a modifier must activate keyd's modifier layer, not emit a
# keycode, or it won't combine with other keys.
MODIFIER_LAYERS = {
    "left_control": "control", "right_control": "control",
    "left_shift": "shift", "right_shift": "shift",
    "left_option": "alt", "right_option": "alt",
    "left_command": "meta", "right_command": "meta",
}

# Modifier prefixes for keyd macros such as C-S-x.
MACRO_MODIFIERS = {
    "control": "C", "left_control": "C", "right_control": "C",
    "shift": "S", "left_shift": "S", "right_shift": "S",
    "option": "A", "left_option": "A", "right_option": "A",
    "command": "M", "left_command": "M", "right_command": "M",
}

# Left-of-space modifiers by distance from the space bar (see module docstring).
APPLE_LEFT_ROW = ["left_command", "left_option", "left_control"]
PC_LEFT_ROW = ["left_option", "left_command", "left_control"]


def die(msg):
    sys.exit(f"karabiner-to-keyd: {msg}")


def keyd_key(event):
    """Return the keyd name for a Karabiner from/to event."""
    if "key_code" in event:
        name = KEY_CODES.get(event["key_code"])
        if name:
            return name
        die(f"no keyd name for key_code {event['key_code']!r}; add it to KEY_CODES")
    if "consumer_key_code" in event:
        name = CONSUMER_KEY_CODES.get(event["consumer_key_code"])
        if name:
            return name
        die(f"no keyd name for consumer_key_code {event['consumer_key_code']!r}; "
            "add it to CONSUMER_KEY_CODES")
    die(f"unsupported Karabiner event {event!r}")


def keyd_action(to_events):
    """Return the keyd right-hand side for a Karabiner 'to' list."""
    parts = []
    for ev in to_events:
        code = ev.get("key_code")
        mods = ev.get("modifiers", [])
        if len(to_events) == 1 and not mods and code in MODIFIER_LAYERS:
            return f"layer({MODIFIER_LAYERS[code]})"
        key = keyd_key(ev)
        prefix = "".join(f"{MACRO_MODIFIERS[m]}-" for m in mods)
        parts.append(prefix + key)
    return parts[0] if len(parts) == 1 else f"macro({' '.join(parts)})"


def mods_by_from(simple_modifications):
    """Map Karabiner from-key_code -> 'to' list, rejecting from-modifiers."""
    out = {}
    for mod in simple_modifications:
        frm = mod["from"]
        if set(frm) - {"key_code", "consumer_key_code"}:
            die(f"simple_modification with modifiers in 'from' is unsupported: {frm!r}")
        out[frm.get("key_code") or frm.get("consumer_key_code")] = mod["to"]
    return out


def apple_to_pc(mapping):
    """Translate an Apple-keyboard mapping to a PC keyboard by key position."""
    out = {k: v for k, v in mapping.items() if k not in APPLE_LEFT_ROW}
    for apple_key, pc_key in zip(APPLE_LEFT_ROW, PC_LEFT_ROW):
        to = mapping.get(apple_key, [{"key_code": apple_key}])
        if to != [{"key_code": pc_key}]:
            out[pc_key] = to
    return out


def render(ids, mapping, comment):
    lines = [
        "# Generated by dotfiles/keyboard/karabiner-to-keyd.py from karabiner.json.",
        f"# {comment}",
        "# Do not edit: change karabiner.json and re-run scripts/install-keyboard.sh.",
        "",
        "[ids]",
        *ids,
        "",
        "[main]",
    ]
    bindings = []
    for frm, to in mapping.items():
        src = KEY_CODES.get(frm) or CONSUMER_KEY_CODES.get(frm) or die(f"unknown key {frm!r}")
        bindings.append(f"{src} = {keyd_action(to)}")
    lines.extend(sorted(bindings))
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("karabiner_json", type=pathlib.Path)
    ap.add_argument("output_dir", type=pathlib.Path)
    ap.add_argument("--profile", help="Karabiner profile name (default: the selected one)")
    args = ap.parse_args()

    profiles = json.loads(args.karabiner_json.read_text())["profiles"]
    if args.profile:
        profile = next((p for p in profiles if p["name"] == args.profile), None)
    else:
        profile = next((p for p in profiles if p.get("selected")), profiles[0])
    if not profile:
        die(f"profile {args.profile!r} not found")

    # Profile-level simple_modifications apply to every device; device blocks override.
    base = mods_by_from(profile.get("simple_modifications", []))
    catch_all = dict(base)
    devices = []  # (vendor, product, mapping)
    for dev in profile.get("devices", []):
        ident = dev.get("identifiers", {})
        if not ident.get("is_keyboard"):
            continue
        mapping = {**base, **mods_by_from(dev.get("simple_modifications", []))}
        if "vendor_id" in ident and "product_id" in ident:
            devices.append((ident["vendor_id"], ident["product_id"], mapping))
        elif "vendor_id" not in ident and "product_id" not in ident:
            catch_all = mapping
        else:
            die(f"device matched by vendor_id OR product_id only is unsupported: {ident!r}")

    files = {}
    for vendor, product, mapping in devices:
        dev_id = f"{vendor:04x}:{product:04x}"
        files[f"{PREFIX}{vendor:04x}-{product:04x}.conf"] = render(
            [f"k:{dev_id}"], mapping, f"Karabiner device vendor_id={vendor} product_id={product}.")

    if not any(v == APPLE_VENDOR_ID for v, _, _ in devices):
        files[f"{PREFIX}apple.conf"] = render(
            [f"k:{APPLE_VENDOR_ID:04x}"], catch_all,
            "Apple keyboards: Karabiner's catch-all block, translated literally.")

    excluded = [f"-{v:04x}:{p:04x}" for v, p, _ in devices] + [f"-{APPLE_VENDOR_ID:04x}"]
    files[f"{PREFIX}default.conf"] = render(
        ["*", *excluded], apple_to_pc(catch_all),
        "Every other keyboard (assumed PC layout): Karabiner's catch-all block, "
        "translated by key position.")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name, text in files.items():
        (args.output_dir / name).write_text(text)
        print(args.output_dir / name)


if __name__ == "__main__":
    main()
