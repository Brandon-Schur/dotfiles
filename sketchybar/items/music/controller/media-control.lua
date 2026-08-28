local media_control = {}

-- Guard: never cold-launch a media player (especially Apple Music). macOS will
-- open the default player (Apple Music) if a play/get intent is sent while
-- nothing is running. So we only talk to `media-control` when a known player is
-- ALREADY running; otherwise we do nothing (and never call the callback, to
-- avoid nil dereferences downstream).
local RUNNING_CHECK = [[for a in Music Spotify Podcasts TV VLC IINA "Google Chrome" "Brave Browser" Arc Safari Firefox "zoom.us"; do pgrep -x "$a" >/dev/null 2>&1 && { echo yes; exit 0; }; done; echo no]]

local function guarded(cmd, cb)
  SBAR.exec(RUNNING_CHECK, function(res)
    local running = type(res) == "string" and res:match("yes") ~= nil
    if running then
      if cb then
        SBAR.exec(cmd, cb)
      else
        SBAR.exec(cmd)
      end
    end
    -- no player running: intentionally do nothing (don't launch Apple Music)
  end)
end

-- #region Control Functions
function media_control.next_track()
  guarded("media-control next-track")
end

function media_control.prev_track()
  guarded("media-control previous-track")
end

function media_control.toggle_play()
  guarded("media-control toggle-play-pause")
end

function media_control.toggle_shuffle()
  guarded("media-control toggle-shuffle")
end

function media_control.toggle_repeat()
  guarded("media-control toggle-repeat")
end

-- #endregion Control Functions

-- #region Info Updaters
function media_control.stats(callback)
  guarded("media-control get -h", function(result)
    if type(result) == "table" then
      callback(result.playing, false, false)
    end
  end)
end

function media_control.update_current_track(callback)
  guarded("media-control get -h", function(result)
    if type(result) == "table" then
      callback(result.title, result.artist, result.album)
    end
  end)
end

--- @param callback function used to receive the cover path and update sketchybar ui
function media_control.update_album_art(callback)
  guarded('media-control get | jq -r ".artworkData"', function(img_data)
    -- Some media may not have album art, e.g. online videos, use default art in that case
    if img_data == "null\n" then
      LOG:warn("No album art found, using default.")
      callback(MUSIC.DEFAULT_ALBUM_ART_PATH)
      return
    end

    local size = MUSIC.ALBUM_ART_SIZE
    local cover = "/tmp/music_cover.jpg"
    local gen_img_cmd = string.format('echo "%s" | base64 -d > %s', img_data, cover)
    local process_cmd = string.format('magick "%s" -resize %dx%d^ -gravity center -extent %dx%d %s', cover, size, size, size, size, cover)

    SBAR.exec(gen_img_cmd .. "&&" .. process_cmd, function()
      callback(cover)
    end)
  end)
end

-- #endregion Info Updaters

return media_control
