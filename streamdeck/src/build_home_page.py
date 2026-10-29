#!/usr/bin/env python3
"""Rewrite the Default Profile's main page as a notifications + Spotify home page.
Run only while Stream Deck is quit.

  Slack    Outlook   Next mtg   Focus 🔭   DnD 🍅
  Art TL   Art TR    ⏮          ⏯           ⏭
  Art BL   Art BR    🔀         Playlists   (empty)

The Playlists key and picker page are added by playlists_page.py.

Reuses the existing Spotify play/prev/next/shuffle actions; drops the app launchers.
"""
import glob
import json
import os
import uuid

ROOT = os.path.expanduser("~/Library/Application Support/com.elgato.StreamDeck/ProfilesV3")
prof = [p for p in glob.glob(f"{ROOT}/*.sdProfile")
        if json.load(open(f"{p}/manifest.json")).get("Name") == "Default Profile"]
assert len(prof) == 1, prof
top = json.load(open(f"{prof[0]}/manifest.json"))
page = f"{prof[0]}/Profiles/{top['Pages']['Pages'][0].upper()}/manifest.json"
m = json.load(open(page))
old = m["Controllers"][0]["Actions"]
by_uuid = {a["UUID"]: a for a in old.values()}

MINE = {"Name": "Zoom Call Deck", "UUID": "com.bschur.zoomcall", "Version": "1.1.0.0"}


def mine(action, name, settings):
    return {"ActionID": str(uuid.uuid4()), "LinkedTitle": True, "Name": name, "Plugin": MINE,
            "Resources": None, "Settings": settings, "State": 0, "States": [{}],
            "UUID": f"com.bschur.zoomcall.{action}"}


slack_dnd = {"ActionID": str(uuid.uuid4()), "LinkedTitle": True, "Name": "Pause Notifications",
             "Plugin": {"Name": "Slack", "UUID": "com.elgato.slack", "Version": "2.1.3.230"},
             "Resources": None, "Settings": {}, "State": 0, "States": [{}],
             "UUID": "com.elgato.slack.pause-notification"}

actions = {
    "0,0": mine("badge", "Slack", {"app": "slack", "mode": "total"}),
    "1,0": mine("badge", "Outlook", {"app": "outlook", "mode": "new"}),
    "2,0": mine("nextmeeting", "Next Meeting", {}),
    "3,0": mine("dnd", "Slack Focus Mode", {}),
    "4,0": mine("slackdnd", "Slack DnD", {"status": "Focus", "emoji": "tomato"}),
    "0,1": mine("nowplaying", "Art", {"quadrant": 0}),
    "1,1": mine("nowplaying", "Art", {"quadrant": 1}),
    "0,2": mine("nowplaying", "Art", {"quadrant": 2}),
    "1,2": mine("nowplaying", "Art", {"quadrant": 3}),
    "2,1": by_uuid["com.elgato.spotify.previous"],
    "3,1": by_uuid["com.elgato.spotify.play"],
    "4,1": by_uuid["com.elgato.spotify.next"],
    "2,2": by_uuid["com.elgato.spotify.shuffle"],
}
m["Controllers"][0]["Actions"] = actions
json.dump(m, open(page, "w"))
print("home page written:", ", ".join(f"{k}={v['Name']}" for k, v in sorted(actions.items())))
