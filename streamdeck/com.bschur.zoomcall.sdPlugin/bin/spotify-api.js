#!/usr/bin/env node
// Spotify Web API helper for the Stream Deck playlist picker (Authorization Code + PKCE; no client secret).
//
//   node spotify-api.js login <client id>   one-time browser login; stores a refresh token
//   node spotify-api.js playlists           JSON: Liked Songs + your playlists, most recently played first
//   node spotify-api.js context             JSON: what's playing now {context, track} (context may be null)
//   node spotify-api.js tracks <uri> <offset> <limit>   JSON: {total, items:[{uri,name,artist,image,albumId}]}
//
// Token file: ~/.config/streamdeck-spotify/token.json (mode 600, outside the repo).
// The login listener binds 127.0.0.1 only, accepts one callback with a matching `state`, then exits.

"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const https = require("node:https");
const os = require("node:os");
const path = require("node:path");
const { execFile } = require("node:child_process");

const DIR = path.join(os.homedir(), ".config", "streamdeck-spotify");
const TOKEN_FILE = path.join(DIR, "token.json");
const HOST = "127.0.0.1";
const PORT = 4202;
// Must match the Redirect URI registered in the Spotify app exactly (no path).
const REDIRECT_URI = `http://${HOST}:${PORT}`;
const SCOPES = "user-read-recently-played user-read-currently-playing playlist-read-private playlist-read-collaborative user-library-read";

function fail(msg, code = 1) {
  process.stderr.write(msg + "\n");
  process.exit(code);
}

function request(method, url, { headers = {}, body } = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, { method, headers }, (res) => {
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => {
        let json = null;
        try {
          json = data ? JSON.parse(data) : null;
        } catch {
          /* non-JSON */
        }
        resolve({ status: res.statusCode, json, text: data });
      });
    });
    req.setTimeout(15000, () => req.destroy(new Error("timeout")));
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function saveToken(tok) {
  fs.mkdirSync(DIR, { recursive: true, mode: 0o700 });
  fs.writeFileSync(TOKEN_FILE, JSON.stringify(tok), { mode: 0o600 });
  fs.chmodSync(TOKEN_FILE, 0o600);
}

async function tokenRequest(params) {
  const r = await request("POST", "https://accounts.spotify.com/api/token", {
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(params).toString(),
  });
  if (r.status !== 200 || !r.json || !r.json.access_token) {
    fail(`token request failed (${r.status}): ${(r.json && (r.json.error_description || r.json.error)) || r.text.slice(0, 200)}`);
  }
  return r.json;
}

// ---------- login ----------
async function login(clientId) {
  if (!/^[0-9a-f]{32}$/i.test(clientId || "")) fail("usage: spotify-api.js login <32-char client id>", 2);
  const verifier = crypto.randomBytes(48).toString("base64url");
  const challenge = crypto.createHash("sha256").update(verifier).digest("base64url");
  const state = crypto.randomBytes(16).toString("hex");
  const authUrl =
    "https://accounts.spotify.com/authorize?" +
    new URLSearchParams({
      client_id: clientId,
      response_type: "code",
      redirect_uri: REDIRECT_URI,
      code_challenge_method: "S256",
      code_challenge: challenge,
      scope: SCOPES,
      state,
    });

  const code = await new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const u = new URL(req.url, REDIRECT_URI);
      if (u.pathname !== "/" || !u.searchParams.has("state")) {
        res.writeHead(404).end();
        return;
      }
      if (u.searchParams.get("state") !== state) {
        res.writeHead(400, { "Content-Type": "text/plain" }).end("State mismatch; ignoring.");
        return; // keep waiting for the real callback
      }
      const err = u.searchParams.get("error");
      res.writeHead(200, { "Content-Type": "text/plain" }).end(
        err ? `Spotify login failed: ${err}` : "Spotify connected to Stream Deck. You can close this tab."
      );
      server.close();
      clearTimeout(timer);
      if (err) fail(`login denied: ${err}`);
      resolve(u.searchParams.get("code"));
    });
    const timer = setTimeout(() => {
      server.close();
      fail("login timed out after 5 minutes");
    }, 5 * 60 * 1000);
    server.listen(PORT, HOST, () => {
      process.stdout.write(`Opening Spotify login in your browser...\nIf it doesn't open: ${authUrl}\n`);
      execFile("/usr/bin/open", [authUrl]);
    });
    server.on("error", (e) => fail(`could not listen on ${HOST}:${PORT}: ${e.message}`));
  });

  const tok = await tokenRequest({
    grant_type: "authorization_code",
    code,
    redirect_uri: REDIRECT_URI,
    client_id: clientId,
    code_verifier: verifier,
  });
  saveToken({
    client_id: clientId,
    access_token: tok.access_token,
    refresh_token: tok.refresh_token,
    expires_at: Date.now() + (tok.expires_in - 60) * 1000,
  });
  process.stdout.write(`Saved token to ${TOKEN_FILE}\n`);
}

// ---------- API ----------
async function accessToken() {
  let tok;
  try {
    tok = JSON.parse(fs.readFileSync(TOKEN_FILE, "utf8"));
  } catch {
    fail("not logged in; run: spotify-api.js login <client id>", 3);
  }
  if (Date.now() < tok.expires_at) return tok.access_token;
  const r = await tokenRequest({ grant_type: "refresh_token", refresh_token: tok.refresh_token, client_id: tok.client_id });
  tok.access_token = r.access_token;
  if (r.refresh_token) tok.refresh_token = r.refresh_token; // PKCE refresh tokens rotate
  tok.expires_at = Date.now() + (r.expires_in - 60) * 1000;
  saveToken(tok);
  return tok.access_token;
}

