// Zoom Call Deck — Stream Deck plugin (raw SDK protocol over WebSocket).
//
// 1. Watches for an active Zoom meeting and flips the deck to the bundled
//    "Zoom Call" profile when one starts, then back to the previous profile when it ends.
// 2. Provides keys the Elgato Zoom plugin lacks: any-emoji reactions, chat / participants
//    toggles, and page navigation inside the Zoom Call profile.
//
// UI automation is delegated to bin/zoomctl (Swift, Accessibility API).

"use strict";

const { execFile } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const WebSocket = require("ws");

const PLUGIN_DIR = path.resolve(__dirname, "..");
const ZOOMCTL = path.join(__dirname, "zoomctl");
const LOG_FILE = path.join(PLUGIN_DIR, "logs", "zoomcall.log");
const PROFILE = "Zoom Call";
const POLL_MS = 2000;
const ENTER_AFTER = 2; // consecutive positive polls before switching in
const EXIT_AFTER = 3; // consecutive negative polls before switching back

// ---------- logging ----------
fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });
function log(...parts) {
  const line = `${new Date().toISOString()} ${parts.map((p) => (typeof p === "string" ? p : JSON.stringify(p))).join(" ")}\n`;
  try {
    // Keep the log from growing without bound.
    if (fs.existsSync(LOG_FILE) && fs.statSync(LOG_FILE).size > 2_000_000) fs.renameSync(LOG_FILE, LOG_FILE + ".1");
    fs.appendFileSync(LOG_FILE, line);
  } catch {
    /* logging must never break the plugin */
  }
}

function run(file, args, timeoutMs = 8000) {
  return new Promise((resolve) => {
    execFile(file, args, { timeout: timeoutMs }, (err, stdout, stderr) => {
      resolve({ code: err ? (typeof err.code === "number" ? err.code : 1) : 0, stdout: String(stdout), stderr: String(stderr) });
    });
  });
}

// ---------- Stream Deck connection ----------
const argv = process.argv.slice(2);
const arg = (name) => argv[argv.indexOf(name) + 1];
const port = arg("-port");
const pluginUUID = arg("-pluginUUID");
const registerEvent = arg("-registerEvent");
const info = JSON.parse(arg("-info") || "{}");

const devices = new Set((info.devices || []).map((d) => d.id));
const ws = new WebSocket(`ws://127.0.0.1:${port}`);
const send = (msg) => ws.readyState === WebSocket.OPEN && ws.send(JSON.stringify(msg));

ws.on("open", () => {
  send({ event: registerEvent, uuid: pluginUUID });
  log("registered", { devices: [...devices] });
  ensureTrusted();
  setInterval(pollMeeting, POLL_MS);
  setInterval(refreshBadges, 4000);
  setInterval(refreshSpotify, 2500);
  setInterval(refreshMeetings, 60000);
});
ws.on("close", () => process.exit(0));
ws.on("message", (raw) => {
  let msg;
  try {
    msg = JSON.parse(raw);
  } catch {
    return;
  }
  switch (msg.event) {
    case "deviceDidConnect":
      devices.add(msg.device);
      break;
    case "deviceDidDisconnect":
      devices.delete(msg.device);
      break;
    case "keyDown":
      onKeyDown(msg).catch((e) => log("keyDown error", String(e)));
      break;
    case "willAppear":
      visible.set(msg.context, {
        action: msg.action,
        settings: (msg.payload && msg.payload.settings) || {},
        coords: (msg.payload && msg.payload.coordinates) || null,
      });
      lastImage.delete(msg.context);
      refreshSoon();
      break;
    case "willDisappear":
      visible.delete(msg.context);
      break;
  }
});

const onCall = new Set(); // devices currently showing the Zoom Call profile

function switchProfile(device, profile, page) {
  if (profile === PROFILE) onCall.add(device);
  else onCall.delete(device);
  const payload = {};
  if (profile) payload.profile = profile;
  if (page !== undefined) payload.page = page;
  send({ event: "switchToProfile", context: pluginUUID, device, payload });
}

// ---------- meeting detection ----------
let inMeeting = false;
let positives = 0;
let negatives = 0;
let polling = false;

async function zoomPids() {
  const r = await run("/usr/bin/pgrep", ["-x", "zoom.us"]);
  return r.stdout.split(/\s+/).filter(Boolean);
}

