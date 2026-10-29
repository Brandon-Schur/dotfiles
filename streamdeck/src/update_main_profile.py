#!/usr/bin/env python3
"""One-time edit of the Default Profile (run only while Stream Deck is quit).

- Removes the Timers / Teams / Zoom folder keys and their folder pages.
- Puts an "Open Zoom Call Deck" key where the Teams folder was (2,2) for manual use.
"""
import glob
import json
import os
import shutil
import uuid

ROOT = os.path.expanduser("~/Library/Application Support/com.elgato.StreamDeck/ProfilesV3")
prof = glob.glob(f"{ROOT}/*.sdProfile")
assert len(prof) == 1, prof
pages_dir = f"{prof[0]}/Profiles"
top = json.load(open(f"{prof[0]}/manifest.json"))
main_id = top["Pages"]["Pages"][0].upper()
main_path = f"{pages_dir}/{main_id}/manifest.json"
main = json.load(open(main_path))
actions = main["Controllers"][0]["Actions"]

removed_children = []
for pos in list(actions):
    a = actions[pos]
    if a["UUID"] == "com.elgato.streamdeck.profile.openchild":
        removed_children.append(a["Settings"]["ProfileUUID"].upper())
        del actions[pos]
        print("removed folder key", pos, a["States"][0].get("Title", "").strip())

actions["2,2"] = {
    "ActionID": str(uuid.uuid4()),
    "LinkedTitle": True,
    "Name": "Open Zoom Call Deck",
    "Plugin": {"Name": "Zoom Call Deck", "UUID": "com.bschur.zoomcall", "Version": "1.0.0.0"},
    "Resources": None,
    "Settings": {},
    "State": 0,
    "States": [{}],
    "UUID": "com.bschur.zoomcall.open",
}
json.dump(main, open(main_path, "w"))

for child in removed_children:
    d = f"{pages_dir}/{child}"
    if os.path.isdir(d):
        shutil.rmtree(d)
        print("deleted folder page", child)
