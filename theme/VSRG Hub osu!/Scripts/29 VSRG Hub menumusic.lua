-- Music on the main menu, as in osu!: a random song from the library plays from its preview point,
-- the "now playing" box shows it (previous / pause / next), and the cookie and its visualizer move
-- to its beat (worked out from the song's own timing).
TW.menu = TW.menu or { history = {} }
local menu = TW.menu

local function pickSong()
	local songs = SONGMAN:GetAllSongs()
	if #songs == 0 then return nil end
	-- (a song with music, playable in the key mode you're in: song select can then open on it)
	for _ = 1, 60 do
		local s = songs[math.random(1, #songs)]
		local ok, path = pcall(function() return s:GetMusicPath() end)
		local fits = true
		if TW.playable then fits = #TW.playable(s) > 0 end
		if ok and fits and path and path ~= "" and FILEMAN:DoesFileExist(path) then return s end
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

-- the first song of a session: the one you last played (song select opens on it, as it always did);
-- random ones after that
local function firstSong()
	local s
	pcall(function() s = GAMESTATE:GetCurrentSong() end)
	-- (on the main menu nobody has joined yet, so the player's profile is looked up by its id)
	if not s then pcall(function() s = PROFILEMAN:GetProfile(PLAYER_1):GetLastPlayedSong() end) end
	if not s then
		pcall(function()
			local id = PREFSMAN:GetPreference("DefaultLocalProfileIDP1")
			local lp = id and id ~= "" and PROFILEMAN:GetLocalProfile(id)
			if lp then s = lp:GetLastPlayedSong() end
		end)
	end
	if s and TW.playable and #TW.playable(s) == 0 then s = nil end
	local ok, path = pcall(function() return s and s:GetMusicPath() end)
	if not (ok and path and path ~= "" and FILEMAN:DoesFileExist(path)) then s = nil end
	return s
end
local function musicPathOf(song)
	local ok, p = pcall(function() return song and song:GetMusicPath() or "" end)
	return ok and (p or "") or ""
end
function TW.menuMusicStart()
	if menu.song and not menu.paused and menu.playing then return end
	menu.playing = true
	-- back from song select with music still going (the menu's own song, or the one picked there):
	-- it goes on as it is, as osu!'s does, instead of starting over
	local playing = ""
	pcall(function() playing = SOUND:GetMusicPath() or "" end)
	if playing ~= "" and not menu.paused then
		local cur = GAMESTATE:GetCurrentSong()
		local keep = (menu.song and musicPathOf(menu.song):lower() == playing:lower()) and menu.song
			or (cur and musicPathOf(cur):lower() == playing:lower()) and cur or nil
		if keep then
			if keep ~= menu.song then
				menu.song, menu.start, menu.startedAt, menu.len = keep, 0, GetTimeSinceStart(), 600
				pcall(function() menu.start = math.max(0, keep:GetSampleStart()) end)
				pcall(function() menu.len = math.max(5, keep:MusicLengthSeconds() - menu.start) end)
				menu.history[#menu.history + 1] = keep
			end
			MESSAGEMAN:Broadcast("TWMenuMusic")
			return
		end
	end
	local s = menu.song or firstSong() or pickSong()
	if s then menu.history[#menu.history + 1] = s end
	play(s)
end
-- The menu's music watched while the menu is up (TW.menuMusicWatcher, an actor in the menu): when
-- nothing plays though it should (whatever stopped it: a screen change's stop landing late, a
-- failed start), it is started again. SOUND:GetMusicPath() is the file playing, "" for none.
local lastLook = 0
function TW.menuMusicWatcher()
	return Def.ActorFrame {
		InitCommand = function(self)
			self:SetUpdateFunction(function()
				local now = GetTimeSinceStart()
				if now - lastLook < 0.5 then return end
				lastLook = now
				if not menu.playing or menu.paused or not menu.song then return end
				local playing, want = "", ""
				pcall(function() playing = SOUND:GetMusicPath() or "" end)
				pcall(function() want = menu.song:GetMusicPath() or "" end)
				-- (only when nothing at all plays: another file playing is Etterna's own doing, left alone)
				if want ~= "" and playing == "" then play(menu.song) end
			end)
		end,
	}
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
-- leaving the menu: the music goes on (osu! keeps the song playing into song select, which opens on
-- it: TW.menuSongPending; the osu! look's own preview then leaves it be, the others restart it from
-- the preview point). keep = false stops it (exit).
function TW.menuMusicStop(keep)
	menu.playing = false
	if keep == false or not menu.song or menu.paused then SOUND:StopMusic() return end
	TW.menuSongPending = menu.song
	TW.menuSongPlaying = menu.song
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