/** Zoom only holds UDP sockets while media (a meeting) is flowing. Needs no permissions. */
async function hasMediaSockets(pids) {
  const r = await run("/usr/sbin/lsof", ["-nP", "-a", "-iUDP", "-p", pids.join(",")]);
  return r.stdout.split("\n").filter((l) => l.startsWith("zoom")).length > 0;
}

async function detectMeeting() {
  const pids = await zoomPids();
  if (pids.length === 0) return { meeting: false, why: "zoom not running" };
  const status = await run(ZOOMCTL, ["status"]);
  try {
    const s = JSON.parse(status.stdout);
    if (s.meetingWindow) return { meeting: true, why: "meeting window" };
  } catch {
    /* fall through to socket check */
  }
  if (await hasMediaSockets(pids)) return { meeting: true, why: "udp media" };
  return { meeting: false, why: "no meeting signals" };
}

async function pollMeeting() {
  if (polling) return;
  polling = true;
  try {
    const { meeting, why } = await detectMeeting();
    if (meeting) {
      negatives = 0;
      positives++;
      if (!inMeeting && positives >= ENTER_AFTER) {
        inMeeting = true;
        log("meeting started", why);
        for (const d of devices) switchProfile(d, PROFILE, 0);
        renderNextMeeting();
      }
    } else {
      positives = 0;
      negatives++;
      if (inMeeting && negatives >= EXIT_AFTER) {
        inMeeting = false;
        log("meeting ended", why);
        // Only switch back devices still on the call profile (not ones sent Home manually).
        for (const d of devices) if (onCall.has(d)) switchProfile(d); // previously active profile
        renderNextMeeting();
      }
    }
  } finally {
    polling = false;
  }
}

async function ensureTrusted() {
  const r = await run(ZOOMCTL, ["status"]);
  try {
    if (JSON.parse(r.stdout).trusted) return log("accessibility: trusted");
  } catch {
    /* ignore */
  }
  log("accessibility: not trusted, prompting");
  await run(ZOOMCTL, ["trust"]);
}

// ---------- keys ----------
const A = "com.bschur.zoomcall.";

async function onKeyDown({ action, context, device, payload }) {
  const s = (payload && payload.settings) || {};
  let r;
  switch (action) {
    case A + "react":
      r = await run(ZOOMCTL, ["react", s.emoji || "👍", s.name || "thumbs up"]);
      // Extra reactions live on page 2; hop back to the main call page afterwards.
      if (r.code === 0 && s.returnToPage !== undefined) switchProfile(device, PROFILE, s.returnToPage);
      break;
    case A + "panel":
      r = await run(ZOOMCTL, ["toggle", s.panel || "chat"]);
      break;
    case A + "page":
      switchProfile(device, PROFILE, Number(s.page || 0));
      return;
    case A + "open":
      switchProfile(device, PROFILE, 0);
      return;
    case A + "home":
      if (s.toCall && inMeeting) switchProfile(device, PROFILE, 0);
      else if (onCall.has(device)) switchProfile(device); // back to the home page
      return;
    case A + "badge":
      return pressBadge(s);
    case A + "nextmeeting":
      return pressNextMeeting(context, device);
    case A + "nowplaying":
      return pressNowPlaying();
    case A + "spotify":
      return pressSpotify(s, context);
    case A + "dnd":
      return pressDnd(context);
    case A + "slackdnd":
      return pressSlackDnd(s, context);
    case A + "playlist":
      return pressPlaylist(s, context, device);
    case A + "playlists":
      switchProfile(device, PROFILE, PLAYLIST_PAGE);
      return;
    case A + "songs":
      return openSongs(context, device);
    case A + "song":
      return pressSong(context, device);
    case A + "songpage":
      return flipSongPage(s, context);
    default:
      return;
  }
  if (r.code === 0) {
    send({ event: "showOk", context });
  } else {
    send({ event: "showAlert", context });
    log("action failed", { action, settings: s, code: r.code, stderr: r.stderr.trim() });
    if (r.code === 1) {
      // Capture the AX tree so selectors can be fixed after a Zoom UI change.
      const d = await run(ZOOMCTL, ["dump", "all"], 15000);
      log("ax dump\n" + d.stdout.slice(0, 200_000));
    }
  }
}

// ---------- home-page keys: notification badges, next meeting, Spotify ----------
const DECKART = path.join(__dirname, "deckart");
const STATE_FILE = path.join(PLUGIN_DIR, "logs", "state.json");
const visible = new Map(); // context -> { action, settings }
const lastImage = new Map(); // context -> last rendered key (skip identical redraws)
let state = {};
try {
  state = JSON.parse(fs.readFileSync(STATE_FILE, "utf8"));
} catch {
  /* first run */
}
const saveState = () => fs.writeFile(STATE_FILE, JSON.stringify(state), () => {});

