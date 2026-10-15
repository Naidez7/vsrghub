-- VSRG Hub's options, osu!-style: a panel that slides in from the left (Ctrl+O, or Options on the
-- main menu, or F3 on song select). Like gucci!mania, the skin for the interface and the notes
-- for gameplay are picked separately.

-- Noteskins -----------------------------------------------------------------------------------

local function po(level)
	return GAMESTATE:GetPlayerState():GetPlayerOptions(level or "ModsLevel_Preferred")
end
function TW.gameName()
	local ok, g = pcall(function() return GAMESTATE:GetCurrentGame():GetName() end)
	return ok and g or "dance"
end
-- the noteskin names Etterna knows for a game, osu! and Quaver ones first
function TW.noteskinsFor(game)
	if TW_ALL_NOTESKINS and TW_ALL_NOTESKINS[game] then return TW_ALL_NOTESKINS[game] end
	local names = NOTESKIN:GetNoteSkinNames()
	table.sort(names)
	return names
end
function TW.prettyNoteskin(name)
	name = name or ""
	if name:find("^osu!_") then return "osu! " .. name:sub(6):gsub("_", " ") end
	if name:find("^quaver_") then return "Quaver " .. name:sub(8):gsub("_", " ") end
	return name
end
-- The noteskin's name as Etterna has it (settings keep names in lower case, and Etterna's own
-- check is case sensitive for noteskins like "osu!_Tachibana_Sheri_[100]"); nil when it's gone.
function TW.realNoteskin(name)
	if not name or name == "" then return nil end
	local want = name:lower()
	for _, n in ipairs(NOTESKIN:GetNoteSkinNames()) do
		if n:lower() == want then return n end
	end
	return nil
end
-- Sets the noteskin for the current game everywhere Etterna reads it, and remembers it.
function TW.setNoteskin(name, game)
	game = game or TW.gameName()
	if game == TW.gameName() then name = TW.realNoteskin(name) or name end
	local joined = true
	pcall(function() joined = GAMESTATE:IsHumanPlayer(PLAYER_1) end)
	if joined and game == TW.gameName() and TW.realNoteskin(name) then
		for _, lvl in ipairs({ "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song", "ModsLevel_Current" }) do
			po(lvl):NoteSkin(name)
		end
		TW.lastNotes = TW.lastNotes or {}
		TW.lastNotes[game] = name:lower()
	else
		-- picked for the other key mode, or on the main menu (no player yet): song select puts it in
		-- force the next time it comes up in that mode
		TW.syncedOnce = TW.syncedOnce or {}
		TW.syncedOnce[game] = nil
		TW.notesPicked = TW.notesPicked or {}
		TW.notesPicked[game] = true
	end
	TW.saveSetting("notes_" .. game, name:lower())
	MESSAGEMAN:Broadcast("TWNoteskinChanged")
