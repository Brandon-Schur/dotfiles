#!/usr/bin/env python3
"""Build the bundled "Zoom Call.streamDeckProfile" (Stream Deck 5x3, profile format 3.0).

Page 0 (main call page)                     Page 1 (More)
  Share RaiseHand Mute  Video  Leave           🐱think 😮    💯
  👍    👏        ❤️    😂     🎉              Record  Chat  People
  🔥    👀        🙌    🏠Home More ▸                               🏠Home ◀Back

👍 👏 ❤️ 😂 🎉 😮 use the Elgato Zoom plugin (Zoom's native reactions); the rest use
zoomctl to drive Zoom's emoji picker.

Usage: build_profile.py <icon-png-dir> <output .streamDeckProfile>
"""
import json
import sys
import uuid
import zipfile

ZOOM = {"Name": "Zoom", "UUID": "com.elgato.zoom", "Version": "1.0.2.102"}
MINE = {"Name": "Zoom Call Deck", "UUID": "com.bschur.zoomcall", "Version": "1.0.0.0"}

# Picker reactions: (label to match in Zoom, picker search term, icon stem)
PICKER = {
    "fire": ("🔥", "fire", "e-fire"), "100": ("💯", "100", "e-100"), "eyes": ("👀", "eyes", "e-eyes"),
    "raised": ("🙌", "raised_hands", "e-raise"), "meow": (":gr_meow_thinking:", "thinking", "e-meow"),
}


def act(plugin, uuid_, name, settings=None, states=1, image=None, title=None):
    state = {}
    if image:
        state["Image"] = f"Images/{image}.png"
    if title is not None:
        state["Title"] = title
    return {
        "ActionID": str(uuid.uuid4()),
        "LinkedTitle": True,
        "Name": name,
        "Plugin": plugin,
        "Resources": None,
        "Settings": settings or {},
        "State": 0,
        "States": [dict(state) for _ in range(states)],
        "UUID": uuid_,
    }


def zoom(action, name, settings=None, states=2):
    return act(ZOOM, f"com.elgato.zoom.{action}", name, settings, states)


def react(emoji):
    return zoom("react", "React", {"emoji": emoji, "tone": "default_tone"})


def picker(key, return_to=None):
    label, search, stem = PICKER[key]
    settings = {"emoji": label, "name": search}
    if return_to is not None:
        settings["returnToPage"] = return_to
    return act(MINE, "com.bschur.zoomcall.react", search, settings, image=stem)


page0 = {
    "2,0": zoom("mute", "Audio"),
    "3,0": zoom("video", "Video"),
    "1,0": zoom("raisehand", "Raise Hand"),
    # Keeps your existing share target (Odyssey G7).
    "0,0": zoom("screenshare", "Share Screen", {
        "monitor": '{"DeviceID":3,"FriendlyName":"Odyssey G7"}', "optimizeVideo": False, "shareSound": False}),
    "4,0": zoom("leavemeeting", "Leave or End", states=1),
    "0,1": react("thumbsup"), "1,1": react("clap"), "2,1": react("heart"),
    "3,1": react("joy"), "4,1": react("tada"),
    "0,2": picker("fire"), "1,2": picker("eyes"), "2,2": picker("raised"),
    "3,2": act(MINE, "com.bschur.zoomcall.home", "Home", {}, image="k-home"),
    "4,2": act(MINE, "com.bschur.zoomcall.page", "More", {"page": 1}, image="k-more"),
}

page1 = {
    "0,0": picker("meow", return_to=0),
    "1,0": react("openmouth"),
    "2,0": picker("100", return_to=0),
    "0,1": zoom("record", "Record", {"mode": "local", "onPress": "stop"}, states=3),
    "1,1": act(MINE, "com.bschur.zoomcall.panel", "Chat", {"panel": "chat"}, image="k-chat"),
    "2,1": act(MINE, "com.bschur.zoomcall.panel", "Participants", {"panel": "participants"}, image="k-people"),
    "3,2": act(MINE, "com.bschur.zoomcall.home", "Home", {}, image="k-home"),
    "4,2": act(MINE, "com.bschur.zoomcall.page", "Back", {"page": 0}, image="k-back"),
}


import os

PLAYLISTS = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "playlists.json")))
page2 = {"0,0": act(MINE, "com.bschur.zoomcall.home", "Back", {"toCall": True}, image="k-back")}
_slots = [(c, r) for r in range(3) for c in range(5) if (c, r) != (0, 0)]
for (c, r), p in zip(_slots, PLAYLISTS):
    page2[f"{c},{r}"] = act(MINE, "com.bschur.zoomcall.playlist", p["name"], {"id": p.get("id", ""), "uri": p.get("uri", ""), "name": p["name"]})


# Page index 3: song picker (plugin.js SONG_PAGE). Back, prev/next page, 12 song slots filled at runtime.
page3 = {"0,0": act(MINE, "com.bschur.zoomcall.home", "Back", {"toCall": True}, image="k-back"),
         "3,2": act(MINE, "com.bschur.zoomcall.songpage", "Prev page", {"delta": -1}),
         "4,2": act(MINE, "com.bschur.zoomcall.songpage", "Next page", {"delta": 1})}
for _r in range(3):
    for _c in range(5):
        page3.setdefault(f"{_c},{_r}", act(MINE, "com.bschur.zoomcall.song", "Song", {}))


def main(icon_dir, out):
    # Page index 2 is the playlist picker (plugin.js PLAYLIST_PAGE).
    pages = [(str(uuid.uuid4()), page0), (str(uuid.uuid4()), page1), (str(uuid.uuid4()), page2), (str(uuid.uuid4()), page3)]
    prof = str(uuid.uuid4()).upper()
    top = {
        "Device": {"Model": "20GBL9901", "UUID": ""},
        "InstalledByPluginUUID": MINE["UUID"],
        "Name": "Zoom Call",
        "PreconfiguredName": "Zoom Call",
        "Pages": {"Current": pages[0][0], "Default": pages[0][0], "Pages": [p for p, _ in pages]},
        "Version": "3.0",
    }
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        root = f"{prof}.sdProfile"
        z.writestr(f"{root}/manifest.json", json.dumps(top))
        for pid, actions in pages:
            pdir = f"{root}/Profiles/{pid.upper()}"
            z.writestr(f"{pdir}/manifest.json",
                       json.dumps({"Controllers": [{"Actions": actions, "Type": "Keypad"}], "Icon": "", "Name": ""}))
            for a in actions.values():
                img = a["States"][0].get("Image")
                if img:
                    z.write(f"{icon_dir}/{img.split('/')[-1]}", f"{pdir}/{img}")
    print(f"wrote {out}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