const contextsFor = (suffix) => [...visible].filter(([, v]) => v.action === A + suffix);

async function setKey(context, renderArgs) {
  const sig = renderArgs.join("\u0000");
  if (lastImage.get(context) === sig) return;
  const r = await run(DECKART, renderArgs);
  if (r.code !== 0 || !r.stdout.startsWith("data:")) return log("deckart failed", renderArgs, r.stderr);
  lastImage.set(context, sig);
  send({ event: "setImage", context, payload: { image: r.stdout.trim(), target: 0 } });
  send({ event: "setTitle", context, payload: { title: "", target: 0 } });
}

let refreshTimer;
function refreshSoon() {
  clearTimeout(refreshTimer);
  refreshTimer = setTimeout(() => {
    refreshBadges();
    refreshSpotify(true);
    refreshMeetings();
    refreshSlack();
    renderSlackDnd();
    renderPlaylists();
    renderSongs();
  }, 300);
}

// --- Dock badges (Slack, Outlook): read via lsappinfo, no permissions needed ---
const APPS = {
  slack: { bundle: "com.tinyspeck.slackmacgap", lsName: "Slack", label: "Slack", accent: "#e01e5a" },
  outlook: { bundle: "com.microsoft.Outlook", lsName: "Microsoft Outlook", label: "Outlook", accent: "#0a64d8" },
};

async function badgeCount(app) {
  const r = await run("/usr/bin/lsappinfo", ["info", "-only", "StatusLabel", app.lsName]);
  const m = r.stdout.match(/"label"="([^"]*)"/);
  if (!m) return { running: /StatusLabel/.test(r.stdout), count: 0 };
  return { running: true, count: parseInt(m[1].replace(/\D/g, ""), 10) || (m[1] ? 1 : 0) };
}

async function refreshBadges() {
  for (const [ctx, v] of contextsFor("badge")) {
    const key = v.settings.app || "slack";
    const app = APPS[key];
    if (!app) continue;
    const { running, count } = await badgeCount(app);
    // "new" mode: count since the key was last pressed (baseline stored in state.json).
    const mode = v.settings.mode || "total";
    const base = state[`seen.${key}`];
    if (mode === "new" && (base === undefined || count < base)) {
      state[`seen.${key}`] = count; // first run, or mail was read elsewhere
      saveState();
    }
    const fresh = mode === "new" ? Math.max(0, count - state[`seen.${key}`]) : count;
    const big = !running ? "" : fresh === 0 ? "" : (mode === "new" ? "+" : "") + (fresh > 999 ? "999" : String(fresh));
    const small = !running ? "not running" : mode === "new" ? `${count} unread` : app.label;
    const extra = key === "slack" && slackState.dms > 0 ? [`DM ${slackState.dms}`, "#1d6fd8"] : [];
    await setKey(ctx, ["badge", app.bundle, big, small, app.accent, ...extra]);
  }
}

async function pressBadge(settings) {
  const key = settings.app || "slack";
  const app = APPS[key];
  if (!app) return;
  if ((settings.mode || "total") === "new") {
    state[`seen.${key}`] = (await badgeCount(app)).count;
    saveState();
  }
  await run("/usr/bin/open", ["-b", app.bundle]);
  for (const [ctx] of contextsFor("badge")) lastImage.delete(ctx);
  refreshBadges();
}

// --- Next meeting (from Zoom Workplace's calendar side panel) ---
let meetings = [];
let meetingsFetchedAt = 0;

async function refreshMeetings() {
  if (contextsFor("nextmeeting").length === 0) return;
  if (Date.now() - meetingsFetchedAt > 55000) {
    const r = await run(ZOOMCTL, ["meetings"], 15000);
    try {
      meetings = JSON.parse(r.stdout);
      meetingsFetchedAt = Date.now();
    } catch {
      if (r.stderr) log("meetings failed", r.stderr.trim());
    }
  }
  renderNextMeeting();
}

function nextMeeting() {
  const d = new Date();
  const now = d.getHours() * 60 + d.getMinutes();
  // Ignore all-day / 9-hour placeholders and holds that are already well under way.
  const candidates = meetings
    .filter((m) => m.end > now && m.end - m.start <= 240 && m.start >= now - 10)
    .filter((m) => !/^(calendar hold|hold|ooo|focus)/i.test(m.title))
    .sort((a, b) => a.start - b.start || b.joinable - a.joinable);
  return { m: candidates[0], now };
}