end
-- Called whenever song select comes up: keeps the picked noteskin in force, picks up a change made
-- in Etterna's own player options, and follows the osu! skin's notes when osu!'s skin changed.
function TW.syncNoteskin()
	local g = TW.gameName()
	TW.lastNotes = TW.lastNotes or {}
	TW.syncedOnce = TW.syncedOnce or {}
	local cur = (po():NoteSkin() or ""):lower()
	-- (back from a replay: the replay's noteskin may still be in force for a moment; yours is put back
	-- by TW.afterReplay, so it mustn't be taken for a change you made)
	if TW.beforeReplay then return end
	if TW.syncedOnce[g] then
		if TW.lastNotes[g] and cur ~= TW.lastNotes[g] then
			TW.setNoteskin(cur, g) -- changed in Etterna's player options: keep it
		end
		return
	end
	TW.syncedOnce[g] = true
	local osuSkin = TW_SKINS and TW_OSU_SKIN and TW_SKINS[TW_OSU_SKIN]
	local fromOsu = osuSkin and osuSkin.noteskins and osuSkin.noteskins[g]
	local picked = TW.settings["notes_" .. g]
	local want
	-- The very first time, 4K keeps the noteskin Etterna already uses (7K takes your osu! skin's).
	if g == "dance" and picked == nil and cur ~= "" and TW.realNoteskin(cur) then
		TW.lastNotes[g] = cur
		TW.saveSetting("notes_" .. g, cur)
		if TW_OSU_CHANGED then TW.saveSetting("osuSeen_" .. g, TW_OSU_SKIN or "") end
		return
	end
	-- (a new skin picked in osu! brings its notes once: not again after a theme switch reloads VSRG Hub)
	local osuNew = TW_OSU_CHANGED and TW.settings["osuSeen_" .. g] ~= TW_OSU_SKIN
	if TW_OSU_CHANGED then TW.saveSetting("osuSeen_" .. g, TW_OSU_SKIN or "") end
	if osuNew and fromOsu and not (TW.notesPicked and TW.notesPicked[g]) then want = fromOsu
	elseif picked and picked ~= "" and TW.realNoteskin(picked) then want = picked
	else want = fromOsu end
	if want and TW.realNoteskin(want) then TW.setNoteskin(want, g)
	else TW.lastNotes[g] = cur end
end

-- Scroll speed / direction ------------------------------------------------------------------

-- (a CMod is shown in the look's game's own scroll speed too: "27 · C886", Scripts/24 VSRG Hub scroll.lua)
local function scrollText()
	local p = po()
	local c = p:CMod()
	if c and c > 0 then
		local v = TW.scrollFromC and TW.scrollNumber(TW.scrollFromC(c))
		return v and string.format("%s  ·  C%d", v, c) or string.format("C%d", c)
	end
	local m = p:MMod()
	if m and m > 0 then return string.format("M%d", m) end
	return string.format("%.2fx", p:XMod() or 1)
end
local function changeScroll(d)
	local p = po()
	local c = p:CMod()
	-- (a CMod steps by one of the look's game's scroll speed: osu! 27 -> 28, Quaver 26.4 -> 27.0)
	if c and c > 0 and TW.scrollStep then TW.scrollStep(d > 0 and 1 or -1, false, false) return end
	if c and c > 0 then
		local v = math.max(10, c + d * 10)
		for _, lvl in ipairs({ "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song" }) do po(lvl):CMod(v) end
	else
		local m = p:MMod()
		if m and m > 0 then
			local v = math.max(10, m + d * 10)
			for _, lvl in ipairs({ "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song" }) do po(lvl):MMod(v) end
		else
			local v = math.max(0.25, (p:XMod() or 1) + d * 0.05)
			for _, lvl in ipairs({ "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song" }) do po(lvl):XMod(v) end
		end
	end
end
-- a typed scroll speed: "C700", "M650", "2.5x" or a plain number (kept in the current kind)
function TW.setScrollText(text)
	text = (text or ""):gsub("%s", ""):upper()
	local kind, num = text:match("^([CMX]?)([%d%.]+)$")
	if not kind then
		local n = text:match("^([%d%.]+)X$")
		if n then kind, num = "X", n end
	end
	num = tonumber(num)
	if not num or num <= 0 then SCREENMAN:SystemMessage("Type a scroll speed like 27, C700, M650 or 2.5x") return end
	if kind == "" then
		local p = po()
		if p:CMod() and p:CMod() > 0 then kind = "C" elseif p:MMod() and p:MMod() > 0 then kind = "M" else kind = "X" end
		-- (a plain number in the look's game's range is its scroll speed: 27 in osu!, 30.2 in Quaver)
		local c = TW.cFromTyped and TW.cFromTyped(num)
		if c and kind ~= "X" then kind, num = "C", c end
	end
	if kind == "X" then num = math.max(0.05, math.min(20, num)) else num = math.max(10, math.min(9999, math.floor(num + 0.5))) end
	for _, lvl in ipairs({ "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song" }) do
		local o = po(lvl)
		if kind == "C" then o:CMod(num) elseif kind == "M" then o:MMod(num) else o:XMod(num) end
	end
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
end
local function typeScroll()
	local game = TW.scrollGame and TW.scrollGame() or "osu"
	local ex = game == "quaver" and "30.2 (Quaver's)" or (game == "lazer" and "26.5 (osu!lazer's)" or "27 (osu!'s)")
	local c = po():CMod()
	TW.openInput { title = "Scroll speed", value = (c and c > 0) and string.format("C%d", c) or scrollText(),
		hint = ex .. ", C700 (constant), M650 (max BPM) or 2.5x.",
		onDone = TW.setScrollText }
end
local function toggleReverse()
	local on = po():UsingReverse()
	for _, lvl in ipairs({ "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song" }) do po(lvl):Reverse(on and 0 or 1) end
end

-- Interface skins -----------------------------------------------------------------------------

local function skinFolders()
	local list = { "" }
	local names = {}
	for folder, _ in pairs(TW_SKINS or {}) do names[#names + 1] = folder end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	for _, n in ipairs(names) do list[#list + 1] = n end
	return list
end
local function skinLabel(folder)
	if folder == nil or folder == "" then
		local cur = TW_SKINS and TW_OSU_SKIN and TW_SKINS[TW_OSU_SKIN]
		return "Same as osu! (" .. (cur and cur.name or "osu! default") .. ")"
	end
	local e = TW_SKINS and TW_SKINS[folder]
	return e and e.name or folder
end

-- The panel ----------------------------------------------------------------------------------

TW.optionsOpen = false
local skinChanged = false

local function cycle(list, cur, d)
	local idx = 1
	for i, v in ipairs(list) do if v:lower() == (cur or ""):lower() then idx = i end end
	return list[(idx - 1 + d) % #list + 1]
end

-- the noteskin in use for a game: the one playing now for the current game once song select has
-- set it, otherwise the saved pick, otherwise the osu! skin's own
local function currentNotes(game)
	-- (back on the main menu Etterna has let the player go and its options are the defaults again)
	local joined = true
	pcall(function() joined = GAMESTATE:IsHumanPlayer(PLAYER_1) end)
	if joined and game == TW.gameName() and TW.syncedOnce and TW.syncedOnce[game] then return (po():NoteSkin() or ""):lower() end
	local picked = TW.settings["notes_" .. game]
	if picked and picked ~= "" then return picked end
	local osuSkin = TW_SKINS and TW_OSU_SKIN and TW_SKINS[TW_OSU_SKIN]
	return osuSkin and osuSkin.noteskins and osuSkin.noteskins[game] or ""
end
local function notesLabel(game)
	local n = currentNotes(game)
	if n == "" then return "(none yet)" end
	return TW.prettyNoteskin(n)
end

TW.currentNotes = currentNotes
function TW.markSkinChanged() skinChanged = true end

-- Themes ---------------------------------------------------------------------------------------

TW.THEMES = {
	{ name = "VSRG Hub osu!", label = "osu!", sub = "from your osu! skin" },
	{ name = "VSRG Hub lazer", label = "osu!lazer", sub = "osu!lazer's look" },
	{ name = "VSRG Hub Quaver", label = "Quaver", sub = "Quaver's look" },
	{ name = "Til Death", label = "Til' Death", sub = "Etterna's classic theme" },
	{ name = "Rebirth", label = "Rebirth", sub = "Etterna's newer theme" },
}
local function themes()
	local out = {}
	for _, t in ipairs(TW.THEMES) do
		local ok, sel = pcall(function() return THEME:IsThemeSelectable(t.name) end)
		if ok and sel then out[#out + 1] = t end
	end
	return out
end
local function themeLabel(name)
	for _, t in ipairs(TW.THEMES) do if t.name == name then return t.label end end
	return name
end
-- What a theme switch keeps: the selected chart (song select picks it again in the new look,
-- which opens straight on song select) and the noteskin of the key mode being played. Etterna
-- forgets the selected song when it reloads for another theme.
function TW.rememberSelection()
	local st = GAMESTATE:GetCurrentSteps()
	local key = ""
	pcall(function() key = st and st:GetChartKey() or "" end)
	TW.saveSetting("resumeChart", key)
	local top = SCREENMAN:GetTopScreen()
	local where = top and top:GetName() or ""
	TW.saveSetting("resume", (where == "ScreenSelectMusic" or where:find("Evaluation")) and "select" or "")
	-- (only once song select has put your noteskin in force: on the main menu Etterna's player options
	-- are still its defaults, and switching looks from there saved DivideByZero as your 4K notes)
	local g = TW.gameName()
	local joined = false
	pcall(function() joined = GAMESTATE:IsHumanPlayer(PLAYER_1) end)
	if not (joined and g and TW.syncedOnce and TW.syncedOnce[g]) then return end
	local ns = (po():NoteSkin() or ""):lower()
	if ns ~= "" then TW.saveSetting("notes_" .. g, ns) end
end
-- Song select, after a theme switch: picks the chart that was selected before it.
function TW.restoreSelection(wheel)
	local key = TW.settings.resumeChart
	if not key or key == "" or not wheel then return end
	TW.saveSetting("resumeChart", "")
	pcall(function()
		local song = SONGMAN:GetSongByChartKey(key)
		local steps = SONGMAN:GetStepsByChartKey(key)
		if not (song and steps) then return end
		GAMESTATE:SetPreferredDifficulty(PLAYER_1, steps:GetDifficulty())
		if wheel:SelectSong(song) then GAMESTATE:SetCurrentSteps(PLAYER_1, steps) end
	end)
end
function TW.setTheme(name)
	if name == THEME:GetCurThemeName() then return end
	TW.saveSetting("theme", name)
	TW.rememberSelection()
	TW.closeOptions()
	THEME:SetTheme(name)
end
-- Etterna goes back to the theme VSRG Hub started with when the game type changes (4K <-> 7K);
-- the main menu puts the one picked in the options back.
-- Switches between 4K (Etterna's "dance") and 7K ("kb7") without leaving VSRG Hub's theme: Etterna
-- reloads into its title screen, as its own game picker does, but keeps the theme you are using.
function TW.switchGame(game)
	if not game or game == TW.gameName() then return end
	TW.saveSetting("resume", "select") -- back to song select once Etterna has switched (see the title menus)
	local ok = pcall(function() GAMEMAN:SetGame(game, THEME:GetCurThemeName()) end)
	if not ok then SCREENMAN:SetNewScreen("ScreenSelectGame") end
end
-- true (and forgets it) when the title menu should go straight on to song select
-- (the metrics are read for the game type being played when the theme loads: after switching 4K <->
-- 7K in the same theme they are read again, or the song list would keep the other game's chart types)
TW_METRICS_GAME = TW_METRICS_GAME or TW.gameName()
function TW.syncMetricsGame()
	local g = TW.gameName()
	if g ~= TW_METRICS_GAME then
		TW_METRICS_GAME = g
		pcall(function() THEME:ReloadMetrics() end)
	end
end
function TW.takeResume()
	TW.syncMetricsGame()
	if TW.settings.resume ~= "select" then return false end
	TW.saveSetting("resume", "")
	return true
end
function TW.enforceTheme()
	local want = TW.settings.theme
	if not want or want == "" or want == THEME:GetCurThemeName() then return false end
	local ok, sel = pcall(function() return THEME:IsThemeSelectable(want) end)
	if not (ok and sel) then return false end
	THEME:SetTheme(want)
	return true
end
local function keysList()
	TW.openList { title = "Keys", current = TW.gameName(), items = {
		{ label = "4K", value = "dance", sub = "4 keys" },
		{ label = "7K", value = "kb7", sub = "7 keys" },
	}, onPick = function(v)
		if v == TW.gameName() then return end
		TW.closeOptions(); TW.switchGame(v)
	end }
end
local function themeList()
	local items = {}
	for _, t in ipairs(themes()) do items[#items + 1] = { label = t.label, value = t.name, sub = t.sub } end
	TW.openList { title = "Theme", items = items, current = THEME:GetCurThemeName(), onPick = TW.setTheme }
end

-- Lists (type to search) ---------------------------------------------------------------------

local function skinList()
	local items = {}
	for _, f in ipairs(skinFolders()) do
		local e = TW_SKINS and TW_SKINS[f]
		local sub = "follows osu!"
		if f ~= "" then sub = (e and e.author and e.author ~= "") and ("by " .. e.author) or "" end
		items[#items + 1] = { label = skinLabel(f), value = f, sub = sub }
	end
	TW.openList { title = "Interface skin", items = items, current = TW.settings.interfaceSkin or "",
		-- picking applies it at once (the screen is redrawn with the new skin)
		onPick = function(v) TW.saveSetting("interfaceSkin", v); TW.markSkinChanged(); TW.closeOptions() end }
end
local function notesList(game, title)
	local items = {}
	for _, n in ipairs(TW.noteskinsFor(game)) do
		local kind = n:find("^osu!_") and "osu! skin" or (n:find("^quaver_") and "Quaver skin" or "Etterna")
		items[#items + 1] = { label = TW.prettyNoteskin(n), value = n, sub = kind }
	end
	TW.openList { title = title, items = items, current = TW.currentNotes(game), notes = true, game = game,
		onPick = function(v) TW.setNoteskin(v, game) end }
end

-- KEYBINDS: every key worth knowing in this look, by category (TWKeys, "VSRG Hub keys.lua"):
-- VSRG Hub's shortcuts and Etterna's note / restart / rate keys change with Enter, then the new key
-- (Delete: the default); the rest are listed as they are
local kbCache, kbKey = nil, nil
local function keyRows()
	if not (TWKeys and TWKeys.catalog) then return {} end
	local k = (TWKeys.look and TWKeys.look() or "") .. (TWKeys.gameName and TWKeys.gameName() or "")
	if kbCache and kbKey == k then return kbCache end
	local out = { { kind = "head", text = "KEYBINDS" } }
	for _, c in ipairs(TWKeys.catalog()) do
		out[#out + 1] = { kind = "sub", text = c.title }
		for _, r in ipairs(c.rows) do
			local edit = TWKeys.editable(r)
			out[#out + 1] = { label = r.label, keyRow = r, info = not edit, desc = r.desc,
				value = function() return TWKeys.rowText(r) end,
				activate = edit and function() TWKeys.capture(r) end or nil,
				reset = edit and function() TWKeys.resetRow(r) end or nil }
		end
	end
	out[#out + 1] = { label = "VSRG Hub's shortcuts back to default", button = true, value = function() return "reset" end,
		desc = "Etterna's key map (note keys, restart, rate) is left as it is", activate = function() TWKeys.resetAll() end }
	kbCache, kbKey = out, k
	return out
end
local function isHead(r) return r ~= nil and (r.kind == "head" or r.kind == "sub") end
TW.isOptionHead = isHead

-- rows: { kind = "head", text } (a section), { kind = "sub", text } (a group in it) or
-- { label, value(), change(d), activate() }
local function rows()
	local game = TW.gameName()
	local t = {
		{ kind = "head", text = "LOOK" },
		{ label = "Theme", value = function() return themeLabel(THEME:GetCurThemeName()) end, activate = themeList },
		{ label = "Interface skin", hide = TW.isQuaver, value = function() return skinLabel(TW.settings.interfaceSkin) end,
		  change = function(d)
			  TW.saveSetting("interfaceSkin", cycle(skinFolders(), TW.settings.interfaceSkin or "", d))
			  skinChanged = true
		  end, activate = skinList },
		{ label = "Interface colour", hide = TW.isQuaver, value = function()
			  for _, c in ipairs(TW.ACCENTS) do if c.key == (TW.settings.accent or "skin") then return c.label end end
			  return TW.ACCENTS[1].label
		  end,
		  change = function(d)
			  local keys = {}
			  for _, c in ipairs(TW.ACCENTS) do keys[#keys + 1] = c.key end
			  TW.saveSetting("accent", cycle(keys, TW.settings.accent or "skin", d))
			  skinChanged = true -- redrawn when the panel closes (or with Apply)
		  end,
		  activate = function()
			  local items = {}
			  for _, c in ipairs(TW.ACCENTS) do items[#items + 1] = { label = c.label, value = c.key } end
			  TW.openList { title = "Interface colour", items = items, current = TW.settings.accent or "skin",
				  onPick = function(v) TW.saveSetting("accent", v); skinChanged = true; TW.closeOptions() end }
		  end },
		{ label = "Cursor", value = TW.cursorLabel, activate = function()
			  TW.openList { title = "Cursor", items = TW.cursorItems(), current = TW.settings.cursor or "",
				  preview = function(it) return TW.cursorSpec(it.value) end,
				  onPick = function(v) TW.setCursor(v) end }
		  end },
		{ label = "Cursor size", value = function() return string.format("%.1fx", TW.cursorSize()) end,
		  change = function(d) TW.setCursorSize(TW.cursorSize() + d * 0.1) end },
		-- the song select's background picture (Scripts/28 VSRG Hub background.lua)
		{ label = "Background dim", value = function() return TW.bgDim() .. "%" end,
		  change = function(d) TW.setBgDim(TW.bgDim() + d * 5) end },
		{ label = "Background blur", value = function() return TW.BLUR_LABEL[TW.bgBlur()] end,
		  change = function(d) TW.setBgBlur((TW.bgBlur() + d) % 3) end,
		  activate = function()
			  TW.openList { title = "Background blur (song select)", current = tostring(TW.bgBlur()),
				  items = { { label = "Off", value = "0" }, { label = "Soft", value = "1" }, { label = "Strong", value = "2" } },
				  onPick = function(v) TW.setBgBlur(tonumber(v)) end }
		  end },
		{ label = "Apply skin", button = true, hide = not skinChanged, value = function() return "apply" end,
		  activate = function() TW.closeOptions() end },
		{ label = "Notes (4K)", value = function() return notesLabel("dance") end,
		  change = function(d) TW.setNoteskin(cycle(TW.noteskinsFor("dance"), currentNotes("dance"), d), "dance") end,
		  activate = function() notesList("dance", "Notes (4K)") end },
		{ label = "Notes (7K)", value = function() return notesLabel("kb7") end,
		  change = function(d) TW.setNoteskin(cycle(TW.noteskinsFor("kb7"), currentNotes("kb7"), d), "kb7") end,
		  activate = function() notesList("kb7", "Notes (7K)") end },
		-- the combo's digits from any skin (Scripts/29 VSRG Hub combo.lua)
		{ label = "Combo skin", value = function() return TW.comboLabel and TW.comboLabel() or "" end,
		  change = function(d)
			  local vals = {}
			  for _, it in ipairs(TW.comboItems()) do vals[#vals + 1] = it.value end
			  TW.setComboSkin(cycle(vals, TW.comboChoice(), d))
		  end,
		  activate = function()
			  TW.openList { title = "Combo skin", items = TW.comboItems(), current = TW.comboChoice(), combo = true,
				  onPick = function(v) TW.setComboSkin(v) end }
		  end },
		{ kind = "head", text = "GAMEPLAY" },
		{ label = "Keys", value = function() return TW.gameName() == "kb7" and "7K" or "4K" end,
		  -- a short list to pick from (no instant toggle, so a stray click doesn't switch modes)
		  change = function() keysList() end, activate = function() keysList() end },
		{ label = "Scroll speed", value = scrollText, change = changeScroll, activate = typeScroll },
		-- timing: Etterna's judge or osu!'s OD, one or the other (Scripts/24 VSRG Hub timing.lua)
		{ label = "Judge", value = function()
			  local m, v = TW.timingMode()
			  if m == "quaver" then return "off (Quaver windows)" end
			  return m == "od" and "off (using osu! OD)" or TW.judgeNames[v - 3] end,
		  change = function(d)
			  local m, v = TW.timingMode()
			  if m ~= "judge" then TW.setJudge(4) else TW.setJudge((v - 4 + d) % 6 + 4) end
		  end },
		{ label = "osu! OD", value = function()
			  local m, v = TW.timingMode()
			  if m == "quaver" then return "off (Quaver windows)" end
			  return m == "od" and string.format("OD %g", v) or "off (using Etterna judge)" end,
		  change = function(d)
			  local m, v = TW.timingMode()
			  -- (off sits past both ends: right goes on at OD 0, left at OD 10)
			  if m ~= "od" then TW.setOD(d > 0 and 0 or 10) else
				  local n = v + d
				  if n < 0 or n > 10 then TW.setOD(nil) else TW.setOD(n) end
			  end
		  end },
		-- Quaver's judgement windows: its presets and your own (the Quaver look edits them in a dialog)
		{ label = "Judgement windows", value = function()
			  local m, v = TW.timingMode()
			  return m == "quaver" and ("Quaver " .. v) or "off (Etterna's)" end,
		  change = function(d)
			  local names = {}
			  for _, p in ipairs(TW.QV_PRESETS) do names[#names + 1] = p[1] end
			  for _, c in ipairs(TW.qvCustom()) do names[#names + 1] = c.name end
			  local m, v = TW.timingMode()
			  local i = 0
			  if m == "quaver" then for k, n in ipairs(names) do if n == v then i = k end end end
			  i = (i + d) % (#names + 1)
			  if i == 0 then TW.setJudge(4) else TW.setQuaverWindows(names[i]) end
		  end,
		  activate = QV and QV.openWindows and function() QV.openWindows() end or nil },
		{ label = "Scroll direction", value = function() return po():UsingReverse() and "Downscroll" or "Upscroll" end,
		  check = function() return po():UsingReverse() end, checkLabel = "Downscroll",
		  change = function() toggleReverse() end, activate = toggleReverse },
		-- like osu!: Esc pauses (a paused play's score is kept but marked invalid); also Ctrl+P
		{ label = "Pausing (" .. TW.keyLabel("pausetoggle", "Ctrl+P") .. ")",
		  value = function() return (TWPauseOn and TWPauseOn()) and ("On: " .. TW.keyLabel("pause", "Esc") .. " pauses") or "Off: Esc quits" end,
		  check = function() return TWPauseOn and TWPauseOn() end,
		  checkLabel = "Pause with " .. TW.keyLabel("pause", "Esc") .. " (" .. TW.keyLabel("pausetoggle", "Ctrl+P") .. ")",
		  change = function() if TWPauseToggle then TWPauseToggle() end end,
		  activate = function() if TWPauseToggle then TWPauseToggle() end end },
		-- Etterna's combo break lane flash (Til Death's "CB Highlight"), off unless you turn it on
		{ label = "Lane flash on misses",
		  value = function() return (TWLaneFlashOn and TWLaneFlashOn()) and "On" or "Off" end,
		  check = function() return TWLaneFlashOn and TWLaneFlashOn() end,
		  checkLabel = "Lane flash on misses",
		  change = function() if TWLaneFlashToggle then TWLaneFlashToggle() end end,
		  activate = function() if TWLaneFlashToggle then TWLaneFlashToggle() end end },
		-- which hand plays 7K's middle column (results: left / right hand stats and combo breaks)
		{ label = "7K thumb on the middle key", value = function() return TW.thumb7() == "left" and "Left (hands 4 + 3)" or "Right (hands 3 + 4)" end,
		  change = function() TW.saveSetting("thumb7", TW.thumb7() == "left" and "right" or "left") end,
		  activate = function() TW.saveSetting("thumb7", TW.thumb7() == "left" and "right" or "left") end },
		{ kind = "head", text = "ETTERNA" },
		-- EtternaOnline: log in (on the profile page, which keeps you logged in) or out
		{ label = "EtternaOnline", value = function()
			  local n = nil
			  pcall(function() if DLMAN:IsLoggedIn() then n = DLMAN:GetUsername() end end)
			  return n and ("Logged in as " .. n) or "Not logged in (log in)"
		  end,
		  activate = function()
			  local top = SCREENMAN:GetTopScreen()
			  if not (top and top:GetName() == "ScreenSelectMusic") then
				  SCREENMAN:SystemMessage("Log in from song select (here, or your profile)")
				  return
			  end
			  TW.closeOptions()
			  if TWProfileLogin then TWProfileLogin() end
		  end },
		{ label = "All Etterna options", button = true, value = function() return "open" end,
		  activate = function() TW.closeOptions(); SCREENMAN:SetNewScreen("ScreenOptionsService") end },
	}
	-- KEYBINDS, then VIDEO and AUDIO (Scripts/29 VSRG Hub video.lua), before ETTERNA
	-- (before ETTERNA's head, wherever it is)
	local function etternaHead()
		for i, r in ipairs(t) do if r.kind == "head" and r.text == "ETTERNA" then return i end end
		return #t + 1
	end
	do
		local at = etternaHead() - 1
		for i, kr in ipairs(keyRows()) do table.insert(t, at + i, kr) end
	end
	if TW.videoRows then
		local at = etternaHead() - 1
		for i, r in ipairs(TW.videoRows()) do table.insert(t, at + i, r) end
	end
	for i = #t, 1, -1 do if t[i].hide then table.remove(t, i) end end
	local top = SCREENMAN:GetTopScreen()
	if top and top:GetName() == "ScreenSelectMusic" then
		-- Etterna's Customize Gameplay: plays the selected chart on autoplay with the layout editor
		table.insert(t, 2 + (function() for i, r in ipairs(t) do if r.label == "Scroll direction" then return i - 1 end end return #t - 2 end)(),
			{ label = "Customize gameplay", button = true, value = function() return "open" end,
			  activate = function() TW.closeOptions(); TW.startCustomize() end })
		t[#t + 1] = { label = "Player options", button = true, value = function() return "open" end,
			activate = function() TW.closeOptions(); SCREENMAN:SetNewScreen("ScreenPlayerOptions") end }
	end
	-- osu!'s "type to search": keep the rows whose label matches, under their section heads
	local f = (TW.optionsFilter or ""):lower()
	if f ~= "" then
		local out, head, sub = {}, nil, nil
		for _, r in ipairs(t) do
			if r.kind == "head" then head = r; sub = nil
			elseif r.kind == "sub" then sub = r
			elseif r.label:lower():find(f, 1, true) or (r.checkLabel and r.checkLabel:lower():find(f, 1, true))
				or (r.keyRow and r.value():lower():find(f, 1, true)) then
				if head then out[#out + 1] = head; head = nil end
				if sub then out[#out + 1] = sub; sub = nil end
				out[#out + 1] = r
			end
		end
		t = out
	end
	return t
end

TW.optionRows = rows
local cursor = 2
-- the osu! panel shows MAXROWS rows at a time and scrolls to keep the cursor in view
local MAXROWS = 17
local scroll = 0
local function follow()
	local n = #rows()
	if cursor - scroll > MAXROWS then scroll = cursor - MAXROWS end
	if cursor - scroll < 2 then scroll = math.max(0, cursor - 2) end -- (the section title above it stays in view)
	scroll = math.max(0, math.min(scroll, math.max(0, n - MAXROWS)))
end
-- (the cursor never rests on a section or group title)
local function toFirst()
	local list = rows()
	while isHead(list[cursor]) and cursor < #list do cursor = cursor + 1 end
end
function TW.optionsCursor() return cursor end
function TW.setOptionsCursor(i) cursor = i end
function TW.openOptions()
	if TW.optionsOpen then return end
	TW.optionsOpen = true
	cursor = 2 -- start at the top, like osu!
	scroll = 0
	skinChanged = false
	TW.optionsFilter = ""
	SCREENMAN:set_input_redirected(PLAYER_1, true)
	MESSAGEMAN:Broadcast("TWOptions", { open = true })
end
function TW.closeOptions()
	if not TW.optionsOpen then return end
	TW.optionsOpen = false
	SCREENMAN:set_input_redirected(PLAYER_1, TW.keepRedirect == true)
	MESSAGEMAN:Broadcast("TWOptions", { open = false })
	if skinChanged then
		skinChanged = false
		TW.useInterfaceSkin()
		local top = SCREENMAN:GetTopScreen()
		if top then SCREENMAN:SetNewScreen(top:GetName()) end -- redraw with the new skin
	end
end
function TW.toggleOptions() if TW.optionsOpen then TW.closeOptions() else TW.openOptions() end end
-- the options, at KEYBINDS
function TW.openKeybinds()
	if not TW.optionsOpen then TW.openOptions() end
	TW.optionsFilter = ""
	local list = rows()
	for j, r in ipairs(list) do
		if r.kind == "head" and r.text == "KEYBINDS" then
			cursor = j + 1
			while isHead(list[cursor]) and cursor < #list do cursor = cursor + 1 end
			scroll = j - 1
			break
		end
	end
	follow()
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
end
-- for the main menu's Options choice (metrics: ChoiceOptions)
function TWOpenOptions() TW.openOptions() end

-- Keyboard while the panel is open. Returns true when it used the key.
function TW.optionsInput(event)
	-- (Quaver's judgement windows dialog, over the options, takes the keyboard first)
	if QV and QV.windows and QV.windowsInput then return QV.windowsInput(event) end
	if not TW.optionsOpen then return false end
	local b = event.DeviceInput.button
	-- (Quaver's dialog shows one section at a time; the wheel scrolls a long one, like Keybinds)
	if (b == "DeviceButton_mousewheel up" or b == "DeviceButton_mousewheel down") and TW.isQuaver and not TW.list
		and (event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat") and not TW.altHeld() then
		if QV and QV.optionsScroll then QV.optionsScroll(b == "DeviceButton_mousewheel up" and -1 or 1) end
		return true
	end
	-- the mouse wheel scrolls the settings (osu! look)
	if (b == "DeviceButton_mousewheel up" or b == "DeviceButton_mousewheel down") and not TW.isQuaver and not TW.list
		and (event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat") and not TW.altHeld() then
		local n = #rows()
		scroll = math.max(0, math.min(scroll + (b == "DeviceButton_mousewheel up" and -3 or 3), math.max(0, n - MAXROWS)))
		if cursor <= scroll then cursor = scroll + 1 end
		if cursor > scroll + MAXROWS then cursor = scroll + MAXROWS end
		local list = rows()
		while isHead(list[cursor]) and cursor < n do cursor = cursor + 1 end
		MESSAGEMAN:Broadcast("TWOptionsRefresh")
		return true
	end
	if event.type == "InputEventType_Release" or event.DeviceInput.is_mouse then return false end
	-- Esc closes on its first press only (a held Esc that just closed a list mustn't close this too)
	if b == "DeviceButton_escape" and event.type ~= "InputEventType_FirstPress" then return true end
	-- typing searches (osu! theme only; Quaver's options have no search box)
	if not TW.isQuaver and event.type == "InputEventType_FirstPress" and not INPUTFILTER:IsControlPressed() then
		if b == "DeviceButton_backspace" and (TW.optionsFilter or "") ~= "" then
			TW.optionsFilter = TW.optionsFilter:sub(1, -2); cursor = 2; scroll = 0; toFirst()
			MESSAGEMAN:Broadcast("TWOptionsRefresh") return true
		elseif event.char and event.char:match("^[%w]$") then
			TW.optionsFilter = (TW.optionsFilter or "") .. event.char:lower(); cursor = 2; scroll = 0; toFirst()
			MESSAGEMAN:Broadcast("TWOptionsRefresh") return true
		end
	end
	local list = rows()
	if #list == 0 then
		if b == "DeviceButton_escape" then TW.optionsFilter = ""; MESSAGEMAN:Broadcast("TWOptionsRefresh") end
		return true
	end
	local function move(d)
		local i = cursor
		repeat i = (i - 1 + d) % #list + 1 until not isHead(list[i])
		cursor = i
	end
	if list[cursor] == nil or isHead(list[cursor]) then move(1) end
	local row = list[cursor]
	local ctrlO = b == "DeviceButton_o" and INPUTFILTER:IsControlPressed()
	if b == "DeviceButton_escape" and (TW.optionsFilter or "") ~= "" then
		TW.optionsFilter = ""; cursor = 2; toFirst()
	elseif b == "DeviceButton_escape" or TW.key(event, "options", ctrlO) or TW.key(event, "beatmap", b == "DeviceButton_F3") then
		TW.closeOptions()
	elseif TW.key(event, "keybinds", false) then
		TW.openKeybinds()
		return true
	elseif b == "DeviceButton_delete" and row.reset then row.reset()
	elseif b == "DeviceButton_up" then move(-1)
	elseif b == "DeviceButton_down" then move(1)
	elseif b == "DeviceButton_left" and row.change then row.change(-1)
	elseif b == "DeviceButton_right" and row.change then row.change(1)
	elseif (b == "DeviceButton_enter" or b == "DeviceButton_KP enter") then
		if row.activate then row.activate() elseif row.change then row.change(1) end
	end
	follow()
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
	return true
end

-- The actor: put it in a screen's overlay (it brings its own mouse buttons). Laid out like osu!'s
-- options: a black icon strip with one icon per section, "Options" and its pink subtitle, the
-- "Type to search!" box, section titles in blue on the right, settings marked by a line on the left
-- (dropdown boxes, circle checkboxes, blue buttons) and the pink "back" button at the bottom.
local headName = { LOOK = "SKIN", GAMEPLAY = "GAMEPLAY", KEYBINDS = "KEYBINDS", VIDEO = "VIDEO", PERFORMANCE = "PERFORMANCE", AUDIO = "AUDIO", ETTERNA = "ETTERNA" }
local headIcon = { LOOK = "S", GAMEPLAY = "G", KEYBINDS = "K", VIDEO = "V", PERFORMANCE = "P", AUDIO = "A", ETTERNA = "E" }
-- (the icon strip's pictures, Font Awesome's)
local headPic = { LOOK = "wand-magic-sparkles", GAMEPLAY = "circle-play", KEYBINDS = "keyboard", VIDEO = "film", PERFORMANCE = "bolt", AUDIO = "volume-high", ETTERNA = "globe" }
local blue = { 102 / 255, 204 / 255, 1, 1 }
function TW.optionsPanel()
	local M = TW.M
	-- (osu!lazer's settings: its greys, pink-tinted section titles, "settings" in light letters)
	local blue = TW.isLazer and LZ.light2 or blue
	local L = TW.isLazer == true
	local W = M(540)
	local RH = M(34)
	local X0 = M(84)                -- content's left edge
	local CW = W - X0 - M(24)       -- content's width
	local function refresh() MESSAGEMAN:Broadcast("TWOptionsRefresh") end
	local t = Def.ActorFrame {
		Name = "TWOptionsPanel",
		InitCommand = function(self) self:z(40):visible(false):x(-W) end,
		TWOptionsMessageCommand = function(self, p)
			self:stoptweening()
			if p.open then
				self:visible(true):playcommand("Build"):decelerate(0.2):x(0)
			else
				self:decelerate(0.15):x(-W):queuecommand("Hide")
			end
		end,
		HideCommand = function(self) self:visible(false) end,
		-- dim the rest and close when clicking outside, like osu!
		Def.Quad { InitCommand = function(self) self:align(0, 0):x(W):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse({ 0.05, 0.05, 0.065, 0.35 }) end },
		TW.button(SCREEN_WIDTH, SCREEN_HEIGHT, function() TW.closeOptions() end) .. {
			InitCommand = function(self) self:align(0, 0):x(W):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffusealpha(0) end },
		-- (solid: the screen's own text mustn't show through the settings)
		Def.Quad { InitCommand = function(self)
			if L then self:align(0, 0):zoomto(W, SCREEN_HEIGHT):diffuse(LZ.a(LZ.bg5, 1)) return end
			TW.glassify(self:align(0, 0):zoomto(W, SCREEN_HEIGHT), "float"); if not TW.isQuaver then self:diffusealpha(1) end
		end },
		-- a soft shadow off its right edge
		Def.Quad { InitCommand = function(self) self:align(0, 0):x(W):zoomto(M(18), SCREEN_HEIGHT):diffuse({ 0, 0, 0, 0.45 }):diffuserightedge({ 0, 0, 0, 0 }) end },
		TW.button(W, SCREEN_HEIGHT, function() end) .. { InitCommand = function(self) self:align(0, 0):zoomto(W, SCREEN_HEIGHT):diffusealpha(0) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(M(62), SCREEN_HEIGHT):diffuse(L and LZ.a(LZ.bg6, 1) or { 0, 0, 0, 0.3 }) end },
		L and LZ.text(M(30), "light", function(self) self:align(0, 0):xy(X0, M(14)):settext("settings") end)
			or TW.text(M(28), false, function(self) self:align(0, 0):xy(X0, M(16)):settext("Options") end),
		TW.text(M(12), false, function(self) self:align(0, 0):xy(X0 + M(2), M(58)):settext(L and "change the way VSRG Hub behaves" or "Change the way VSRG Hub behaves"):diffuse(L and LZ.light2 or TW.pink) end),
		-- search box
		TW.box { w = CW, h = M(30), r = M(15), ay = 0.5, col = { 0, 0, 0, 0.35 }, init = function(self) self:xy(X0, M(98)) end },
		TW.icon("magnifying-glass", M(13), function(self) self:xy(X0 + M(18), M(98)):diffusealpha(0.5) end),
		TW.text(M(14), false, function(self) self:align(0.5, 0.5):xy(X0 + CW / 2, M(98)) end) .. {
			BuildCommand = function(self) self:playcommand("Show") end,
			TWOptionsRefreshMessageCommand = function(self) self:playcommand("Show") end,
			ShowCommand = function(self)
				local f = TW.optionsFilter or ""
				if f == "" then self:settext("Type to search!"):diffusealpha(0.5)
				else self:settext(f .. "_"):diffusealpha(1) end
			end
		},
		TW.text(M(14), false, function(self) self:align(0.5, 0.5):xy(X0 + CW / 2, M(330)):settext("No matching settings."):diffusealpha(0.6) end) .. {
			BuildCommand = function(self) self:playcommand("Show") end,
			TWOptionsRefreshMessageCommand = function(self) self:playcommand("Show") end,
			ShowCommand = function(self) self:visible(#rows() == 0) end
		},
	}
	-- the icon strip: one per section, the current one lit
	local heads = { "LOOK", "GAMEPLAY", "KEYBINDS", "VIDEO", "PERFORMANCE", "AUDIO", "ETTERNA" }
	for i, h in ipairs(heads) do
		t[#t + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(M(31), M(140) + (i - 1) * M(50)) end,
			BuildCommand = function(self) self:playcommand("Show") end,
			TWOptionsRefreshMessageCommand = function(self) self:playcommand("Show") end,
			ShowCommand = function(self)
				local list, sec = rows(), nil
				for j = 1, math.min(cursor, #list) do if list[j].kind == "head" then sec = list[j].text end end
				local on = sec == h
				self:GetChild("Bar"):visible(on)
				self:GetChild("Icon"):diffuse(on and TW.pink or color("#FFFFFF")):diffusealpha(on and 1 or 0.6)
			end,
			TW.box { w = M(4), h = M(36), r = M(2), ax = 0.5, ay = 0.5, col = TW.pink, init = function(self) self:x(M(28)) end } .. { Name = "Bar" },
			TW.disc(M(16), { 1, 1, 1, 0.08 }),
			TW.icon(headPic[h], M(16)) .. { Name = "Icon" },
			TW.button(M(62), M(56), function()
				TW.optionsFilter = ""
				local list = rows()
				for j, r in ipairs(list) do
					if r.kind == "head" and r.text == h then
						cursor = math.min(j + 1, #list); scroll = j - 1
						while isHead(list[cursor]) and cursor < #list do cursor = cursor + 1 end
					end
				end
				follow()
				refresh()
			end) .. { InitCommand = function(self) self:zoomto(M(62), M(56)):diffusealpha(0) end },
		}
	end
	for i = 1, MAXROWS do
		local y = M(150) + (i - 1) * RH
		local BX = M(170) -- where a setting's box starts
		local BW = CW - BX - M(6)
		t[#t + 1] = Def.ActorFrame {
			Name = "Row" .. i,
			InitCommand = function(self) self:xy(X0, y) end,
			BuildCommand = function(self) self:playcommand("Show") end,
			TWOptionsRefreshMessageCommand = function(self) self:playcommand("Show") end,
			TWNoteskinChangedMessageCommand = function(self) self:playcommand("Show") end,
			TWKeysChangedMessageCommand = function(self) self:playcommand("Show") end,
			ShowCommand = function(self)
				local list = rows()
				local r = list[i + scroll]
				self:visible(r ~= nil)
				self.row = r
				self.index = i + scroll
				if not r then return end
				local c = self:GetChildren()
				local head = r.kind == "head"
				local sub = r.kind == "sub"
				local check = not head and not sub and r.check ~= nil
				local button = not head and not sub and r.button == true
				local box = not head and not sub and not check and not button
				local keyRow = box and r.keyRow ~= nil
				c.Head:visible(head):settext(head and (headName[r.text] or r.text) or "")
				-- a group of keybinds: its name in the interface colour over a thin rule
				c.Sub:visible(sub):settext(sub and r.text:upper() or "")
				c.SubRule:visible(sub)
				c.Line:visible(not head and not sub)
				c.Sel:visible(not head and not sub and i + scroll == cursor)
				c.Label:visible(box):settext(box and r.label or "")
				c.Box:visible(box)
				c.Value:visible(box):settext(box and r.value() or "")
				c.Value:maxwidth((BW - M(40)) / c.Value:GetZoom())
				-- keybinds: the ones that can be changed in white (pink while waiting for the key), the
				-- others dimmer
				local picking = keyRow and TWKeys and TWKeys.capturing(r.keyRow)
				c.Value:diffuse(picking and TW.pink or color("#FFFFFF")):diffusealpha((keyRow and r.info) and 0.55 or 1)
				c.Label:diffusealpha((keyRow and r.info) and 0.8 or 1)
				c.Chev:visible(box and r.activate ~= nil and not keyRow)
				c.Prev:visible(box and r.activate == nil and r.change ~= nil)
				c.Next:visible(box and r.activate == nil and r.change ~= nil)
				c.Ring:visible(check)
				c.Dot:visible(check and r.check())
				c.CheckLabel:visible(check):settext(check and (r.checkLabel or r.label) or "")
				c.Btn:visible(button)
				c.BtnLabel:visible(button):settext(button and r.label or "")
			end,
			TW.box { w = CW + M(10), h = RH - M(4), r = M(6), ay = 0.5, col = { 1, 1, 1, 0.12 }, init = function(self) self:x(-M(5)) end } .. { Name = "Sel" },
			Def.Quad { Name = "Line", InitCommand = function(self) self:align(0, 0.5):x(-M(10)):zoomto(M(2), RH):diffuse(TW.rgb(255, 255, 255, 0.22)) end },
			TW.text(M(18), true, function(self) self:align(1, 0.5):xy(CW, M(4)):diffuse(blue) end) .. { Name = "Head" },
			TW.text(M(11.5), true, function(self) self:align(0, 1):xy(0, M(10)):diffuse(TW.pink) end) .. { Name = "Sub" },
			Def.Quad { Name = "SubRule", InitCommand = function(self) self:align(0, 0.5):xy(0, M(14)):zoomto(CW, 1):diffuse(TW.rgb(255, 255, 255, 0.25)) end },
			TW.text(M(12), false, function(self) self:align(0, 0.5):maxwidth((BX - M(10)) / self:GetZoom()) end) .. { Name = "Label" },
			TW.box { w = BW, h = M(25), r = M(6), ay = 0.5, col = { 0.2, 0.2, 0.25, 0.5 }, col2 = { 0, 0, 0, 0.4 }, init = function(self) self:x(BX) end } .. { Name = "Box" },
			TW.text(M(11.5), false, function(self) self:align(0, 0.5):x(BX + M(9)) end) .. { Name = "Value" },
			TW.icon("chevron-down", M(9), function(self) self:x(BX + BW - M(13)):diffusealpha(0.75) end) .. { Name = "Chev" },
			TW.icon("chevron-left", M(9), function(self) self:x(BX + BW - M(30)):diffusealpha(0.75) end) .. { Name = "Prev" },
			TW.icon("chevron-right", M(9), function(self) self:x(BX + BW - M(13)):diffusealpha(0.75) end) .. { Name = "Next" },
			TW.ringShape(M(8.5), M(1.6), TW.pink, function(self) self:x(M(11)) end) .. { Name = "Ring" },
			TW.disc(M(6.5), { 0, 0, 0, 0.5 }, nil, function(self) self:x(M(11)) end) .. {
				ShowCommand = function(self) local r = self:GetParent().row; self:visible(r ~= nil and r.check ~= nil) end },
			TW.disc(M(4.5), TW.pink, nil, function(self) self:x(M(11)) end) .. { Name = "Dot" },
			TW.text(M(12), false, function(self) self:align(0, 0.5):x(M(26)) end) .. { Name = "CheckLabel" },
			TW.box { w = CW, h = M(27), r = M(13.5), ay = 0.5, col = TW.rgb(86, 156, 226), col2 = TW.rgb(60, 120, 196) } .. { Name = "Btn" },
			TW.text(M(12), false, function(self) self:align(0.5, 0.5):x(CW / 2) end) .. { Name = "BtnLabel" },
			-- clicks: the left arrow side steps back on a < > setting, the rest opens or steps on
			TW.button(CW, RH, function(self)
				local r = self:GetParent().row
				if not r or isHead(r) then return end
				cursor = self:GetParent().index
				if r.activate then r.activate() elseif r.change then r.change(1) end
				refresh()
			end, function(self, on)
				local r = self:GetParent().row
				local idx = self:GetParent().index
				if on and r and not isHead(r) and cursor ~= idx then cursor = idx; refresh() end
			end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(CW, RH):diffusealpha(0) end },
			TW.button(M(26), RH, function(self)
				local r = self:GetParent().row
				if r and r.change and not r.activate then cursor = self:GetParent().index; r.change(-1); refresh() end
			end) .. { InitCommand = function(self) self:align(1, 0.5):x(BX + BW - M(22)):zoomto(M(26), RH):diffusealpha(0):z(1) end },
		}
	end
	-- osu!'s pink "back" button, bottom left
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(0, SCREEN_HEIGHT) end,
		TW.box { w = M(140), h = M(44), r = M(10), shear = 0.15, ay = 1, col = TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.1), col2 = TW.pink, init = function(self) self:xy(-M(14), -M(8)) end } .. { Name = "Bg" },
		TW.text(M(17), true, function(self) self:align(0, 0.5):xy(M(48), -M(30)):settext("back") end),
		TW.icon("chevron-left", M(14), function(self) self:xy(M(30), -M(30)) end),
		TW.button(M(130), M(44), function() TW.closeOptions() end, function(self, on)
			self:GetParent():GetChild("Bg"):stoptweening():decelerate(0.1):x(on and 0 or -M(14))
		end) .. { InitCommand = function(self) self:align(0, 1):y(-M(8)):zoomto(M(130), M(44)):diffusealpha(0) end },
	}
	-- the keys of the panel; on a keybind, what it does and how to change it
	t[#t + 1] = TW.text(M(11), false, function(self)
		self:align(1, 1):xy(W - M(16), SCREEN_HEIGHT - M(18)):diffusealpha(0.5):maxwidth((W - M(160)) / self:GetZoom())
	end) .. {
		BuildCommand = function(self) self:playcommand("Show") end,
		TWOptionsRefreshMessageCommand = function(self) self:playcommand("Show") end,
		TWKeysChangedMessageCommand = function(self) self:playcommand("Show") end,
		ShowCommand = function(self)
			local r = rows()[cursor]
			if r and r.keyRow then
				local how = r.info and "" or (TWKeys.capturing(r.keyRow) and "   Press the new key (Esc cancels)" or "   Enter: new key, Delete: default")
				self:settext((r.desc or r.label) .. how):diffusealpha(0.8)
			elseif r and r.desc then
				self:settext(r.desc):diffusealpha(0.8)
			else
				self:settext("Arrows move and change, Enter opens, Esc closes"):diffusealpha(0.5)
			end
		end,
	}
	return t
end

