-- Quaver's song select: the navigation bar, the map info strip with the search box and the Mode /
-- Group by / Sort by menus, the bottom button bar and the modifiers panel. The song list is the
-- music wheel (Graphics/MusicWheelItem Song NormalPart.lua), the leaderboard is in decorations.
local M, R = TW.M, TW.R
local white = color("#FFFFFF")

local function top() return SCREENMAN:GetTopScreen() end
local function wheel() local s = top(); return s and s:GetMusicWheel() end
local function po() return GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred") end

local panel = nil -- nil, "Mods" or "Search"
local search = ""
local function setPanel(name)
	panel = name
	-- (the left side's modifiers / map preview / profile keep the keyboard too, see showLeft)
	SCREENMAN:set_input_redirected(PLAYER_1, name ~= nil or TW.keepRedirect == true)
	MESSAGEMAN:Broadcast("TWPanel", { name = name })
end
local function startSong()
	-- (scrolled away from the picked map: back to it first)
	if TW.browsing and TW.syncToPick then
		TW.syncToPick(function() local s = top(); if s and s.SelectCurrent then s:SelectCurrent() end end)
		return
	end
	local s = top()
	if s and s.SelectCurrent then s:SelectCurrent() end
end
local function randomSong()
	local w = wheel()
	if not w then return end
	local songs = w:GetSongs()
	TW.browsing = false
	if songs and #songs > 0 then w:SelectSong(songs[math.random(1, #songs)]) end
end

local function fmtTime(s) return QV.clock(s) end

-- Group by / Sort by, as Quaver lists them, mapped to Etterna's sort orders (Etterna's pattern
-- types are added to Sort by)
local sortLabel = {
	Group = "Pack", Title = "Title", Artist = "Artist", Author = "Creator", Genre = "Genre", DateAdded = "Date Added",
	TopGrades = "Grade", Favorites = "Favourites", Ungrouped = "None", Overall = "Difficulty", Stream = "Stream",
	Jumpstream = "Jumpstream", Handstream = "Handstream", Stamina = "Stamina", JackSpeed = "Jackspeed",
	Chordjack = "Chordjack", Technical = "Technical", BPM = "BPM", Length = "Length"
}
local sortSorts = { "Artist", "Title", "Author", "DateAdded", "BPM", "Genre", "Length", "Overall", "TopGrades",
	"Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical" }
local function curSort() return ToEnumShortString(GAMESTATE:GetSortOrder() or "SortOrder_Group") end
local function setSort(name)
	local w = wheel()
	if w then w:ChangeSort("SortOrder_" .. name) end
	MESSAGEMAN:Broadcast("TWSortChanged")
end

-- the left side: Quaver swaps the leaderboard for the modifiers, the map preview or the profile
TW.qvPanel = "Leaderboard"
local function showLeft(name)
	if TW.qvPanel == name then name = "Leaderboard" end
	TW.qvPanel = name
	-- while the left side shows something else than the leaderboard VSRG Hub holds the keyboard, so
	-- Esc only closes it (Etterna would also leave song select); Enter and the arrows still work
	TW.keepRedirect = name ~= "Leaderboard"
	SCREENMAN:set_input_redirected(PLAYER_1, panel ~= nil or TW.keepRedirect or TW.optionsOpen == true)
	MESSAGEMAN:Broadcast("QVLeft", { name = name })
	if name == "ViewMap" then MESSAGEMAN:Broadcast("QVPreview") end
end