function renderNextMeeting() {
  const { m, now } = nextMeeting();
  for (const [ctx] of contextsFor("nextmeeting")) {
    if (inMeeting) {
      setKey(ctx, ["text", "📞 Call", "Back to call controls", "#1f6f43"]);
      continue;
    }
    if (!m) {
      setKey(ctx, ["text", "—", "No more meetings today", "#2d3a46"]);
      continue;
    }
    const mins = m.start - now;
    const when = mins <= 0 ? "Now" : mins < 60 ? `${mins}m` : `${Math.floor(mins / 60)}h${String(mins % 60).padStart(2, "0")}`;
    // Green when it's joinable or starting within 5 minutes, amber within 15, grey otherwise.
    const bg = m.joinable || mins <= 5 ? "#1f6f43" : mins <= 15 ? "#9a6a00" : "#2d3a46";
    setKey(ctx, ["text", m.joinable ? `Join · ${when}` : when, m.title, bg]);
  }
}
setInterval(renderNextMeeting, 20000);

async function pressNextMeeting(context, device) {
  if (inMeeting) return switchProfile(device, PROFILE, 0);
  const { m } = nextMeeting();
  if (m) {
    const r = await run(ZOOMCTL, ["join", m.title], 10000);
    if (r.code === 0) return send({ event: "showOk", context });
  }
  await run("/usr/bin/open", ["-b", "us.zoom.xos"]); // no Join button yet: just show Zoom
}

// --- Spotify (AppleScript; only queried while Spotify is already running) ---
const ART_DIR = path.join(PLUGIN_DIR, "logs", "art");
fs.mkdirSync(ART_DIR, { recursive: true });
let spotify = { running: false };

function osa(script) {
  return run("/usr/bin/osascript", ["-e", script], 5000);
}

const SPOTIFY_STATE = `
if application "Spotify" is running then
  tell application "Spotify"
    try
      set t to current track
      return (player state as text) & "\\n" & (name of t) & "\\n" & (artist of t) & "\\n" & (artwork url of t) & "\\n" & (id of t) & "\\n" & (sound volume as text) & "\\n" & (shuffling as text)
    on error
      return (player state as text)
    end try
  end tell
end if
return "off"`;

function download(url, file) {
  return new Promise((resolve) => {
    require("node:https")
      .get(url, (res) => {
        if (res.statusCode !== 200) return resolve(false), res.resume();
        const out = fs.createWriteStream(file);
        res.pipe(out);
        out.on("finish", () => resolve(true));
      })
      .on("error", () => resolve(false));
  });
}

let spotifyBusy = false;
async function refreshSpotify(force) {
  if (spotifyBusy || (contextsFor("nowplaying").length === 0 && contextsFor("spotify").length === 0)) return;
  spotifyBusy = true;
  try {
    const r = await osa(SPOTIFY_STATE);
    if (r.code !== 0) {
      if (!spotify.error) log("spotify osascript failed", r.stderr.trim());
      spotify = { running: false, error: true };
    } else {
      const [st, name, artist, artUrl, id, vol, shuffle] = r.stdout.trim().split("\n");
      spotify = { running: st !== "off", state: st, name, artist, artUrl, id, volume: Number(vol), shuffle: shuffle === "true" };
    }
    let artFile = "";
    if (spotify.artUrl && /^https:\/\/i\.scdn\.co\//.test(spotify.artUrl)) {
      artFile = path.join(ART_DIR, spotify.artUrl.split("/").pop().replace(/\W/g, "") + ".jpg");
      if (!fs.existsSync(artFile)) {
        for (const f of fs.readdirSync(ART_DIR)) fs.rmSync(path.join(ART_DIR, f), { force: true }); // keep one cover
        if (!(await download(spotify.artUrl, artFile))) artFile = "";
      }
    }
    for (const [ctx, v] of contextsFor("nowplaying")) {
      const q = Number(v.settings.quadrant || 0);
      if (!spotify.running) {
        await setKey(ctx, q === 0 ? ["text", "♫", "Spotify off", "#1db954"] : ["art", "/nonexistent", String(q), ""]);
        continue;
      }
      const caption = q === 2 ? spotify.name || "" : q === 3 ? spotify.artist || "" : "";
      const paused = spotify.state !== "playing" && q === 1 ? "⏸ paused" : "";
      await setKey(ctx, ["art", artFile || "/nonexistent", String(q), caption || paused]);
    }
    for (const [ctx, v] of contextsFor("spotify")) {
      const cmd = v.settings.cmd;
      const label = cmd === "volup" ? `🔊 +` : cmd === "voldown" ? `🔉 −` : "";
      if (label) await setKey(ctx, ["text", label, spotify.running ? `Vol ${spotify.volume}` : "", "#14532d"]);
    }
  } finally {
    spotifyBusy = false;
  }
}

