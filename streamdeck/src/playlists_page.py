#!/usr/bin/env python3
"""Installs the playlist picker as page 3 of the "Zoom Call" profile (run only while Stream Deck is quit).

Plugins can leave pages of their own bundled profile (back to the home page), but they can't close a
built-in folder. So the picker lives in the plugin's profile:
  - home page 3,2: "Open Playlists" key (switches to Zoom Call page index 2)
  - picker page: Back (0,0) + up to 14 playlists from playlists.json; a pick plays it and returns home
Also removes the old built-in Playlists folder page. Edit playlists.json and re-run to change the list.
"""
import glob
import json
import os
import shutil
import subprocess
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.expanduser("~/Library/Application Support/com.elgato.StreamDeck/ProfilesV3")
PLAYLISTS = json.load(open(f"{HERE}/playlists.json"))
MINE = {"Name": "Zoom Call Deck", "UUID": "com.bschur.zoomcall", "Version": "1.1.0.0"}


def profile(name):
    hits = [p for p in glob.glob(f"{ROOT}/*.sdProfile") if json.load(open(f"{p}/manifest.json")).get("Name") == name]
    assert len(hits) == 1, (name, hits)
    return hits[0]


def act(uuid_, name, settings=None, image=None, plugin=MINE):
    return {"ActionID": str(uuid.uuid4()), "LinkedTitle": True, "Name": name, "Plugin": plugin, "Resources": None,
            "Settings": settings or {}, "State": 0, "States": [{"Image": image} if image else {}], "UUID": uuid_}


def icon(outdir, line):
    subprocess.run(["swift", f"{HERE}/make-icons.swift", outdir], input=line, text=True, check=True)


# --- picker page in the Zoom Call profile ---
zc = profile("Zoom Call")
top = json.load(open(f"{zc}/manifest.json"))
pages = top["Pages"]["Pages"]
assert len(pages) >= 2, pages
if len(pages) >= 3:
    pid = pages[2].upper()
    shutil.rmtree(f"{zc}/Profiles/{pid}", ignore_errors=True)
else:
    pid = str(uuid.uuid4()).upper()
    pages.append(pid.lower())
    json.dump(top, open(f"{zc}/manifest.json", "w"))
pdir = f"{zc}/Profiles/{pid}"
os.makedirs(f"{pdir}/Images")
icon(f"{pdir}/Images", "k-back\t144\t◀\tBack\t\n")
page = {"0,0": act("com.bschur.zoomcall.home", "Back", {"toCall": True}, image="Images/k-back.png")}
slots = [(c, r) for r in range(3) for c in range(5) if (c, r) != (0, 0)]
for (c, r), p in zip(slots, PLAYLISTS):
    page[f"{c},{r}"] = act("com.bschur.zoomcall.playlist", p["name"], {"id": p.get("id", ""), "uri": p.get("uri", ""), "name": p["name"]})
json.dump({"Controllers": [{"Actions": page, "Type": "Keypad"}], "Icon": "", "Name": ""},
          open(f"{pdir}/manifest.json", "w"))
print("picker page", pid, "index 2 with", len(page) - 1, "playlists")

# --- home page key ---
home = profile("Default Profile")
htop = json.load(open(f"{home}/manifest.json"))
hdir = f"{home}/Profiles/{htop['Pages']['Pages'][0].upper()}"
hm = json.load(open(f"{hdir}/manifest.json"))
acts = hm["Controllers"][0]["Actions"]
old = acts.get("3,2")
if old and old["UUID"] == "com.elgato.streamdeck.profile.openchild":
    shutil.rmtree(f"{home}/Profiles/{old['Settings']['ProfileUUID'].upper()}", ignore_errors=True)
    print("removed old folder page")
os.makedirs(f"{hdir}/Images", exist_ok=True)
icon(f"{hdir}/Images", "k-playlists\t144\t🎵\tPlaylists\t#2d3a46\n")
acts["3,2"] = act("com.bschur.zoomcall.playlists", "Playlists", image="Images/k-playlists.png")
json.dump(hm, open(f"{hdir}/manifest.json", "w"))
print("home 3,2 -> Open Playlists")