-- Quaver's modifiers, mapped to what Etterna can do; colours as Quaver gives them
local function rateIs(r) return math.abs(getCurRateValue() - r) < 0.001 end
local mods = {
	{ "MIRROR", "MR", TW.rgb(170, 170, 170), function() return po():Mirror() end, function(on) po():Mirror(on) end, true },
	-- Full LN and Inverse play a converted copy of the chart (its own MSD and scores)
	{ "FULL LN", "FLN", TW.rgb(225, 75, 120), function() return TW.lnMod == "FLN" end, function(on) if on or TW.lnMod == "FLN" then TW.setLnMod(on and "FLN" or nil) end end, true },
	{ "INVERSE", "INV", TW.rgb(225, 75, 120), function() return TW.lnMod == "INV" end, function(on) if on or TW.lnMod == "INV" then TW.setLnMod(on and "INV" or nil) end end, true },
	{ "AUTOPLAY", "AP", TW.rgb(43, 135, 210), function() return TW.autoplay == true end, function(on) TW.autoplay = on end },
	{ "NO FAIL", "NF", TW.rgb(43, 135, 210), function() return po():FailSetting() == "FailType_Off" end, function(on) po():FailSetting(on and "FailType_Off" or "FailType_Immediate") end },
	{ "HIDDEN", "HD", TW.rgb(230, 140, 60), function() return po():Hidden() > 0 end, function(on) po():Hidden(on and 1 or 0) end },
	{ "FADE IN", "FI", TW.rgb(230, 140, 60), function() return po():Sudden() > 0 end, function(on) po():Sudden(on and 1 or 0) end },
	{ "RANDOMIZE", "RND", TW.rgb(38, 170, 100), function() return po():Shuffle() end, function(on) po():Shuffle(on) end },
	-- Etterna's practice mode (29 VSRG Hub practice.lua): nothing is scored
	{ "PRACTICE", "PR", TW.rgb(120, 120, 200), function() return TW.practiceOn == true end, function(on) TW.setPractice(on) end },
}
local function modsText()
	local out = {}
	if not rateIs(1) then out[#out + 1] = getCurRateDisplayString(true) end
	for _, m in ipairs(mods) do if m[4]() then out[#out + 1] = m[2] end end
	return #out > 0 and table.concat(out, ", ") or "None"
end

-- the playlist being named in the Create Playlist dialog
local plName = ""

-- keyboard
local wheelMoving = false
local function input(event)
	-- Alt + wheel is the volume (osu!, Quaver), before anything else gets the wheel
	if TW.volumeInput(event) then return true end
	-- Etterna takes Ctrl+O as "practice mode" (when the wheel is settled) before VSRG Hub sees it;
	-- undo that whatever VSRG Hub then does with the key
	if not TWSystemGateOK and event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_o"
		and INPUTFILTER:IsControlPressed() then
		local w = wheel()
		if w and w:IsSettled() and not SCREENMAN:get_input_redirected(PLAYER_1) then
			GAMESTATE:SetPracticeMode(not GAMESTATE:IsPracticeMode())
			SCREENMAN:SystemMessage("Options") -- in place of Etterna's "Practice Mode On"
		end
	end
	if TW.hubScoreInput and TW.hubScoreInput(event) then return true end
	if TW.listInput(event) then return true end
	if TW.optionsInput(event) then return true end
	local b = event.DeviceInput.button
	-- an open Mode / Group by / Sort by list: Esc closes it, other keys do nothing behind it
	if QV.openDropdown then
		if event.type == "InputEventType_FirstPress" and b == "DeviceButton_escape" then
			QV.openDropdown = nil
			MESSAGEMAN:Broadcast("QVDropdown", { id = "" })
		end
		return not event.DeviceInput.is_mouse or b:find("mousewheel") ~= nil
	end
	if (b == "DeviceButton_mousewheel up" or b == "DeviceButton_mousewheel down") and not TW.altHeld() then
		-- (over the scoreboard: it scrolls, not the song list)
		if event.type == "InputEventType_FirstPress" and TW.boardScroll and TW.boardScroll(b == "DeviceButton_mousewheel up" and -1 or 1) then return true end
		local w = wheel()
		if not w or TW.optionsOpen or TW.list or (panel and panel ~= "Search") then return false end
		-- (as Quaver's list: the wheel scrolls it, the picked map staying picked until you click
		-- another: 29 VSRG Hub stable pick.lua)
		if event.type == "InputEventType_FirstPress" then
			wheelMoving = true
			TW.browse(b == "DeviceButton_mousewheel up" and -1 or 1)
		elseif wheelMoving then
			wheelMoving = false
			w:Move(0)
		end
		return false
	end
	-- The arrow keys move through the song list, as in osu! and Quaver, also in 7K where Etterna's
	-- own key map gives the arrows no menu job.
	local arrows = { ["DeviceButton_up"] = -1, ["DeviceButton_left"] = -1, ["DeviceButton_down"] = 1, ["DeviceButton_right"] = 1 }
	local gb = event.GameButton
	if arrows[b] and (not panel or panel == "Search") and (panel == "Search" or gb == nil or gb == "" or gb == "Invalid" or SCREENMAN:get_input_redirected(PLAYER_1)) then
		local w = wheel()
		if w then
			if event.type == "InputEventType_Release" then w:Move(0)
			elseif event.type == "InputEventType_FirstPress" then
				-- (scrolled away with the mouse wheel: the keys go on from the picked map)
				if TW.browsing then TW.syncToPick(function() w:Move(arrows[b]); w:Move(0) end) return true end
				w:Move(arrows[b])
			end
			return true
		end
	end
	if event.type == "InputEventType_Release" or event.DeviceInput.is_mouse then return false end
	if panel == "Search" then
		if b == "DeviceButton_escape" then
			search = ""; TW.searchSoon(""); setPanel(nil)
		elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" then
			-- as in Quaver, Enter in the search box plays the selected map (once the search has run:
			-- if it was still waiting, Enter runs it and the list shows its results first)
			local waited = TW.searchPending()
			TW.searchNow()
			setPanel(nil)
			MESSAGEMAN:Broadcast("TWSearch", { text = search, active = false })
			if not waited then startSong() end
			return true
		elseif b == "DeviceButton_backspace" then
			search = search:sub(1, -2); TW.searchSoon(search)
		elseif b == "DeviceButton_space" then
			search = search .. " "; TW.searchSoon(search)
		elseif event.char and event.char:match("[%w%p]") and not INPUTFILTER:IsControlPressed() then
			search = search .. event.char; TW.searchSoon(search)
		end
		MESSAGEMAN:Broadcast("TWSearch", { text = search, active = panel == "Search" })
		return true
	end
	if panel == "Playlist" then
		if b == "DeviceButton_escape" then setPanel(nil)
		elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" then MESSAGEMAN:Broadcast("QVCreatePlaylist")
		elseif b == "DeviceButton_backspace" then plName = plName:sub(1, -2)
		elseif b == "DeviceButton_space" then plName = plName .. " "
		elseif event.char and event.char:match("[%w%p]") and not INPUTFILTER:IsControlPressed() then plName = plName .. event.char end
		MESSAGEMAN:Broadcast("QVPlaylistName")
		return true
	end
	if panel == "MapMenu" then
		if b == "DeviceButton_escape" then setPanel(nil) end
		return true
	end
	if event.type ~= "InputEventType_FirstPress" then return false end
	-- as in Quaver, typing anywhere on song select goes into the search box
	if not panel and event.char and event.char:match("^[%w%p]$") and not TW.rateKey(event) and not INPUTFILTER:IsControlPressed()
		and not TW.altHeld() and not b:find("F%d") then
		search = event.char
		setPanel("Search"); TW.searchSoon(search)
		MESSAGEMAN:Broadcast("TWSearch", { text = search, active = true })
		return true
	end
	-- Enter plays the selected map, as in Quaver (Etterna does that itself unless VSRG Hub holds the
	-- keyboard, e.g. after a click on the song list or a menu)
	if not panel and not TW.dropOpen and not TW.optionsOpen and (b == "DeviceButton_enter" or b == "DeviceButton_KP enter")
		and (SCREENMAN:get_input_redirected(PLAYER_1) or TW.browsing) then
		startSong()
		return true
	end
	if b == "DeviceButton_escape" and TW.qvPanel ~= "Leaderboard" then showLeft("Leaderboard") return true end
	-- (VSRG Hub's shortcuts: their keys can be changed in Keybinds)
	if TW.key(event, "preview", b == "DeviceButton_tab") then TW.playFromPreview() return true end
	if TW.key(event, "mods", b == "DeviceButton_F1") then showLeft("Modifiers") return true end
	if TW.key(event, "beatmap", b == "DeviceButton_F3") then TW.openOptions() return true end
	-- random (Etterna takes F2 for itself before any screen sees it)
	if TW.key(event, "random", b == "DeviceButton_r" and INPUTFILTER:IsControlPressed() and not INPUTFILTER:IsShiftPressed()) then randomSong() return true end
	if TW.key(event, "options", b == "DeviceButton_o" and INPUTFILTER:IsControlPressed()) then
		TW.openOptions()
		return true
	end
	if TW.key(event, "keybinds", false) then TW.openKeybinds() return true end
	return false
end

-- Keys VSRG Hub must have before Etterna's song select (Etterna's screen sees every key before the
-- screen's Lua callbacks): an open Mode / Group by / Sort by list, the first letter typed (it starts
-- the search without moving the list or playing), Ctrl+O. VSRG Hub's system layer asks this first.
local function gate(event)
	local s = top()
	if not s or SCREENMAN:GetTopScreen() ~= s then return false end
	local b = event.DeviceInput.button
	local mouse = event.DeviceInput.is_mouse
	if mouse and not b:find("mousewheel") then return false end
	if TW.list or TW.optionsOpen then return false end
	if not panel and not QV.openDropdown and TW.rateInput(event) then return true end
	if QV.openDropdown and not TW.altHeld() then input(event) return true end
	-- (scrolled away from the picked map with the mouse wheel: Enter plays the picked one, and
	-- up / down go on from it, before Etterna's list takes them from its middle)
	if TW.browsing and not panel and not mouse and event.type == "InputEventType_FirstPress" then
		if b == "DeviceButton_enter" or b == "DeviceButton_KP enter" then startSong() return true end
		if b == "DeviceButton_up" or b == "DeviceButton_down" then
			local d = b == "DeviceButton_up" and -1 or 1
			TW.syncToPick(function() local w = wheel(); if w then w:Move(d); w:Move(0) end end)
			return true
		end
	end
	-- left / right go through the selected map set's difficulties, as in Quaver (28 VSRG Hub difficulties.lua)
	if (not panel or panel == "Search") and TW.diffKey(event, "horizontal") then return true end
	if mouse or event.type ~= "InputEventType_FirstPress" then return false end
	-- (Etterna's own Ctrl+O, practice mode, never gets through: the Quaver look has its own practice)
	local ctrlO = b == "DeviceButton_o" and INPUTFILTER:IsControlPressed() and not INPUTFILTER:IsShiftPressed()
	if TW.key(event, "options", ctrlO) then
		if not panel then TW.openOptions() end
		return true
	end
	if TW.key(event, "keybinds", false) then
		if not panel then TW.openKeybinds() end
		return true
	end
	-- Ctrl+G: a goal for the selected chart (28 VSRG Hub goals.lua)
	if not panel and TW.goalKey and TW.goalKey(event) then return true end
	if ctrlO then return true end
	if not panel and event.char and event.char:match("^[%w%p]$") and not TW.rateKey(event) and not INPUTFILTER:IsControlPressed()
		and not TW.altHeld() and not b:find("F%d") then
		input(event)
		return true
	end
	return false
end

local t = Def.ActorFrame {
	InitCommand = function(self) self:z(20) end,
	TW.mouse(),
	TW.pauseCatcher(),
	TW.lnModWatcher(),
	OnCommand = function(self)
		TW.restoreLnModSong(wheel())
		TW.keepRedirect = false
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		TW.endTabPractice()
		top():AddInputCallback(input)
		TWSystemInput = gate
		TW.syncNoteskin()
		if TW.collection and TW.applyCollection then self:sleep(0.05):queuecommand("Collection") end
		-- after a theme switch: the chart that was selected in the other look
		if TW.settings.resumeChart and TW.settings.resumeChart ~= "" then self:sleep(0.1):queuecommand("Resume") end
		-- back from a score's results: your rate again (Etterna showed them at the score's)
		TW.afterScoreView()
		-- from the main menu: the song that was playing there
		if TW.menuSongPending then
			local s = TW.menuSongPending
			TW.menuSongPending = nil
			local resuming = TW.settings.resumeChart and TW.settings.resumeChart ~= ""
			if GAMESTATE:GetCurrentSong() ~= s and not resuming then self:sleep(0.1):queuecommand("MenuSong") end
		end
		-- "Watch replay" on the results: started once song select is up again
		if TW.pendingReplay then self:sleep(0.4):queuecommand("PendingReplay") end
		-- back from a replay: Etterna puts your own rate back as the replay's screen goes away, after
		-- song select has shown the replay's rate
		if TW.replayStarted then TW.replayStarted = false; self:sleep(0.3):queuecommand("RateBack") end
	end,
	ResumeCommand = function() TW.restoreSelection(wheel()) end,
	MenuSongCommand = function(self)
		local s = TW.menu and TW.menu.song
		local w = wheel()
		if s and w then pcall(function() w:SelectSong(s) end) end
	end,
	PendingReplayCommand = function() TW.startPendingReplay() end,
	RateBackCommand = function() TW.afterReplay() end,
	CollectionCommand = function(self) if TW.collection then TW.applyCollection(TW.collection) end end,
	OffCommand = function(self)
		if TWSystemInput == gate then TWSystemInput = nil end
		if panel then setPanel(nil) end
		TW.closeOptions()
		TW.keepRedirect = false
		SCREENMAN:set_input_redirected(PLAYER_1, false)
	end,
	CodeMessageCommand = function(self, params)
		-- (NextScore / PrevScore: Etterna's 0.1x steps, as in the osu! look)
		if params.Name == "NextRate" or params.Name == "PrevRate" or params.Name == "NextScore" or params.Name == "PrevScore" then
			ChangeMusicRate(nil, params)
			MESSAGEMAN:Broadcast("CurrentRateChanged")
		end
	end,
}

t[#t + 1] = QV.navbar()

-- the map info strip
local strip = Def.ActorFrame {
	InitCommand = function(self) self:y(M(42)) end,
	CurrentSongChangedMessageCommand = function(self) if not TW.browsingSkip() then self:queuecommand("Info") end end,
	CurrentStepsChangedMessageCommand = function(self) if not TW.browsingSkip() then self:queuecommand("Info") end end,
	CurrentRateChangedMessageCommand = function(self) self:queuecommand("Info") end,
	TWModsChangedMessageCommand = function(self) self:queuecommand("Info") end,
	OnCommand = function(self) self:queuecommand("Info") end,
	InfoCommand = function(self)
		local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
		local c = self:GetChildren()
		if not song then
			c.Title:settext(""); c.Diff:settext("")
			for i = 1, 6 do c["K" .. i]:settext(""); c["V" .. i]:settext("") end
			return
		end
		local rate = getCurRateValue()
		QV.fit(c.Title, song:GetDisplayArtist() .. " - " .. song:GetDisplayMainTitle(), M(440))
		QV.fit(c.Diff, steps and ("[" .. TW.diffName(steps) .. "]") or "", M(440))
		local bpms = song:GetDisplayBpms()
		local bpm = math.abs(bpms[1] - bpms[2]) < 0.5 and string.format("%d", bpms[1] * rate + 0.5)
			or string.format("%d-%d", bpms[1] * rate + 0.5, bpms[2] * rate + 0.5)
		local rv = steps and steps:GetRadarValues(PLAYER_1)
		local function radar(k) return rv and rv:GetValue(k) or 0 end
		local len = (steps and steps:GetLengthSeconds() or song:MusicLengthSeconds()) / rate
		local notes, holds = radar("RadarCategory_Notes"), radar("RadarCategory_Holds")
		local nps = len > 0 and (notes / len) or 0
		local vals = {
			{ "Mode:", TW.keys(steps) .. "K" }, { "Length:", fmtTime(len) }, { "BPM:", bpm },
			{ "LNs:", string.format("%d%%", notes > 0 and math.floor(holds / notes * 100 + 0.5) or 0) },
			{ "NPS:", string.format("%.2f", nps) }, { "Mods:", modsText() },
		}
		local x = M(19)
		for i, v in ipairs(vals) do
			local k, val = c["K" .. i], c["V" .. i]
			k:settext(v[1]):x(x)
			x = x + k:GetZoomedWidth() + M(5)
			val:settext(v[2]):x(x)
			x = x + val:GetZoomedWidth() + M(19)
		end
	end,
	Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, M(66)):diffuse(TW.rgb(8, 8, 10)):diffusealpha(0.97) end },
	QV.t(M(12.5), true, function(self) self:align(0, 0.5):xy(M(19), M(14)) end) .. { Name = "Title" },
	QV.t(M(12.5), true, function(self) self:align(0, 0.5):xy(M(19), M(35)) end) .. { Name = "Diff" },
}
for i = 1, 6 do
	strip[#strip + 1] = QV.t(M(12.5), true, function(self) self:align(0, 0.5):y(M(56)) end) .. { Name = "K" .. i }
	strip[#strip + 1] = QV.t(M(12.5), true, function(self) self:align(0, 0.5):y(M(56)):diffuse(QV.yellow) end) .. { Name = "V" .. i }
end
-- "N MAPS FOUND"
strip[#strip + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(R(474), M(33)) end,
	OnCommand = function(self) self:queuecommand("Count") end,
	TWSortChangedMessageCommand = function(self) self:queuecommand("Count") end,
	TWCollectionChangedMessageCommand = function(self) self:queuecommand("Count") end,
	TWSearchMessageCommand = function(self) self:queuecommand("Count") end,
	TWSearchResultsMessageCommand = function(self) self:queuecommand("Count") end,
	CountCommand = function(self)
		local w = wheel()
		local n = 0
		pcall(function() n = #w:GetSongs() end)
		local c = self:GetChildren()
		c.N:settext(tostring(n))
		c.L:x(c.N:GetZoomedWidth() + M(5))
	end,
	QV.t(M(13), true, function(self) self:align(0, 0.5):diffuse(TW.rgb(64, 195, 255)) end) .. { Name = "N" },
	QV.t(M(13), true, function(self) self:align(0, 0.5):settext("SONGS FOUND") end) .. { Name = "L" },
}
-- search box
strip[#strip + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(R(612), M(33)) end,
	Def.Quad { InitCommand = function(self) self:align(0, 0.5):zoomto(M(212), M(27)):diffuse(TW.rgb(23, 23, 23)) end },
	QV.t(M(12.5), false, function(self) self:align(0, 0.5):x(M(9)):maxwidth(M(170) / self:GetZoom()) end) .. {
		OnCommand = function(self) self:playcommand("TWSearch", { text = "", active = false }) end,
		TWSearchMessageCommand = function(self, p)
			if p.text ~= "" then QV.fit(self, p.text .. (p.active and "_" or ""), M(170)):diffuse(white)
			elseif p.active then self:settext("_"):diffuse(white)
			else self:settext("Type to search..."):diffuse(QV.grey) end
		end
	},
	-- magnifier
	QV.ring(M(5), M(1.8), white) .. { InitCommand = function(self) self:xy(M(196), -M(2)) end },
	Def.Quad { InitCommand = function(self) self:xy(M(201), M(4)):zoomto(M(6), M(2)):rotationz(45) end },
	TW.button(M(212), M(27), function() setPanel("Search"); MESSAGEMAN:Broadcast("TWSearch", { text = search, active = true }) end) ..
		{ InitCommand = function(self) self:align(0, 0.5):zoomto(M(212), M(27)):diffusealpha(0) end },
}
-- Mode / Group by / Sort by, Quaver's drop-downs
strip[#strip + 1] = QV.dropdown {
	label = "MODE:", x = R(907), y = M(33), w = M(89), colour = TW.rgb(75, 249, 55),
	items = function() return { { label = "4 Keys", value = "dance" }, { label = "7 Keys", value = "kb7" } } end,
	current = function() return TW.gameName() end,
	text = function()
		local ok, g = pcall(function() return GAMESTATE:GetCurrentStyle():ColumnsPerPlayer() end)
		return (ok and g or 4) .. " Keys"
	end,
	onPick = function(v) TW.switchGame(v) end,
}
strip[#strip + 1] = QV.dropdown {
	label = "GROUP BY:", x = R(1105), y = M(33), w = M(92), colour = TW.rgb(6, 202, 250),
	items = function() return { { label = "None", value = "Ungrouped" }, { label = "Pack", value = "Group" },
		{ label = "Playlists", value = "Playlists" }, { label = "Pattern", value = "Patterns" },
		{ label = "Favourites", value = "Favorites" } } end,
	current = function() return TW.collection and (TW.collection.pattern and "Patterns" or "Playlists") or curSort() end,
	text = function()
		if TW.collection then return TW.collection.pattern and "Pattern" or "Playlists" end
		local c = curSort()
		if c == "Group" then return "Pack" elseif c == "Favorites" then return "Favourites" end
		return "None"
	end,
	onPick = function(v)
		if v == "Playlists" then TW.openCollections("Playlists") return end
		if v == "Patterns" then TW.openPatterns("Group by pattern") return end
		if TW.collection then TW.applyCollection(nil) end
		setSort(v)
	end,
}
strip[#strip + 1] = QV.dropdown {
	label = "SORT BY:", x = R(1294), y = M(33), w = M(140), colour = QV.yellow,
	items = function()
		local out = {}
		for _, v in ipairs(sortSorts) do out[#out + 1] = { label = sortLabel[v], value = v } end
		return out
	end,
	current = function() return curSort() end,
	-- (grouped by pack, the maps in each pack are in title order)
	text = function() local c = curSort(); for _, v in ipairs(sortSorts) do if v == c then return sortLabel[v] end end return c == "Group" and "Title" or "None" end,
	onPick = setSort,
}
t[#t + 1] = strip
-- the search runs once you stop typing (28 VSRG Hub search.lua)
t[#t + 1] = TW.searchRunner()
-- the selected map set's difficulties, opened up under its row as in Quaver
t[#t + 1] = TW.diffRows {
	look = "quaver", browse = true, x = function() return TW.R(556) - M(38) end, y = function() return M(441) + M(32) end,
	centre = function() return M(441) end,
	unit = M(73.6), indent = M(24), rowH = M(46), step = M(50), maxActors = 20, fs = 0.85,
	-- (under the top bar and over the bottom bar the rows fade out)
	fade = function(y) return math.max(0, math.min(1, (y - M(70)) / M(40), (SCREEN_HEIGHT - M(50) - y) / M(30))) end,
	msdColour = function(v) return QV.diffColour(v) end,
	gradeText = function(g, b)
		local r = (b and b.pct and not b.failed) and QV.accGrade(b.pct) or QV.grade(g)
		if b and b.failed then r = "F" end
		return QV.gradeLetter[r] or r, QV.gradeColour[r] or TW.RankColour[r] or color("#FFFFFF")
	end,
}

-- the bottom bar, as Quaver's (Etterna has no editor, so no EDIT)
t[#t + 1] = QV.bottombar(
	{ { "< BACK", function() if TW.qvPanel ~= "Leaderboard" then showLeft("Leaderboard") else top():Cancel() end end, nil, 95 },
	  { "OPTIONS", function() TW.toggleOptions() end, nil, 120 },
	  { "MODIFIERS", function() showLeft("Modifiers") end, nil, 125 },
	  { "VIEW MAP", function() showLeft("ViewMap") end, nil, 112 },
	  { "PROFILE", function() if TWOpenProfile then TWOpenProfile() else showLeft("Profile") end end, nil, 110 } },
	{ { "+ CREATE PLAYLIST", function() plName = ""; setPanel("Playlist"); MESSAGEMAN:Broadcast("QVPlaylistName") end },
	  { "RANDOM", randomSong }, { "> PLAY", startSong } }
)
-- the active playlist / collection, over the bar
t[#t + 1] = QV.t(M(12), true, function(self) self:align(1, 1):xy(SCREEN_WIDTH - M(22), SCREEN_HEIGHT - M(46)):diffuse(QV.cyan) end) .. {
	OnCommand = function(self) self:playcommand("TWCollectionChanged") end,
	TWCollectionChangedMessageCommand = function(self)
		QV.fit(self, TW.collection and ((TW.collection.pattern and "Pattern: " or (TW.collection.playlist and "Playlist: " or "Collection: ")) .. TW.collection.name) or "", M(500))
	end
}

-- left panels ---------------------------------------------------------------------------------
local X0, W = M(37), M(427)
local function leftPanel(name, title, sub)
	return Def.ActorFrame {
		Name = name,
		InitCommand = function(self) self:visible(false) end,
		QVLeftMessageCommand = function(self, p)
			self:visible(p.name == name)
			if p.name == name then self:playcommand("Refresh") end
		end,
		QV.t(M(19), true, function(self) self:align(0, 0.5):xy(X0, M(130)):settext(title) end),
		QV.t(M(10.5), true, function(self) self:align(1, 0.5):xy(X0 + W, M(132)):diffuse(QV.grey):settext(sub or "") end),
		Def.Quad { InitCommand = function(self) self:align(0, 0):xy(X0 - 1, M(146) - 1):zoomto(W + 2, M(610) + 2):diffuse(TW.rgb(5, 155, 172)) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):xy(X0, M(146)):zoomto(W, M(610)):diffuse(TW.rgb(36, 36, 36)) end },
	}
end

-- MODIFIERS
local mp = leftPanel("Modifiers", "MODIFIERS", "CUSTOMIZE GAMEPLAY TO YOUR HEART'S DESIRE")
local function section(y, colour, title, sub)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(X0, y) end,
		Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(W, M(46)):diffuse(TW.rgb(27, 27, 27)) end },
		TW.circle(M(7), colour) .. { InitCommand = function(self) self:xy(M(16), M(23)) end },
		QV.t(M(13), true, function(self) self:align(0, 0.5):xy(M(31), M(15)):settext(title):diffuse(colour) end),
		QV.t(M(10), true, function(self) self:align(0, 0.5):xy(M(31), M(32)):settext(sub) end),
	}
end
local function modRow(y, tag, name, colour, control)
	local f = Def.ActorFrame {
		InitCommand = function(self) self:xy(X0, y):z(2) end,
		Def.Quad { Name = "Hover", InitCommand = function(self) self:align(0, 0.5):zoomto(W, M(32)):diffuse(color("#FFFFFF")):diffusealpha(0) end },
		-- the outlined tag
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):x(M(11)):zoomto(M(31), M(15)):diffuse(colour) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):x(M(12)):zoomto(M(29), M(13)):diffuse(TW.rgb(36, 36, 36)) end },
		QV.t(M(8), true, function(self) self:align(0.5, 0.5):x(M(26.5)):settext(tag):diffuse(colour) end),
		QV.t(M(13), true, function(self) self:align(0, 0.5):x(M(53)):settext(name):diffuse(colour) end),
	}
	f[#f + 1] = control
	return f
end
mp[#mp + 1] = section(M(147), TW.rgb(12, 192, 85), "RANKED", "THESE MODS KEEP YOUR SCORES COUNTING")
-- speed (the music rate)
mp[#mp + 1] = modRow(M(209), "1.0x", "SPEED", TW.rgb(215, 97, 235), Def.ActorFrame {
	InitCommand = function(self) self:x(W - M(60)) end,
	QV.t(M(13), true, function(self) self:align(0.5, 0.5):diffuse(TW.rgb(215, 97, 235)) end) .. {
		RefreshCommand = function(self) self:settext(getCurRateDisplayString(true)) end,
		CurrentRateChangedMessageCommand = function(self) self:settext(getCurRateDisplayString(true)) end,
	},
	QV.t(M(16), true, function(self) self:align(0.5, 0.5):x(-M(42)):settext("<") end),
	QV.t(M(16), true, function(self) self:align(0.5, 0.5):x(M(42)):settext(">") end),
	TW.button(M(26), M(26), function() ChangeMusicRate(nil, { Name = "NextRate" }); MESSAGEMAN:Broadcast("TWModsChanged") end) ..
		{ InitCommand = function(self) self:x(-M(42)):zoomto(M(26), M(26)):diffusealpha(0) end },
	TW.button(M(26), M(26), function() ChangeMusicRate(nil, { Name = "PrevRate" }); MESSAGEMAN:Broadcast("TWModsChanged") end) ..
		{ InitCommand = function(self) self:x(M(42)):zoomto(M(26), M(26)):diffusealpha(0) end },
})
local y = M(241)
local function toggleRow(m)
	return modRow(y, m[2], m[1], m[3], Def.ActorFrame {
		InitCommand = function(self) self:x(W - M(36)) end,
		RefreshCommand = function(self) self:GetChild("Sw"):playcommand("Refresh") end,
		TWModsChangedMessageCommand = function(self) self:GetChild("Sw"):playcommand("Refresh") end,
		QV.switch(m[4]) .. { Name = "Sw" },
		TW.button(M(60), M(26), function(self)
			m[5](not m[4]())
			MESSAGEMAN:Broadcast("TWModsChanged")
		end) .. { InitCommand = function(self) self:zoomto(M(60), M(26)):diffusealpha(0) end },
	})
end
for _, m in ipairs(mods) do
	if m[6] then mp[#mp + 1] = toggleRow(m); y = y + M(32) end
end
y = y + M(4)
mp[#mp + 1] = section(y, QV.yellow, "UNRANKED", "SCORES MAY SAVE, BUT WON'T COUNT THE SAME")
y = y + M(62)
for _, m in ipairs(mods) do
	if not m[6] then mp[#mp + 1] = toggleRow(m); y = y + M(32) end
end
mp[#mp + 1] = QV.pill("RESET MODS", TW.rgb(244, 100, 99), M(166), M(26), function()
	for _, m in ipairs(mods) do if m[4]() then m[5](false) end end
	TW.resetRate()
	MESSAGEMAN:Broadcast("TWModsChanged")
end, function(self) self:xy(X0 + M(92), M(727)):z(2) end)
mp[#mp + 1] = QV.pill("CLOSE PANEL", TW.rgb(127, 127, 127), M(166), M(26), function() showLeft("Leaderboard") end,
	function(self) self:xy(X0 + W - M(92), M(727)):z(2) end)
t[#t + 1] = mp

-- VIEW MAP: the chart scrolling with the song's preview, and its density beside it
local vm = leftPanel("ViewMap", "VIEW MAP", "CLICK THE GRAPH TO JUMP  -  TAB TO PLAY IT")
vm[#vm + 1] = TW.mapPreview {
	x = X0, y = M(146), w = W, h = M(610), openMessage = "QVPreview",
	isOpen = function() return TW.qvPanel == "ViewMap" end,
	text = QV.t, colour = QV.diffColour,
}
t[#t + 1] = vm

-- PROFILE
local pf = leftPanel("Profile", "PROFILE", "")
pf[#pf + 1] = QV.t(M(14), true, function(self) self:align(0, 0.5):xy(X0 + M(190), M(130)):settext("SELECT:") end)
pf[#pf + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(X0 + M(258), M(130)):zoomto(M(120), M(24)):diffuse(TW.rgb(25, 25, 25)) end }
pf[#pf + 1] = QV.t(M(13.5), true, function(self) self:align(0, 0.5):xy(X0 + M(266), M(130)):settext("Local"):diffuse(TW.rgb(6, 202, 250)) end)
pf[#pf + 1] = Def.Sprite { InitCommand = function(self)
	local _, av = TW.profile()
	self:Load(av):align(0, 0):xy(X0 + M(12), M(162)):zoomto(M(38), M(38))
end }
pf[#pf + 1] = QV.t(M(14), true, function(self) self:align(0, 0.5):xy(X0 + M(60), M(174)) end) .. {
	RefreshCommand = function(self) local p = TW.profile(); QV.fit(self, p and p:GetDisplayName() or "Guest", M(300)) end }
pf[#pf + 1] = QV.t(M(11), true, function(self) self:align(0, 0.5):xy(X0 + M(60), M(193)):diffuse(QV.blue):settext("Local Profile") end)
local rows = TW.profileRows()
local RH2 = M(510) / #rows
for i, r in ipairs(rows) do
	pf[#pf + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(X0, M(244) + (i - 1) * RH2) end,
		Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(W, RH2 - 1):diffuse(i % 2 == 1 and TW.rgb(42, 42, 42) or TW.rgb(36, 36, 36)) end },
		QV.t(M(13), true, function(self) self:align(0, 0.5):xy(M(12), RH2 / 2):settext(r[1]) end),
		QV.t(M(13), true, function(self) self:align(1, 0.5):xy(W - M(12), RH2 / 2) end) .. {
			RefreshCommand = function(self)
				local p = TW.profile()
				local ok, v = pcall(r[2], p)
				self:settext(ok and v or "-")
			end
		},
	}
end
t[#t + 1] = pf

-- CREATE PLAYLIST: names a new Etterna playlist and puts the selected chart in it
local DW, DH = M(436), M(258)
local dlg = QV.dialog("PlaylistDialog", "CREATE NEW PLAYLIST", DW, DH)
dlg.TWPanelMessageCommand = function(self, p) self:visible(p.name == "Playlist") end
dlg.QVCreatePlaylistMessageCommand = function(self)
	if TW.createPlaylist(plName) then setPanel(nil) end
end
local body = dlg[#dlg]
body[#body + 1] = Def.Sprite {
	TWPanelMessageCommand = function(self, p)
		if p.name ~= "Playlist" then return end
		local s = GAMESTATE:GetCurrentSong()
		local b = s and ((s:GetBannerPath() ~= "" and s:GetBannerPath() ~= s:GetBackgroundPath()) and s:GetBannerPath() or TW.thumbPath(s))
		if b and b ~= "" then self:LoadBackground(b):align(0, 0):scaletoclipped(DW, M(84)):visible(true) else self:visible(false) end
	end
}
body[#body + 1] = QV.t(M(13), true, function(self) self:align(0, 0.5):xy(M(19), M(100)):settext("Name") end)
body[#body + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(M(19), M(111)):zoomto(DW - M(38), M(28)):diffuse(TW.rgb(54, 54, 54)) end }
body[#body + 1] = QV.t(M(12), false, function(self) self:align(0, 0.5):xy(M(27), M(125)) end) .. {
	QVPlaylistNameMessageCommand = function(self)
		if plName == "" then self:settext("What would you like your playlist to be called?"):diffuse(QV.grey)
		else QV.fit(self, plName .. "_", DW - M(54)):diffuse(color("#FFFFFF")) end
	end
}
body[#body + 1] = QV.t(M(11), false, function(self) self:align(0, 0.5):xy(M(19), M(160)):diffuse(QV.grey)
	:settext("The selected chart goes in it. Pick it later under Group by > Playlists.") end)
body[#body + 1] = QV.pill("CREATE", TW.rgb(25, 170, 100), M(146), M(26), function() MESSAGEMAN:Broadcast("QVCreatePlaylist") end,
	function(self) self:xy(DW / 2 - M(80), M(226)) end)
body[#body + 1] = QV.pill("CANCEL", TW.rgb(244, 100, 99), M(146), M(26), function() setPanel(nil) end,
	function(self) self:xy(DW / 2 + M(80), M(226)) end)
t[#t + 1] = dlg

-- right click on a map: Quaver's context menu (play, favourite, playlists, view map)
local MW, MH = M(300), M(330)
local mm = QV.dialog("MapMenu", "MAP OPTIONS", MW, MH)
mm.TWPanelMessageCommand = function(self, p)
	self:visible(p.name == "MapMenu")
	-- (a right click moves the wheel first: name the map once it has)
	if p.name == "MapMenu" then self:stoptweening():sleep(0.05):queuecommand("Refresh") end
end
mm.QVMapMenuMessageCommand = function() setPanel("MapMenu") end
local mbody = mm[#mm]
mbody[#mbody + 1] = QV.t(M(13), true, function(self) self:align(0.5, 0.5):xy(MW / 2, M(22)) end) .. {
	RefreshCommand = function(self)
		local s = GAMESTATE:GetCurrentSong()
		QV.fit(self, s and (s:GetDisplayArtist() .. " - " .. s:GetDisplayMainTitle()) or "", MW - M(24))
	end }
local items = {
	{ "PLAY", TW.rgb(25, 170, 100), function() setPanel(nil); startSong() end },
	{ "FAVOURITE", TW.rgb(230, 160, 40), function()
		local s = top(); if s and s.ToggleCurrentFavorite then s:ToggleCurrentFavorite() end
		MESSAGEMAN:Broadcast("FavoritesUpdated"); setPanel(nil)
	end, function()
		local s = GAMESTATE:GetCurrentSong()
		return (s and s:IsFavorited()) and "REMOVE FROM FAVOURITES" or "ADD TO FAVOURITES"
	end },
	{ "ADD TO PLAYLIST", TW.rgb(12, 160, 210), function()
		local pl = SONGMAN:GetActivePlaylist()
		if not pl or (pl:GetName() or "") == "" then
			SCREENMAN:SystemMessage("No playlist yet: create one first")
			return
		end
		local s = top(); if s and s.AddCurrentChartToActivePlaylist then s:AddCurrentChartToActivePlaylist() end
		SCREENMAN:SystemMessage("Added to " .. pl:GetName())
		setPanel(nil)
	end, function()
		local pl = SONGMAN:GetActivePlaylist()
		local n = pl and pl:GetName() or ""
		return n ~= "" and ("ADD TO \"" .. n:upper() .. "\"") or "ADD TO PLAYLIST"
	end },
	{ "CREATE NEW PLAYLIST", TW.rgb(130, 90, 210), function() plName = ""; setPanel("Playlist"); MESSAGEMAN:Broadcast("QVPlaylistName") end },
	{ "VIEW MAP", TW.rgb(90, 90, 110), function() setPanel(nil); showLeft("ViewMap") end },
	{ "CANCEL", TW.rgb(244, 100, 99), function() setPanel(nil) end },
}
for i, it in ipairs(items) do
	mbody[#mbody + 1] = QV.pill(it[1], it[2], MW - M(40), M(30), it[3], function(self) self:xy(MW / 2, M(36) + i * M(46)) end) .. {
		RefreshCommand = function(self)
			if it[4] then local l = self:GetChild("Label"); QV.fit(l, it[4](), MW - M(70)) end
		end }
end
t[#t + 1] = mm

t[#t + 1] = QV.optionsPanel()
t[#t + 1] = QV.windowsDialog()
t[#t + 1] = TW.listPanel { notes = true }
t[#t + 1] = TW.hubScorePanel()
t[#t + 1] = TW.textureKeeper()
return t