async function pressSpotify(settings, context) {
  const step = Number(settings.step || 10);
  const scripts = {
    volup: `tell application "Spotify" to set sound volume to ((sound volume) + ${step})`,
    voldown: `tell application "Spotify" to set sound volume to ((sound volume) - ${step})`,
  };
  if (!scripts[settings.cmd]) return;
  const r = await osa(`if application "Spotify" is running then\n${scripts[settings.cmd]}\nend if`);
  if (r.code !== 0) {
    log("spotify cmd failed", settings.cmd, r.stderr.trim());
    send({ event: "showAlert", context });
  }
  refreshSpotify(true);
}

async function pressNowPlaying() {
  await run("/usr/bin/open", ["-b", "com.spotify.client"]);
}

// --- Slack focus mode (Slack's own sidebar toggle; also the source of the DM count) ---
let slackState = { running: false, focus: undefined, dms: 0 };

async function refreshSlack() {
  if (contextsFor("dnd").length === 0 && contextsFor("badge").length === 0) return;
  const r = await run(ZOOMCTL, ["slack-status"]);
  try {
    const s = JSON.parse(r.stdout);
    slackState = { running: s.running, focus: s.focus, dms: s.dms || 0, paused: s.paused };
  } catch {
    return;
  }
  // Pause state comes from Slack itself, so pauses set in Slack (or expiring) show up too.
  if (slackState.paused !== undefined && slackPause.state !== "error") {
    slackPause = { state: slackState.paused ? "paused" : "idle" };
  }
  renderDnd();
  renderSlackDnd();
}

function renderDnd() {
  for (const [ctx] of contextsFor("dnd")) {
    if (!slackState.running) setKey(ctx, ["text", "🔭", "Slack not running", "#2d3a46"]);
    else if (slackState.focus === undefined) setKey(ctx, ["text", "🔭 ?", "Slack focus button not found", "#7a2e2e"]);
    else if (slackState.focus) setKey(ctx, ["text", "🔭 On", "Slack focus mode", "#5b3fa8"]);
    else setKey(ctx, ["text", "🔔 Off", "Slack focus mode", "#2d3a46"]);
  }
}
setInterval(refreshSlack, 5000);

async function pressDnd(context) {
  const r = await run(ZOOMCTL, ["slack-focus"], 10000);
  if (r.code === 0) {
    slackState.focus = r.stdout.trim() === "on";
    send({ event: "showOk", context });
  } else {
    log("slack focus toggle failed", r.stderr.trim());
    send({ event: "showAlert", context });
  }
  renderDnd();
}

// --- Slack DnD: status "🍅 Focus" + "Pause notifications until status is cleared" (VIPs still notify) ---
let slackPause = { state: "idle" }; // idle | paused | error

function renderSlackDnd() {
  for (const [ctx] of contextsFor("slackdnd")) {
    if (slackPause.state === "error") setKey(ctx, ["text", "🍅 ⚠️", "Couldn't set Slack status", "#7a2e2e"]);
    else if (slackPause.state === "paused") setKey(ctx, ["text", "🍅 On", "Do not disturb (VIPs ok)", "#b3261e"]);
    else setKey(ctx, ["text", "🍅 Off", "Press: Do not disturb", "#2d3a46"]);
  }
}

async function pressSlackDnd(settings, context) {
  const r = await run(ZOOMCTL, ["slack-status-dnd", "toggle", settings.status || "Focus", settings.emoji || "tomato"], 20000);
  const out = r.stdout.trim().split("\n").pop();
  if (r.code === 0) slackPause = { state: out === "on" ? "paused" : "idle" };
  else {
    slackPause = { state: "error" };
    log("slack status dnd failed", r.stderr.trim());
  }
  send({ event: r.code === 0 ? "showOk" : "showAlert", context });
  for (const [ctx] of contextsFor("slackdnd")) lastImage.delete(ctx);
  renderSlackDnd();
  setTimeout(refreshSlack, 1500);
  if (slackPause.state === "error") {
    setTimeout(() => {
      slackPause.state = "idle";
      refreshSlack();
    }, 5000);
  }
}

