-- Written by VSRG Hub into Etterna's own themes (Til Death, Rebirth) while VSRG Hub runs them. It only
-- exists in VSRG Hub's folder, which Etterna mounts over its own; your theme files are untouched.
-- It keeps Etterna's error display and adds the VSRG Hub menu: Ctrl+O on the main menu, song select
-- or results. From it you go back to the osu! or Quaver look, play 4K or 7K, turn pausing on or off,
-- and get what the osu! and Quaver looks have that these themes don't: osu!'s OD as the timing, Full
-- LN and Inverse, your osu! collections and pattern groups as song filters, the pointer picker and
-- your play time per key mode. It is drawn the way the theme draws its own panels.
local THEMES = {
	{ name = "VSRG Hub osu!", label = "osu!", sub = "osu!'s interface, from your osu! skin" },
	{ name = "VSRG Hub lazer", label = "osu!lazer", sub = "osu!lazer's interface" },
	{ name = "VSRG Hub Quaver", label = "Quaver", sub = "Quaver's interface" },
	{ name = "Til Death", label = "Til' Death", sub = "Etterna's classic theme" },
	{ name = "Rebirth", label = "Rebirth", sub = "Etterna's newer theme" },
}
local SETTINGS = "Save/VSRGHub/settings.ini"
local MENUS = { ScreenTitleMenu = true, ScreenSelectMusic = true, ScreenEvaluationNormal = true,
	ScreenSelectProfile = true, ScreenNetSelectMusic = false }
local function ownTheme() return not THEME:GetCurThemeName():find("^VSRG Hub") end
local function isRebirth() return THEME:GetCurThemeName() == "Rebirth" end
local function topName() local top = SCREENMAN:GetTopScreen(); return top and top:GetName() or "" end