async function api(token, url, { allow = [] } = {}) {
  const r = await request("GET", url.startsWith("https://") ? url : `https://api.spotify.com/v1${url}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (allow.includes(r.status)) return { __status: r.status, ...(r.json || {}) };
  if ((r.status === 403 && /scope/i.test(r.text)) || (r.status === 401 && /permissions missing/i.test(r.text))) fail("missing permission; re-run: spotify-api.js login <client id>", 3);
  if (r.status !== 200) fail(`GET ${url} -> ${r.status}: ${r.text.slice(0, 200)}`);
  return r.json;
}

function smallestImage(images, min = 120) {
  const list = (images || []).filter((i) => i && i.url);
  if (!list.length) return "";
  const ok = list.filter((i) => !i.width || i.width >= min).sort((a, b) => (a.width || 0) - (b.width || 0));
  return (ok[0] || list[0]).url;
}

function trackRow(t) {
  if (!t || !t.uri) return null;
  return {
    uri: t.uri,
    name: t.name || "",
    artist: (t.artists || []).map((a) => a.name).join(", "),
    image: smallestImage(t.album && t.album.images),
    albumId: (t.album && t.album.id) || "",
  };
}

async function context() {
  const token = await accessToken();
  const r = await api(token, "/me/player/currently-playing", { allow: [204] });
  if (r.__status === 204 || !r.item) return process.stdout.write(JSON.stringify({ context: null, track: null }) + "\n");
  process.stdout.write(JSON.stringify({ context: (r.context && r.context.uri) || null, track: r.item.uri, playing: !!r.is_playing }) + "\n");
}

async function tracks(uri, offset, limit) {
  offset = Math.max(0, parseInt(offset, 10) || 0);
  limit = Math.min(50, Math.max(1, parseInt(limit, 10) || 12));
  const token = await accessToken();
  let m;
  let out;
  if (/^spotify:user:[^:]+:collection$/.test(uri) || uri === "spotify:collection") {
    const r = await api(token, `/me/tracks?offset=${offset}&limit=${limit}`);
    out = { total: r.total, items: r.items.map((i) => trackRow(i.track)) };
  } else if ((m = uri.match(/^spotify:playlist:([A-Za-z0-9]{22})$/))) {
    const q = `offset=${offset}&limit=${limit}`;
    let r = await api(token, `/playlists/${m[1]}/tracks?${q}`, { allow: [404] });
    if (r.__status === 404) r = await api(token, `/playlists/${m[1]}/items?${q}`); // newer API name
    out = { total: r.total, items: (r.items || []).map((i) => trackRow(i.track || i.item)) };
  } else if ((m = uri.match(/^spotify:album:([A-Za-z0-9]{22})$/))) {
    const album = await api(token, `/albums/${m[1]}`);
    const r = await api(token, `/albums/${m[1]}/tracks?offset=${offset}&limit=${limit}`);
    out = { total: r.total, items: r.items.map((t) => trackRow({ ...t, album })) };
  } else {
    fail(`unsupported context: ${uri}`, 4);
  }
  out.items = out.items.map((t) => t || { uri: "", name: "(unavailable)", artist: "", image: "", albumId: "" });
  process.stdout.write(JSON.stringify(out) + "\n");
}

async function playlists() {
  const token = await accessToken();
  const me = await api(token, "/me");

  // Library playlists, in Spotify's library order (used as the tie-breaker).
  const lib = [];
  for (let url = "/me/playlists?limit=50"; url && lib.length < 500; ) {
    const page = await api(token, url);
    lib.push(...page.items.filter(Boolean));
    url = page.next;
  }

  // Last 50 plays; each carries the playlist ("context") it was played from.
  const recent = await api(token, "/me/player/recently-played?limit=50");
  const lastPlayed = {};
  for (const it of recent.items || []) {
    const uri = it.context && it.context.uri;
    const t = Date.parse(it.played_at);
    if (uri && !(lastPlayed[uri] >= t)) lastPlayed[uri] = t;
  }

  const likedUri = `spotify:user:${me.id}:collection`;
  const likedPlayed = lastPlayed[likedUri] || lastPlayed[`spotify:collection`] || 0;
  const rows = lib.map((p, i) => ({
    id: p.id,
    uri: p.uri,
    name: p.name,
    image: (p.images && p.images.length && p.images[p.images.length > 1 ? 1 : 0].url) || "",
    lastPlayed: lastPlayed[p.uri] || 0,
    order: i,
  }));
  rows.sort((a, b) => b.lastPlayed - a.lastPlayed || a.order - b.order);

  // Liked Songs stays first (his preference), then most recently played.
  const out = [{ id: "", uri: likedUri, name: "Liked Songs", image: "", lastPlayed: likedPlayed }, ...rows];
  process.stdout.write(JSON.stringify(out.map(({ order, ...r }) => r)) + "\n");
}

const [cmd, arg] = process.argv.slice(2);
if (cmd === "login") login(arg);
else if (cmd === "playlists") playlists().catch((e) => fail(String(e)));
else if (cmd === "context") context().catch((e) => fail(String(e)));
else if (cmd === "tracks") tracks(arg, process.argv[4], process.argv[5]).catch((e) => fail(String(e)));
else fail("usage: spotify-api.js login <client id> | playlists | context | tracks <uri> <offset> <limit>", 2);