// --- Spotify playlist keys (cover art via Spotify's public oEmbed endpoint; no login) ---
const COVER_DIR = path.join(PLUGIN_DIR, "logs", "covers");
fs.mkdirSync(COVER_DIR, { recursive: true });

function getJson(url) {
  return new Promise((resolve) => {
    require("node:https")
      .get(url, (res) => {
        let body = "";
        res.on("data", (c) => (body += c));
        res.on("end", () => {
          try {
            resolve(JSON.parse(body));
          } catch {
            resolve(null);
          }
        });
      })
      .on("error", () => resolve(null));
  });
}

async function playlistCover(id) {
  if (!/^[A-Za-z0-9]{22}$/.test(id)) return "";
  const file = path.join(COVER_DIR, `${id}.jpg`);
  if (fs.existsSync(file)) return file;
  const meta = await getJson(`https://open.spotify.com/oembed?url=https://open.spotify.com/playlist/${id}`);
  const thumb = meta && meta.thumbnail_url;
  if (!thumb || !/^https:\/\//.test(thumb)) return "";
  return (await download(thumb, file)) ? file : "";
}

// Dynamic list from the Spotify Web API (spotify-api.js): Liked Songs, then most recently played.
// Falls back to the fixed list in each key's settings until `spotify-api.js login` has been run.
const SPOTIFY_API = path.join(__dirname, "spotify-api.js");
let apiPlaylists = null;
let apiFetchedAt = 0;
let apiFetching = null;

async function fetchApiPlaylists() {
  if (apiFetching) return apiFetching;
  apiFetching = (async () => {
    const r = await run(process.execPath, [SPOTIFY_API, "playlists"], 30000);
    if (r.code === 0) {
      try {
        apiPlaylists = JSON.parse(r.stdout);
        apiFetchedAt = Date.now();
      } catch {
        log("spotify api: bad output");
      }
    } else if (r.code !== 3) {
      log("spotify api failed", r.stderr.trim()); // 3 = not logged in yet (expected)
    }
  })().finally(() => (apiFetching = null));
  return apiFetching;
}

/** Slot index of a picker key: row-major, skipping the Back key at 0,0. */
function playlistSlot(coords) {
  if (!coords) return -1;
  return coords.row * 5 + coords.column - 1;
}

function playlistFor(v) {
  if (apiPlaylists) {
    const p = apiPlaylists[playlistSlot(v.coords)];
    return p || null; // fewer playlists than keys: blank key
  }
  return v.settings;
}

async function coverFromUrl(id, url) {
  if (!/^[A-Za-z0-9]{22}$/.test(id) || !/^https:\/\/[a-z0-9.-]*(scdn\.co|spotifycdn\.com)\//.test(url)) return "";
  const file = path.join(COVER_DIR, `${id}.jpg`);
  if (fs.existsSync(file)) return file;
  return (await download(url, file)) ? file : "";
}

async function renderPlaylists() {
  if (contextsFor("playlist").length === 0) return;
  if (Date.now() - apiFetchedAt > 10 * 60 * 1000) await fetchApiPlaylists(); // refresh at most every 10 min
  for (const [ctx, v] of contextsFor("playlist")) {
    const p = playlistFor(v);
    if (!p) {
      await setKey(ctx, ["text", "", "", "#000000"]);
      continue;
    }
    const { id = "", name = "", uri = "", image = "" } = p;
    if (/:collection$/.test(uri)) {
      await setKey(ctx, ["text", "💜", name || "Liked Songs", "#4b2bbf"]);
      continue;
    }
    const cover = (image && (await coverFromUrl(id, image))) || (await playlistCover(id));
    if (cover) await setKey(ctx, ["cover", cover, name]);
    else await setKey(ctx, ["text", "♫", name || "Playlist", "#14532d"]);
  }
}


// --- AeroSpace: undo workspace jumps caused by apps activating themselves (e.g. Spotify on play) ---
const AEROSPACE = ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace"].find((f) => fs.existsSync(f));

async function aerospaceSnapshot() {
  if (!AEROSPACE) return null;
  const vis = await run(AEROSPACE, ["list-workspaces", "--monitor", "all", "--visible", "--format", "%{monitor-id}\t%{workspace}"]);
  const foc = await run(AEROSPACE, ["list-workspaces", "--focused"]);
  if (vis.code !== 0 || foc.code !== 0) return null;
  const visible = {};
  for (const line of vis.stdout.trim().split("\n")) {
    const [mon, ws] = line.split("\t");
    if (mon && ws) visible[mon] = ws;
  }
  return { visible, focused: foc.stdout.trim() };
}

/** Wait up to `ms` for the visible workspaces to change, then switch them back in one layout pass. */
async function aerospaceRestore(before, ms = 2500) {
  if (!before) return;
  const deadline = Date.now() + ms;
  let after;
  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 250));
    after = await aerospaceSnapshot();
    if (after && (after.focused !== before.focused || JSON.stringify(after.visible) !== JSON.stringify(before.visible))) break;
    after = null;
  }
  if (!after) return; // nothing moved
  const cmds = Object.entries(before.visible)
    .filter(([mon, ws]) => after.visible[mon] !== ws)
    .map(([, ws]) => `workspace ${ws}`);
  cmds.push(`workspace ${before.focused}`); // last, so focus ends where it was
  const valid = (c) => /^workspace [\w-]+$/.test(c);
  const r = await run(AEROSPACE, ["eval", cmds.filter(valid).join("; ")]);
  if (r.code !== 0) log("aerospace restore failed", cmds, r.stderr.trim());
}

