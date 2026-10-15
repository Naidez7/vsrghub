-- osu!'s song select, bottom: the skin's songselect-bottom bar with back / mode / mods / random /
-- options, the player card in the middle and the cookie to start the song. Plus osu!'s mod
-- select (F1), beatmap options (F3 or the options button) and search (click the search bar).
TW.useInterfaceSkin()
local M, R = TW.M, TW.R
local U = TW.U
local white = color("#FFFFFF")

local function top() return SCREENMAN:GetTopScreen() end
local function wheel() local s = top(); return s and s:GetMusicWheel() end
local function po() return GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred") end
local function gameName() return GAMESTATE:GetCurrentGame():GetName() end

-- which panel is open: nil, "Mods", "Options" or "Search"
local panel = nil
local search = ""
local function setPanel(name)
	panel = name
	SCREENMAN:set_input_redirected(PLAYER_1, name ~= nil)
	MESSAGEMAN:Broadcast("TWPanel", { name = name })
end

local function startSong()
	-- (osu! stable look scrolled away from the picked song: back to it first)
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
	if songs and #songs > 0 then w:SelectSong(songs[math.random(1, #songs)]) end
end

-- osu! mods mapped to what Etterna can do
local function rateIs(r) return math.abs(getCurRateValue() - r) < 0.001 end
local function setRate(r)
	GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(r)
	GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(r)
	GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(r)
	MESSAGEMAN:Broadcast("CurrentRateChanged")
end
local mods = {
	{ row = 1, id = "mod_nofail", short = "NF", name = "No Fail", desc = "You can't fail, no matter what.", col = "reduce", get = function() return po():FailSetting() == "FailType_Off" end,
	  set = function(on) po():FailSetting(on and "FailType_Off" or "FailType_Immediate") end },
	{ row = 1, id = "mod_halftime", short = "HT", name = "Half Time", desc = "Less zoom... at 0.75x the speed.", col = "reduce", get = function() return rateIs(0.75) end, set = function(on) setRate(on and 0.75 or 1) end },
	{ row = 2, id = "mod_doubletime", short = "DT", name = "Double Time", desc = "Zoooooooooom... at 1.5x the speed.", col = "increase", get = function() return rateIs(1.5) end, set = function(on) setRate(on and 1.5 or 1) end },
	{ row = 2, id = "mod_hidden", short = "HD", name = "Hidden", desc = "Notes fade out before you hit them.", col = "increase", get = function() return po():Hidden() > 0 end, set = function(on) po():Hidden(on and 1 or 0) end },
	{ row = 2, id = "mod_fadein", short = "FI", name = "Fade In", desc = "Notes appear out of nowhere.", col = "increase", get = function() return po():Sudden() > 0 end, set = function(on) po():Sudden(on and 1 or 0) end },
	{ row = 3, id = "mod_mirror", short = "MR", name = "Mirror", desc = "Notes are flipped across the columns.", col = "convert", get = function() return po():Mirror() end, set = function(on) po():Mirror(on) end },
	{ row = 3, id = "mod_random", short = "RD", name = "Random", desc = "Shuffles the columns.", col = "convert", get = function() return po():Shuffle() end, set = function(on) po():Shuffle(on) end },
	{ row = 3, id = "mod_autoplay", short = "AT", name = "Autoplay", desc = "Watch a perfect automated play.", col = "auto", get = function() return TW.autoplay == true end, set = function(on) TW.autoplay = on end },
	-- osu!lazer's Invert and Quaver's Full LN (a converted copy of the chart; see 26 VSRG Hub lnmods.lua)
	{ row = 3, id = "mod_invert", short = "IN", name = "Invert", desc = "Hold the keys. To the beat.", col = "convert", get = function() return TW.lnMod == "INV" end, set = function(on) if on or TW.lnMod == "INV" then TW.setLnMod(on and "INV" or nil) end end },
	-- Etterna's practice mode (29 VSRG Hub practice.lua)
	{ row = 3, id = "mod_practice", short = "PR", name = "Practice", desc = "Etterna's practice: jump around and loop parts.", col = "auto", get = function() return TW.practiceOn == true end, set = function(on) TW.setPractice(on) end },
	{ row = 3, id = "mod_fln", short = "FLN", name = "Full LN", desc = "Every note becomes a long note.", col = "convert", get = function() return TW.lnMod == "FLN" end, set = function(on) if on or TW.lnMod == "FLN" then TW.setLnMod(on and "FLN" or nil) end end },
}

-- keyboard: F1 mods, F3 / Ctrl+O options, and typing while a panel is open
local wheelMoving = false
local function beatmapOptions()
	local song = GAMESTATE:GetCurrentSong()
	if not song then return end
	local fav = song:IsFavorited()
	TW.openDialog { lines = { song:GetDisplayArtist() .. " - " .. song:GetDisplayMainTitle(), "What do you want to do with this beatmap?" },
		buttons = {
			{ "Manage Collections", "green", function() TW.openCollections() end },
			{ fav and "Remove from Favourites" or "Add to Favourites", "purple", function()
				local s = top(); if s and s.ToggleCurrentFavorite then s:ToggleCurrentFavorite() end
				MESSAGEMAN:Broadcast("FavoritesUpdated")
			end },
			{ "Add to Active Playlist", "purple", function()
				local pl = SONGMAN:GetActivePlaylist()
				if not pl or (pl:GetName() or "") == "" then SCREENMAN:SystemMessage("No playlist yet: make one with Create New Playlist") return end
				local s = top(); if s and s.AddCurrentChartToActivePlaylist then s:AddCurrentChartToActivePlaylist() end
				SCREENMAN:SystemMessage("Added to " .. pl:GetName())
			end },
			{ "Create New Playlist", "purple", function()
				easyInputStringWithFunction("New playlist name:", 64, false,
					function(answer) TW.createPlaylist(answer) end)
			end },
			{ "Options", "purple", function() TW.openOptions() end },
			{ "Cancel", "grey" },
		} }
end
TW.beatmapOptions = beatmapOptions

