-- osu! stable's song list scrolls freely: the mouse wheel moves the list, the song you picked stays
-- picked (its music, background, info, ranking and open difficulties) until you click another one.
--
-- Etterna's song list always has the song in its middle selected, so here its middle is only where
-- the list is scrolled to, and the picked song is kept apart (TW.pick): while you browse, the game's
-- current song and chart are put back to the picked ones each time the list moves (everything that
-- shows the selected song then keeps showing it), and Etterna's own preview music is off for this
-- look (metrics.ini: SampleMusicPreviewMode_Nothing) so VSRG Hub plays the picked song's preview.
-- Before anything that needs Etterna's list on the picked song (Enter, changing difficulty), the
-- list goes back to it (TW.syncToPick).
--
-- TW.pick       { song, steps } the picked song and chart
-- TW.browsing   true while the list is scrolled away from the picked song
-- TW.pickY      where the picked song's panel is, from the list's middle (screen units)

TW.pick = TW.pick or {}
TW.browsing = false
TW.pickY = 0

local function top()
	local s = SCREENMAN:GetTopScreen()
	return s and s:GetName() == "ScreenSelectMusic" and s or nil
end
local function wheel()
	local s = top()
	return s and s:GetMusicWheel() or nil
end

-- the mouse wheel: scroll the list without picking
function TW.browse(dir)
	local w = wheel()
	if not w then return end
	if not TW.pick.song then
		-- (on a pack's name nothing is picked, whatever Etterna's current song is: a pack opened or
		-- closed from its name leaves it as it was)
		local kind
		pcall(function() kind = w:GetSelectedType() end)
		if kind == "WheelItemDataType_Section" then TW.pick = {}
		else TW.pick = { song = GAMESTATE:GetCurrentSong(), steps = GAMESTATE:GetCurrentSteps() } end
	end
	TW.browsing = TW.pick.song ~= nil
	w:Move(dir)
end

-- The list's change messages: not browsing, whatever the list stops on is picked (as before). While
-- you browse nothing follows the list (the song select's parts skip the list's messages then:
-- TW.browsing), and once the list rests the game's current song and chart are put back to the
-- picked ones (TW.restorePick, from the difficulties' update): doing that for every song the list
-- runs past made a fast spin of the mouse wheel stutter.
function TW.keepPick()
	if TW.browsing then return end
	local song = GAMESTATE:GetCurrentSong()
	if song then TW.pick = { song = song, steps = GAMESTATE:GetCurrentSteps() }
	else
		-- (the list on a pack's name, e.g. the pack just closed: nothing is picked, so browsing from
		-- here doesn't bring the old song's difficulties back over the packs)
		TW.pick = {}
	end
end
local restoring = false
function TW.restorePick()
	local p = TW.pick
	if restoring or not TW.browsing or not p.song then return end
	if GAMESTATE:GetCurrentSong() == p.song and (not p.steps or GAMESTATE:GetCurrentSteps() == p.steps) then return end
	restoring = true
	pcall(function()
		if GAMESTATE:GetCurrentSong() ~= p.song then GAMESTATE:SetCurrentSong(p.song) end
		if p.steps and GAMESTATE:GetCurrentSteps() ~= p.steps then GAMESTATE:SetCurrentSteps(PLAYER_1, p.steps) end
	end)
	restoring = false
end
-- (song select's parts: skip the list's song messages while browsing, the picked song is kept)
function TW.browsingSkip() return TW.browsing == true and not restoring end

-- the list back on the picked song, then fn (once the list has stopped there)
TW.syncPending = nil
function TW.syncToPick(fn)
	local w = wheel()
	if not TW.browsing or not w or not TW.pick.song then
		TW.browsing = false
		if fn then fn() end
		return
	end
	TW.browsing = false
	local p = TW.pick
	TW.syncPending = { fn = fn, song = p.song, steps = p.steps, t = GetTimeSinceStart() }
	w:SelectSong(p.song)
end
-- (from the difficulties' update: runs the waiting action once the list is there)
function TW.syncStep()
	local s = TW.syncPending
	if not s then return end
	local w = wheel()
	if not w then TW.syncPending = nil return end
	if GetTimeSinceStart() - s.t > 3 then TW.syncPending = nil return end
	if not w:IsSettled() or GAMESTATE:GetCurrentSong() ~= s.song then return end
	TW.syncPending = nil
	-- (the chart that was picked, not the one Etterna prefers for the song)
	if s.steps and GAMESTATE:GetCurrentSteps() ~= s.steps then
		local list = TW.diffCharts and TW.diffCharts(s.song) or {}
		local i = TW.diffIndexOf and TW.diffIndexOf(list, s.steps)
		if i then TW.pickDiff(i) end
	end
	if s.fn then s.fn() end
end

-- a pack opened or closed from its name (a click on it): Etterna leaves its current song as it was,
-- but the list is on the pack's name now, so nothing is picked
function TW.packToggled()
	TW.browsing = false
	TW.pick = {}
	if GAMESTATE:GetCurrentSong() then GAMESTATE:SetCurrentSong(nil) end
end

-- the panel in the list's middle picked, without moving the list (a click on it while browsing)
function TW.pickHere(song)
	if not song then return end
	TW.browsing = false
	local list = TW.diffCharts and TW.diffCharts(song) or {}
	local steps = list[1]
	-- (the difficulty closest to the one you had)
	local want = TW.pick.steps and TW.msd(TW.pick.steps) or nil
	if want then
		local best
		for _, st in ipairs(list) do
			local d = math.abs(TW.msd(st) - want)
			if not best or d < best then best, steps = d, st end
		end
	end
	GAMESTATE:SetCurrentSong(song)
	if steps then GAMESTATE:SetCurrentSteps(PLAYER_1, steps) end
	TW.pick = { song = song, steps = GAMESTATE:GetCurrentSteps() }
end

-- the picked song's preview: played once the pick has settled (Etterna's own is off for this look;
-- Etterna doesn't start it in the screen's first moments, so it's asked again until it plays)
local previewFor, wantKey, previewAt, tried = nil, nil, 0, 0
function TW.pickMusicStep()
	local s = top()
	local song = TW.pick.song
	if not s or not song or TW.browsing then return end
	local key = tostring(song) .. "|" .. tostring(getCurRateValue())
	if key == previewFor then return end
	local now = GetTimeSinceStart()
	local w = s:GetMusicWheel()
	if not w or not w:IsSettled() then previewAt = now return end
	if now - previewAt < 0.25 or now - tried < 0.4 then return end
	if GAMESTATE:GetCurrentSong() ~= song then return end
	-- (the menu's song, still playing from the menu: left as it is, as osu! does)
	if TW.menuSongPlaying == song and math.abs(getCurRateValue() - 1) < 0.001 then
		TW.menuSongPlaying = nil
		previewFor = key
		return
	end
	TW.menuSongPlaying = nil
	tried, wantKey = now, key
	pcall(function() s:PlayCurrentSongSampleMusic(false, false) end)
end
-- (Etterna's "PlayingSampleMusic": the preview asked for is playing)
function TW.pickMusicPlaying() if wantKey then previewFor = wantKey end end
function TW.pickMusicReset() previewFor, wantKey = nil, nil end
