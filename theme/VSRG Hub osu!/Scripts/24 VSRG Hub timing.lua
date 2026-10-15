-- How strict the timing is: Etterna's judges (J4 to Justice) or osu!'s Overall Difficulty (OD 0-10).
-- One or the other is in force: picking a judge turns OD off, picking an OD replaces the judge.
-- Both set Etterna's timing window scale, so scores stay Etterna scores (Wife, rescored to J4).

TW.judgeNames = { "J4", "J5", "J6", "J7", "J8", "Justice" }

-- osu!mania's 300 window is 64 - 3 x OD ms; Etterna's Perfect window at J4 is 45 ms
function TW.odScale(od) return (64 - 3 * od) / 45 end

-- Quaver's judgement windows (Marvelous, Perfect, Great, Good, Okay, Miss in ms): its presets, each
-- Standard's times 1.1 to a power (truncated, as Quaver does; the stricter ones keep Standard's Okay
-- and Miss), and your own (made in the Quaver look's Judgement windows dialog). With them in force
-- Etterna judges on those windows (Marvelous..Okay: its W1..W5, at most 180 ms as Etterna allows) at
-- the J4 scale, so Wife% stays the J4 one, and the accuracy shown is Quaver's.
TW.QV_STANDARD = { 18, 43, 76, 106, 127, 164 }
TW.QV_PRESETS = { { "Peaceful", -3 }, { "Lenient", -2 }, { "Chill", -1 }, { "Standard", 0 }, { "Strict", 1 },
	{ "Tough", 2 }, { "Extreme", 3 }, { "Impossible", 8 } }
function TW.qvPresetWindows(n)
	local out = {}
	for i, v in ipairs(TW.QV_STANDARD) do
		if n > 0 and i >= 5 then out[i] = v else out[i] = math.floor(v * 1.1 ^ (-n) + 1e-9) end
	end
	return out
end
-- your own windows: "name:18,43,76,106,127,164;other:..."
function TW.qvCustom()
	local out = {}
	for name, list in ((TW.settings and TW.settings.qv_custom) or ""):gmatch("([^:;]+):([%d,%.]+)") do
		local w = {}
		for v in list:gmatch("[%d%.]+") do w[#w + 1] = tonumber(v) end
		if #w == 6 then out[#out + 1] = { name = name, w = w } end
	end
	return out
end
function TW.saveQvCustom(list)
	local parts = {}
	for _, c in ipairs(list) do
		local ms = {}
		for i = 1, 6 do ms[i] = string.format("%d", math.floor(c.w[i] + 0.5)) end
		parts[#parts + 1] = c.name:gsub("[:;]", "") .. ":" .. table.concat(ms, ",")
	end
	TW.saveSetting("qv_custom", table.concat(parts, ";"))
end
-- the windows of a name (a preset or one of yours), nil when there is none by that name
function TW.qvWindows(name)
	for _, p in ipairs(TW.QV_PRESETS) do if p[1] == name then return TW.qvPresetWindows(p[2]) end end
	for _, c in ipairs(TW.qvCustom()) do if c.name == name then return c.w end end
	return nil
end
local ETT_WINDOWS = { 0.0225, 0.045, 0.090, 0.135, 0.180 } -- Etterna's own W1..W5
local function setWindows(ms)
	for i = 1, 5 do
		local sec = ms and math.min(0.18, math.max(0.001, ms[i] / 1000)) or ETT_WINDOWS[i]
		pcall(function() PREFSMAN:SetPreference("TimingWindowSecondsW" .. i, sec) end)
	end
end
function TW.setQuaverWindows(name)
	local w = name and TW.qvWindows(name)
	if not w then
		setWindows(nil)
		TW.saveSetting("qv_windows", "")
		MESSAGEMAN:Broadcast("TWTimingChanged")
		return
	end
	setWindows(w)
	pcall(SetTimingDifficulty, 1)
	TW.saveSetting("osu_od", "")
	TW.saveSetting("qv_windows", name)
	MESSAGEMAN:Broadcast("TWTimingChanged")
end
-- Quaver's accuracy from judgement counts (W1..W5, Miss)
TW.QV_WEIGHTS = { 100, 98.25, 65, 25, -100, -50 }
function TW.quaverAcc(c)
	local n, sum = 0, 0
	for i = 1, 6 do n = n + (c[i] or 0); sum = sum + (c[i] or 0) * TW.QV_WEIGHTS[i] end
	if n <= 0 then return 100 end
	return math.max(0, sum / (n * 100)) * 100
end

function TW.timingMode()
	local qv = TW.settings and TW.settings.qv_windows or ""
	if qv ~= "" and TW.qvWindows(qv) then return "quaver", qv end
	local od = tonumber(TW.settings and TW.settings.osu_od or "")
	if od then return "od", od end
	local ok, j = pcall(GetTimingDifficulty)
	return "judge", math.max(4, math.min(9, (ok and j) or 4))
end
function TW.timingText()
	local mode, v = TW.timingMode()
	if mode == "od" then return string.format("osu! OD %g", v) end
	if mode == "quaver" then return "Quaver " .. v end
	return "Etterna " .. TW.judgeNames[v - 3]
end
function TW.setJudge(n) -- 4..9 (9 = Justice)
	n = math.max(4, math.min(9, n))
	local scales = GAMESTATE:GetTimingScales()
	SetTimingDifficulty(scales[n])
	TW.saveSetting("osu_od", "")
	if (TW.settings.qv_windows or "") ~= "" then setWindows(nil); TW.saveSetting("qv_windows", "") end
	MESSAGEMAN:Broadcast("TWTimingChanged")
end
function TW.setOD(od) -- nil turns OD off (back to J4)
	if od == nil then TW.setJudge(4) return end
	od = math.max(0, math.min(10, od))
	SetTimingDifficulty(TW.odScale(od))
	TW.saveSetting("osu_od", tostring(od))
	if (TW.settings.qv_windows or "") ~= "" then setWindows(nil); TW.saveSetting("qv_windows", "") end
	MESSAGEMAN:Broadcast("TWTimingChanged")
end
-- puts the saved OD back in force (Etterna only remembers the scale)
function TW.applyTiming()
	local mode, v = TW.timingMode()
	if mode == "od" then pcall(SetTimingDifficulty, TW.odScale(v)) end
	if mode == "quaver" then setWindows(TW.qvWindows(v)); pcall(SetTimingDifficulty, 1) else setWindows(nil) end
end
TW.applyTiming()

-- Etterna's player options (Enter on a song): one row for the judge, one for osu!'s OD; each shows one
-- value at a time and changing either cancels the other.
local function oneRow(name, choices, load, save)
	local t = {
		Name = name, LayoutType = "ShowOneInRow", SelectType = "SelectOne", OneChoiceForAllPlayers = true,
		ExportOnChange = true, ExportOnCancel = false, Choices = choices,
		LoadSelections = function(self, list, pn) list[load()] = true end,
		SaveSelections = function(self, list, pn)
			for i = 1, #list do if list[i] then save(i) return end end
		end,
		-- when the other row changes, this one shows it
		ReloadRowMessages = { "TWTimingChanged" },
	}
	setmetatable(t, t)
	return t
end
function JudgeDifficulty()
	local choices = { "Off (osu! OD)", "4", "5", "6", "7", "8", "Justice" }
	return oneRow("TimingWindowScale", choices,
		function() local m, v = TW.timingMode(); return m == "od" and 1 or (m == "quaver" and 2) or (v - 2) end,
		function(i)
			local m, v = TW.timingMode()
			if i == 1 then if m ~= "od" then TW.setOD(8) end -- "Off (osu! OD)": osu!'s OD takes over
			elseif m ~= "judge" or v ~= i + 2 then TW.setJudge(i + 2) end
		end)
end
function TWOsuOD()
	local choices = { "Off (Etterna judge)" }
	for od = 0, 10 do choices[#choices + 1] = "OD " .. od end
	return oneRow("TWOsuOD", choices,
		function() local m, v = TW.timingMode(); return m == "od" and (v + 2) or 1 end,
		function(i)
			local m, v = TW.timingMode()
			if i == 1 then if m == "od" then TW.setJudge(4) end -- "Off (Etterna judge)": back to J4
			elseif m ~= "od" or v ~= i - 2 then TW.setOD(i - 2) end
		end)
end

-- the Main page of Etterna's player options, with osu!'s OD right under the judge
function getPlayerOptionsList(itemSet)
	local Items = {
		["Main"] = "Speed,RateList,NoteSk,RS,PRAC,CG,ScrollDir,Center,Persp,BG,SF,Background,Judge,OD,Life,Fail,Assist,Score",
		["Theme"] = "LC,CBHL,JT,CT,DP,DM,TT,TG,TTM,JC,EB,EBC,PI,FBP,FB,MB,LEADB,NPS",
		["Effect"] = "Persp,App,GHO,SHO,Acc,Hide,Effect1,Effect2,Scroll,Turn,Insert,R1,R2,Holds,Mines,HoldReleases"
	}
	return (Items[itemSet] or Items.Main) .. ",NextScr"
end

-- Til Death's noteskin preview in Player Options shows one note per column of the game: give it
-- 7K's seven columns too (it only knows 4K's)
local tdNSkinElements = GameToNSkinElements
function GameToNSkinElements()
	local ok, g = pcall(function() return GAMESTATE:GetCurrentGame():GetName() end)
	if ok and g == "kb7" then return { "Key1", "Key2", "Key3", "Key4", "Key5", "Key6", "Key7" } end
	if tdNSkinElements then return tdNSkinElements() end
	return { "Left", "Down", "Up", "Right" }
end

-- The accuracy shown while playing: Etterna's Wife% (it can go below 0, as in Etterna), or with an
-- osu! OD in force osu!'s own accuracy, where a 300g (Marvelous) and a 300 (Perfect) both count in
-- full. TW.accTracker() gives a function to call with each Judgment message; it returns the
-- accuracy to show (nil when the message has none).
local tnsIndex = { TapNoteScore_W1 = 1, TapNoteScore_W2 = 2, TapNoteScore_W3 = 3, TapNoteScore_W4 = 4, TapNoteScore_W5 = 5, TapNoteScore_Miss = 6 }
function TW.accTracker()
	local c = { 0, 0, 0, 0, 0, 0 }
	local od = TW.timingMode() == "od"
	local qv = TW.timingMode() == "quaver"
	return function(p)
		if p.TapNoteScore and not p.HoldNoteScore then
			local i = tnsIndex[p.TapNoteScore]
			if i then
				-- (a replay that jumps sends each count again, as Val)
				if p.FromReplay and tonumber(p.Val) then c[i] = tonumber(p.Val) else c[i] = c[i] + 1 end
			end
		end
		if od and TW.osuAcc then return TW.osuAcc(c) end
		if qv then return TW.quaverAcc(c) end
		local w = p.WifePercent
		-- (autoplay scores nothing: Etterna's number is meaningless then)
		if w == nil then return nil end
		local auto = false
		pcall(function()
			local pc = GAMESTATE:GetPlayerState():GetPlayerController()
			auto = pc == "PlayerController_Autoplay" or pc == "PlayerController_Cpu"
		end)
		if auto or w ~= w or w > 100 then return 100 end
		return math.max(-1000, w)
	end
end