local function input(event)
	-- Alt + wheel is the volume (osu!, Quaver), before anything else gets the wheel
	if TW.volumeInput(event) then return true end
	-- Etterna takes Ctrl+O as "practice mode" (when the wheel is settled) before VSRG Hub sees it;
	-- undo that whatever VSRG Hub then does with the key (opens its options, or a dialog swallows it)
	local ctrlO = event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_o"
		and INPUTFILTER:IsControlPressed()
	if ctrlO and not TWSystemGateOK then
		local w = wheel()
		if w and w:IsSettled() and not SCREENMAN:get_input_redirected(PLAYER_1) then
			GAMESTATE:SetPracticeMode(not GAMESTATE:IsPracticeMode())
			SCREENMAN:SystemMessage("Options") -- in place of Etterna's "Practice Mode On"
		end
	end
	if TW.dialogInput(event) then return true end
	if TW.listInput(event) then return true end
	if TW.optionsInput(event) then return true end
	local b = event.DeviceInput.button
	-- the mouse wheel scrolls the song wheel, unless a panel is open
	if (b == "DeviceButton_mousewheel up" or b == "DeviceButton_mousewheel down") and not TW.altHeld() then
		local w = wheel()
		if not w or TW.optionsOpen or TW.list or TW.dropOpen or (panel and panel ~= "Search") then return false end
		-- (over a song's difficulties, when it has more than fit, the wheel scrolls them instead;
		-- osu! stable's list just scrolls, the picked song staying picked: 29 VSRG Hub stable pick.lua)
		if not TW.isLazer then
			if event.type == "InputEventType_FirstPress" then
				wheelMoving = true
				TW.browse(b == "DeviceButton_mousewheel up" and -1 or 1)
			elseif wheelMoving then
				wheelMoving = false
				w:Move(0)
			end
			return false
		end
		if event.type == "InputEventType_FirstPress" and TW.diffWheel and TW.diffWheel(b == "DeviceButton_mousewheel up" and -1 or 1) then
			return true
		end
		if event.type == "InputEventType_FirstPress" then
			wheelMoving = true
			w:Move(b == "DeviceButton_mousewheel up" and -1 or 1)
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
	if arrows[b] and not TW.dropOpen and (not panel or panel == "Search") and (gb == nil or gb == "" or gb == "Invalid" or panel == "Search") then
		local w = wheel()
		if w then
			if event.type == "InputEventType_Release" then w:Move(0)
			elseif event.type == "InputEventType_FirstPress" then w:Move(arrows[b]) end
			return true
		end
	end
	if event.type == "InputEventType_Release" or event.DeviceInput.is_mouse then return false end
	if panel == "Search" then
		if b == "DeviceButton_escape" then
			search = ""; TW.searchSoon(""); setPanel(nil)
		elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" then
			TW.searchNow()
			setPanel(nil)
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
	if panel == "Mods" then
		if b == "DeviceButton_escape" or b == "DeviceButton_2" or TW.key(event, "mods", b == "DeviceButton_F1") or b == "DeviceButton_enter" then setPanel(nil)
		elseif b == "DeviceButton_1" then MESSAGEMAN:Broadcast("TWResetMods") end
		return true
	end
	if panel == "Profile" then
		if b == "DeviceButton_escape" or b == "DeviceButton_enter" then setPanel(nil) end
		return true
	end
	if event.type ~= "InputEventType_FirstPress" then return false end
	-- as in osu!, typing anywhere on song select starts a search
	if not panel and not TW.dropOpen and event.char and event.char:match("^[%w%p]$") and not TW.rateKey(event)
		and not INPUTFILTER:IsControlPressed() and not TW.altHeld() and not b:find("F%d") then
		search = event.char
		setPanel("Search"); TW.searchSoon(search)
		MESSAGEMAN:Broadcast("TWSearch", { text = search, active = true })
		return true
	end
	-- Enter plays the song, as in osu! (Etterna does that itself unless VSRG Hub holds the keyboard)
	if not panel and not TW.dropOpen and (b == "DeviceButton_enter" or b == "DeviceButton_KP enter")
		and SCREENMAN:get_input_redirected(PLAYER_1) then
		startSong()
		return true
	end
	if TW.dropOpen and b == "DeviceButton_escape" then TW.dropOpen = nil; MESSAGEMAN:Broadcast("TWDrop", {}) return true end
	-- (VSRG Hub's shortcuts: their keys can be changed in Keybinds)
	if TW.key(event, "preview", b == "DeviceButton_tab") then TW.playFromPreview() return true end
	-- osu!'s F1 (mods) and F3 (options). osu!'s F2 (random) can't be had: Etterna reloads the theme
	-- on F2 before any screen sees it, so random is Ctrl+R here. (VSRG Hub's metrics move Etterna's
	-- debug menu from F3 to F10.)
	if TW.key(event, "mods", b == "DeviceButton_F1") then setPanel("Mods") return true end
	if TW.key(event, "random", b == "DeviceButton_r" and INPUTFILTER:IsControlPressed() and not INPUTFILTER:IsShiftPressed()) then randomSong() return true end
	if TW.key(event, "beatmap", b == "DeviceButton_F3") then beatmapOptions() return true end
	if TW.key(event, "options", b == "DeviceButton_o" and INPUTFILTER:IsControlPressed()) then
		TW.openOptions() -- osu!'s options key (the practice-mode toggle is undone above)
		return true
	end
	if TW.key(event, "keybinds", false) then TW.openKeybinds() return true end
	return false
end

-- Keys VSRG Hub must have before Etterna's song select does (Etterna's screen sees every key
-- before the screen's Lua callbacks, and returning true there doesn't stop it): an open Group /
-- Sort list takes the keyboard and the mouse wheel; the first letter typed starts the search
-- without also moving the wheel or picking a song; Ctrl+O opens the options instead of Etterna's
-- practice-mode toggle. VSRG Hub's system layer (pause.lua) asks this first.
local function gate(event)
	local s = top()
	if not s or SCREENMAN:GetTopScreen() ~= s then return false end
	local b = event.DeviceInput.button
	local mouse = event.DeviceInput.is_mouse
	if mouse and not b:find("mousewheel") then return false end
	if TW.dialogSpec or TW.list or TW.optionsOpen then return false end -- (they hold the keyboard already)
	if not panel and not TW.dropOpen and TW.rateInput(event) then return true end
	if TW.dropOpen and not TW.altHeld() then input(event) return true end
	-- (osu! stable look, scrolled away from the picked song: Enter plays the picked one)
	if TW.browsing and not panel and not TW.dropOpen and not mouse and event.type == "InputEventType_FirstPress"
		and (b == "DeviceButton_enter" or b == "DeviceButton_KP enter") then
		startSong()
		return true
	end
	-- up / down go through the selected song's difficulties, as in osu! (28 VSRG Hub difficulties.lua)
	if (not panel or panel == "Search") and not TW.dropOpen and TW.diffKey(event, "vertical") then return true end
	if mouse or event.type ~= "InputEventType_FirstPress" then return false end
	-- (Etterna's own Ctrl+O, practice mode, never gets through: the osu! look has its own practice)
	local ctrlO = b == "DeviceButton_o" and INPUTFILTER:IsControlPressed() and not INPUTFILTER:IsShiftPressed()
	-- (also while typing a search, as in osu!: the search stays as it is under the options)
	if TW.key(event, "options", ctrlO) then
		if not panel or panel == "Search" then TW.openOptions() end
		return true
	end
	if TW.key(event, "keybinds", false) then
		if not panel or panel == "Search" then TW.openKeybinds() end
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

-- (Til Death's mouse picks the button with the highest "true z", its z plus its parents' z:
-- ties go to the button registered last, so panels drawn later win)
local t = Def.ActorFrame {
	InitCommand = function(self) self:z(20) end,
	TW.mouse(),
	TW.pauseCatcher(),
	TW.lnModWatcher(),
	OpenCollectionsCommand = function() if TW.openCollections then TW.openCollections() end end,
	OnCommand = function(self)
		TW.restoreLnModSong(wheel())
		-- the title menu keeps the keyboard to itself; song select gives it back to Etterna
		TW.keepRedirect = false
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		TW.endTabPractice()
		top():AddInputCallback(input)
		TWSystemInput = gate
		-- (the menu's "playlists": the collections, once the screen is up)
		if TW.openCollectionsOnSelect then
			TW.openCollectionsOnSelect = nil
			self:sleep(0.4):queuecommand("OpenCollections")
		end
		TW.syncNoteskin()
		if TW.collection and TW.applyCollection then self:sleep(0.05):queuecommand("Collection") end
		-- after a theme switch: the chart that was selected in the other look
		if TW.settings.resumeChart and TW.settings.resumeChart ~= "" then self:sleep(0.1):queuecommand("Resume") end
		-- back from a score's results: your rate again (Etterna showed them at the score's)
		TW.afterScoreView()
		-- "Watch replay" on the results: started once song select is up again
		if TW.pendingReplay then self:sleep(0.4):queuecommand("PendingReplay") end
		-- back from a replay: Etterna puts your own rate back as the replay's screen goes away, after
		-- song select has shown the replay's rate
		if TW.replayStarted then TW.replayStarted = false; self:sleep(0.3):queuecommand("RateBack") end
	end,
	ResumeCommand = function() TW.restoreSelection(wheel()) end,
	PendingReplayCommand = function() TW.startPendingReplay() end,
	RateBackCommand = function() TW.afterReplay() end,
	CollectionCommand = function(self)
		if TW.collection then TW.applyCollection(TW.collection) end
	end,
	OffCommand = function(self)
		if TWSystemInput == gate then TWSystemInput = nil end
		if panel then setPanel(nil) end
		TW.closeOptions()
		TW.closeDialog()
	end,
	TWStartSearchMessageCommand = function(self)
		setPanel("Search"); MESSAGEMAN:Broadcast("TWSearch", { text = search, active = true })
	end,
}


-- the search runs once you stop typing (28 VSRG Hub search.lua)
t[#t + 1] = TW.searchRunner()
-- the selected song's difficulties, opened up under its panel as in osu!lazer
t[#t + 1] = (not TW.isLazer) and TW.stableDiffRows {} or TW.diffRows {
	look = TW.isLazer and "lazer" or "osu",
	x = function() return TW.isLazer and (R(828) - M(60) + M(14)) or R(806) end,
	y = function() return TW.isLazer and (M(452) + M(36)) or (M(395) + M(42)) end,
	centre = function() return TW.isLazer and M(452) or M(395) end,
	unit = TW.isLazer and M(78) or M(95), indent = M(36), rowH = M(44), step = M(48), maxActors = 20,
	-- (as the list fades its panels: metrics.ini's ItemTransformFunction)
	fade = function(y)
		if TW.isLazer then return math.max(0, math.min(1, (y - M(150)) / M(60), (M(792) - y) / M(70))) end
		return math.max(0, math.min(1, (y - M(110)) / M(80), (M(805) - y) / M(100)))
	end,
	-- (the text keeps clear of the play cookie in the bottom right, as big as it gets under the mouse)
	clear = function(y0, y1)
		local cx, cy, r = R(1400), M(772), M(140) * 1.1 + M(14)
		local dy = math.abs(cy - math.max(y0, math.min(cy, y1)))
		if dy >= r then return nil end
		return cx - math.sqrt(r * r - dy * dy)
	end,
	msdColour = function(v) return TW.isLazer and LZ.starColour(v) or byMSD(v) end,
	gradeText = function(g, b)
		local r = TW.GradeToRank[g] or "D"
		-- (by the accuracy on the timing it was played on, as on the results)
		if b and b.pct and TW.accRank then r = TW.accRank(b.pct) end
		if g == "Grade_Failed" or (b and b.failed) then r = "F" end
		return TW.RankLetter[r] or r, TW.RankColour[r] or white
	end,
}

-- osu!'s mode button opens its list of modes; here the two osu!mania key counts VSRG Hub plays
local function modeMenu()
	local cur = TW.gameName()
	TW.openDialog { lines = { "Mode", "Which keys do you want to play?" },
		buttons = {
			{ (cur == "dance" and "> " or "") .. "osu!mania 4K", "purple", function() TW.switchGame("dance") end },
			{ (cur == "kb7" and "> " or "") .. "osu!mania 7K", "purple", function() TW.switchGame("kb7") end },
			{ "Cancel", "grey" },
		} }
end
-- (osu! stable's cookie in the bottom right goes under the bottom bar's art: skins cover it)
local cookieSlot = Def.ActorFrame {}
local topbar
-- osu!lazer's footer: the big pink back button, Mods / Random / Options as slanted tabs (the key
-- mode is on the toolbar), and the mods that are on, as lazer's little mod tiles beside them
if TW.isLazer then
	t[#t + 1] = Def.Quad { InitCommand = function(self)
		self:align(0, 1):xy(0, SCREEN_HEIGHT):zoomto(SCREEN_WIDTH, M(LZ.FOOT) + M(30)):diffuse({ 0, 0, 0, 0 }):diffusebottomedge({ 0, 0, 0, 0.75 })
	end }
	t[#t + 1] = LZ.backButton(function() if panel then setPanel(nil) else top():Cancel() end end)
	t[#t + 1] = LZ.footerButton { id = "mods", x = M(250), w = M(124), icon = "wand-magic-sparkles", label = "Mods", col = LZ.lime, key = TW.keyLabel("mods", "F1"),
		onClick = function() setPanel(panel == "Mods" and nil or "Mods") end, delay = 0.03 }
	t[#t + 1] = LZ.footerButton { id = "random", x = M(380), w = M(124), icon = "shuffle", label = "Random", col = LZ.blue, key = TW.keyLabel("random", "Ctrl+R"),
		onClick = randomSong, delay = 0.06 }
	t[#t + 1] = LZ.footerButton { id = "options", x = M(510), w = M(124), icon = "bars", label = "Options", col = LZ.purpleLight, key = TW.keyLabel("beatmap", "F3"),
		onClick = beatmapOptions, delay = 0.09 }
	-- the mods that are on (and a rate that isn't one of theirs), lazer's small tiles
	local onMods = Def.ActorFrame {
		InitCommand = function(self) self:xy(M(650), SCREEN_HEIGHT - M(33)) end,
		OnCommand = function(self) self:playcommand("Refresh") end,
		TWModsChangedMessageCommand = function(self) self:playcommand("Refresh") end,
		CurrentRateChangedMessageCommand = function(self) self:playcommand("Refresh") end,
		TWPanelMessageCommand = function(self, p) MESSAGEMAN:Broadcast("LZActive", { id = "mods", on = p.name == "Mods" }) end,
		RefreshCommand = function(self)
			local n = 0
			for i, m in ipairs(mods) do
				local c = self:GetChild("M" .. i)
				c:visible(m.get())
				if m.get() then c:x(n * M(52)); n = n + 1 end
			end
			local r = self:GetChild("Rate")
			local custom = not rateIs(1) and not rateIs(0.75) and not rateIs(1.5)
			r:visible(custom):x(n * M(52))
			r:GetChild("T"):settext(custom and getCurRateDisplayString(true) or "")
		end,
	}
	local modCol = { reduce = LZ.lime, increase = TW.rgb(255, 102, 102), auto = LZ.blue, convert = LZ.purpleLight }
	for i, m in ipairs(mods) do
		local c = modCol[m.col] or LZ.pink
		onMods[#onMods + 1] = Def.ActorFrame {
			Name = "M" .. i,
			LZ.panel { w = M(46), h = M(26), r = M(6), ay = 0.5, col = TW.mix(c, { 0, 0, 0, 1 }, 0.55) },
			LZ.text(M(12), "bold", function(self) self:align(0.5, 0.5):x(M(23)):settext(m.short):diffuse(c) end),
		}
	end
	onMods[#onMods + 1] = Def.ActorFrame {
		Name = "Rate",
		LZ.panel { w = M(56), h = M(26), r = M(6), ay = 0.5, col = LZ.purpleDark },
		LZ.text(M(12), "bold", function(self) self:align(0.5, 0.5):x(M(28)) end) .. { Name = "T" },
	}
	t[#t + 1] = onMods
else
	-- bottom bar art (VSRG Hub's stand-in when the skin has none: a dark see-through strip with a faint
	-- top edge, so the song list and background show through as in osu!)
	local BAR = M(96)
	-- the top bar's own parts (topbar.lua) load first: its art goes under the bottom buttons' art
	topbar = LoadActor("topbar")
	t[#t + 1] = cookieSlot
	if TW.has("songselect_bottom") then
		t[#t + 1] = TW.sprite("songselect_bottom", function(self) self:align(0, 1):xy(0, SCREEN_HEIGHT):zoomtowidth(SCREEN_WIDTH) end)
	elseif TW.fallback("songselect_bottom") then
		-- osu!'s default bar: black, with a blue line along its top
		t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 1):xy(0, SCREEN_HEIGHT):zoomto(SCREEN_WIDTH, BAR):diffuse({ 0, 0, 0, 0.92 }) end }
		t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 1):xy(0, SCREEN_HEIGHT - BAR + M(2)):zoomto(SCREEN_WIDTH, M(2.5)):diffuse(TW.rgb(42, 128, 230)) end }
	end

	-- the player card: under the bottom buttons' art, as osu! draws it (skins frame it with their art,
	-- some with their own "Performance" / "Accuracy" words over osu!'s)
	t[#t + 1] = TW.userCard(SCREEN_CENTER_X - M(60), SCREEN_HEIGHT - M(80), M(80), true)
	-- the top bar art with osu!'s own parts of it: over the bottom bar, under the bottom buttons' art
	t[#t + 1] = TW.stableTopArt

	-- osu!'s bottom buttons: skin art at osu!'s positions; when the skin blanks them they stay
	-- clickable but invisible, exactly like in osu!. A skin without them gets VSRG Hub's: flat text
	-- buttons on the bar itself (no boxes of their own), osu!'s key under each, a thin line between
	-- them, and the interface colour lighting up the one under the mouse.
	local function barButton(id, label, x, w, onClick, key)
		local f = Def.ActorFrame { InitCommand = function(self) self:xy(x, SCREEN_HEIGHT) end }
		local plain = false
		if TW.has(id) then
			f[#f + 1] = TW.sprite(id, function(self) self:align(0, 1) end) .. { Name = "Img" }
		elseif TW.fallback(id) then
			plain = true
			local back = id == "menu_back"
			-- each button has its own colour, like osu!'s (back and mode pink, mods blue, random green,
			-- options purple)
			local col = ({ menu_back = TW.pink, sel_mode = TW.rgb(150, 95, 235), sel_mods = TW.rgb(220, 85, 175),
				sel_random = TW.rgb(110, 200, 70), sel_options = TW.rgb(60, 140, 235) })[id] or TW.pink
			if back then
				-- osu!'s back button: a slanted tab in the interface colour with an arrow; it slides out
				-- under the mouse
				f[#f + 1] = TW.box { w = w - M(20), h = BAR * 0.62, r = M(10), shear = 0.15, ax = 0, ay = 0.5,
					col = TW.mix(col, { 1, 1, 1, 1 }, 0.1), col2 = TW.mix(col, { 0, 0, 0, 1 }, 0.15), init = function(self) self:xy(-M(12), -BAR / 2) end } .. { Name = "Tab" }
				f[#f + 1] = TW.icon("chevron-left", M(16), function(self) self:xy(M(34), -BAR / 2) end) .. { Name = "Arrow" }
				f[#f + 1] = TW.text(M(19), true, function(self) self:align(0, 0.5):xy(M(52), -BAR / 2):settext(label):shadowlength(1) end) .. { Name = "Label" }
			else
				-- osu!'s default buttons: dark, a coloured line along the top, the word in the middle and
				-- the key in the bottom right corner (the mode button its mode's round icon over its word)
				f[#f + 1] = Def.Quad { Name = "Glow", InitCommand = function(self) self:align(0, 1):zoomto(w - M(3), BAR - M(4)):diffuse({ 0.1, 0.1, 0.11, 1 }) end }
				f[#f + 1] = Def.Quad { Name = "Edge", InitCommand = function(self) self:align(0, 1):y(-BAR + M(8)):zoomto(w - M(3), M(4)):diffuse(col) end }
				if id == "sel_mode" then
					f[#f + 1] = TW.ringShape(M(15), M(2.5), { 1, 1, 1, 1 }, function(self) self:xy((w - M(3)) / 2, -BAR * 0.62) end)
					f[#f + 1] = TW.text(M(12), true, function(self) self:align(0.5, 0.5):xy((w - M(3)) / 2, -BAR * 0.62):settext(TW.gameName and TW.gameName() == "kb7" and "7" or "4"):shadowlength(0) end)
				end
				f[#f + 1] = TW.text(M(17), false, function(self)
					self:align(0.5, 0.5):xy((w - M(3)) / 2, id == "sel_mode" and -BAR * 0.25 or -BAR * 0.5):settext(label):shadowlength(1)
						:diffuse(color("#FFFFFF")):maxwidth((w - M(8)) / self:GetZoom())
				end) .. { Name = "Label" }
			end
			if key then
				-- (key: the shortcut's id; its key can be changed in Keybinds)
				local function keyText() return TW.keyLabel(key[1], key[2]) end
				f[#f + 1] = TW.text(M(10.5), false, function(self)
					self:align(1, 1):xy(w - M(7), -M(3)):settext(keyText()):shadowlength(1)
				end) .. { TWKeysChangedMessageCommand = function(self) self:settext(keyText()) end }
			end
		end
		if TW.has(id .. "_over") then
			f[#f + 1] = TW.sprite(id .. "_over", function(self) self:align(0, 1):diffusealpha(0) end) .. { Name = "Over" }
		end
		f[#f + 1] = TW.button(w, M(90), onClick, function(self, on)
			local p = self:GetParent()
			local o = p:GetChild("Over")
			-- (the skin's lit art fades in and out quickly, as osu!'s does)
			if o then o:stoptweening():linear(on and 0.08 or 0.15):diffusealpha(on and 1 or 0) end
			if plain then
				if id == "menu_back" then
					p:GetChild("Tab"):stoptweening():decelerate(0.12):x(on and M(0) or -M(12))
					p:GetChild("Arrow"):stoptweening():decelerate(0.12):x(on and M(28) or M(34))
				else
					p:GetChild("Glow"):stoptweening():linear(0.1):diffuse(on and { 0.22, 0.22, 0.25, 1 } or { 0.1, 0.1, 0.11, 1 })
				end
			end
		end) .. { InitCommand = function(self) self:align(0, 1):zoomto(w, M(90)):diffusealpha(0) end }
		return f
	end
	-- (osu!'s order: the mode button, the mode's icon over it, the other buttons, and the back button
	-- over everything; some skins make these whole-screen frames that build on that order)
	-- (the mode's own icon sits on the button when the skin has one, so it needs no word)
	t[#t + 1] = barButton("sel_mode", "Mode", U * 224, U * 88, modeMenu)
	t[#t + 1] = TW.stableModeIcon
	t[#t + 1] = barButton("sel_mods", "Mods", U * 316, U * 77, function() setPanel(panel == "Mods" and nil or "Mods") end, { "mods", "F1" })
	t[#t + 1] = barButton("sel_random", "Random", U * 393, U * 77, randomSong, { "random", "Ctrl+R" })
	t[#t + 1] = barButton("sel_options", "Beatmap\nOptions", U * 470, U * 77, beatmapOptions, { "beatmap", "F3" })
	t[#t + 1] = barButton("menu_back", "back", 0, U * 200, function() if panel then setPanel(nil) else top():Cancel() end end)
	-- the current mode's icon on the mode button
	-- (the skin's mode-*-small, centred on the mode button, is drawn with the top bar: topbar.lua)
	-- active mods as the skin's mod icons, above the bar like osu! (right of the personal best panel)
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(M(458), SCREEN_HEIGHT - M(122)) end,
		OnCommand = function(self) self:playcommand("Refresh") end,
		TWModsChangedMessageCommand = function(self) self:playcommand("Refresh") end,
		CurrentRateChangedMessageCommand = function(self) self:playcommand("Refresh") end,
		RefreshCommand = function(self)
			local n = 0
			for i, m in ipairs(mods) do
				local c = self:GetChild("M" .. i)
				if c then
					c:visible(m.get())
					if m.get() then c:x(n * M(36)); n = n + 1 end
				end
			end
			local r = self:GetChild("Rate")
			local custom = not rateIs(1) and not rateIs(0.75) and not rateIs(1.5)
			r:visible(custom):x(n * M(36)):settext(custom and getCurRateDisplayString(true) or "")
		end,
		TW.text(M(14), true, function(self) self:align(0, 0.5) end) .. { Name = "Rate" },
	}
	for i, m in ipairs(mods) do
		local f = t[#t]
		if TW.has(m.id) then
			f[#f + 1] = TW.sprite(m.id, function(self)
				local w, h = self:GetWidth(), self:GetHeight()
				if w > 0 and h > 0 then self:zoom(math.min(M(34) / w, M(32) / h)) end
			end) .. { Name = "M" .. i }
		elseif TW.fallback(m.id) then
			f[#f + 1] = TW.text(M(14), true, function(self) self:align(0.5, 0.5):settext(m.short) end) .. { Name = "M" .. i }
		end
	end
end

-- top bar (songselect-top, beatmap info, Group / Sort, search). Drawn after the bottom bar's
-- art: some skins make selection-mode a full-screen frame with the header and search box drawn
-- in, and osu! writes its header text over it.
-- (osu!lazer's look: its wedge, tabs, search and toolbar instead; your profile is on its toolbar)
if TW.isLazer then
	t[#t + 1] = LoadActor("/Themes/VSRG Hub lazer/BGAnimations/_lazer select top.lua")
else
	t[#t + 1] = topbar
	-- (click the player card for your profile, as in osu!)
	-- (the full profile page, VSRG Hub profile.lua; the small panel when it isn't there)
	t[#t + 1] = TW.button(M(300), M(80), function() if TWOpenProfile then TWOpenProfile() else setPanel(panel == "Profile" and nil or "Profile") end end) .. {
		InitCommand = function(self) self:align(0, 0):xy(SCREEN_CENTER_X - M(60), SCREEN_HEIGHT - M(80)):zoomto(M(300), M(80)):diffusealpha(0) end }
end
-- the cookie to start the song (lazer's logo, bottom right)
-- (it beats to the song's own beat while its preview plays; lazer's logo has its visualizer too)
local function songBeat()
	local ok, b = pcall(function() return GAMESTATE:GetSongPosition():GetSongBeat() end)
	if ok and b and b > -100 and GAMESTATE:GetCurrentSong() then return b end
	return GetTimeSinceStart() * 2
end
-- (osu! stable's: bigger, lower and half off the screen, under the bottom bar's art)
local CR = TW.isLazer and M(140) or M(152)
local playCookie = Def.ActorFrame {
	InitCommand = function(self) if TW.isLazer then self:xy(R(1400), M(772)) else self:xy(R(1407), M(815)) end end,
	OnCommand = function(self) self:zoom(0.6):diffusealpha(0):decelerate(0.4):zoom(1):diffusealpha(1) end,
	TW.cookieShadow(CR),
	Def.ActorFrame {
		Name = "Pulse",
		InitCommand = function(self)
			local last = nil
			TW.everyFrame(self)
			self:SetUpdateFunction(function()
				local whole = math.floor(songBeat())
				if last and whole ~= last then
					local strong = whole % 4 == 0
					TW.visualKick(strong and 0.9 or 0.55)
					self:stoptweening():linear(0.05):zoom(strong and 1.04 or 1.02):decelerate(0.4):zoom(1)
				end
				last = whole
			end)
		end,
		TW.isLazer and TW.visualizer(CR, { 1, 1, 1, 0.38 }, 120) or Def.Actor {},
		Def.ActorFrame {
			Name = "Hover",
			TW.cookie(CR, TW.isLazer and "play" or "osu!", TW.cookieColour()),
		},
	},
	TW.button(CR * 1.7, CR * 1.7, startSong, function(self, on)
		self:GetParent():GetChild("Pulse"):GetChild("Hover"):stoptweening():decelerate(0.15):zoom(on and 1.06 or 1)
	end)
}
if TW.isLazer then t[#t + 1] = playCookie else cookieSlot[#cookieSlot + 1] = playCookie end

-- osu!lazer's mod select: a column for each kind of mod (Difficulty Reduction, Difficulty Increase,
-- Automation, Conversion), each mod a slanted row with its tile, name and what it does; it lights up in
-- its column's colour when on. 1 (or Deselect all) turns them all off, 2 / Esc / Enter closes.
if TW.isLazer then
	local cols = {
		{ key = "reduce", title = "Difficulty Reduction", col = LZ.lime },
		{ key = "increase", title = "Difficulty Increase", col = TW.rgb(255, 102, 102) },
		{ key = "auto", title = "Automation", col = LZ.blue },
		{ key = "convert", title = "Conversion", col = LZ.purpleLight },
	}
	local CWd, GAPc, X0 = M(320), M(18), M(36)
	local Y0 = M(176)
	local panelL = Def.ActorFrame {
		InitCommand = function(self) self:visible(false):z(2) end,
		TWPanelMessageCommand = function(self, p)
			self:stoptweening()
			if p.name == "Mods" then
				self:visible(true):diffusealpha(0):linear(0.15):diffusealpha(1)
				self:playcommand("Refresh")
			else
				self:linear(0.1):diffusealpha(0):queuecommand("Hide")
			end
		end,
		HideCommand = function(self) if panel ~= "Mods" then self:visible(false) end end,
		TWResetModsMessageCommand = function(self)
			for _, m in ipairs(mods) do if m.get() then m.set(false) end end
			TW.resetRate()
			self:playcommand("Refresh"); MESSAGEMAN:Broadcast("TWModsChanged")
		end,
		Def.Quad { InitCommand = function(self) self:FullScreen():diffuse({ 0, 0, 0, 0.62 }) end },
		-- the sheet, coming up from the bottom
		Def.ActorFrame {
			Name = "Sheet",
			TWPanelMessageCommand = function(self, p) if p.name == "Mods" then self:stoptweening():y(M(60)):decelerate(0.3):y(0) end end,
			Def.Quad { InitCommand = function(self) self:align(0, 0):xy(0, M(100)):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT - M(100)):diffuse(LZ.a(LZ.bg5, 0.97)):diffusebottomedge(LZ.a(LZ.bg6, 0.98)) end },
			Def.Quad { InitCommand = function(self) self:align(0, 0):xy(0, M(100)):zoomto(SCREEN_WIDTH, M(3)):diffuse(LZ.pink) end },
		},
		TW.button(1, 1, function() end) .. { InitCommand = function(self) self:FullScreen():diffusealpha(0) end }, -- swallow clicks behind the panel
		LZ.text(M(26), "bold", function(self) self:align(0, 0.5):xy(X0, M(128)):settext("Mod Select") end),
		LZ.text(M(12.5), "regular", function(self)
			self:align(0, 0.5):xy(X0 + M(230), M(130)):diffuse(LZ.dim):maxwidth(M(900) / self:GetZoom())
			self:settext("Mods change how a song plays. Etterna scores you the same way with any of them; rates change the MSD. Invert and Full LN play a converted copy.")
		end),
		-- the music rate, as lazer shows its score multiplier
		Def.ActorFrame {
			InitCommand = function(self) self:xy(SCREEN_WIDTH - M(36), M(128)) end,
			LZ.panel { w = M(170), h = M(34), r = M(8), ax = 1, ay = 0.5, col = LZ.a(LZ.bg3, 1) },
			LZ.text(M(11), "bold", function(self) self:align(0, 0.5):x(-M(160)):settext("Music rate"):diffuse(LZ.dim) end),
			LZ.text(M(16), "bold", function(self) self:align(1, 0.5):x(-M(14)) end) .. {
				RefreshCommand = function(self) self:settext(getCurRateDisplayString(true)):diffuse(rateIs(1) and color("#FFFFFF") or LZ.yellow) end,
				CurrentRateChangedMessageCommand = function(self) self:playcommand("Refresh") end,
			},
		},
	}
	for ci, c in ipairs(cols) do
		local x = X0 + (ci - 1) * (CWd + GAPc)
		local list = {}
		for _, m in ipairs(mods) do if m.col == c.key then list[#list + 1] = m end end
		local colH = M(48) + #list * M(62) + M(10)
		panelL[#panelL + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(x, Y0) end,
			TWPanelMessageCommand = function(self, p)
				if p.name == "Mods" then self:stoptweening():diffusealpha(0):addy(M(30)):sleep(0.04 * ci):decelerate(0.3):diffusealpha(1):addy(-M(30)) end
			end,
			TW.shadow { w = CWd, h = colH, spread = M(12), alpha = 0.45, drop = M(3) },
			LZ.panel { w = CWd, h = colH, r = M(10), col = LZ.a(LZ.bg4, 1), col2 = LZ.a(LZ.bg5, 1) },
			-- the column's header in its colour
			LZ.panel { w = CWd, h = M(40), r = M(10), col = TW.mix(c.col, { 1, 1, 1, 1 }, 0.05), col2 = c.col },
			LZ.text(M(14), "bold", function(self) self:align(0, 0.5):xy(M(18), M(20)):settext(c.title):diffuse(TW.rgb(25, 20, 30)) end),
		}
		local colFrame = panelL[#panelL]
		for ri, m in ipairs(list) do
			local y = M(48) + (ri - 1) * M(62)
			local RW = CWd - M(20)
			colFrame[#colFrame + 1] = Def.ActorFrame {
				InitCommand = function(self) self:xy(M(10), y) end,
				RefreshCommand = function(self)
					local on = m.get()
					local ch = self:GetChildren()
					TW.setBox(ch.Bg, { col = on and TW.mix(c.col, { 0, 0, 0, 1 }, 0.15) or LZ.a(LZ.bg3, 1), col2 = on and TW.mix(c.col, { 0, 0, 0, 1 }, 0.35) or LZ.a(LZ.bg3, 1) })
					TW.setBox(ch.Tile, { col = on and TW.rgb(25, 20, 30) or TW.mix(c.col, { 0, 0, 0, 1 }, 0.5) })
					ch.Short:diffuse(on and c.col or TW.mix(c.col, { 1, 1, 1, 1 }, 0.2))
					ch.Name:diffuse(on and TW.rgb(25, 20, 30) or color("#FFFFFF"))
					ch.Desc:diffuse(on and TW.rgb(40, 32, 46) or LZ.dim)
					self:stoptweening():decelerate(0.1):x(M(10) + (on and M(6) or 0))
				end,
				LZ.panel { w = RW, h = M(54), r = M(8) } .. { Name = "Bg" },
				LZ.panel { w = M(58), h = M(36), r = M(8), ay = 0.5, init = function(self) self:xy(M(10), M(27)) end } .. { Name = "Tile" },
				LZ.text(#m.short > 2 and M(14) or M(16), "bold", function(self) self:align(0.5, 0.5):xy(M(39), M(27)):settext(m.short) end) .. { Name = "Short" },
				LZ.text(M(14), "bold", function(self) self:align(0, 0.5):xy(M(80), M(18)):settext(m.name or m.short) end) .. { Name = "Name" },
				LZ.text(M(10.5), "regular", function(self) self:align(0, 0.5):xy(M(80), M(37)):settext(m.desc or ""):maxwidth((RW - M(92)) / self:GetZoom()) end) .. { Name = "Desc" },
				TW.button(RW, M(54), function(self)
					m.set(not m.get())
					if m.id == "mod_halftime" or m.id == "mod_doubletime" then MESSAGEMAN:Broadcast("TWRefreshMods") end
					self:GetParent():GetParent():GetParent():playcommand("Refresh")
					MESSAGEMAN:Broadcast("TWModsChanged")
				end, function(self, on) self:GetParent():GetChild("Bg"):stoptweening():linear(0.08):diffusealpha(on and 0.85 or 1) end) ..
					{ InitCommand = function(self) self:align(0, 0):zoomto(RW, M(54)):diffusealpha(0) end },
			}
		end
	end
	-- Deselect all / Close, as lazer's footer of the mod select
	local function sheetButton(text, x, col, onClick)
		local w, h = M(200), M(44)
		return Def.ActorFrame {
			InitCommand = function(self) self:xy(x, SCREEN_HEIGHT - M(70)) end,
			TW.shadow { w = w, h = h, spread = M(8), alpha = 0.4 },
			LZ.panel { w = w, h = h, r = M(8), col = TW.mix(col, { 1, 1, 1, 1 }, 0.08), col2 = col } .. { Name = "Bg" },
			LZ.text(M(14), "bold", function(self) self:align(0.5, 0.5):xy(w / 2, h / 2):settext(text) end),
			TW.button(w, h, onClick, function(self, on) self:GetParent():GetChild("Bg"):stoptweening():linear(0.08):diffusealpha(on and 0.8 or 1) end) ..
				{ InitCommand = function(self) self:align(0, 0):zoomto(w, h):diffusealpha(0) end },
		}
	end
	panelL[#panelL + 1] = sheetButton("1. Deselect all", X0, TW.rgb(200, 60, 90), function() MESSAGEMAN:Broadcast("TWResetMods") end)
	panelL[#panelL + 1] = sheetButton("2. Close", X0 + M(216), LZ.bg1, function() setPanel(nil) end)
	t[#t + 1] = panelL
else
	-- mod select, as osu! stable lays it out (measured on osu! at 1080p): the whole screen darkened,
	-- the explanation in big letters at the top left, the rate in the middle where osu! has its score
	-- multiplier, a row of mods for each kind with its name on the left in its colour (lime, orange-
	-- red, white), the skin's mod icons at their own size in columns, and the two buttons in the
	-- middle below: the skin's button art behind their words when it has some (none at all when the
	-- skin blanks it), osu!'s coloured bars when it has none
	TW.modIconBox = nil -- (measured from the skin's own mod art as it loads)
	local modsPanel = Def.ActorFrame {
		InitCommand = function(self) self:visible(false):z(2) end,
		TWPanelMessageCommand = function(self, p)
			self:visible(p.name == "Mods")
			if p.name == "Mods" then self:playcommand("Refresh") end
		end,
		TWResetModsMessageCommand = function(self)
			for _, m in ipairs(mods) do if m.get() then m.set(false) end end
			TW.resetRate() -- the rate too, as Half Time / Double Time are rates here
			self:playcommand("Refresh"); MESSAGEMAN:Broadcast("TWModsChanged")
		end,
		CurrentRateChangedMessageCommand = function(self) if self:GetVisible() then self:playcommand("Refresh") end end,
		Def.Quad { Name = "Shade", InitCommand = function(self) self:FullScreen():diffuse({ 0, 0, 0, 0.84 }) end },
		TW.button(1, 1, function() end) .. { InitCommand = function(self) self:FullScreen():diffusealpha(0) end }, -- swallow clicks behind the panel
		TW.text(M(23.5), false, function(self)
			self:align(0, 0):xy(M(11), M(4)):shadowlength(0):wrapwidthpixels(M(1415) / self:GetZoom())
			self:settext("Mods change how a song plays. Etterna scores them all the same way; rates change the MSD, and Invert and Full LN play a converted copy of the chart.")
		end),
		TW.text(M(30.3), false, function(self) self:align(0.5, 0.5):xy(SCREEN_CENTER_X, M(137.3)):shadowlength(0) end) .. {
			RefreshCommand = function(self) self:settext("Music Rate: " .. getCurRateDisplayString(true)) end
		},
		-- < and > beside it: 0.05x down and up (the mouse wheel over the line does the same)
		TW.text(M(34), true, function(self) self:align(0.5, 0.5):xy(SCREEN_CENTER_X - M(190), M(137.3)):settext("<"):shadowlength(0):diffuse(TW.rgb(255, 204, 34)) end),
		TW.text(M(34), true, function(self) self:align(0.5, 0.5):xy(SCREEN_CENTER_X + M(190), M(137.3)):settext(">"):shadowlength(0):diffuse(TW.rgb(255, 204, 34)) end),
		-- (Etterna's names run the other way: "PrevRate" is 0.05x up, "NextRate" 0.05x down)
		TW.button(M(44), M(44), function() ChangeMusicRate(nil, { Name = "NextRate" }); MESSAGEMAN:Broadcast("CurrentRateChanged") end) ..
			{ InitCommand = function(self) self:xy(SCREEN_CENTER_X - M(190), M(137.3)):zoomto(M(44), M(44)):diffusealpha(0) end },
		TW.button(M(44), M(44), function() ChangeMusicRate(nil, { Name = "PrevRate" }); MESSAGEMAN:Broadcast("CurrentRateChanged") end) ..
			{ InitCommand = function(self) self:xy(SCREEN_CENTER_X + M(190), M(137.3)):zoomto(M(44), M(44)):diffusealpha(0) end },
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self) self:xy(SCREEN_CENTER_X, M(137.3)):zoomto(M(300), M(44)):diffusealpha(0) end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_mousewheel up" or params.event == "DeviceButton_left mouse button" then ChangeMusicRate(nil, { Name = "PrevRate" })
				elseif params.event == "DeviceButton_mousewheel down" or params.event == "DeviceButton_right mouse button" then ChangeMusicRate(nil, { Name = "NextRate" })
				else return end
				MESSAGEMAN:Broadcast("CurrentRateChanged")
			end,
		},
	}
	-- (osu!'s own mod icons, for mods the skin has none for: the tile's colours by kind, and a symbol)
	local TILE = {
		reduce = { TW.rgb(70, 120, 20), TW.rgb(38, 72, 10) }, increase = { TW.rgb(150, 95, 0), TW.rgb(95, 58, 0) },
		convert = { TW.rgb(0, 95, 42), TW.rgb(18, 58, 28) }, auto = { TW.rgb(36, 32, 40), TW.rgb(14, 12, 18) },
	}
	local MODICON = {
		mod_nofail = "shield-heart", mod_halftime = "backward-fast", mod_doubletime = "forward-fast", mod_hidden = "eye-slash",
		mod_fadein = "eye", mod_mirror = "right-left", mod_random = "dice", mod_autoplay = "robot",
		mod_invert = "arrows-left-right", mod_practice = "repeat", mod_fln = "bars",
	}
	local rowLabel = { { "Difficulty Reduction", TW.rgb(50, 205, 50) }, { "Difficulty Increase", TW.rgb(255, 69, 0) }, { "Special", white } }
	local ROWY = { M(234.3), M(336), M(439) }
	for r, l in ipairs(rowLabel) do
		modsPanel[#modsPanel + 1] = TW.text(M(27.3), false, function(self)
			self:align(0, 0.5):xy(M(42.5), ROWY[r]):settext(l[1]):diffuse(l[2]):shadowlength(0):maxwidth(M(330) / self:GetZoom())
		end)
	end
	local col = { 0, 0, 0 }
	for _, m in ipairs(mods) do
		col[m.row] = col[m.row] + 1
		local x, y = M(410.3 + (col[m.row] - 1) * 112.2), ROWY[m.row]
		modsPanel[#modsPanel + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(x, y) end,
			RefreshCommand = function(self)
				local on = m.get()
				self:stoptweening():decelerate(0.1):zoom(on and 1.15 or 1):rotationz(on and -6 or 0)
				self:GetChild("Icon"):diffuse(on and white or color("#BBBBBB"))
				self:GetChild("Icon"):glow(on and color("#FFFFFF33") or color("#FFFFFF00"))
			end,
			-- the skin's icon at osu!'s size (never wider than the gap to the next one); without one, a
			-- tile like osu!'s own mod icons: dark, in the colour of its kind, a symbol and its name
			TW.has(m.id) and TW.sprite(m.id, function(self)
				local w, h = self:GetZoomedWidth(), self:GetZoomedHeight()
				if w > M(104) or h > M(96) then self:zoom(self:GetZoom() * math.min(M(104) / w, M(96) / h)) end
				-- (the tiles of the mods the skin has no art for take the size of its art)
				if not TW.modIconBox and w > 0 then TW.modIconBox = { self:GetZoomedWidth(), self:GetZoomedHeight() } end
			end) .. { Name = "Icon" }
				or Def.ActorFrame { Name = "Icon",
					InitCommand = function(self) self:queuecommand("Fit") end,
					FitCommand = function(self)
						local b = TW.modIconBox or { M(67.5), M(66) }
						local w, h = math.min(M(80), math.max(M(56), b[1])), math.min(M(78), math.max(M(54), b[2]))
						local c = self:GetChildren()
						TW.setBox(c.Tile, { w = w, h = h })
						c.Sym:zoomto(h * 0.42, h * 0.42):y(-h * 0.1)
						c.Name:y(h * 0.32):maxwidth((w - M(6)) / c.Name:GetZoom())
					end,
					TW.box { w = M(66), h = M(66), r = M(4), ax = 0.5, ay = 0.5, col = TILE[m.col] and TILE[m.col][1] or TILE.auto[1], col2 = TILE[m.col] and TILE[m.col][2] or TILE.auto[2] } .. { Name = "Tile" },
					TW.icon(MODICON[m.id] or "star", M(28), function(self) end) .. { Name = "Sym" },
					TW.text(M(8.5), false, function(self) self:align(0.5, 0.5):settext(m.name):shadowlength(0) end) .. { Name = "Name" } },
			TW.button(M(104), M(96), function(self)
				m.set(not m.get())
				if m.id == "mod_halftime" or m.id == "mod_doubletime" then MESSAGEMAN:Broadcast("TWRefreshMods") end
				self:GetParent():GetParent():playcommand("Refresh")
				MESSAGEMAN:Broadcast("TWModsChanged")
			end)
		}
	end
	local function osuButton(text, y, col, onClick)
		local w, h = M(784), M(66.7)
		local f = Def.ActorFrame { InitCommand = function(self) self:xy(SCREEN_CENTER_X - w / 2, y) end }
		if TW.has("btn_middle") then
			-- (the skin's button art, tinted as osu! tints its buttons)
			f[#f + 1] = Def.ActorFrame {
				Name = "Bg",
				TW.sprite("btn_middle", function(self) self:align(0, 0.5):zoomto(w, h):diffuse(col) end),
				TW.sprite("btn_left", function(self) local ih = self:GetHeight(); if ih > 0 then self:zoom(h / ih) end; self:align(1, 0.5):diffuse(col) end),
				TW.sprite("btn_right", function(self) local ih = self:GetHeight(); if ih > 0 then self:zoom(h / ih) end; self:align(0, 0.5):x(w):diffuse(col) end),
			}
		elseif TW.fallback("btn_middle") then
			f[#f + 1] = TW.box { w = w, h = h, r = h / 2, ay = 0.5, col = TW.mix(col, { 1, 1, 1, 1 }, 0.12), col2 = col } .. { Name = "Bg" }
		else
			f[#f + 1] = Def.Actor { Name = "Bg" }
		end
		f[#f + 1] = TW.text(M(31), false, function(self) self:align(0.5, 0.5):x(w / 2):settext(text):shadowlength(0) end) .. { Name = "Word" }
		f[#f + 1] = TW.button(w, h, onClick, function(self, on)
			local p = self:GetParent()
			p:GetChild("Bg"):stoptweening():linear(0.08):diffusealpha(on and 1 or 0.85)
			p:GetChild("Word"):stoptweening():decelerate(0.1):zoom(p:GetChild("Word"):GetZoom()):x(w / 2 + (on and M(6) or 0))
		end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(w, h):diffusealpha(0) end }
		return f
	end
	modsPanel[#modsPanel + 1] = osuButton("1. Reset All Mods", M(577), TW.rgb(250, 55, 0), function() MESSAGEMAN:Broadcast("TWResetMods") end)
	modsPanel[#modsPanel + 1] = osuButton("2. Close", M(662), TW.rgb(120, 120, 120), function() setPanel(nil) end)
	t[#t + 1] = modsPanel
end

-- your profile: Etterna's ratings in osu!'s dark panel (click the player card, Esc closes)
local profilePanel = Def.ActorFrame {
	InitCommand = function(self) self:visible(false):z(2) end,
	TWPanelMessageCommand = function(self, p)
		self:visible(p.name == "Profile")
		if p.name == "Profile" then self:playcommand("Refresh") end
	end,
	Def.Quad { InitCommand = function(self) TW.shade(self:FullScreen(), 0.9) end },
	TW.button(1, 1, function() setPanel(nil) end) .. { InitCommand = function(self) self:FullScreen():diffusealpha(0) end }, -- a click outside closes it
}
do
	local PX, PW = SCREEN_CENTER_X - M(260), M(520)
	local prow = TW.profileRows()
	local RHp = M(34)
	local PY = SCREEN_CENTER_Y - (#prow * RHp) / 2 + M(20)
	profilePanel[#profilePanel + 1] = Def.Quad { InitCommand = function(self)
		self:align(0, 0):xy(PX - M(10), PY - M(110)):zoomto(PW + M(20), #prow * RHp + M(130)); TW.glassify(self, "float") end }
	profilePanel[#profilePanel + 1] = Def.Quad { InitCommand = function(self)
		self:align(0, 0):xy(PX - M(10), PY - M(110)):zoomto(PW + M(20), M(4)):diffuse(TW.pink) end }
	profilePanel[#profilePanel + 1] = TW.button(PW + M(20), #prow * RHp + M(130), function() end) .. { InitCommand = function(self)
		self:align(0, 0):xy(PX - M(10), PY - M(110)):zoomto(PW + M(20), #prow * RHp + M(130)):diffusealpha(0) end }
	profilePanel[#profilePanel + 1] = Def.Sprite { RefreshCommand = function(self)
		local _, av = TW.profile(); self:Load(av):align(0, 0):xy(PX, PY - M(92)):zoomto(M(70), M(70)) end }
	profilePanel[#profilePanel + 1] = TW.text(M(26), true, function(self) self:align(0, 0.5):xy(PX + M(84), PY - M(70)) end) .. {
		RefreshCommand = function(self) local p = TW.profile(); local n = p and p:GetDisplayName() or ""; self:settext(n ~= "" and n or "Guest") end }
	profilePanel[#profilePanel + 1] = TW.text(M(15), false, function(self) self:align(0, 0.5):xy(PX + M(84), PY - M(40)):diffuse(TW.pinkLight):settext("Local profile  -  Etterna ratings") end)
	for i, r in ipairs(prow) do
		local y = PY + (i - 1) * RHp
		profilePanel[#profilePanel + 1] = Def.Quad { InitCommand = function(self)
			self:align(0, 0):xy(PX, y):zoomto(PW, RHp - 2):diffuse(i % 2 == 1 and color("1,1,1,0.06") or color("1,1,1,0.02")) end }
		profilePanel[#profilePanel + 1] = TW.text(M(16), false, function(self) self:align(0, 0.5):xy(PX + M(14), y + RHp / 2):settext(r[1]) end)
		profilePanel[#profilePanel + 1] = TW.text(M(16), true, function(self) self:align(1, 0.5):xy(PX + PW - M(14), y + RHp / 2) end) .. {
			RefreshCommand = function(self)
				local p = TW.profile()
				local ok, v = pcall(r[2], p)
				self:settext(ok and v or "-"):diffuse(i == 1 and TW.yellow or color("#FFFFFF"))
			end }
	end
end
t[#t + 1] = profilePanel

-- VSRG Hub's options (Ctrl+O, or Options in the beatmap options), lists and osu!'s dialogs
t[#t + 1] = TW.optionsPanel()
t[#t + 1] = TW.listPanel { notes = true }
t[#t + 1] = TW.dialogPanel()
t[#t + 1] = TW.textureKeeper()
return t
