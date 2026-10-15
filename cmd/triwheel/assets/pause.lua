-- Written by VSRG Hub next to its theme picker in Etterna's own themes and loaded by every look
-- (the VSRG Hub looks fall back to Til Death). It adds pausing, like osu! and Quaver.
--
-- Etterna can pause a song only on its practice screen. With pausing on, VSRG Hub starts each play on
-- that screen but with practice mode's flag taken off, so the play is judged, ends on the results
-- screen and is saved like any other. Esc pauses (Continue / Retry / Quit, Esc again continues);
-- Ctrl+P on the menus turns pausing on and off, as does the "Pausing" option. A play that was paused
-- is kept but marked invalid (like Etterna's own "invalidate score"): it doesn't count for your rating
-- or go to EtternaOnline as a valid score. TW_PAUSE holds the pauses of the current or last play,
-- for the results screen.

local SETTINGS = "Save/VSRGHub/settings.ini"

-- Til Death's and Rebirth's combo break lane flash (Etterna's "CB Highlight": a column lit in the
-- judgment's colour on a Bad or Miss, in every look, the VSRG Hub ones too): VSRG Hub's "Lane flash on
-- misses" option, off unless you turn it on; it decides Etterna's own setting before every play.
local function readSetting(k)
	if TW and TW.settings and TW.settings[k] ~= nil then return TW.settings[k] end
	local ok, txt = pcall(function() return File.Read(SETTINGS) end)
	txt = ok and type(txt) == "string" and txt or ""
	return txt:match("\n" .. k .. "=([^\r\n]*)") or txt:match("^" .. k .. "=([^\r\n]*)")
end
function TWLaneFlashOn() return readSetting("laneflash") == "true" end
local function applyLaneFlash()
	local on = TWLaneFlashOn()
	-- (only once a profile is loaded: the theme's player config complains loudly before that)
	pcall(function()
		local slot = pn_to_profile_slot(PLAYER_1)
		local dir = PROFILEMAN:GetProfileDir(slot)
		if not dir or dir == "" or not playerConfig then return end
		playerConfig:get_data(slot).CBHighlight = on
	end)
end
function TWLaneFlashToggle()
	local v = TWLaneFlashOn() and "false" or "true"
	if TW and TW.saveSetting then TW.saveSetting("laneflash", v)
	else
		local ok, txt = pcall(function() return File.Read(SETTINGS) end)
		local lines, found = {}, false
		for l in ((ok and txt) or ""):gmatch("[^\r\n]+") do
			local line = l
			if line:match("^laneflash=") then line = "laneflash=" .. v; found = true end
			lines[#lines + 1] = line
		end
		if not found then lines[#lines + 1] = "laneflash=" .. v end
		pcall(function() File.Write(SETTINGS, table.concat(lines, "\n") .. "\n") end)
		if TW and TW.settings then TW.settings.laneflash = v end
	end
	applyLaneFlash()
	SCREENMAN:SystemMessage(v == "true" and "Lane flash on misses: on" or "Lane flash on misses: off")
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
end
TW_PAUSE = { count = 0, times = {}, active = false, state = "playing", inPlay = false }
-- the pauses to show on the results screen now (nil when there are none)
-- (the results screen is built before it becomes the top screen: the last screen shown is still
-- the play then; a saved score opened from song select is not)
function TWPausesForResults()
	if TW_PAUSE.inPlay and TW_PAUSE.count > 0 then return TW_PAUSE.times end
	return nil
end
local P = TW_PAUSE

-- the setting ---------------------------------------------------------------------------------
local function fileSetting()
	local ok, txt = pcall(function() return File.Read(SETTINGS) end)
	return ok and type(txt) == "string" and txt:match("pause=(%a+)") == "true"
end
function TWPauseOn()
	if TW and TW.settings then return TW.settings.pause == "true" end
	return fileSetting()
end
function TWPauseSet(on)
	local v = on and "true" or "false"
	if TW and TW.saveSetting then TW.saveSetting("pause", v)
	else
		local ok, txt = pcall(function() return File.Read(SETTINGS) end)
		local lines, found = {}, false
		for l in ((ok and txt) or ""):gmatch("[^\r\n]+") do
			local line = l
			if line:match("^pause=") then line = "pause=" .. v; found = true end
			lines[#lines + 1] = line
		end
		if not found then lines[#lines + 1] = "pause=" .. v end
		pcall(function() File.Write(SETTINGS, table.concat(lines, "\n") .. "\n") end)
	end
	MESSAGEMAN:Broadcast("TWPauseSetting", { on = on })
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
end
function TWPauseToggle()
	local on = not TWPauseOn()
	TWPauseSet(on)
	local pk = (TWKeys and TWKeys.label and TWKeys.label("pause")) or "Esc"
	SCREENMAN:SystemMessage(on and ("Pausing on: " .. pk .. " pauses a song (a paused play's score is kept but marked invalid)")
		or "Pausing off: Esc leaves a song, as in Etterna")
end

-- practice mode for pausable plays --------------------------------------------------------------
local ours = false -- practice mode was turned on here (so it's turned off again on song select)
local function customizing()
	if THEME:GetCurThemeName():find("^VSRG Hub") then return TW ~= nil and TW.customize == true end
	local ok, on = pcall(function() return playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay end)
	return ok and on == true
end
local function mode() return GAMESTATE:GetGameplayMode() end
-- a long intro (the first note this many seconds or more into the song) can be skipped with Space
-- even with pausing off: such a play also runs on the screen that can move through the song
local LONG_INTRO = 8
local function longIntro()
	local first = 0
	pcall(function() first = GAMESTATE:GetCurrentSteps():GetFirstSecond() end)
	return first >= LONG_INTRO
end
local function prepare()
	if ours and mode() == "GameplayMode_Practice" then return end -- (both messages come)
	P.active = false
	P.pausable = TWPauseOn()
	-- a real practice run (Tab on song select, the Practice mod): Esc always pauses there
	if GAMESTATE:IsPracticeMode() and not customizing() then P.active = true; P.pausable = true return end
	-- Customize gameplay never pauses (Esc ends it), but a long intro can be skipped there too, to get
	-- to the notes sooner
	if customizing() then
		if not longIntro() then return end
		P.pausable = false
	end
	if not (P.pausable or longIntro()) then return end
	pcall(function() GAMESTATE:SetPracticeMode(true) end)
	if mode() ~= "GameplayMode_Practice" then return end -- (refused: online, replays)
	-- Etterna's practice screen is the one that can pause; with its practice flag taken off again the
	-- play is judged, ends on the results screen and is saved exactly like a normal play
	pcall(function() GAMESTATE:ApplyPreferredModifiers(PLAYER_1, "no practicemode") end)
	ours = true
	P.active = true
end
-- song select tells when a song is picked to play (SongChosen / StartFinalized, handled below):
-- practice mode is set then, before Etterna makes the gameplay screen

-- a paused play's score: kept, marked invalid ---------------------------------------------------
-- While a play that was paused is on, Etterna's automatic upload to EtternaOnline is held back (it
-- would happen before the score could be marked); it is turned back on right after.
local function holdSync()
	if P.syncWas ~= nil then return end
	local loggedIn = false
	pcall(function() loggedIn = DLMAN:IsLoggedIn() end)
	if not loggedIn then return end
	pcall(function()
		P.syncWas = PREFSMAN:GetPreference("automaticScoreSync")
		PREFSMAN:SetPreference("automaticScoreSync", 0)
	end)
end
local function restoreSync()
	if P.syncWas == nil then return end
	pcall(function() PREFSMAN:SetPreference("automaticScoreSync", P.syncWas) end)
	P.syncWas = nil
end
-- seconds between a score's date ("2026-10-11 03:43:29") and now; nil when it can't be read
local function scoreAge(hs)
	local y, mo, d, h, mi, s = tostring(hs:GetDate()):match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
	if not y then return nil end
	local function stamp(Y, Mo, D, H, Mi, S) return ((((Y * 12 + Mo) * 31 + D) * 24 + H) * 60 + Mi) * 60 + S end
	return stamp(Year(), MonthOfYear() + 1, DayOfMonth(), Hour(), Minute(), Second())
		- stamp(tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), tonumber(s))
end
local function markPaused()
	pcall(function()
		-- only the score this play just saved (an autoplay run saves none, so an older one must be left alone)
		if GAMESTATE:GetPlayerState():GetPlayerController() ~= "PlayerController_Human" then return end
		local hs = SCOREMAN:GetMostRecentScore()
		local age = hs and scoreAge(hs)
		if hs and age and age >= -5 and age < 120 and (P.chart == nil or hs:GetChartKey() == P.chart) and hs:GetEtternaValid() then
			hs:ToggleEtternaValidation()
			MESSAGEMAN:Broadcast("UpdateRanking")
		end
	end)
end

-- a skin picture drawn half a texel in from its edges: Etterna leaves the rest of a picture's texture
-- as it was in memory, and drawn up to the edge the picture picks up a line of it (as TW.inset)
local function inset(spr)
	pcall(function()
		local tex = spr:GetTexture()
		if not tex or (tex:GetNumFrames() or 1) > 1 then return end
		local l, t, r, b = tex:GetTextureCoordRect(0)
		local tw, th = tex:GetTextureWidth(), tex:GetTextureHeight()
		if not (l and tw and th and tw > 0 and th > 0) then return end
		local dx, dy = math.min(0.5 / tw, (r - l) / 4), math.min(0.5 / th, (b - t) / 4)
		spr:customtexturerect(l + dx, t + dy, r - dx, b - dy)
	end)
	return spr
end

-- the pause menu ------------------------------------------------------------------------------
local ITEMS = {
	{ label = "Continue", art = "pause_continue", colour = "#55CC77" },
	{ label = "Retry", art = "pause_retry", colour = "#E6C34A" },
	{ label = "Quit", art = "pause_back", colour = "#E0566A" },
}
local frame, cursor = nil, 1
local BW, BH, GAP = 0, 0, 0
local function layout()
	local s = SCREEN_HEIGHT / 480
	BW, BH, GAP = 170 * s, 34 * s, 10 * s
end
layout()
local hitW = {}
local function itemY(i) return SCREEN_CENTER_Y - BH * 0.5 + (i - 2) * (BH + GAP) + 20 * SCREEN_HEIGHT / 480 end
local function itemAt(mx, my)
	for i = 1, #ITEMS do
		local y = itemY(i)
		local w = math.max(BW, hitW[i] or 0)
		if math.abs(mx - SCREEN_CENTER_X) <= w / 2 and my >= y and my <= y + BH then return i end
	end
end
local function refresh() if frame then frame:playcommand("Refresh") end end
local function setPausedFlag(on) if TW then TW.paused = on end end

local function pause(top)
	if P.state ~= "playing" then return end
	local ok = pcall(function() top:TogglePause() end)
	if not ok then return end
	P.state = "paused"
	P.count = P.count + 1
	local t = 0
	pcall(function() t = GAMESTATE:GetSongPosition():GetMusicSeconds() end)
	P.times[#P.times + 1] = t
	holdSync()
	cursor = 1
	setPausedFlag(true)
	refresh()
end
local function resume()
	if P.state ~= "paused" then return end
	P.state = "countdown"
	setPausedFlag(false)
	refresh()
	if frame then frame:playcommand("Countdown") end
end
local function choose(i)
	local top = SCREENMAN:GetTopScreen()
	if not top then return end
	if i == 1 then resume()
	elseif i == 2 then
		P.state = "leaving"; setPausedFlag(false); refresh()
		pcall(function() top:RestartGameplay() end)
	elseif i == 3 then
		P.state = "leaving"; setPausedFlag(false); refresh()
		pcall(function() top:begin_backing_out() end)
	end
end

-- Going on after a pause: Etterna starts the song again where it stopped, but for the first moments
-- it reports the song a little ahead of what is heard (by the sound card's delay), then snaps back:
-- the notes would run ahead and jump back. Just then the notes are held where they were (through
-- Etterna's visual delay) until the song's position settles, and let go smoothly.
local hold = { mode = nil }
local function getVD()
	local ok, v = pcall(function() return PREFSMAN:GetPreference("VisualDelaySeconds") end)
	return (ok and tonumber(v)) or 0
end
local function setVD(v) pcall(function() PREFSMAN:SetPreference("VisualDelaySeconds", v) end) end
local function holdStart()
	local pos = 0
	pcall(function() pos = GAMESTATE:GetSongPosition():GetMusicSeconds() end)
	hold.orig = hold.orig or getVD()
	hold.S, hold.t0, hold.last, hold.mode, hold.vd = pos, GetTimeSinceStart(), nil, "hold", nil
end
-- (the frame the song's position snaps back in was already placed with the delay of the frame before:
-- the notes are left out of that one frame instead of being drawn too far back)
local function noteField()
	local nf
	pcall(function() nf = SCREENMAN:GetTopScreen():GetChild("PlayerP1"):GetChild("NoteField") end)
	return nf
end
local function showNotes()
	if hold.hidden then pcall(function() hold.hidden:visible(true) end); hold.hidden = nil end
end
local function holdStop()
	showNotes()
	if hold.orig ~= nil then setVD(hold.orig) end
	hold.orig, hold.mode = nil, nil
end
local function holdUpdate()
	if not hold.mode then return end
	local pos = 0
	pcall(function() pos = GAMESTATE:GetSongPosition():GetMusicSeconds() end)
	local rate = (getCurRateValue and getCurRateValue()) or 1
	if rate <= 0 then rate = 1 end
	local now = GetTimeSinceStart()
	showNotes()
	if hold.mode == "hold" then
		local snapped = hold.last ~= nil and pos < hold.last - 0.01
		hold.last = pos
		if not snapped and now - hold.t0 < 0.5 then
			-- (visible = position - delay x rate: kept where the song stopped)
			hold.vd = hold.orig + math.max(0, pos - hold.S) / rate
			setVD(hold.vd)
			return
		end
		hold.mode, hold.r0 = "ramp", now
		hold.from = hold.orig + math.max(0, pos - hold.S) / rate
		if snapped and hold.vd and (hold.vd - hold.from) * rate > 0.02 then
			local nf = noteField()
			if nf and nf:GetVisible() then nf:visible(false); hold.hidden = nf end
		end
	end
	local k = math.min(1, (now - hold.r0) / 0.25)
	setVD(hold.from + (hold.orig - hold.from) * k)
	if k >= 1 then holdStop() end
end

local function inPausablePlay(top)
	if not (P.active and top and top.TogglePause) then return false end
	local name = top:GetName()
	return name:find("^ScreenGameplay") ~= nil and not name:find("Replay") and not name:find("Net")
end

-- intro skip ----------------------------------------------------------------------------------------
-- Space skips a song's intro, as each game does it. osu! (and Til' Death / Rebirth): while there are
-- more than 3 seconds to the first note, to 3 seconds before it. Quaver: while the first note is 8
-- seconds or more away, to 3 seconds before it. ("3 seconds" are of play time, so more of the song
-- at a faster rate.) Space only skips then: after that it is a key like any other (a 7K layout may
-- use it).
local function skipTarget()
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then return nil end
	local first = steps:GetFirstSecond()
	local rate = getCurRateValue and getCurRateValue() or 1
	local now = GAMESTATE:GetSongPosition():GetMusicSeconds()
	local target = first - 3 * rate
	local ok
	if THEME:GetCurThemeName() == "VSRG Hub Quaver" then ok = first - now >= 8
	else ok = now < target - 0.5 * rate end -- (a skip of half a second isn't worth it)
	return ok and target or nil
end
local function skippable(top)
	if not (P.inPlay and inPausablePlay(top) and P.state == "playing") then return nil end
	if not (top and top.SetSongPosition) then return nil end
	local ok, t = pcall(skipTarget)
	return ok and t or nil
end
local function skip(top)
	local t = skippable(top)
	if not t then return end
	pcall(function() top:SetSongPosition(t, 0, true) end)
	MESSAGEMAN:Broadcast("TWSkipped")
end

local MENUS = { ScreenTitleMenu = true, ScreenSelectMusic = true, ScreenEvaluationNormal = true, ScreenSelectProfile = true }
-- A look's screen can take keys here before Etterna's screen sees them (Etterna gives every key to
-- the screen before its Lua callbacks, and a callback returning true doesn't stop that): it sets
-- TWSystemInput(event) -> true when it took the key. (TWSystemGateOK: the hook is in place.)
local ctrlOAt = -10 -- (when Ctrl+O was last pressed: see practiceGuard below)
local function input(event)
	if TWProfileIsOpen and TWProfileIsOpen() then return false end -- (the profile page has the keys)
	if event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_o" and INPUTFILTER:IsControlPressed() then
		ctrlOAt = GetTimeSinceStart()
	end
	-- (the osu! and Quaver looks' gate only while one of them is the look: after switching to Til' Death
	-- or Rebirth the old gate is still set, as their screens go away without their Off, and it would
	-- take Ctrl+O and the typing)
	if TWSystemInput and not THEME:GetCurThemeName():find("^VSRG Hub") then TWSystemInput = nil end
	if TWSystemInput then
		local ok, took = pcall(TWSystemInput, event)
		if ok and took then return true end
	end
	local b = event.DeviceInput.button
	local first = event.type == "InputEventType_FirstPress"
	local top = SCREENMAN:GetTopScreen()
	local name = top and top:GetName() or ""
	-- Ctrl+P on the menus (Etterna's own Ctrl+P, naming a new playlist, is left out)
	-- (Til Death's and Rebirth's song select keep Etterna's Ctrl+P, a new playlist: pausing is in their
	-- VSRG Hub menu, Ctrl+O)
	-- (the keys are VSRG Hub's keybinds, TWKeys: Pausing on / off, Pause, Skip the intro)
	local function key(id, default)
		if TWKeys and TWKeys.is then return TWKeys.is(event, id) end
		return default
	end
	local own = not THEME:GetCurThemeName():find("^VSRG Hub")
	local ctrlP = b == "DeviceButton_p" and INPUTFILTER:IsControlPressed() and not INPUTFILTER:IsShiftPressed()
	if MENUS[name] and key("pausetoggle", ctrlP) and not (own and name == "ScreenSelectMusic" and ctrlP) then
		if first then TWPauseToggle() end
		return true
	end
	-- (Etterna's Ctrl+P, a new playlist, stays out of the osu! and Quaver looks' menus, as before)
	if ctrlP and not own and MENUS[name] then return true end
	-- the scroll speed keys (the osu! and Quaver looks: TWScrollKey, Scripts/24 VSRG Hub scroll.lua),
	-- taken here, while playing (paused or not), so Etterna's F4 (undo offset changes) doesn't see
	-- them while they work
	if TWScrollKey and name:find("^ScreenGameplay") and THEME:GetCurThemeName():find("^VSRG Hub")
		and not (P.inPlay and P.state ~= "playing") then
		local ok, took = pcall(TWScrollKey, event, top)
		if ok and took then return true end
	end
	if not inPausablePlay(top) then return false end
	if P.state == "playing" then
		if key("skip", b == "DeviceButton_space") and skippable(top) then
			if first then skip(top) end
			return true -- (the key doesn't reach the notes while it skips)
		end
		if not key("pause", b == "DeviceButton_escape") then return false end
		if not P.pausable then return false end -- (on for a long intro only: Esc leaves, as usual)
		if first then pause(top) end
		return true -- the song never sees the pause key while pausing is on
	end
	-- paused (or counting down to go on): the keys and the mouse work the menu only
	if P.state ~= "paused" or not (first or event.type == "InputEventType_Repeat") then return true end
	if b == "DeviceButton_escape" or (first and key("pause", false)) then resume()
	elseif b == "DeviceButton_up" or b == "DeviceButton_mousewheel up" then cursor = (cursor - 2) % #ITEMS + 1; refresh()
	elseif b == "DeviceButton_down" or b == "DeviceButton_mousewheel down" then cursor = cursor % #ITEMS + 1; refresh()
	elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" or b == "DeviceButton_space" then choose(cursor)
	elseif b == "DeviceButton_left mouse button" and first then
		local i = itemAt(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY())
		if i then choose(i) end
	else
		local n = tonumber((b:match("^DeviceButton_(%d)$")))
		if n and ITEMS[n] then choose(n) end
	end
	return true
end

-- loads a picture into a sprite unless it already shows it (true when it was loaded now)
local function loadOnce(spr, path)
	if spr.twPath == path then return false end
	inset(spr:Load(path))
	spr.twPath = path
	return true
end
local function skinArt(id)
	if TW and TW.has and TW.has(id) then return TW.img(id) end
	return nil
end

local t = Def.ActorFrame {
	InitCommand = function(self) frame = self; self:visible(false); self:queuecommand("Hook") end,
	HookCommand = function(self)
		-- the callback goes on this overlay itself, so Esc and Ctrl+P are taken before the screen sees them
		local s = self
		while s:GetParent() do s = s:GetParent() end
		if s.AddInputCallback then s:AddInputCallback(input); TWSystemGateOK = true end
	end,
	SongChosenMessageCommand = function() applyLaneFlash(); pcall(prepare) end,
	StartFinalizedMessageCommand = function() applyLaneFlash(); pcall(prepare) end,
	ScreenChangedMessageCommand = function(self)
		applyLaneFlash()
		local top = SCREENMAN:GetTopScreen()
		local name = top and top:GetName() or ""
		-- Til Death and Rebirth results after a paused play: the pauses on their offset plot
		local marks = self:GetParent() and self:GetParent():GetChild("TWPauseMarks")
		if marks then
			marks:visible(false)
			if name:find("^ScreenEvaluation") and TWPausesForResults() and not THEME:GetCurThemeName():find("^VSRG Hub") then
				marks:sleep(0.15):queuecommand("Place")
			end
		end
		holdStop()
		local fresh = TWPausesForResults() ~= nil
		if name:find("^ScreenEvaluation") and fresh then markPaused() end
		restoreSync()
		P.state = "playing"
		setPausedFlag(false)
		if name:find("^ScreenGameplay") then
			-- a new play (or a retry): its own pauses
			P.count, P.times = 0, {}
			P.chart = nil
			pcall(function() P.chart = GAMESTATE:GetCurrentSteps():GetChartKey() end)
			P.inPlay = true
		else
			P.inPlay = false
		end
		if name == "ScreenSelectMusic" then
			P.active = false
			if ours then ours = false; pcall(function() GAMESTATE:SetPracticeMode(false) end) end
		end
		refresh()
	end,
	RefreshCommand = function(self)
		local show = P.state == "paused"
		self:visible(show or P.state == "countdown")
		local c = self:GetChildren()
		c.Dim:visible(show)
		-- the osu! skin's pause screen when it has one
		-- (the pictures are loaded once, when the play comes up, not when Esc is pressed: a skin's
		-- full-screen pause picture can take a moment to read, and the pause has to be instant)
		local overlay = skinArt("pause_overlay")
		c.Overlay:visible(show and overlay ~= nil)
		if overlay and loadOnce(c.Overlay, overlay) then
			local w, h = c.Overlay:GetWidth(), c.Overlay:GetHeight()
			if w > 0 and h > 0 then c.Overlay:zoom(math.max(SCREEN_WIDTH / w, SCREEN_HEIGHT / h)) end
		end
		local m = c.Menu:GetChildren()
		if not show then
			c.Menu:visible(false)
			if P.inPlay then
				for i, it in ipairs(ITEMS) do
					local art = skinArt(it.art)
					if art then loadOnce(m["Item" .. i]:GetChild("Art"), art) end
				end
			end
			return
		end
		c.Menu:visible(true)
		local at = P.times[#P.times] or 0
		local len = 0
		pcall(function() len = GAMESTATE:GetCurrentSteps():GetLastSecond() end)
		local function clock(sec) sec = math.max(0, sec); return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60)) end
		m.Count:settext((P.count == 1 and "Paused once" or ("Paused " .. P.count .. " times")) .. "   (at " .. clock(at) .. " of " .. clock(len) .. ")")
		-- (the skin's button art only when it has all three: a mix of art and plain buttons looks broken)
		local arts, allArt = {}, true
		for i, it in ipairs(ITEMS) do arts[i] = skinArt(it.art); if not arts[i] then allArt = false end end
		for i, it in ipairs(ITEMS) do
			local r = m["Item" .. i]
			local rc = r:GetChildren()
			local art = allArt and arts[i] or nil
			r:y(itemY(i))
			if art then
				loadOnce(rc.Art:visible(true), art)
				local h = rc.Art:GetHeight()
				if h and h > 0 then rc.Art:zoom((BH + GAP) / h) end
				hitW[i] = rc.Art:GetZoomedWidth()
				rc.Art:diffusealpha(i == cursor and 1 or 0.75)
				rc.Bg:visible(false); rc.Label:visible(false)
			else
				rc.Art:visible(false)
				hitW[i] = nil
				-- (the others darker but solid: nothing from the play shows through them)
				local c = color(it.colour)
				local k = i == cursor and 1 or 0.5
				rc.Bg:visible(true):zoomto(BW, BH):diffuse({ c[1] * k, c[2] * k, c[3] * k, 0.97 })
				rc.Label:visible(true):settext(i .. "  " .. it.label):diffuse(color(i == cursor and "#101014" or "#E4E4EA"))
			end
		end
	end,
	CountdownCommand = function(self)
		local n = self:GetChild("Count")
		n:stoptweening():visible(true):settext("3"):zoom(1.2):diffusealpha(1)
			:sleep(0.4):queuecommand("Two"):sleep(0.4):queuecommand("One"):sleep(0.4):queuecommand("Go")
	end,
	Def.Quad { Name = "Dim", InitCommand = function(self)
		-- (the osu! look's see-through grey; black elsewhere)
		if THEME:GetCurThemeName():find("^VSRG Hub osu!") or THEME:GetCurThemeName() == "VSRG Hub lazer" then self:FullScreen():diffuse({ 0.07, 0.07, 0.09, 0.74 }):diffusetopedge({ 0.12, 0.12, 0.15, 0.7 })
		else self:FullScreen():diffuse(color("#000000")):diffusealpha(0.72) end
	end },
	Def.Sprite { Name = "Overlay", InitCommand = function(self) self:Center():visible(false) end },
	Def.ActorFrame {
		Name = "Menu",
		LoadFont("Common Large") .. { InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 110 * SCREEN_HEIGHT / 480):zoom(0.7 * SCREEN_HEIGHT / 480):settext("Paused") end },
		LoadFont("Common Normal") .. { Name = "Count", InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 82 * SCREEN_HEIGHT / 480):zoom(0.55 * SCREEN_HEIGHT / 480):diffuse(color("#66DD66")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + 95 * SCREEN_HEIGHT / 480):zoom(0.4 * SCREEN_HEIGHT / 480):diffusealpha(0.7)
				:settext("Esc: continue    Up / Down and Enter, or click") end },
	},
	LoadFont("Common Large") .. {
		Name = "Count",
		InitCommand = function(self) self:visible(false):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):zoom(1.2 * SCREEN_HEIGHT / 480) end,
		TwoCommand = function(self) self:settext("2") end,
		OneCommand = function(self) self:settext("1") end,
		GoCommand = function(self)
			self:visible(false)
			if P.state ~= "countdown" then return end
			local top = SCREENMAN:GetTopScreen()
			if inPausablePlay(top) then holdStart(); pcall(function() top:TogglePause() end) end
			P.state = "playing"
			refresh()
		end,
	},
}
-- Etterna's practice screen never ends a song by itself (it waits for you to leave), and never fails
-- you: for a pausable play VSRG Hub tells it the notes ended (after the last note, as the normal
-- screen does, or when you fail with fail mode on), so it goes to results like a normal play.
local ender = Def.ActorFrame {
	InitCommand = function(self)
		local sent = false
		self:SetUpdateFunction(function()
			holdUpdate()
			local top = SCREENMAN:GetTopScreen()
			if not (P.inPlay and inPausablePlay(top)) or P.state ~= "playing" then sent = false return end
			if sent or GAMESTATE:IsPracticeMode() then return end -- (a real practice run keeps Etterna's way)
			local steps = GAMESTATE:GetCurrentSteps()
			if not steps then return end
			local now = GAMESTATE:GetSongPosition():GetMusicSeconds()
			local rate = getCurRateValue and getCurRateValue() or 1
			local done = now >= steps:GetLastSecond() + 0.36 * rate + 0.3
			if not done then
				pcall(function()
					local lm = top:GetLifeMeter(PLAYER_1)
					local fail = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():FailSetting()
					done = fail == "FailType_Immediate" and lm and lm:IsFailing()
				end)
			end
			if done then
				sent = true
				pcall(function() top:PostScreenMessage("SM_NotesEnded", 0) end)
			end
		end)
	end,
}

-- "Press Space to skip" while the intro can be skipped: the osu! skin's play-skip art at osu!'s
-- place (bottom right) when the look is osu!'s and the skin has it, otherwise a small bar
local skipPrompt = Def.ActorFrame {
	InitCommand = function(self)
		self:visible(false):diffusealpha(0)
		local shown = false
		self:SetUpdateFunction(function()
			local want = skippable(SCREENMAN:GetTopScreen()) ~= nil
			if want == shown then return end
			shown = want
			self:stoptweening()
			if want then self:playcommand("Look"); self:visible(true):linear(0.3):diffusealpha(1)
			else self:linear(0.3):diffusealpha(0) end
		end)
	end,
	LookCommand = function(self)
		local c = self:GetChildren()
		local art = TW and TW.has and THEME:GetCurThemeName() == "VSRG Hub osu!" and TW.has("play_skip") and TW.img("play_skip")
		c.Art:visible(art ~= nil and art ~= false)
		c.Bar:visible(not art)
		-- (the key may have been changed in Keybinds)
		c.Bar:GetChild("Label"):settext("Press " .. ((TWKeys and TWKeys.label and TWKeys.label("skip")) or "Space") .. " to skip")
		if art then
			inset(c.Art:Load(art))
			c.Art:zoom(SCREEN_HEIGHT / 768 * ((TW.hd and TW.hd("play_skip")) and 0.5 or 1))
		end
	end,
	Def.Sprite { Name = "Art", InitCommand = function(self) self:align(1, 1):xy(SCREEN_WIDTH, SCREEN_HEIGHT):visible(false) end },
	Def.ActorFrame {
		Name = "Bar",
		InitCommand = function(self) self:xy(SCREEN_WIDTH - 24 * SCREEN_HEIGHT / 480, SCREEN_HEIGHT - 40 * SCREEN_HEIGHT / 480) end,
		Def.Quad { InitCommand = function(self)
			self:align(1, 0.5):zoomto(150 * SCREEN_HEIGHT / 480, 26 * SCREEN_HEIGHT / 480)
			if THEME:GetCurThemeName() == "VSRG Hub osu!" or THEME:GetCurThemeName() == "VSRG Hub lazer" then self:diffuse({ 0.09, 0.09, 0.115, 0.72 }):diffusetopedge({ 0.15, 0.15, 0.185, 0.64 })
			else self:diffuse(color("0.05,0.05,0.07,0.72")) end
		end },
		Def.Quad { InitCommand = function(self)
			self:align(1, 0.5):x(0):zoomto(3 * SCREEN_HEIGHT / 480, 26 * SCREEN_HEIGHT / 480):diffuse(color("#FFFFFF")):diffusealpha(0.8)
		end },
		LoadFont("Common Normal") .. { Name = "Label", InitCommand = function(self)
			self:align(1, 0.5):x(-12 * SCREEN_HEIGHT / 480):zoom(0.5 * SCREEN_HEIGHT / 480):settext("Press Space to skip")
		end },
	},
}

local function findChild(actor, name, depth)
	if not actor or (depth or 0) > 7 then return nil end
	local ok, kids = pcall(function() return actor:GetChildren() end)
	if not ok or type(kids) ~= "table" then return nil end
	-- actors are Lua tables too; a name shared by several children gives a plain list of them
	local k = kids[name]
	if k then
		if k.GetName then return k end
		if k[1] then return k[1] end
	end
	for _, c in pairs(kids) do
		local list = (type(c) == "table" and not c.GetName) and c or { c }
		for _, a in ipairs(list) do
			local f = findChild(a, name, (depth or 0) + 1)
			if f then return f end
		end
	end
	return nil
end
local marks = Def.ActorFrame {
	Name = "TWPauseMarks",
	InitCommand = function(self) self:visible(false) end,
	PlaceCommand = function(self)
		local times = TWPausesForResults() or P.times
		local top = SCREENMAN:GetTopScreen()
		if not top or #times == 0 then return end
		local steps = GAMESTATE:GetCurrentSteps()
		local last = steps and steps:GetLastSecond() or 0
		local x0, y0, w, h
		pcall(function()
			local td = findChild(top, "OffsetPlot") -- Til Death: a 400 x 120 plot around its position
			if td then
				x0, y0, w, h = td:GetTrueX() - 200, td:GetTrueY() - 60, 400, 120
				return
			end
			local rb = findChild(top, "OffsetPlotFile") -- Rebirth: its background is the plot
			local bg = rb and rb:GetChild("BG")
			if bg then
				w, h = bg:GetZoomedWidth(), bg:GetZoomedHeight()
				x0, y0 = bg:GetTrueX(), bg:GetTrueY() - h / 2
			end
		end)
		local label = self:GetChild("Label")
		label:settext("Pauses: " .. #times)
		if not (x0 and last > 0) then
			label:xy(SCREEN_CENTER_X, 12):halign(0.5)
			self:GetChild("Lines"):visible(false)
			self:visible(true)
			return
		end
		label:xy(x0 + w - 4, y0 + 4):halign(1)
		local v, c = {}, { 0.35, 1, 0.45, 0.9 }
		for _, t in ipairs(times) do
			local x = x0 + math.max(0, math.min(1, t / last)) * w
			v[#v + 1] = { { x - 1, y0, 0 }, c }; v[#v + 1] = { { x + 1, y0, 0 }, c }
			v[#v + 1] = { { x + 1, y0 + h, 0 }, c }; v[#v + 1] = { { x - 1, y0 + h, 0 }, c }
		end
		self:GetChild("Lines"):visible(true):SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(v)
		self:visible(true)
	end,
	Def.ActorMultiVertex { Name = "Lines" },
	LoadFont("Common Normal") .. { Name = "Label", InitCommand = function(self)
		self:valign(0):zoom(0.45 * SCREEN_HEIGHT / 480):diffuse(color("#55FF77")) end },
}

local menu = t[3]
for i = 1, #ITEMS do
	menu[#menu + 1] = Def.ActorFrame {
		Name = "Item" .. i,
		InitCommand = function(self) self:x(SCREEN_CENTER_X) end,
		Def.Quad { Name = "Bg", InitCommand = function(self) self:valign(0) end },
		Def.Sprite { Name = "Art", InitCommand = function(self) self:y(BH / 2):visible(false) end },
		LoadFont("Common Normal") .. { Name = "Label", InitCommand = function(self)
			self:y(BH / 2):zoom(0.6 * SCREEN_HEIGHT / 480):diffuse(color("#101014")) end },
	}
end
-- Etterna's own Ctrl+O on song select turns its practice mode on or off; in every look Ctrl+O is
-- VSRG Hub's menu (practice mode is a row there, or the Practice mod). The looks take the key before
-- Etterna's screen does, but should one ever get through, the practice mode it flipped while Ctrl+O
-- is held goes straight back (and Etterna's "Practice Mode On" message with it).
local lastPractice = nil
local practiceGuard = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function()
			local top = SCREENMAN:GetTopScreen()
			if not (top and top:GetName() == "ScreenSelectMusic") then lastPractice = nil return end
			local ok, p = pcall(function() return GAMESTATE:IsPracticeMode() end)
			if not ok then return end
			local justCtrlO = GetTimeSinceStart() - ctrlOAt < 1 or (INPUTFILTER:IsControlPressed() and INPUTFILTER:IsBeingPressed("o"))
			if lastPractice ~= nil and p ~= lastPractice and justCtrlO then
				Trace("VSRG Hub: Etterna's Ctrl+O practice toggle undone")
				pcall(function() GAMESTATE:SetPracticeMode(lastPractice) end)
				MESSAGEMAN:Broadcast("HideSystemMessage")
				p = lastPractice
			end
			lastPractice = p
		end)
	end,
}

return Def.ActorFrame { marks, skipPrompt, t, ender, practiceGuard }