-- settings.ini, shared with the osu! and Quaver looks ------------------------------------------
local function saveKeys(kv)
	local ok, txt = pcall(function() return File.Read(SETTINGS) end)
	local lines, done = {}, {}
	for l in ((ok and txt) or ""):gmatch("[^\r\n]+") do
		local line = l
		local k = line:match("^([%w_]+)=")
		if k and kv[k] ~= nil then line = k .. "=" .. kv[k]; done[k] = true end
		lines[#lines + 1] = line
	end
	for k, v in pairs(kv) do if not done[k] then lines[#lines + 1] = k .. "=" .. v end end
	pcall(function() File.Write(SETTINGS, table.concat(lines, "\n") .. "\n") end)
	-- (the osu! and Quaver looks keep a copy while they run: theirs is read again when they load)
	if TW and TW.settings then for k, v in pairs(kv) do TW.settings[k] = v end end
end
local function readKey(k)
	local ok, txt = pcall(function() return File.Read(SETTINGS) end)
	txt = ok and type(txt) == "string" and txt or ""
	return txt:match("\n" .. k .. "=([^\r\n]*)") or txt:match("^" .. k .. "=([^\r\n]*)") or ""
end

-- Timing: Etterna's judge or osu!'s OD (as in the osu! and Quaver looks' options) --------------
local JUDGES = { [4] = "J4", [5] = "J5", [6] = "J6", [7] = "J7", [8] = "J8", [9] = "Justice" }
local function odScale(od) return (64 - 3 * od) / 45 end -- osu!mania's 300 window against Etterna's J4 Perfect
-- Quaver's judgement windows (picked or made in the Quaver look): its presets and yours, in force
-- here too (Etterna's W1..W5 at the J4 scale)
local QV_STANDARD = { 18, 43, 76, 106, 127, 164 }
local QV_PRESETS = { { "Peaceful", -3 }, { "Lenient", -2 }, { "Chill", -1 }, { "Standard", 0 }, { "Strict", 1 },
	{ "Tough", 2 }, { "Extreme", 3 }, { "Impossible", 8 } }
local function qvWindows(name)
	for _, p in ipairs(QV_PRESETS) do
		if p[1] == name then
			local out = {}
			for i, v in ipairs(QV_STANDARD) do
				if p[2] > 0 and i >= 5 then out[i] = v else out[i] = math.floor(v * 1.1 ^ (-p[2]) + 1e-9) end
			end
			return out
		end
	end
	for n, list in readKey("qv_custom"):gmatch("([^:;]+):([%d,%.]+)") do
		if n == name then
			local w = {}
			for v in list:gmatch("[%d%.]+") do w[#w + 1] = tonumber(v) end
			if #w == 6 then return w end
		end
	end
	return nil
end
local function qvCustomNames()
	local out = {}
	for n in readKey("qv_custom"):gmatch("([^:;]+):[%d,%.]+") do out[#out + 1] = n end
	return out
end
local ETT_WINDOWS = { 0.0225, 0.045, 0.090, 0.135, 0.180 }
local function setWindows(ms)
	for i = 1, 5 do
		local sec = ms and math.min(0.18, math.max(0.001, ms[i] / 1000)) or ETT_WINDOWS[i]
		pcall(function() PREFSMAN:SetPreference("TimingWindowSecondsW" .. i, sec) end)
	end
end
local function timingMode()
	local qv = readKey("qv_windows")
	if qv ~= "" and qvWindows(qv) then return "quaver", qv end
	local od = tonumber(readKey("osu_od"))
	if od then return "od", od end
	local ok, j = pcall(GetTimingDifficulty)
	return "judge", math.max(4, math.min(9, (ok and j) or 4))
end
local function timingLabel()
	local m, v = timingMode()
	if m == "quaver" then return "Quaver " .. v end
	return m == "od" and string.format("osu! OD %g", v) or ("Etterna " .. JUDGES[v])
end
local function setJudge(n)
	pcall(function() SetTimingDifficulty(GAMESTATE:GetTimingScales()[n]) end)
	setWindows(nil)
	saveKeys { osu_od = "", qv_windows = "" }
	MESSAGEMAN:Broadcast("TWTimingChanged")
end
local function setOD(od)
	pcall(SetTimingDifficulty, odScale(od))
	setWindows(nil)
	saveKeys { osu_od = tostring(od), qv_windows = "" }
	MESSAGEMAN:Broadcast("TWTimingChanged")
end
local function setQuaver(name)
	local w = qvWindows(name)
	if not w then return end
	setWindows(w)
	pcall(SetTimingDifficulty, 1)
	saveKeys { osu_od = "", qv_windows = name }
	MESSAGEMAN:Broadcast("TWTimingChanged")
end
-- (the windows picked last time, in force again: Etterna starts on its own)
do
	local m, v = timingMode()
	if m == "quaver" then setWindows(qvWindows(v)) end
end

-- Full LN and Inverse: the osu! look's converter (Songs/VSRG Hub Mods), loaded here as well -------
local function lnMods()
	if not (TW and TW.lnModChart) then
		TW = TW or { lite = true }
		pcall(dofile, "/Themes/VSRG Hub osu!/Scripts/26 VSRG Hub lnmods.lua")
	end
	return TW and TW.lnModChart ~= nil
end
local LN_NAMES = { FLN = "Full LN", INV = "Inverse" }
local function lnLabel() return TW and TW.lnMod and LN_NAMES[TW.lnMod] or "Off" end

-- Play time per key mode (Etterna counts only the total): each saved play by its chart's keys
local playCache = {}
local function playTimes()
	local n = 0
	pcall(function() n = SCOREMAN:GetTotalNumberOfScores() end)
	if playCache.n == n and playCache.v then return playCache.v end
	local k4, k7, sum = 0, 0, 0
	pcall(function()
		SCOREMAN:SortRecentScores()
		local kinds = {}
		local i = 1
		while true do
			local hs = SCOREMAN:GetRecentScore(i)
			if not hs then break end
			local sec = hs:GetPlayedSeconds() or 0
			local ck = hs:GetChartKey()
			local kind = kinds[ck]
			if kind == nil then
				kind = ""
				local st = SONGMAN:GetStepsByChartKey(ck)
				if st then
					local t = tostring(st:GetStepsType())
					kind = t == "StepsType_Dance_Single" and "4" or (t == "StepsType_Kb7_Single" and "7" or "")
				end
				kinds[ck] = kind
			end
			if kind == "4" then k4 = k4 + sec elseif kind == "7" then k7 = k7 + sec end
			sum = sum + sec
			i = i + 1
		end
	end)
	local total = sum
	pcall(function() total = math.max(sum, PROFILEMAN:GetProfile(PLAYER_1):GetTotalGameplaySeconds()) end)
	-- (on the title screen Etterna hasn't loaded the profile yet: its saved total, scores later)
	if n == 0 then
		pcall(function()
			local lp = PROFILEMAN:GetLocalProfile(PREFSMAN:GetPreference("DefaultLocalProfileIDP1"))
			if lp then total = math.max(total, lp:GetTotalGameplaySeconds()) end
		end)
	end
	playCache = { n = n, v = { k4 = k4, k7 = k7, total = total, early = n == 0 } }
	return playCache.v
end
local function hm(sec)
	sec = math.floor(sec or 0)
	return string.format("%dh %02dm", math.floor(sec / 3600), math.floor(sec / 60) % 60)
end

-- The pointer (Etterna's, Quaver's or any osu! skin's), as the looks' Cursor option picks it -----
local function cursorItems()
	if not TW_SKINS then pcall(dofile, "/Themes/VSRG Hub osu!/Scripts/00 VSRG Hub skin.lua") end
	local items = {
		{ label = "Etterna", sub = "the theme's own pointer", cur = { kind = "etterna" } },
		{ label = "Quaver", sub = "Quaver's pointer", cur = { kind = "quaver", file = "/Themes/VSRG Hub Quaver/Graphics/_quaver cursor.png" } },
	}
	local folders = {}
	for folder, s in pairs(TW_SKINS or {}) do
		if s.files and s.files.cursor then folders[#folders + 1] = folder end
	end
	table.sort(folders, function(a, b) return (TW_SKINS[a].name or a):lower() < (TW_SKINS[b].name or b):lower() end)
	for _, folder in ipairs(folders) do
		local s = TW_SKINS[folder]
		local f = s.files
		items[#items + 1] = { label = s.name or folder, sub = "osu! skin" .. ((s.hd and s.hd.cursor) and ", @2x" or ""), id = "osu:" .. folder,
			cur = { kind = "osu", file = s.dir .. f.cursor, hd = s.hd ~= nil and s.hd.cursor == true,
				centre = s.cursorCentre ~= false, rotate = s.cursorRotate ~= false } }
	end
	return items
end
local function setCursor(it)
	local c = it.cur
	saveKeys { cursor = it.id or c.kind, cursorKind = c.kind, cursorFile = c.file or "",
		cursorHd = c.hd and "1" or "0", cursorCentre = c.centre == false and "0" or "1", cursorRotate = c.rotate and "1" or "0" }
	MESSAGEMAN:Broadcast("TWCursorChanged")
end
local function cursorLabel()
	local kind, file = readKey("cursorKind"), readKey("cursorFile")
	if kind == "quaver" then return "Quaver" end
	if kind == "osu" then
		local folder = readKey("cursor"):match("^osu:(.*)$")
		return folder and (folder:gsub("^[%s_%-#]+", "")) or "osu! skin"
	end
	return "Etterna"
end

-- Song filters, as in the osu! and Quaver looks: the wheel shows only the charts of an osu!
-- collection (TW_COLLECTIONS, written by VSRG Hub), an Etterna playlist or a pattern type.
TWFilter = TWFilter -- { kind, name, keys } while one is on
local function diffName(st)
	local d = ""
	pcall(function() d = st:GetChartName() end)
	if d == nil or d == "" then pcall(function() d = st:GetDescription() end) end
	return d or ""
end
local function collectionKeys(c)
	local want = {}
	for _, ch in ipairs(c.charts or {}) do
		want[ch[1]] = want[ch[1]] or {}
		table.insert(want[ch[1]], (ch[2] or ""):lower())
	end
	local keys = {}
	for _, song in ipairs(SONGMAN:GetAllSongs()) do
		local dir = (song:GetSongDir() or ""):gsub("\\", "/"):gsub("/+$", "")
		local a, b = dir:match("([^/]+)/([^/]+)$")
		local diffs = a and want[(a .. "/" .. b):lower()]
		if diffs then
			local hit = false
			for _, st in ipairs(song:GetAllSteps()) do
				local dn = diffName(st):lower()
				for _, d in ipairs(diffs) do
					if d == "" or dn == d or dn:find(d, 1, true) then keys[#keys + 1] = st:GetChartKey(); hit = true; break end
				end
			end
			if not hit then for _, st in ipairs(song:GetAllSteps()) do keys[#keys + 1] = st:GetChartKey() end end
		end
	end
	return keys
end
local PATTERNS = { [2] = "Stream", [3] = "Jumpstream", [4] = "Handstream", [5] = "Stamina", [6] = "JackSpeed", [7] = "Chordjack", [8] = "Technical" }
local function patternKeys(i)
	local rate = 1
	pcall(function() rate = getCurRateValue() end)
	local out = {}
	for _, song in ipairs(SONGMAN:GetAllSongs()) do
		for _, st in ipairs(song:GetChartsOfCurrentGameMode()) do
			local vals, best = {}, 0
			for k = 2, 8 do
				local ok, v = pcall(function() return st:GetMSD(rate, k) end)
				vals[k] = ok and v or 0
				if vals[k] > best then best = vals[k] end
			end
			if best > 0 and vals[i] >= best * 0.9 then out[#out + 1] = st:GetChartKey() end
		end
	end
	return out
end
-- Til Death filters Etterna's song wheel; Rebirth draws its own wheel from WHEELDATA, so the filter
-- goes into Rebirth's filter instead (its "valid" check, for songs and charts) and the wheel reloads.
local function rebirthWheel()
	local top = SCREENMAN:GetTopScreen()
	return isRebirth() and WHEELDATA and top and top:GetChild("WheelFile") or nil
end
local function setWheelFilter(keys)
	local top = SCREENMAN:GetTopScreen()
	local rw = rebirthWheel()
	if rw then
		if keys and #keys > 0 then
			local set = {}
			for _, k in ipairs(keys) do set[k] = true end
			WHEELDATA.ActiveFilter.valid = function(x)
				if x.GetChartKey then return set[x:GetChartKey()] == true end
				for _, st in ipairs(x:GetChartsOfCurrentGameMode() or {}) do if set[st:GetChartKey()] then return true end end
				return false
			end
		else
			WHEELDATA.ActiveFilter.valid = nil
		end
		pcall(function() rw:playcommand("ApplyFilter") end)
		return
	end
	local w = top and top.GetMusicWheel and top:GetMusicWheel()
	if w then w:FilterByStepKeys(keys or {}) end
end
local function applyFilter(kind, name, keys)
	if not kind then
		TWFilter = nil
		setWheelFilter({})
		SCREENMAN:SystemMessage("Showing every song")
		return
	end
	if #keys == 0 then
		SCREENMAN:SystemMessage("No songs from \"" .. name .. "\" are here")
		return
	end
	TWFilter = { kind = kind, name = name, keys = keys }
	setWheelFilter(keys)
	SCREENMAN:SystemMessage("Showing " .. name)
end
-- (a picked chart: Til Death moves Etterna's wheel, Rebirth its own)
local function selectChart(song, steps)
	local rw = rebirthWheel()
	if rw then
		pcall(function() rw:playcommand("FindSong", { chartkey = steps:GetChartKey() }) end)
		return
	end
	local top = SCREENMAN:GetTopScreen()
	local w = top and top.GetMusicWheel and top:GetMusicWheel()
	pcall(function()
		GAMESTATE:SetPreferredDifficulty(PLAYER_1, steps:GetDifficulty())
		if w and w:SelectSong(song) then GAMESTATE:SetCurrentSteps(PLAYER_1, steps) end
	end)
end

-- the menu's lists ------------------------------------------------------------------------------
-- an item: { label, sub, value (shown on the right), on (highlighted value), act() / menu = fn, back,
-- change(d) (left / right step it), head (a section's title), pv (what the preview shows) }; a list
-- can have preview = "notes" / "combo" / "cursor" (drawn beside it)
local function backItem() return { label = "Back", sub = "to the VSRG Hub menu", back = true } end
local close, openSpecList, saveTheme -- (the menu's own, below)
local mainMenu -- (below)
local function filterMenu(which)
	local items = { { label = "All songs", sub = "no filter", act = function() applyFilter(nil); return "close" end } }
	if which == "collections" then
		for _, c in ipairs(TW_COLLECTIONS or {}) do
			items[#items + 1] = { label = c.name, sub = "osu! collection, " .. (c.maps or 0) .. " maps",
				on = TWFilter and TWFilter.name == c.name,
				act = function() applyFilter("collection", c.name, collectionKeys(c)); return "close" end }
		end
		local ok, pls = pcall(function() return SONGMAN:GetPlaylists() end)
		for _, pl in ipairs(ok and pls or {}) do
			local name = pl:GetName()
			items[#items + 1] = { label = name, sub = "playlist, " .. pl:GetNumCharts() .. " charts",
				on = TWFilter and TWFilter.name == name,
				act = function()
					pcall(function() SONGMAN:SetActivePlaylist(name) end)
					applyFilter("playlist", name, pl:GetChartkeys() or {})
					return "close"
				end }
		end
		if #items == 1 then items[1].sub = "no osu! collections or playlists yet" end
	else
		for i = 2, 8 do
			items[#items + 1] = { label = PATTERNS[i] == "JackSpeed" and "Jackspeed" or PATTERNS[i],
				sub = "charts rated highest (within 10%) in " .. PATTERNS[i], on = TWFilter and TWFilter.name == PATTERNS[i],
				act = function() applyFilter("pattern", PATTERNS[i], patternKeys(i)); return "close" end }
		end
	end
	items[#items + 1] = backItem()
	return items
end
local function timingMenu()
	local m, v = timingMode()
	local items = {}
	for j = 4, 9 do
		items[#items + 1] = { label = "Etterna " .. JUDGES[j], sub = j == 4 and "Etterna's usual judge" or "stricter windows",
			on = m == "judge" and v == j, act = function() setJudge(j); return "back" end }
	end
	for od = 10, 0, -1 do
		items[#items + 1] = { label = "osu! OD " .. od, sub = string.format("osu!mania's windows (300: %d ms); scores stay Etterna scores", 64 - 3 * od),
			on = m == "od" and v == od, act = function() setOD(od); return "back" end }
	end
	local names = {}
	for _, p in ipairs(QV_PRESETS) do names[#names + 1] = p[1] end
	for _, n in ipairs(qvCustomNames()) do names[#names + 1] = n end
	for _, n in ipairs(names) do
		local w = qvWindows(n)
		if w then
			items[#items + 1] = { label = "Quaver " .. n .. (n == "Standard" and "*" or ""),
				sub = string.format("Quaver's windows (Marvelous %d, Perfect %d, Great %d, Good %d, Okay %d ms)", w[1], w[2], w[3], w[4], w[5]),
				on = m == "quaver" and v == n, act = function() setQuaver(n); return "back" end }
		end
	end
	items[#items + 1] = backItem()
	return items
end
local function cursorMenu()
	local items = cursorItems()
	items.preview = "cursor"
	local cur = readKey("cursor")
	for _, it in ipairs(items) do
		it.pv = it.cur
		local val = it.id or it.cur.kind
		it.on = cur == val or (cur == "" and val == "etterna")
		it.value = it.on and "in use" or nil
		it.act = function() setCursor(it); return "back" end
	end
	local size = tonumber(readKey("cursorSize")) or 1
	for _, z in ipairs({ 0.5, 0.75, 1, 1.25, 1.5, 2 }) do
		items[#items + 1] = { label = string.format("Pointer size %gx", z), sub = "how big the pointer is drawn",
			on = math.abs(size - z) < 0.01, value = math.abs(size - z) < 0.01 and "in use" or nil, act = function() saveKeys { cursorSize = string.format("%.2f", z) }; MESSAGEMAN:Broadcast("TWCursorChanged"); return "stay" end }
	end
	items[#items + 1] = backItem()
	return items
end

-- Keybinds: every key worth knowing in this theme, by category (TWKeys, "VSRG Hub keys.lua"); VSRG Hub's
-- shortcuts and Etterna's note / restart / rate keys are changed here (Enter, then the new key)
local function keyCategory(c)
	return function()
		local items = {}
		for _, r in ipairs(c.rows) do
			local edit = TWKeys.editable(r)
			items[#items + 1] = { label = r.label, value = TWKeys.rowText(r), sub = r.desc or (edit and "Enter: change   Delete: default" or nil),
				on = edit, info = not edit, keyRow = r,
				act = edit and function() TWKeys.capture(r); return "stay" end or nil }
		end
		items[#items + 1] = backItem()
		return items
	end
end
local function keybindsMenu()
	local items = {}
	if not TWKeys then return { backItem() } end
	for _, c in ipairs(TWKeys.catalog()) do
		local n, e = #c.rows, 0
		for _, r in ipairs(c.rows) do if TWKeys.editable(r) then e = e + 1 end end
		items[#items + 1] = { label = c.title, value = n .. " keys", on = true,
			sub = e > 0 and (e .. " of them can be changed here") or "to know", menu = keyCategory(c), title = "Keybinds: " .. c.title }
	end
	items[#items + 1] = { label = "VSRG Hub's shortcuts back to default", sub = "Etterna's key map is left as it is",
		act = function() TWKeys.resetAll(); return "stay" end }
	items[#items + 1] = backItem()
	return items
end

-- what the osu! and Quaver looks' options have, here too ------------------------------------------
local function po(level) return GAMESTATE:GetPlayerState():GetPlayerOptions(level or "ModsLevel_Preferred") end
local LEVELS = { "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song" }
local function scrollText()
	local p = po()
	local c = p:CMod()
	if c and c > 0 then return string.format("C%d", c) end
	local m = p:MMod()
	if m and m > 0 then return string.format("M%d", m) end
	return string.format("%.2fx", p:XMod() or 1)
end
local function changeScroll(d)
	local p = po()
	local c, m = p:CMod(), p:MMod()
	if c and c > 0 then
		for _, lvl in ipairs(LEVELS) do po(lvl):CMod(math.max(10, c + d * 10)) end
	elseif m and m > 0 then
		for _, lvl in ipairs(LEVELS) do po(lvl):MMod(math.max(10, m + d * 10)) end
	else
		local v = math.max(0.25, (p:XMod() or 1) + d * 0.05)
		for _, lvl in ipairs(LEVELS) do po(lvl):XMod(v) end
	end
end
local function toggleReverse()
	local on = po():UsingReverse()
	for _, lvl in ipairs(LEVELS) do po(lvl):Reverse(on and 0 or 1) end
end
local function gameName()
	local ok, g = pcall(function() return GAMESTATE:GetCurrentGame():GetName() end)
	return ok and g or "dance"
end
local function prettyNoteskin(n)
	n = n or ""
	if n:find("^osu!_") then return "osu! " .. n:sub(6):gsub("_", " ") end
	if n:find("^quaver_") then return "Quaver " .. n:sub(8):gsub("_", " ") end
	return n
end
local function setNoteskin(name)
	for _, lvl in ipairs({ "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song", "ModsLevel_Current" }) do
		pcall(function() po(lvl):NoteSkin(name) end)
	end
	saveKeys { ["notes_" .. gameName()] = name:lower() }
	MESSAGEMAN:Broadcast("TWNoteskinChanged")
end
-- the noteskins of the key mode being played, each shown playing the selected chart
local function notesMenu()
	local names = NOTESKIN:GetNoteSkinNames()
	table.sort(names, function(a, b)
		local ka = (a:find("^osu!_") and "1" or (a:find("^quaver_") and "2" or "3")) .. a:lower()
		local kb = (b:find("^osu!_") and "1" or (b:find("^quaver_") and "2" or "3")) .. b:lower()
		return ka < kb
	end)
	local cur = ""
	pcall(function() cur = po():NoteSkin() or "" end)
	local items = { preview = "notes" }
	for _, n in ipairs(names) do
		local kind = n:find("^osu!_") and "osu! skin" or (n:find("^quaver_") and "Quaver skin" or "Etterna noteskin")
		items[#items + 1] = { label = prettyNoteskin(n), sub = kind, pv = n, on = n:lower() == cur:lower(),
			value = n:lower() == cur:lower() and "in use" or nil, act = function() setNoteskin(n); return "back" end }
	end
	items[#items + 1] = backItem()
	return items
end
-- the combo in any skin's digits (TWCombo: "VSRG Hub customize.lua")
local function comboMenu()
	local items = { preview = "combo" }
	local cur = TWCombo and TWCombo.current() or ""
	for _, it in ipairs(TWCombo and TWCombo.items() or {}) do
		items[#items + 1] = { label = it.label, sub = it.sub, pv = it.value, on = it.value == cur,
			value = it.value == cur and "in use" or nil,
			act = function() saveKeys { combo_skin = it.value }; MESSAGEMAN:Broadcast("TWComboSkinChanged"); return "back" end }
	end
	items[#items + 1] = backItem()
	return items
end
local function thumb7() return readKey("thumb7") == "left" and "left" or "right" end
local function customizeOn()
	local ok, on = pcall(function() return playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay end)
	return ok and on == true
end
local function setCustomize(on)
	pcall(function()
		local slot = pn_to_profile_slot(PLAYER_1)
		playerConfig:get_data(slot).CustomizeGameplay = on
		playerConfig:set_dirty(slot)
		playerConfig:save(slot)
	end)
end
-- VIDEO, PERFORMANCE and AUDIO: the osu! and Quaver looks' own rows ("29 VSRG Hub video.lua"),
-- read into a table of their own here (their lists open as this menu's lists)
local videoShim = nil
local function rowsMenu(make)
	return function()
		local items = {}
		for _, r in ipairs(make()) do
			if r.kind == "head" then
				items[#items + 1] = { label = r.text, head = true, info = true }
			elseif not r.hide then
				local v = r.value and r.value() or nil
				items[#items + 1] = { label = r.label, value = v, on = true, sub = r.desc,
					change = r.change and function(d) r.change(d) end,
					act = function()
						if r.activate then r.activate() elseif r.change then r.change(1) end
						return "stay"
					end }
			end
		end
		items[#items + 1] = backItem()
		return items
	end
end
local function videoRows()
	if not videoShim then
		videoShim = {
			closeOptions = function() if close then close() end end,
			rememberSelection = function() saveTheme(THEME:GetCurThemeName()) end,
			canFrost = function()
				local v = ""
				pcall(function() v = tostring(PREFSMAN:GetPreference("VideoRenderers") or ""):lower() end)
				return v == "" or v:sub(1, 6) == "opengl"
			end,
			openList = function(spec) if openSpecList then openSpecList(spec) end end,
			-- (a typed value: steps to pick from instead)
			openInput = function(spec)
				local cur = tonumber(spec.value) or 0
				local items = {}
				for _, d in ipairs({ -20, -5, -1, 1, 5, 20 }) do
					items[#items + 1] = { label = string.format("%+d", d), value = tostring(cur + d), sub = "to " .. (cur + d) }
				end
				if openSpecList then openSpecList { title = spec.title, items = items, onPick = spec.onDone } end
			end,
		}
		pcall(function()
			local chunk = loadstring(File.Read("/Themes/VSRG Hub osu!/Scripts/29 VSRG Hub video.lua"))
			setfenv(chunk, setmetatable({ TW = videoShim }, { __index = _G }))
			chunk()
		end)
	end
	return videoShim.videoRows and videoShim.videoRows() or {}
end

mainMenu = function()
	local out = {}
	out[#out + 1] = { label = "LOOK", head = true, info = true }
	local cur = THEME:GetCurThemeName()
	for _, t in ipairs(THEMES) do
		local ok, sel = pcall(function() return THEME:IsThemeSelectable(t.name) end)
		if ok and sel then
			out[#out + 1] = { label = "Look: " .. t.label, sub = t.sub, value = t.name == cur and "in use" or nil, on = t.name == cur, theme = t.name }
		end
	end
	local ok, g = pcall(function() return GAMESTATE:GetCurrentGame():GetName() end)
	local seven = ok and g == "kb7"
	local joined = false
	pcall(function() joined = GAMESTATE:IsHumanPlayer(PLAYER_1) end)
	if joined then
		local ns = ""
		pcall(function() ns = po():NoteSkin() or "" end)
		out[#out + 1] = { label = "Notes (" .. (seven and "7K" or "4K") .. ")", value = prettyNoteskin(ns), on = true,
			sub = "the noteskin, shown playing the selected chart", menu = notesMenu, title = "Notes (" .. (seven and "7K" or "4K") .. ")" }
	end
	out[#out + 1] = { label = "Pointer", value = cursorLabel(), on = true, sub = "Etterna's, Quaver's or an osu! skin's cursor",
		menu = cursorMenu, title = "Pointer" }
	out[#out + 1] = { label = "GAMEPLAY", head = true, info = true }
	out[#out + 1] = { label = "Keys", value = seven and "7K" or "4K", on = true,
		sub = "switch to " .. (seven and "4" or "7") .. " keys", keys = seven and "dance" or "kb7" }
	if joined then
		out[#out + 1] = { label = "Scroll speed", value = "< " .. scrollText() .. " >", on = true,
			sub = "left / right change it", change = changeScroll, act = function() changeScroll(1); return "stay" end }
		out[#out + 1] = { label = "Scroll direction", value = po():UsingReverse() and "Downscroll" or "Upscroll", on = true,
			sub = "the notes come down or go up", change = function() toggleReverse() end, act = function() toggleReverse(); return "stay" end }
	end
	local pause = TWPauseOn and TWPauseOn()
	local pk = TWKeys and TWKeys.label("pause") or "Esc"
	out[#out + 1] = { label = "Pausing", value = pause and "On" or "Off", on = pause,
		sub = pause and (pk .. " pauses a song (a paused play's score is marked invalid)") or "Esc leaves a song, as usual",
		act = function() if TWPauseToggle then TWPauseToggle() end; return "stay" end }
	local flash = TWLaneFlashOn and TWLaneFlashOn()
	out[#out + 1] = { label = "Lane flash on misses", value = flash and "On" or "Off", on = flash,
		sub = "Etterna's coloured column on a Bad or a Miss (CB Highlight)",
		act = function() if TWLaneFlashToggle then TWLaneFlashToggle() end; return "stay" end }
	out[#out + 1] = { label = "Timing", value = timingLabel(), on = true,
		sub = "Etterna's judge, osu!'s OD like osu!mania, or Quaver's windows", menu = timingMenu, title = "Timing" }
	out[#out + 1] = { label = "7K thumb on the middle key", value = thumb7() == "left" and "Left (hands 4 + 3)" or "Right (hands 3 + 4)", on = true,
		sub = "which hand plays 7K's middle column (results' hand stats)",
		change = function() saveKeys { thumb7 = thumb7() == "left" and "right" or "left" } end,
		act = function() saveKeys { thumb7 = thumb7() == "left" and "right" or "left" }; return "stay" end }
	out[#out + 1] = { label = "Customize gameplay", value = customizeOn() and "On" or "Off", on = customizeOn(),
		sub = "move and size the parts while playing (VSRG Hub's panel opens with it)",
		change = function() setCustomize(not customizeOn()) end,
		act = function() setCustomize(not customizeOn()); return "stay" end }
	if topName() == "ScreenSelectMusic" then out[#out + 1] = { label = "SONGS", head = true, info = true } end
	if topName() == "ScreenSelectMusic" and TWOpenProfile then
		out[#out + 1] = { label = "Profile", value = "open", on = true,
			sub = "your ratings for 4K and 7K, top plays, recent and most played (or click your profile corner)",
			act = function() TWOpenProfile(); return "close" end }
	end
	if topName() == "ScreenSelectMusic" then
		local practice = GAMESTATE:IsPracticeMode()
		out[#out + 1] = { label = "Practice mode", value = practice and "On" or "Off", on = practice,
			sub = "the song plays with a seek bar and loops; nothing is scored",
			act = function()
				GAMESTATE:SetPracticeMode(not GAMESTATE:IsPracticeMode())
				SCREENMAN:SystemMessage(GAMESTATE:IsPracticeMode() and "Practice Mode On" or "Practice Mode Off")
				return "stay"
			end }
		if lnMods() then
			out[#out + 1] = { label = "Long note mod", value = lnLabel(), on = TW.lnMod ~= nil,
				sub = "Full LN / Inverse play a converted copy of the chart (its own scores)",
				act = function()
					local nextMod = ({ [""] = "FLN", FLN = "INV", INV = "" })[TW.lnMod or ""]
					TW.lnMod = nextMod ~= "" and nextMod or nil
					SCREENMAN:SystemMessage("Long note mod: " .. lnLabel())
					return "stay"
				end }
		end
		out[#out + 1] = { label = "Collections and playlists", value = TWFilter and TWFilter.kind ~= "pattern" and TWFilter.name or "All",
			on = TWFilter ~= nil and TWFilter.kind ~= "pattern", sub = "show only the songs of an osu! collection or a playlist",
			menu = function() return filterMenu("collections") end, title = "Collections and playlists" }
		out[#out + 1] = { label = "Group by pattern", value = TWFilter and TWFilter.kind == "pattern" and TWFilter.name or "All",
			on = TWFilter ~= nil and TWFilter.kind == "pattern", sub = "Stream, Jumpstream, Chordjack...",
			menu = function() return filterMenu("patterns") end, title = "Group by pattern" }
	end
	local eoUser = nil
	pcall(function() if DLMAN:IsLoggedIn() then eoUser = DLMAN:GetUsername() end end)
	out[#out + 1] = { label = "EtternaOnline", value = eoUser and ("logged in as " .. eoUser) or "log in", on = true,
		sub = topName() == "ScreenSelectMusic" and "log in or out (on your profile page; it remembers you in every look)"
			or "log in from song select",
		act = function()
			if topName() ~= "ScreenSelectMusic" or not TWProfileLogin then
				SCREENMAN:SystemMessage("Log in from song select")
				return "stay"
			end
			TWProfileLogin()
			return "close"
		end }
	out[#out + 1] = { label = "SETTINGS", head = true, info = true }
	out[#out + 1] = { label = "Keybinds", value = TWKeys and TWKeys.label("keybinds") or nil, on = true,
		sub = "every useful key, by category; change VSRG Hub's and the note keys", menu = keybindsMenu, title = "Keybinds" }
	out[#out + 1] = { label = "Video, performance and audio", value = "open", on = true,
		sub = "display mode, resolution, VSync, FPS limits, volumes, audio offset...",
		menu = rowsMenu(videoRows), title = "Video, performance and audio" }
	out[#out + 1] = { label = "All Etterna options", value = "open", on = true, sub = "Etterna's own options menu",
		act = function() SCREENMAN:SetNewScreen("ScreenOptionsService"); return "close" end }
	if topName() == "ScreenSelectMusic" then
		out[#out + 1] = { label = "Player options", value = "open", on = true, sub = "Etterna's player options for the next song",
			act = function() SCREENMAN:SetNewScreen("ScreenPlayerOptions"); return "close" end }
	end
	local pt = playTimes()
	out[#out + 1] = { label = "Play time", value = hm(pt.total), info = true,
		sub = pt.early and "4K and 7K once song select has loaded your scores"
			or string.format("4K %s     7K %s     total %s", hm(pt.k4), hm(pt.k7), hm(pt.total)) }
	return out
end

-- A theme switch keeps the selected chart (the next look's song select picks it again; the osu! and
-- Quaver looks open straight on song select) and the noteskin of the key mode being played.
saveTheme = function(name)
	local kv = { theme = name, resume = "" }
	pcall(function()
		local st = GAMESTATE:GetCurrentSteps()
		kv.resumeChart = st and st:GetChartKey() or ""
		local where = topName()
		if where == "ScreenSelectMusic" or where:find("Evaluation") then kv.resume = "select" end
		local g = GAMESTATE:GetCurrentGame():GetName()
		local ns = GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin() or ""
		if ns ~= "" then kv["notes_" .. g] = ns:lower() end
	end)
	saveKeys(kv)
end

-- the menu's state and drawing -------------------------------------------------------------------
local open, cursor, list = false, 1, {}
local shownNotes = nil -- (the noteskin the preview has loaded)
local stack = {} -- the menus above the open one
local first = 1 -- the first row shown (long lists scroll)
local title = "VSRG Hub"
local frame
local function L()
	-- the theme's own measures: Til Death lays out a 480-tall screen, Rebirth a 720-tall one
	if isRebirth() then
		local u = SCREEN_HEIGHT / 720
		return { u = u, W = 620 * u, RH = 44 * u, rows = 10, pad = 16 * u, lip = 40 * u, label = 0.62, sub = 0.4, title = 0.8 }
	end
	local u = SCREEN_HEIGHT / 480
	return { u = u, W = 360 * u, RH = 30 * u, rows = 10, pad = 10 * u, lip = 24 * u, label = 0.42, sub = 0.27, title = 0.55 }
end
local function shown() return math.min(#list, L().rows) end
-- a list with a preview: the menu moves left to make room for it on the right
local function previewW(l) return list.preview and (l.W * 0.55) or 0 end
local function geometry()
	local l = L()
	local h = shown() * l.RH
	local pw = previewW(l)
	local x0 = SCREEN_CENTER_X - (l.W + (pw > 0 and (pw + l.pad * 2) or 0)) / 2
	local y0 = SCREEN_CENTER_Y - h / 2 + l.lip / 2
	return l, x0, y0, h
end
local function follow()
	local rows = L().rows
	if cursor < first then first = cursor end
	if cursor > first + rows - 1 then first = cursor - rows + 1 end
	first = math.max(1, math.min(first, math.max(1, #list - rows + 1)))
end
local function refresh() if frame then frame:playcommand("Refresh") end end
local current = nil -- makes the open list (to show its values again, or to come back to it)
local function selectable(it) return it ~= nil and not it.head end
-- the cursor moved by d, past section titles
local function step(d)
	local i = cursor + d
	while list[i] and not selectable(list[i]) do i = i + (d > 0 and 1 or -1) end
	if list[i] then cursor = i end
end
local function showList(make, newTitle, keepCursor)
	current = make
	list = make()
	cursor, first = 1, 1
	if keepCursor then cursor = math.max(1, math.min(keepCursor, #list))
	else for i, it in ipairs(list) do if it.on and not it.info then cursor = i break end end end
	if not selectable(list[cursor]) then step(1) end
	title = newTitle
	follow()
	refresh()
end
close = function()
	open = false
	stack = {}
	shownNotes = nil
	refresh()
end
-- a list asked for by the osu! and Quaver looks' rows (TW.openList): its items to pick from
openSpecList = function(spec)
	stack[#stack + 1] = { make = current, title = title, cursor = cursor }
	showList(function()
		local items = {}
		for _, it in ipairs(spec.items or {}) do
			local on = spec.current ~= nil and tostring(it.value):lower() == tostring(spec.current):lower()
			items[#items + 1] = { label = it.label, sub = it.sub, on = on, value = on and "in use" or nil,
				act = function() if spec.onPick then spec.onPick(it.value) end; return "back" end }
		end
		items[#items + 1] = backItem()
		return items
	end, spec.title or "")
end
local function openMenu()
	stack = {}
	showList(mainMenu, "VSRG Hub")
	for i, it in ipairs(list) do if it.theme == THEME:GetCurThemeName() then cursor = i end end
	follow()
	open = true
	refresh()
end
local function openKeybinds()
	stack = {}
	showList(mainMenu, "VSRG Hub")
	for i, it in ipairs(list) do if it.menu == keybindsMenu then cursor = i end end
	stack[#stack + 1] = { make = current, title = title, cursor = cursor }
	showList(keybindsMenu, "Keybinds")
	open = true
	refresh()
end
local function back()
	local prev = table.remove(stack)
	if not prev then close() return end
	showList(prev.make, prev.title, prev.cursor)
end
local function pick(it)
	if not it or it.info then return end
	if it.back then back() return end
	if it.menu then
		stack[#stack + 1] = { make = current, title = title, cursor = cursor }
		showList(it.menu, it.title or it.label)
		return
	end
	if it.act then
		local r = it.act()
		if r == "close" then close()
		elseif r == "back" then back()
		else showList(current, title, cursor) end -- (stay: the same list, its values again)
		return
	end
	if it.keys then
		close()
		pcall(function() GAMEMAN:SetGame(it.keys, THEME:GetCurThemeName()) end)
		return
	end
	if it.theme then
		if it.theme == THEME:GetCurThemeName() then close() return end
		close()
		saveTheme(it.theme)
		THEME:SetTheme(it.theme)
	end
end

local function overPreview(mx, my)
	local l, x0, y0, h = geometry()
	local pw = previewW(l)
	return pw > 0 and mx >= x0 + l.W and mx <= x0 + l.W + pw + l.pad * 2 and my >= y0 - l.lip and my <= y0 + h + l.lip
end
local function rowAt(mx, my)
	local l, x0, y0 = geometry()
	for j = 1, shown() do
		local y = y0 + (j - 1) * l.RH
		if mx >= x0 and mx <= x0 + l.W and my >= y and my <= y + l.RH then return first + j - 1 end
	end
end

-- Alt + mouse wheel changes the volume, as in the osu! and Quaver looks (and osu! / Quaver)
local function volumeKey(event)
	local b = event.DeviceInput.button
	if (b ~= "DeviceButton_mousewheel up" and b ~= "DeviceButton_mousewheel down")
		or (event.type ~= "InputEventType_FirstPress" and event.type ~= "InputEventType_Repeat") then return false end
	local ok, alt = pcall(function() return INPUTFILTER:IsBeingPressed("left alt") or INPUTFILTER:IsBeingPressed("right alt") end)
	if not (ok and alt) then return false end
	local v = 1
	pcall(function() v = PREFSMAN:GetPreference("SoundVolumeMaster") or 1 end)
	v = math.max(0, math.min(1, math.floor((v + (b == "DeviceButton_mousewheel up" and 0.05 or -0.05)) * 20 + 0.5) / 20))
	pcall(function() SOUND:SetVolume(v) end)
	SCREENMAN:SystemMessage(string.format("Volume %d%%", math.floor(v * 100 + 0.5)))
	return true
end
-- (on Etterna's system layer: it sees every key and click before the theme's screen, and taking one
-- here keeps it from the screen entirely, so Esc / Enter / the wheel never also act behind the menu)
function TWMenuIsOpen() return open end
local function input(event)
	if TWProfileIsOpen and TWProfileIsOpen() then return false end -- (the profile page has the keys)
	if not ownTheme() then return false end
	local b = event.DeviceInput.button
	if volumeKey(event) then return true end -- (Til Death would also scroll its song list)
	local first_ = event.type == "InputEventType_FirstPress"
	local function key(id, default) if TWKeys then return TWKeys.is(event, id) end return default end
	if key("options", b == "DeviceButton_o" and INPUTFILTER:IsControlPressed() and not INPUTFILTER:IsShiftPressed()) then
		if not MENUS[topName()] and not open then return false end
		-- (Etterna's own Ctrl+O, practice mode, is in the menu as a row)
		if first_ then if open then close() else openMenu() end end
		return true
	end
	if TWKeys and key("keybinds", false) then
		if not MENUS[topName()] and not open then return false end
		if first_ then openKeybinds() end
		return true
	end
	if not open then return false end
	if not first_ and event.type ~= "InputEventType_Repeat" then return true end
	if b == "DeviceButton_left mouse button" then
		if first_ then
			local i = rowAt(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY())
			if i then
				if selectable(list[i]) then cursor = i; refresh(); pick(list[i]) end
			elseif not overPreview(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()) then close() end
		end
	elseif b == "DeviceButton_left" or b == "DeviceButton_right" then
		-- a value that steps: left / right change it
		local it = list[cursor]
		if it and it.change then
			it.change(b == "DeviceButton_right" and 1 or -1)
			showList(current, title, cursor)
		end
	elseif b == "DeviceButton_right mouse button" then if first_ then back() end
	elseif b == "DeviceButton_escape" or b == "DeviceButton_backspace" then if first_ then back() end
	elseif b == "DeviceButton_up" or b == "DeviceButton_mousewheel up" then step(-1); follow(); refresh()
	elseif b == "DeviceButton_down" or b == "DeviceButton_mousewheel down" then step(1); follow(); refresh()
	elseif b == "DeviceButton_pgup" then cursor = math.max(1, cursor - L().rows); if not selectable(list[cursor]) then step(1) end; follow(); refresh()
	elseif b == "DeviceButton_pgdn" then cursor = math.min(#list, cursor + L().rows); if not selectable(list[cursor]) then step(-1) end; follow(); refresh()
	elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" or b == "DeviceButton_space" then if first_ then pick(list[cursor]) end
	elseif b == "DeviceButton_delete" then
		-- a key back to its default
		local it = list[cursor]
		if first_ and it and it.keyRow and TWKeys and TWKeys.editable(it.keyRow) then TWKeys.resetRow(it.keyRow) end
	end
	return true
end

-- colours: the theme's own (Til Death's colour config, Rebirth's colour preset)
local function C(k)
	if isRebirth() then
		local map = { body = "PrimaryBackground", lip = "SecondaryBackground", text = "PrimaryText", sub = "SecondaryText", line = "SeparationDivider" }
		local ok, c = pcall(function() return COLORS:getMainColor(map[k] or "PrimaryText") end)
		return ok and c or color((k == "body" or k == "lip") and "#111111" or "#FFFFFF")
	end
	local map = { body = "tabs", lip = "frames", text = "positive", accent = "highlight", line = "highlight" }
	local ok, c = pcall(function() return getMainColor(map[k] or "positive") end)
	local fallback = { body = "#2E2E2E", lip = "#000111", text = "#9654FD", accent = "#614080", line = "#614080" }
	return ok and c or color(fallback[k] or "#FFFFFF")
end
local function withAlpha(c, a) return { c[1], c[2], c[3], a } end

local hooked = false
local switchTo = nil
local ROWS_MAX = 10
local t = Def.ActorFrame {
	InitCommand = function(self) frame = self; self:visible(false); self:queuecommand("Hook") end,
	HookCommand = function(self)
		if hooked then return end
		local s = self
		while s:GetParent() do s = s:GetParent() end
		if s.AddInputCallback then s:AddInputCallback(input); hooked = true end
	end,
	TWKeysChangedMessageCommand = function(self) if open and current then showList(current, title, cursor) end end,
	ScreenChangedMessageCommand = function(self)
		if open then close() end
		-- VSRG Hub's own themes fall back to Til Death and so see this file too; they have their own options
		if not ownTheme() then return end
		-- Etterna goes back to the theme VSRG Hub started with when the game type changes (4K <-> 7K):
		-- on the main menu, put the picked one back
		if topName() == "ScreenTitleMenu" then
			local want = readKey("theme")
			if want ~= "" and want ~= THEME:GetCurThemeName() then
				local ok2, sel = pcall(function() return THEME:IsThemeSelectable(want) end)
				if ok2 and sel then switchTo = want; self:GetParent():sleep(0.05):queuecommand("Switch"); return end
			end
		end
	end,
	RefreshCommand = function(self)
		self:visible(open)
		if not open then return end
		local l, x0, y0, h = geometry()
		local rb = isRebirth()
		local c = self:GetChildren()
		local top = y0 - l.lip - l.pad
		local bottom = y0 + h + l.pad + l.lip
		local pw = previewW(l)
		local fullW = l.W + (pw > 0 and (pw + l.pad * 2) or 0)
		c.Dim:diffuse(color("0,0,0," .. (rb and 0.6 or 0.55)))
		c.Body:xy(x0 - l.pad, top):zoomto(fullW + l.pad * 2, bottom - top):diffuse(withAlpha(C("body"), rb and 0.97 or 0.96))
		c.LipTop:xy(x0 - l.pad, top):zoomto(fullW + l.pad * 2, l.lip):diffuse(withAlpha(C("lip"), rb and 0.95 or 0.8))
		c.LipBottom:xy(x0 - l.pad, bottom - l.lip):zoomto(fullW + l.pad * 2, l.lip):diffuse(withAlpha(C("lip"), rb and 0.95 or 0.8))
		-- Til Death edges its bars with a thin line in the highlight colour
		c.Edge:visible(not rb):xy(x0 - l.pad, top + l.lip):zoomto(fullW + l.pad * 2, 2 * l.u):diffuse(withAlpha(C("accent"), 0.5))
		c.Title:xy(x0, top + l.lip / 2):zoom(l.title):diffuse(rb and C("text") or color("#FFFFFF")):settext(title)
		-- the preview beside the list (noteskins, combo digits, pointers)
		local pv = c.Preview
		pv:visible(pw > 0)
		if pw > 0 then
			pv:xy(x0 + l.W + l.pad * 2, y0)
			local it = list[cursor]
			pv:playcommand("Show", { kind = list.preview, value = it and it.pv, w = pw, h = h, l = l, rb = rb,
				col = rb and C("text") or color("#FFFFFF"), line = rb and C("line") or C("accent") })
		end
		c.Keys:xy(x0 + fullW, top + l.lip / 2):zoom(l.sub):diffuse(rb and C("text") or color("#FFFFFF")):diffusealpha(0.6)
			:settext((TWKeys and TWKeys.label("options") or "Ctrl+O") .. " closes")
		c.Help:xy(x0, bottom - l.lip / 2):zoom(l.sub):diffuse(rb and C("text") or color("#FFFFFF")):diffusealpha(0.7)
			:settext(((list[cursor] and list[cursor].keyRow and TWKeys and TWKeys.editable(list[cursor].keyRow))
				and "Enter: new key   Delete: default key   Esc goes back"
				or ((list[cursor] and list[cursor].change) and "Left / right change it   Enter picks   Esc goes back"
				or "Click or Enter picks   Right click / Esc goes back   Wheel or arrows move"))
				.. (#list > l.rows and string.format("   (%d-%d of %d)", first, first + shown() - 1, #list) or ""))
		for j = 1, ROWS_MAX do
			local r = c["Row" .. j]
			local i = first + j - 1
			local it = j <= shown() and list[i] or nil
			r:visible(it ~= nil)
			if it then
				r:xy(x0, y0 + (j - 1) * l.RH)
				local rc = r:GetChildren()
				local sel = i == cursor
				if rb then
					-- Rebirth: plain rows, the picked one lifted a little with a white bar at its left
					rc.Bg:zoomto(l.W, l.RH - 2 * l.u):diffuse(color("1,1,1," .. (sel and 0.12 or 0.03)))
					rc.Mark:visible(sel):zoomto(3 * l.u, l.RH - 2 * l.u):diffuse(C("line"))
				else
					-- Til Death: tab-like rows, the picked one in the purple highlight
					rc.Bg:zoomto(l.W, l.RH - 2 * l.u):diffuse(sel and withAlpha(C("accent"), 0.75) or withAlpha(C("lip"), 0.45))
					rc.Mark:visible(sel):zoomto(2 * l.u, l.RH - 2 * l.u):diffuse(C("text"))
				end
				local labelCol = rb and C("text") or color("#FFFFFF")
				if it.head then
					-- a section's title: in the highlight colour, no box
					rc.Bg:diffuse(color("0,0,0,0"))
					rc.Mark:visible(false)
				end
				rc.Label:xy(10 * l.u, l.RH * 0.36):zoom(l.label):maxwidth((l.W * 0.62) / l.label):diffuse(labelCol)
					:diffusealpha(it.info and 0.75 or 1):settext(it.label)
				rc.Value:xy(l.W - 10 * l.u, l.RH * 0.36):zoom(l.label):maxwidth((l.W * 0.36) / l.label)
					:diffuse(rb and C("text") or (sel and color("#FFFFFF")) or (it.on and C("text") or color("#BBBBBB"))) -- (white on the purple highlight)
					:diffusealpha(it.value and ((it.info and it.keyRow) and 0.55 or 1) or 0):settext(it.value or ""):strokecolor(rb and sel and color("0.4,0.4,0.4,1") or color("0,0,0,0"))
				rc.Sub:xy(10 * l.u, l.RH * 0.76):zoom(l.sub):maxwidth((l.W - 20 * l.u) / l.sub):diffuse(labelCol):diffusealpha(0.6):settext(it.sub or "")
				if it.head then
					rc.Label:xy(4 * l.u, l.RH * 0.62):zoom(l.sub * 1.2):diffuse(rb and C("line") or C("text")):diffusealpha(1)
					rc.Value:settext("")
				end
			end
		end
	end,
	Def.Quad { Name = "Dim", InitCommand = function(self) self:FullScreen() end },
	Def.Quad { Name = "Body", InitCommand = function(self) self:align(0, 0) end },
	Def.Quad { Name = "LipTop", InitCommand = function(self) self:align(0, 0) end },
	Def.Quad { Name = "LipBottom", InitCommand = function(self) self:align(0, 0) end },
	Def.Quad { Name = "Edge", InitCommand = function(self) self:align(0, 0) end },
	LoadFont("Common Normal") .. { Name = "Title", InitCommand = function(self) self:align(0, 0.5) end },
	LoadFont("Common Normal") .. { Name = "Keys", InitCommand = function(self) self:align(1, 0.5) end },
	LoadFont("Common Normal") .. { Name = "Help", InitCommand = function(self) self:align(0, 0.5) end },
}
for i = 1, ROWS_MAX do
	t[#t + 1] = Def.ActorFrame {
		Name = "Row" .. i,
		Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0) end },
		Def.Quad { Name = "Mark", InitCommand = function(self) self:align(0, 0) end },
		LoadFont("Common Normal") .. { Name = "Label", InitCommand = function(self) self:align(0, 0.5) end },
		LoadFont("Common Normal") .. { Name = "Value", InitCommand = function(self) self:align(1, 0.5) end },
		LoadFont("Common Normal") .. { Name = "Sub", InitCommand = function(self) self:align(0, 0.5) end },
	}
end

-- The preview beside a list: the noteskin under the cursor playing the selected chart (it loads a
-- moment after the cursor stops), the combo skin's digits, or the pointer.
local function noteWidth(ns)
	if not TW_NOTESKINS then pcall(dofile, "/Themes/VSRG Hub osu!/Scripts/00 VSRG Hub skin.lua") end
	ns = (ns or ""):lower()
	local g = TW_NOTESKINS_GAME and TW_NOTESKINS_GAME[gameName()]
	local info = (g and g[ns]) or (TW_NOTESKINS and TW_NOTESKINS[ns])
	return info and info.width or 64
end
local preview = Def.ActorFrame {
	Name = "Preview",
	ShowCommand = function(self, p)
		local c = self:GetChildren()
		local w, h, l = p.w, p.h, p.l
		self.box = p
		c.Bg:zoomto(w, h):diffuse(color(p.rb and "1,1,1,0.04" or "0,0,0,0.45"))
		c.Top:zoomto(w, 2 * l.u):diffuse(p.line)
		c.Note:xy(w / 2, h - 8 * l.u):zoom(l.sub):maxwidth((w - 10 * l.u) / l.sub):diffuse(p.col):diffusealpha(0.7)
		c.Field:visible(p.kind == "notes")
		c.Combo:visible(p.kind == "combo")
		c.Pointer:visible(p.kind == "cursor")
		if p.kind == "notes" then
			if not GAMESTATE:GetCurrentSteps() then
				c.Field:visible(false)
				c.Note:settext("pick a song to see the notes played")
				return
			end
			c.Note:settext(p.value and prettyNoteskin(p.value) or "")
			if p.value and p.value ~= shownNotes then self:stoptweening():sleep(0.2):queuecommand("LoadNotes") end
		elseif p.kind == "combo" then
			local pics = TWCombo and p.value and TWCombo.pics(p.value)
			local row = c.Combo:GetChild("Row")
			c.Combo:xy(w / 2, h / 2)
			c.Combo:GetChild("Plain"):visible(pics == nil):zoom(1.2 * l.u * 2):diffuse(p.col):settext("727")
			c.Note:settext(pics and "the combo, as it will look" or "the theme's own combo")
			local x, ht = 0, 1
			for i = 1, 3 do
				local spr = row:GetChild("D" .. i)
				local path = pics and pics[tonumber(("727"):sub(i, i))]
				spr:visible(path ~= nil)
				if path then
					spr:Load(path):align(0, 0.5):zoom(pics.zoom):x(x)
					x = x + spr:GetZoomedWidth() - (i < 3 and pics.overlap or 0)
					ht = math.max(ht, spr:GetZoomedHeight())
				end
			end
			local fit = math.min(2.5 * l.u, w * 0.8 / math.max(1, x), h * 0.45 / ht)
			row:zoom(fit):x(-x * fit / 2)
		elseif p.kind == "cursor" then
			local cur = p.value or {}
			local img, dia = c.Pointer:GetChild("Img"), c.Pointer:GetChild("Diamond")
			c.Pointer:xy(w / 2, h / 2)
			local useImg = (cur.kind == "osu" or cur.kind == "quaver") and cur.file and cur.file ~= ""
			if useImg then useImg = pcall(function() img:Load(cur.file) end) end
			img:visible(useImg == true)
			dia:visible(not useImg)
			if useImg then
				if cur.kind == "quaver" then img:align(0.5, 0.5):zoomto(40 * l.u * 2, 40 * l.u * 2)
				else img:align(0.5, 0.5):zoom(SCREEN_HEIGHT / 768 * (cur.hd and 0.5 or 1) * 2) end
			end
			c.Note:settext(cur.kind == "osu" and "osu! skin pointer (shown at 2x)" or (cur.kind == "quaver" and "Quaver's pointer" or "Etterna's pointer"))
		end
	end,
	LoadNotesCommand = function(self)
		local p = self.box
		local it = list[cursor]
		if not (p and it and it.pv and open and list.preview == "notes") then return end
		local ns = it.pv
		shownNotes = ns
		local ff = self:GetChild("Field")
		-- (made the first time it's needed: made with the menu, Etterna's notefield would load before
		-- there is a profile and a style)
		local nf = ff:GetChild("NoteField")
		if not nf then
			pcall(function()
				ff:AddChild(Def.NoteFieldPreview { Name = "NoteField", DrawDistanceBeforeTargetsPixels = 600, DrawDistanceAfterTargetsPixels = 0 })
			end)
			nf = ff:GetChild("NoteField")
			if not nf then return end
		end
		local steps = GAMESTATE:GetCurrentSteps()
		if not steps then return end
		-- (Etterna's preview loads the noteskin the player has: the one to show is put there just
		-- while it loads)
		local ps = GAMESTATE:GetPlayerState()
		local keep = {}
		for _, lvl in ipairs({ "ModsLevel_Stage", "ModsLevel_Current" }) do
			keep[lvl] = ps:GetPlayerOptions(lvl):NoteSkin()
			ps:GetPlayerOptions(lvl):NoteSkin(ns)
		end
		pcall(function() nf:LoadNoteData(steps) end)
		for lvl, v in pairs(keep) do ps:GetPlayerOptions(lvl):NoteSkin(v) end
		local w = noteWidth(ns)
		local cols = nf:get_column_actors()
		local n = math.max(1, #cols)
		for i, col in ipairs(cols) do col:x((i - (n + 1) / 2) * (w - 64)) end
		local zoom = math.min(1, p.w * 0.86 / (n * w))
		local rev = po():UsingReverse()
		local ry = THEME:GetMetric("Player", rev and "ReceptorArrowsYReverse" or "ReceptorArrowsYStandard")
		local edge = 30 * p.l.u
		local target = rev and (p.h - edge) or edge
		ff:xy(p.w / 2, target - ry * zoom):zoom(zoom)
		local mini = 0
		pcall(function() mini = po():Mini() or 0 end)
		local miniZoom = math.max(0.1, 1 - mini * 0.5)
		local scale = zoom * (1 + math.abs(mini)) * miniZoom
		nf:UpdateDrawDistance(0, math.max(1, math.floor((p.h - edge - 20 * p.l.u) / scale)))
	end,
	Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0) end },
	Def.Quad { Name = "Top", InitCommand = function(self) self:align(0, 0) end },
	Def.ActorFrame { Name = "Field" },
	Def.ActorFrame {
		Name = "Combo",
		Def.ActorFrame {
			Name = "Row",
			Def.Sprite { Name = "D1", InitCommand = function(self) self:visible(false) end },
			Def.Sprite { Name = "D2", InitCommand = function(self) self:visible(false) end },
			Def.Sprite { Name = "D3", InitCommand = function(self) self:visible(false) end },
		},
		LoadFont("Common Normal") .. { Name = "Plain", InitCommand = function(self) self:visible(false) end },
	},
	Def.ActorFrame {
		Name = "Pointer",
		Def.Sprite { Name = "Img", InitCommand = function(self) self:visible(false) end },
		Def.ActorFrame {
			Name = "Diamond",
			Def.Quad { InitCommand = function(self) self:rotationz(45):zoomto(16, 16):diffuse(color("#000000")):diffusealpha(0.6) end },
			Def.Quad { InitCommand = function(self) self:rotationz(45):zoomto(13, 13):diffuse(color("#FFFFFF")) end },
		},
	},
	LoadFont("Common Normal") .. { Name = "Note", InitCommand = function(self) self:align(0.5, 1) end },
}
t[#t + 1] = preview

-- song select in these themes: a filter picked here stays on when song select comes back (after a
-- song, as in the osu! look); after a theme switch it picks the chart that was selected in the other
-- look; the Long note mod swaps in the converted chart when a song starts and puts the original
-- back after
local lnPending = false
t[#t + 1] = Def.ActorFrame {
	ScreenChangedMessageCommand = function(self)
		if not ownTheme() then return end
		local name = topName()
		if name == "ScreenSelectMusic" then
			self:stoptweening()
			if TW and TW.lnOrig then self:sleep(0.15):queuecommand("LnBack") end
			if TWFilter then self:sleep(0.1):queuecommand("Refilter") end
			if readKey("resumeChart") ~= "" then self:sleep(0.05):queuecommand("Resume") end
		end
	end,
	StepsChosenMessageCommand = function(self)
		if not ownTheme() or topName() ~= "ScreenSelectMusic" then return end
		if not (TW and TW.lnMod and TW.lnModChart) then return end
		local replay = false
		pcall(function() replay = GAMESTATE:GetGameplayMode() ~= "GameplayMode_Normal" and GAMESTATE:GetGameplayMode() ~= "GameplayMode_Practice" end)
		if replay then return end
		TW.songChosen = true
		pcall(TW.applyLnModOnStart)
	end,
	LnBackCommand = function()
		local o = TW and TW.lnOrig
		if TW then TW.lnOrig = nil; TW.songChosen = false end
		if o then selectChart(o.song, o.steps) end
	end,
	ResumeCommand = function()
		local key = readKey("resumeChart")
		if key == "" then return end
		saveKeys { resumeChart = "" }
		pcall(function()
			local song, steps = SONGMAN:GetSongByChartKey(key), SONGMAN:GetStepsByChartKey(key)
			if song and steps then selectChart(song, steps) end
		end)
	end,
	RefilterCommand = function()
		if TWFilter and TWFilter.keys then setWheelFilter(TWFilter.keys) end
	end,
}

-- Til Death's chart preview, drawn smaller (same proportions) so it takes less of the screen
local PREVIEW_SCALE = 0.72
local function findChild(actor, name, depth)
	if not actor or (depth or 0) > 6 then return nil end
	local ok, kids = pcall(function() return actor:GetChildren() end)
	if not ok or type(kids) ~= "table" then return nil end
	if kids[name] then return kids[name] end
	for _, c in pairs(kids) do
		local list = (type(c) == "table" and c[1]) and c or { c }
		for _, a in ipairs(list) do
			local f = findChild(a, name, (depth or 0) + 1)
			if f then return f end
		end
	end
	return nil
end
local scaled = setmetatable({}, { __mode = "k" })
local function shrinkPreview()
	if THEME:GetCurThemeName() ~= "Til Death" then return end
	local top = SCREENMAN:GetTopScreen()
	local cp = top and findChild(top, "ChartPreview")
	if not cp then return end
	local nf, bg = cp:GetChild("NoteField"), cp:GetChild("BG")
	if nf and not scaled[nf] then
		scaled[nf] = true
		nf:zoom(nf:GetZoom() * PREVIEW_SCALE)
	end
	if bg then
		local cols = GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()
		bg:zoomto(48 * cols * PREVIEW_SCALE, SCREEN_HEIGHT)
	end
end

-- Etterna's pointer: Til Death and Rebirth show it only in true fullscreen and leave Windows' arrow
-- in a window. Here Etterna's pointer is drawn in a window too and Windows' arrow is hidden over the
-- game (it comes back over the window's title bar and borders). Like Etterna, no pointer while
-- playing, except in practice, replays and Customize Gameplay.
local function etternaPointer()
	local hidden, again = false, 0
	local function osArrow(show) pcall(function() Arch.setCursorVisible(show) end) end
	local function wanted(top)
		local name = top and top:GetName() or ""
		if not name:find("Gameplay") then return true end
		local ok, on = pcall(function()
			return GAMESTATE:IsPracticeMode() or GAMESTATE:GetGameplayMode() == "GameplayMode_Replay"
				or playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay == true
		end)
		return ok and on
	end
	local s = 5 * SCREEN_HEIGHT / 480
	-- the pointer picked in the osu! / Quaver looks' options (Cursor), when it isn't Etterna's own
	local picked = ""
	local function loadPicked(self)
		local ok, txt = pcall(function() return File.Read(SETTINGS) end)
		txt = ok and type(txt) == "string" and txt or ""
		local function get(k) return txt:match("\n" .. k .. "=([^\r\n]*)") or txt:match("^" .. k .. "=([^\r\n]*)") or "" end
		local kind, file = get("cursorKind"), get("cursorFile")
		local size = math.max(0.5, math.min(2, tonumber(get("cursorSize")) or 1))
		local key = kind .. "|" .. file .. "|" .. size
		if key == picked then return end
		picked = key
		local img = self:GetChild("Img")
		local u = SCREEN_HEIGHT / 768
		local useImg = (kind == "osu" or kind == "quaver") and file ~= ""
		if useImg then
			local ok2 = pcall(function() img:Load(file) end)
			useImg = ok2
		end
		img:visible(useImg):stopeffect():rotationz(0)
		self:GetChild("Diamond"):visible(not useImg)
		if not useImg then return end
		if kind == "quaver" then
			img:align(0, 0):zoomto(40 * u * size, 40 * u * size)
		else
			local a = get("cursorCentre") == "0" and 0 or 0.5
			img:align(a, a):zoom(u * (get("cursorHd") == "1" and 0.5 or 1) * size)
			if get("cursorRotate") ~= "0" then img:spin():effectmagnitude(0, 0, 36) end
		end
	end
	return Def.ActorFrame {
		-- Etterna's own copy of the pointer (shown in true fullscreen) would double this one
		ScreenChangedMessageCommand = function(self) hidden = false; loadPicked(self); self:stoptweening():sleep(0.2):queuecommand("NoTooltip") end,
		TWCursorChangedMessageCommand = function(self) picked = ""; loadPicked(self) end,
		WindowedChangedMessageCommand = function(self) self:stoptweening():sleep(0.2):queuecommand("NoTooltip") end,
		NoTooltipCommand = function(self)
			if not THEME:GetCurThemeName():find("^VSRG Hub") then pcall(function() TOOLTIP:HidePointer() end) end
		end,
		InitCommand = function(self)
			self:draworder(10001):visible(false)
			self:SetUpdateFunction(function(_, dt)
				-- VSRG Hub's own looks draw their own pointer
				if THEME:GetCurThemeName():find("^VSRG Hub") then self:visible(false) return end
				local x, y = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				local inside = x >= 0 and y >= 0 and x <= SCREEN_WIDTH and y <= SCREEN_HEIGHT
				local top = SCREENMAN:GetTopScreen()
				local want = wanted(top)
				-- in play without a pointer Etterna hides Windows' arrow itself
				local hide = inside
				again = again + (dt or 0)
				if again > 1 then again = 0; if hide and hidden then osArrow(true); hidden = false end end
				if hide ~= hidden then hidden = hide; osArrow(not hide) end
				self:visible(inside and want):xy(x, y)
			end)
		end,
		Def.ActorFrame {
			Name = "Diamond",
			Def.Quad { InitCommand = function(self) self:rotationz(45):zoomto(s + 2, s + 2):diffuse(color("#000000")):diffusealpha(0.6) end },
			Def.Quad { InitCommand = function(self) self:rotationz(45):zoomto(s, s):diffuse(color("#FFFFFF")) end },
		},
		Def.Sprite { Name = "Img", InitCommand = function(self) self:visible(false) end },
	}
end

-- The osu! and Quaver looks take the keyboard for their own menus (input redirected); a look
-- switched to from one of them gets it back, or its menus wouldn't hear the arrows and Enter.
local freedInput = false
local function freeInput()
	if freedInput or not ownTheme() then return end
	freedInput = true
	pcall(function() SCREENMAN:set_input_redirected(PLAYER_1, false) end)
end
return Def.ActorFrame {
	OnCommand = function(self) freeInput() end,
	ScreenChangedMessageCommand = function(self) freeInput() end,
	ChartPreviewOnMessageCommand = function(self) self:sleep(0.02):queuecommand("Shrink") end,
	CurrentStyleChangedMessageCommand = function(self) self:sleep(0.02):queuecommand("Shrink") end,
	ShrinkCommand = function(self) shrinkPreview() end,
	SwitchCommand = function(self) if switchTo then local w = switchTo; switchTo = nil; THEME:SetTheme(w) end end,
	LoadActor("VSRG Hub keys.lua"), -- TWKeys (first: it takes the key being picked before anything else)
	LoadActor("/Themes/_fallback/BGAnimations/ScreenSystemLayer error.lua"),
	LoadActor("VSRG Hub pause.lua"),
	LoadActor("VSRG Hub collections.lua"), -- TW_COLLECTIONS: your osu! collections, for the picker's filter
	LoadActor("VSRG Hub customize.lua"), -- Customize Gameplay's panel and the noteskin settings (TWL)
	t,
	LoadActor("VSRG Hub profile.lua"), -- your profile page (TWOpenProfile), over this menu
	etternaPointer(), -- last: over the pause menu and this menu
}