const PLAYLIST_PAGE = 2; // third page of the bundled "Zoom Call" profile

async function pressPlaylist(keySettings, context, device) {
  const v = visible.get(context);
  const settings = (v && playlistFor(v)) || keySettings;
  const id = settings.id || "";
  // Either a playlist id, or a full URI such as Liked Songs ("spotify:user:<id>:collection").
  const uri = /^spotify:user:[\w.-]+:collection$/.test(settings.uri || "") ? settings.uri
    : /^[A-Za-z0-9]{22}$/.test(id) ? `spotify:playlist:${id}` : "";
  if (!uri) return send({ event: "showAlert", context });
  const before = await aerospaceSnapshot();
  const r = await osa(`
if application "Spotify" is not running then
  tell application "Spotify" to launch
  delay 3
end if
tell application "Spotify" to play track "${uri}"`);
  if (r.code !== 0) {
    log("playlist play failed", id, r.stderr.trim());
    send({ event: "showAlert", context });
  } else {
    send({ event: "showOk", context });
    if (onCall.has(device) && !inMeeting) switchProfile(device); // back to the home page
    aerospaceRestore(before);
    apiFetchedAt = 0; // next visit re-sorts by what was just played
    setTimeout(() => refreshSpotify(true), 1500);
  }
}

// --- Song picker for the current playlist (page index 3 of the Zoom Call profile) ---
// Keys: Back 0,0 · prev page 3,2 · next page 4,2 · 12 songs in the remaining slots (row-major).
const SONG_PAGE = 3;
const SONG_SLOTS = [];
for (let r = 0; r < 3; r++)
  for (let c = 0; c < 5; c++) if (!(c === 0 && r === 0) && !(r === 2 && c >= 3)) SONG_SLOTS.push(`${c},${r}`);
const PER_PAGE = SONG_SLOTS.length; // 12
const ART_CACHE = path.join(PLUGIN_DIR, "logs", "albums");
fs.mkdirSync(ART_CACHE, { recursive: true });

let songs = { context: null, current: null, page: 0, total: 0, items: {} }; // items: index -> track

async function spotifyApi(args, timeout = 20000) {
  const r = await run(process.execPath, [SPOTIFY_API, ...args], timeout);
  if (r.code !== 0) {
    if (r.code !== 3) log("spotify api", args[0], "failed", r.stderr.trim());
    return { error: r.code === 3 ? "login" : "api" };
  }
  try {
    return JSON.parse(r.stdout);
  } catch {
    return { error: "api" };
  }
}

async function loadSongPage(page) {
  const start = page * PER_PAGE;
  const missing = [...Array(PER_PAGE).keys()].some((i) => !(start + i in songs.items) && (songs.total === 0 || start + i < songs.total));
  if (!missing) return true;
  const r = await spotifyApi(["tracks", songs.context, String(start), String(PER_PAGE)]);
  if (r.error) return false;
  songs.total = r.total;
  r.items.forEach((t, i) => (songs.items[start + i] = t));
  return true;
}

