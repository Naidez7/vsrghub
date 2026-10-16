-- Music on the main menu, as in osu!: a random song from the library plays from its preview point,
-- the "now playing" box shows it (previous / pause / next), and the cookie and its visualizer move
-- to its beat (worked out from the song's own timing).
TW.menu = TW.menu or { history = {} }
local menu = TW.menu

local function pickSong()
	local songs = SONGMAN:GetAllSongs()
	if #songs == 0 then return nil end
	for _ = 1, 30 do
		local s = songs[math.random(1, #songs)]
		local ok, path = pcall(function() return s:GetMusicPath() end)
		if ok and path and path ~= "" and FILEMAN:DoesFileExist(path) then return s end
	end
	return nil
end

local function play(song)
	if not song then return end
	local path = song:GetMusicPath()
	local start = 0
	pcall(function() start = math.max(0, song:GetSampleStart()) end)
	local len = 600
	pcall(function() len = math.max(5, song:MusicLengthSeconds() - start) end)
	SOUND:StopMusic()
	-- (path, start, length, fade in, fade out, loop, rate, align to the beat)
	SOUND:PlayMusicPart(path, start, len, 0.5, 1, true, false, false)
	menu.song, menu.start, menu.startedAt, menu.paused, menu.len = song, start, GetTimeSinceStart(), false, len
	MESSAGEMAN:Broadcast("TWMenuMusic")
end

function TW.menuMusicStart()
	if menu.song and not menu.paused and menu.playing then return end
	menu.playing = true
	local s = menu.song or pickSong()
	if s then menu.history[#menu.history + 1] = s end
	play(s)
end
function TW.menuMusicNext()
	local s = pickSong()
	if s then menu.history[#menu.history + 1] = s; play(s) end
end
function TW.menuMusicPrev()
	if #menu.history > 1 then
		table.remove(menu.history)
		play(menu.history[#menu.history])
	elseif menu.song then
		play(menu.song)
	end
end
function TW.menuMusicToggle()
	if not menu.song then return TW.menuMusicNext() end
	if menu.paused then
		-- (from where it stopped)
		local at = menu.pausedAt or menu.start
		local path = menu.song:GetMusicPath()
		SOUND:PlayMusicPart(path, at, math.max(5, menu.len - (at - menu.start)), 0.2, 1, true, false, false)
		menu.startedAt = GetTimeSinceStart() - (at - menu.start)
		menu.paused = false
	else
		menu.pausedAt = menu.start + (GetTimeSinceStart() - menu.startedAt)
		SOUND:StopMusic()
		menu.paused = true
	end
	MESSAGEMAN:Broadcast("TWMenuMusic")
end
-- leaving the menu: the music stops (song select plays its own)
function TW.menuMusicStop()
	menu.playing = false
	-- (song select opens on the song that was playing, as osu!'s does)
	if menu.song then TW.menuSongPending = menu.song end
	SOUND:StopMusic()
end
function TW.menuMusicTitle()
	local s = menu.song
	if not s then return "" end
	return s:GetDisplayArtist() .. " - " .. s:GetDisplayMainTitle()
end

-- The beat the music is on now (nil when nothing plays).
function TW.menuBeat()
	local s = menu.song
	if not s or menu.paused or not menu.playing then return nil end
	local t = menu.start + (GetTimeSinceStart() - menu.startedAt)
	if menu.len and menu.len > 0 then t = menu.start + ((t - menu.start) % menu.len) end
	local ok, b = pcall(function() return s:GetTimingData():GetBeatFromElapsedTime(t) end)
	if ok then return b end
	return nil
end

-- An actor that kicks TW.visualKick on every beat and plays its "Beat" command on the frames it
-- names (so the cookie can bounce).
function TW.beatWatcher(onBeat)
	local last = nil
	return Def.ActorFrame {
		InitCommand = function(self)
			TW.everyFrame(self)
			self:SetUpdateFunction(function()
				local b = TW.menuBeat()
				if not b then
					-- (no music: a gentle beat of its own, 100 BPM)
					b = GetTimeSinceStart() * 100 / 60
				end
				local whole = math.floor(b)
				if last and whole ~= last then
					local strong = whole % 4 == 0
					TW.visualKick(strong and 1 or 0.6)
					if onBeat then onBeat(strong) end
				end
				last = whole
			end)
		end,
	}
end