async function albumArt(t) {
  if (!t.albumId || !/^[A-Za-z0-9]{22}$/.test(t.albumId) || !/^https:\/\/i\.scdn\.co\//.test(t.image)) return "";
  const file = path.join(ART_CACHE, `${t.albumId}.jpg`);
  if (fs.existsSync(file)) return file;
  return (await download(t.image, file)) ? file : "";
}

function coordKey(v) {
  return v.coords ? `${v.coords.column},${v.coords.row}` : "";
}

let songRenderSeq = 0;
async function renderSongs() {
  if (contextsFor("song").length === 0 && contextsFor("songpage").length === 0) return;
  const seq = ++songRenderSeq;
  const pages = Math.max(1, Math.ceil(songs.total / PER_PAGE));
  for (const [ctx, v] of contextsFor("songpage")) {
    const delta = Number(v.settings.delta || 1);
    const has = delta < 0 ? songs.page > 0 : songs.page < pages - 1;
    const label = `${songs.page + 1}/${pages}`;
    await setKey(ctx, has ? ["text", delta < 0 ? "◀" : "▶", label, "#2d3a46"] : ["text", "", label, "#000000"]);
  }
  for (const [ctx, v] of contextsFor("song")) {
    if (seq !== songRenderSeq) return; // a newer page change superseded this render
    const slot = SONG_SLOTS.indexOf(coordKey(v));
    const t = slot < 0 ? null : songs.items[songs.page * PER_PAGE + slot];
    if (!t) {
      await setKey(ctx, ["text", "", "", "#000000"]);
      continue;
    }
    const caption = (t.uri && t.uri === songs.current ? "▶ " : "") + t.name;
    const art = await albumArt(t);
    await setKey(ctx, art ? ["cover", art, caption] : ["text", "♫", caption, "#14532d"]);
  }
}

async function openSongs(context, device) {
  const now = await spotifyApi(["context"]);
  if (now.error === "login") {
    log("song picker: run `spotify-api.js login <client id>` to grant the currently-playing permission");
    return send({ event: "showAlert", context });
  }
  // Nothing playing (or playing outside a playlist): fall back to the most recently played playlist.
  let ctxUri = !now.error && now.context;
  if (!ctxUri || !/^spotify:(playlist|album|user:[^:]+:collection)/.test(ctxUri)) {
    if (!apiPlaylists) await fetchApiPlaylists();
    const recent = (apiPlaylists || []).filter((p) => p.lastPlayed).sort((a, b) => b.lastPlayed - a.lastPlayed)[0];
    ctxUri = recent ? recent.uri : null;
  }
  if (!ctxUri) return send({ event: "showAlert", context });
  if (songs.context !== ctxUri) songs = { context: ctxUri, current: null, page: 0, total: 0, items: {} };
  songs.current = (!now.error && now.track) || null;
  if (!(await loadSongPage(songs.page))) return send({ event: "showAlert", context });
  // Start on the page holding the current song, if it's within what we've loaded.
  const idx = Object.keys(songs.items).find((i) => songs.items[i] && songs.items[i].uri === songs.current);
  if (idx !== undefined) songs.page = Math.floor(Number(idx) / PER_PAGE);
  for (const [ctx] of [...contextsFor("song"), ...contextsFor("songpage")]) lastImage.delete(ctx);
  switchProfile(device, PROFILE, SONG_PAGE);
  renderSongs();
}

async function flipSongPage(settings, context) {
  const pages = Math.max(1, Math.ceil(songs.total / PER_PAGE));
  const next = songs.page + Number(settings.delta || 1);
  if (next < 0 || next >= pages) return;
  songs.page = next;
  if (!(await loadSongPage(next))) return send({ event: "showAlert", context });
  renderSongs();
}

async function pressSong(context, device) {
  const v = visible.get(context);
  const slot = v ? SONG_SLOTS.indexOf(coordKey(v)) : -1;
  const t = slot < 0 ? null : songs.items[songs.page * PER_PAGE + slot];
  if (!t || !/^spotify:track:[A-Za-z0-9]{22}$/.test(t.uri) || !/^spotify:[\w:.-]+$/.test(songs.context || "")) {
    return send({ event: "showAlert", context });
  }
  const before = await aerospaceSnapshot();
  const r = await osa(`
if application "Spotify" is not running then
  tell application "Spotify" to launch
  delay 3
end if
tell application "Spotify" to play track "${t.uri}" in context "${songs.context}"`);
  if (r.code !== 0) {
    log("song play failed", t.uri, r.stderr.trim());
    return send({ event: "showAlert", context });
  }
  send({ event: "showOk", context });
  songs.current = t.uri;
  if (onCall.has(device) && !inMeeting) switchProfile(device); // back to the home page
  aerospaceRestore(before);
  setTimeout(() => refreshSpotify(true), 1500);
}
