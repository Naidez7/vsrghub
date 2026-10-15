-- osu!lazer's song select, top: the toolbar; the slanted wedge with the selected chart (title,
-- artist, length / BPM / notes / mines, its MSD on a star pill with the difficulty and mapper, and
-- Etterna's eight pattern ratings as lazer's detail bars); the Local / Global / Preview tabs with the
-- rate over the scores; and on the right lazer's search box with Sort, Group and Collection.
-- (Loaded by VSRG Hub osu!'s song select overlay in this look, in place of osu!'s top bar.)
TW.useInterfaceSkin()
local M, R = TW.M, TW.R
local white = color("#FFFFFF")

local function fmtTime(s)
	s = math.max(0, math.floor(s))
	return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end
local function commas(n)
	local s = tostring(math.floor(math.abs(n)))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
local skillNames = { "Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical" }
local skillLabel = { "Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "Jackspeed", "Chordjack", "Technical" }

local t = Def.ActorFrame {
	CurrentSongChangedMessageCommand = function(self) self:playcommand("Info") end,
	CurrentStepsChangedMessageCommand = function(self) self:playcommand("Info") end,
	CurrentRateChangedMessageCommand = function(self) self:playcommand("Info") end,
	OnCommand = function(self) self:playcommand("Info") end,
	CodeMessageCommand = function(self, params)
		if params.Name == "NextRate" or params.Name == "PrevRate" or params.Name == "NextScore" or params.Name == "PrevScore" then
			ChangeMusicRate(nil, params)
			MESSAGEMAN:Broadcast("CurrentRateChanged")
		end
	end,
}

-- ------------------------------------------------------------------------------------------------
-- the wedge
-- ------------------------------------------------------------------------------------------------
local WX, WY, WW, WH = -M(30), M(48), M(720), M(204)
local wedge = Def.ActorFrame {
	OnCommand = function(self) self:addx(-M(80)):diffusealpha(0):decelerate(0.35):addx(M(80)):diffusealpha(1) end,
	TW.shadow { w = WW, h = WH, spread = M(14), alpha = 0.5, drop = M(4), init = function(self) self:xy(WX, WY) end },
	LZ.panel { w = WW, h = WH, r = M(10), col = LZ.a(LZ.bg5, 0.86), col2 = LZ.a(LZ.bg6, 0.9), init = function(self) self:xy(WX, WY) end },
	-- the song's picture faded in from the right, as lazer's wedge shows its background
	Def.Sprite {
		Name = "Pic",
		InfoCommand = function(self)
			local s = GAMESTATE:GetCurrentSong()
			local p = s and TW.bigPicture(s)
			if not p or p == "" then self:visible(false) self.shown = nil return end
			local fresh = p ~= self.shown
			if fresh then
				self.shown = p
				self:LoadBackground(p)
			end
			self:visible(true):scaletocover(M(330), WY + M(4), WX + WW - M(10), WY + WH - M(4))
			self:fadeleft(0.6)
			-- (a new song's picture fades in)
			if fresh then self:stoptweening():diffusealpha(0):linear(0.35):diffusealpha(0.35) end
			-- (cut to the wedge's height: a picture taller than wide spills over)
			local h = self:GetZoomedHeight()
			local over = (h - (WH - M(8))) / math.max(1, h)
			self:croptop(math.max(0, over / 2)):cropbottom(math.max(0, over / 2))
		end,
	},
}
-- RANKED, the key count and the rate on pills (lazer's status pill row)
wedge[#wedge + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(M(18), WY + M(16)) end,
	InfoCommand = function(self)
		local st = GAMESTATE:GetCurrentSteps()
		local c = self:GetChildren()
		local x = M(54)
		c.Keys:visible(st ~= nil):x(x + M(8)):settext(st and (TW.keys(st) .. "K") or "")
		c.KeysBg:visible(st ~= nil):x(x)
		TW.setBox(c.KeysBg, { w = c.Keys:GetZoomedWidth() + M(16) })
		x = x + c.Keys:GetZoomedWidth() + M(22)
		local rate = getCurRateValue()
		local showRate = math.abs(rate - 1) > 0.001
		c.Rate:visible(showRate):x(x + M(8)):settext(getCurRateDisplayString(true))
		c.RateBg:visible(showRate):x(x)
		TW.setBox(c.RateBg, { w = c.Rate:GetZoomedWidth() + M(16) })
	end,
	TW.box { w = M(48), h = M(15), r = M(5), ay = 0.5, col = TW.rgb(179, 255, 102) } .. { Name = "RankedBg" },
	LZ.text(M(8.5), "bold", function(self) self:align(0.5, 0.5):x(M(24)):settext("RANKED"):diffuse(TW.rgb(30, 50, 10)) end),
	TW.box { w = M(30), h = M(15), r = M(5), ay = 0.5, col = LZ.pink } .. { Name = "KeysBg" },
	LZ.text(M(8.5), "bold", function(self) self:align(0, 0.5):diffuse(TW.rgb(40, 20, 30)) end) .. { Name = "Keys" },
	TW.box { w = M(30), h = M(15), r = M(5), ay = 0.5, col = LZ.purpleDark } .. { Name = "RateBg" },
	LZ.text(M(8.5), "bold", function(self) self:align(0, 0.5) end) .. { Name = "Rate" },
}
-- title (big, light) and artist
wedge[#wedge + 1] = LZ.text(M(27), "regular", function(self) self:align(0, 0.5):xy(M(16), WY + M(46)):maxwidth(M(660) / self:GetZoom()) end) .. {
	InfoCommand = function(self) local s = GAMESTATE:GetCurrentSong(); self:settext(s and s:GetDisplayMainTitle() or "") end }
wedge[#wedge + 1] = LZ.text(M(14), "regular", function(self) self:align(0, 0.5):xy(M(17), WY + M(72)):maxwidth(M(660) / self:GetZoom()) end) .. {
	InfoCommand = function(self) local s = GAMESTATE:GetCurrentSong(); self:settext(s and s:GetDisplayArtist() or "") end }
-- the counts in a row with icons, a thin line between (lazer's plays / favourites / length / bpm row):
-- length, BPM, notes, holds, mines (at the rate)
local stats = { { "clock", "len" }, { "music", "bpm" }, { "circle-play", "notes" }, { "hourglass-half", "holds" }, { "bolt", "mines" } }
local statRow = Def.ActorFrame {
	InitCommand = function(self) self:xy(M(16), WY + M(98)) end,
	InfoCommand = function(self)
		local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
		local rate = getCurRateValue()
		local vals = {}
		if song then
			local bpms = song:GetDisplayBpms()
			vals.bpm = math.abs(bpms[1] - bpms[2]) < 0.5 and string.format("%d", bpms[1] * rate + 0.5)
				or string.format("%d-%d", bpms[1] * rate + 0.5, bpms[2] * rate + 0.5)
			vals.len = fmtTime((steps and steps:GetLengthSeconds() or song:MusicLengthSeconds()) / rate)
			local rv = steps and steps:GetRadarValues(PLAYER_1)
			local function radar(k) return rv and rv:GetValue(k) or 0 end
			vals.notes = commas(radar("RadarCategory_Notes"))
			vals.holds = commas(radar("RadarCategory_Holds"))
			vals.mines = commas(radar("RadarCategory_Mines"))
		end
		local x = 0
		for i, st in ipairs(stats) do
			local c = self:GetChild("S" .. i)
			local v = vals[st[2]]
			c:visible(v ~= nil)
			if v then
				local txt = c:GetChild("V")
				txt:settext(v)
				c:x(x)
				c:GetChild("Sep"):visible(i < #stats)
				local w = txt:GetZoomedWidth() + M(30)
				c:GetChild("Sep"):x(w + M(2))
				x = x + w + M(12)
			end
		end
	end,
}
for i, st in ipairs(stats) do
	statRow[#statRow + 1] = Def.ActorFrame {
		Name = "S" .. i,
		TW.icon(st[1], M(13), function(self) self:x(M(8)):diffuse(st[2] == "notes" and LZ.pinkLight or white) end),
		LZ.text(M(14), "regular", function(self) self:align(0, 0.5):x(M(22)) end) .. { Name = "V" },
		Def.Quad { Name = "Sep", InitCommand = function(self) self:zoomto(1, M(14)):diffuse({ 1, 1, 1, 0.25 }) end },
	}
end
wedge[#wedge + 1] = statRow
-- the star pill (MSD), the difficulty (in lazer's yellow) and its mapper
wedge[#wedge + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(M(16), WY + M(126)) end,
	InfoCommand = function(self)
		local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
		local c = self:GetChildren()
		c.Star:visible(steps ~= nil):playcommand("Msd", { v = TW.msd(steps) })
		local x = (c.Star.w or M(60)) + M(10)
		c.Diff:x(x):settext(steps and TW.diffName(steps) or "")
		local by = song and TW.author(song) or ""
		c.By:x(x + c.Diff:GetZoomedWidth() + M(6)):settext(by ~= "" and ("mapped by " .. by) or "")
		c.By:maxwidth(math.max(M(60), M(640) - x - c.Diff:GetZoomedWidth()) / c.By:GetZoom())
	end,
	LZ.starPill(M(18)) .. { Name = "Star" },
	LZ.text(M(13), "bold", function(self) self:align(0, 0.5):diffuse(TW.rgb(255, 224, 120)) end) .. { Name = "Diff" },
	LZ.text(M(12), "regular", function(self) self:align(0, 0.5):diffuse(LZ.a(white, 0.9)) end) .. { Name = "By" },
}
-- Etterna's pattern ratings as lazer's statistic boxes: a line of the rating's colour on top, the
-- name under it, the value below
local CW = M(80)
local details = Def.ActorFrame {
	InitCommand = function(self) self:xy(M(16), WY + M(150)) end,
	InfoCommand = function(self)
		local steps = GAMESTATE:GetCurrentSteps()
		for i = 1, 8 do
			local v = steps and TW.msd(steps, i) or 0
			self:GetChild("V" .. i):settext(steps and string.format("%.2f", v) or "-")
			TW.setBox(self:GetChild("B" .. i), { col = steps and LZ.starColour(v) or { 1, 1, 1, 0.3 } })
		end
	end,
}
for i, name in ipairs(skillLabel) do
	local x = (i - 1) * (CW + M(4))
	details[#details + 1] = TW.box { w = CW - M(8), h = M(2), r = M(1), col = white, init = function(self) self:xy(x, 0) end } .. { Name = "B" .. i }
	details[#details + 1] = LZ.text(M(9.5), "bold", function(self) self:align(0, 0):xy(x, M(6)):settext(name):diffuse(LZ.a(white, 0.85)):maxwidth((CW - M(8)) / self:GetZoom()) end)
	details[#details + 1] = LZ.text(M(13.5), "regular", function(self) self:align(0, 0):xy(x, M(20)) end) .. { Name = "V" .. i }
end
wedge[#wedge + 1] = details
-- the wedge's text slides in again for each new song, as lazer's does
local content = Def.ActorFrame {
	Name = "Content",
	CurrentSongChangedMessageCommand = function(self) self:stoptweening():diffusealpha(0.2):x(-M(14)):decelerate(0.28):diffusealpha(1):x(0) end,
	CurrentStepsChangedMessageCommand = function(self) self:stoptweening():diffusealpha(0.6):x(-M(5)):decelerate(0.2):diffusealpha(1):x(0) end,
}
local nw = #wedge
for i = 4, nw do content[#content + 1] = wedge[i] end
for i = nw, 4, -1 do wedge[i] = nil end
wedge[4] = content
t[#t + 1] = wedge

-- ------------------------------------------------------------------------------------------------
-- Local / Global / Preview over the scores (lazer's Details / Ranking tabs and its scope), and the
-- rate (left click faster, right click slower, as in Etterna)
-- ------------------------------------------------------------------------------------------------
-- Details (the preview) and Ranking, then the scope of the scores (Local / VSRG Hub / EtternaOnline)
-- on a pill and the rate on another, as lazer's Scope / Sort / Selected Mods row
local scopes = { { "Local", "local" }, { "VSRG Hub", "hub" }, { "EtternaOnline", "online" } }
local function scopeIndex()
	for i, sc in ipairs(scopes) do if TW.rankSource == sc[2] then return i end end
	return 1
end
local function setScope(i)
	TW.osuLeft = "Ranking"
	if TW.setRankSource then TW.setRankSource(scopes[i][2]) end
	MESSAGEMAN:Broadcast("TWOsuLeft")
end
-- (the osu! look's ranking box steps through these; kept for the keybind and right clicks)
function TW.osuLeftStep(d)
	if TW.osuLeft == "Preview" then TW.osuLeft = "Ranking"; MESSAGEMAN:Broadcast("TWOsuLeft") return end
	setScope((scopeIndex() - 1 + d) % #scopes + 1)
end
local tabs = { { "Details", function() return TW.osuLeft == "Preview" end, function() TW.osuLeft = "Preview"; MESSAGEMAN:Broadcast("TWOsuLeft") end },
	{ "Ranking", function() return TW.osuLeft ~= "Preview" end, function() TW.osuLeft = "Ranking"; MESSAGEMAN:Broadcast("TWOsuLeft") end } }
local tabRow = Def.ActorFrame { InitCommand = function(self) self:xy(M(18), M(274)) end }
local tabPos = {}
local tx = 0
for i, tb in ipairs(tabs) do
	local w = M(14) * #tb[1] * 0.62 + M(16)
	local x = tx
	tabRow[#tabRow + 1] = Def.ActorFrame {
		InitCommand = function(self) self:x(x) end,
		OnCommand = function(self) self:playcommand("Tab") end,
		TWOsuLeftMessageCommand = function(self) self:playcommand("Tab") end,
		TabCommand = function(self)
			self:GetChild("L"):stoptweening():linear(0.12):diffuse(tb[2]() and white or LZ.a(white, 0.6))
		end,
		LZ.text(M(13.5), "regular", function(self) self:align(0, 0.5):settext(tb[1]) end) .. { Name = "L" },
		TW.button(w, M(30), function() tb[3]() end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(w, M(30)):diffusealpha(0) end },
	}
	tabPos[i] = { x, w - M(16) }
	tx = tx + w + M(8)
end
-- one line under the picked tab, sliding to the next one picked
tabRow[#tabRow + 1] = Def.Quad {
	InitCommand = function(self) self:align(0, 0.5):y(M(13)):zoomto(M(30), M(2)):diffuse(LZ.blue) end,
	OnCommand = function(self) self:playcommand("Move", { now = true }) end,
	TWOsuLeftMessageCommand = function(self) self:playcommand("Move") end,
	MoveCommand = function(self, p)
		for i, tb in ipairs(tabs) do
			if tb[2]() then
				self:stoptweening()
				if not (p and p.now) then self:decelerate(0.25) end
				self:x(tabPos[i][1]):zoomto(tabPos[i][2], M(2))
			end
		end
	end,
}
-- a pill with a darker part for its name and a value (lazer's Scope / Sort pills)
local function valuePill(x, w, label, value, onLeft, onRight)
	local LW = M(14) + #label * M(7.2)
	return Def.ActorFrame {
		InitCommand = function(self) self:x(x) end,
		TW.shadow { w = w, h = M(26), ay = 0.5, spread = M(6), alpha = 0.35 },
		LZ.panel { w = w, h = M(26), r = M(7), ay = 0.5, col = LZ.a(LZ.bg4, 0.96) } .. { Name = "Bg" },
		LZ.panel { w = LW, h = M(26), r = M(7), ay = 0.5, col = LZ.a(LZ.bg2, 0.98) },
		LZ.text(M(11.5), "bold", function(self) self:align(0.5, 0.5):x(LW / 2 + M(1)):settext(label) end),
		LZ.text(M(11.5), "regular", function(self) self:align(0, 0.5):x(LW + M(9)) end) .. {
			OnCommand = function(self) self:playcommand("Val") end,
			TWOsuLeftMessageCommand = function(self) self:playcommand("Val") end,
			TWRankSourceMessageCommand = function(self) self:playcommand("Val") end,
			CurrentRateChangedMessageCommand = function(self) self:playcommand("Val") end,
			ValCommand = function(self) self:settext(value()):maxwidth((w - LW - M(30)) / self:GetZoom()) end,
		},
		TW.icon("chevron-down", M(9), function(self) self:x(w - M(13)):diffusealpha(0.8) end),
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self) self:align(0, 0.5):zoomto(w, M(26)):diffusealpha(0) end,
			MouseOverCommand = function(self) self:GetParent():GetChild("Bg"):diffusealpha(0.8) end,
			MouseOutCommand = function(self) self:GetParent():GetChild("Bg"):diffusealpha(1) end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then onLeft()
				elseif params.event == "DeviceButton_right mouse button" and onRight then onRight() end
			end,
		},
	}
end
tabRow[#tabRow + 1] = valuePill(M(190), M(190), "Scope", function() return scopes[scopeIndex()][1] end,
	function() setScope(scopeIndex() % #scopes + 1) end, function() setScope((scopeIndex() - 2) % #scopes + 1) end)
tabRow[#tabRow + 1] = valuePill(M(392), M(150), "Rate", function() return getCurRateDisplayString(true) end,
	function() ChangeMusicRate(nil, { Name = "PrevRate" }) end, function() ChangeMusicRate(nil, { Name = "NextRate" }) end)
t[#t + 1] = tabRow

-- ------------------------------------------------------------------------------------------------
-- right: search, then Sort / Group / Collection
-- ------------------------------------------------------------------------------------------------
local groupItems = {
	{ "No Grouping", "Ungrouped" }, { "By Artist", "Artist" }, { "By BPM", "BPM" }, { "By Creator", "Author" },
	{ "By Date Added", "DateAdded" }, { "By Difficulty", "Overall" }, { "By Genre", "Genre" }, { "By Length", "Length" },
	{ "By Pack", "Group" }, { "By Pattern", "@patterns" }, { "By Rank Achieved", "TopGrades" }, { "By Title", "Title" }, { "Collections", "@collections" },
	{ "Favourites", "Favorites" },
}
local sortItems = {
	{ "By Artist", "Artist" }, { "By BPM", "BPM" }, { "By Creator", "Author" }, { "By Date Added", "DateAdded" },
	{ "By Difficulty", "Overall" }, { "By Length", "Length" }, { "By Rank Achieved", "TopGrades" }, { "By Title", "Title" },
	{ "By Stream", "Stream" }, { "By Jumpstream", "Jumpstream" }, { "By Handstream", "Handstream" }, { "By Stamina", "Stamina" },
	{ "By Jackspeed", "JackSpeed" }, { "By Chordjack", "Chordjack" }, { "By Technical", "Technical" },
}
local function curSort() return ToEnumShortString(GAMESTATE:GetSortOrder() or "SortOrder_Group") end
local function setSort(name)
	if name == "@collections" then TW.openCollections() return end
	if name == "@patterns" then TW.openPatterns() return end
	local w = SCREENMAN:GetTopScreen():GetMusicWheel()
	if w then w:ChangeSort("SortOrder_" .. name) end
	MESSAGEMAN:Broadcast("TWSortChanged")
end
local function labelFor(list)
	local cur = curSort()
	for _, it in ipairs(list) do if it[2] == cur then return (it[1]:gsub("^By ", "")) end end
	return list == groupItems and "Pack" or "Title"
end

local SX = R(812)
local SW = SCREEN_WIDTH - SX - M(10)
-- the search box: lazer's big field, the query in large text, the matches under it
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(SX, M(50)) end,
	OnCommand = function(self) self:addx(M(80)):diffusealpha(0):decelerate(0.35):addx(-M(80)):diffusealpha(1) end,
	TW.shadow { w = SW, h = M(46), spread = M(10), alpha = 0.45 },
	LZ.panel { w = SW, h = M(46), r = M(8), shear = 0, col = LZ.a(LZ.bg4, 0.92), col2 = LZ.a(LZ.bg5, 0.92) } .. { Name = "Bg" },
	TW.box { w = SW, h = M(46), r = M(8), tex = "ring", col = { 1, 1, 1, 0 } } .. { Name = "Edge",
		TWSearchMessageCommand = function(self, p) TW.setBox(self, { col = p.active and LZ.a(LZ.pink, 0.9) or { 1, 1, 1, 0 } }) end },
	TW.icon("magnifying-glass", M(17), function(self) self:xy(SW - M(26), M(23)) end),
	LZ.text(M(16), "regular", function(self) self:align(0, 0.5):xy(M(16), M(20)):maxwidth((SW - M(70)) / self:GetZoom()) end) .. {
		OnCommand = function(self) self:playcommand("TWSearch", { text = "", active = false }) end,
		TWSearchMessageCommand = function(self, p)
			if p.text ~= "" then self:settext(p.text .. (p.active and "|" or "")):diffuse(white)
			elseif p.active then self:settext("|"):diffuse(white)
			else self:settext("type to search"):diffuse(LZ.a(LZ.dim, 0.7)) end
		end,
	},
	-- how many songs the list shows (lazer's "N matches")
	LZ.text(M(9.5), "bold", function(self) self:align(0, 0.5):xy(M(16), M(37)):diffuse(LZ.yellow) end) .. {
		OnCommand = function(self) self:queuecommand("Count") end,
		TWSearchMessageCommand = function(self) self:sleep(0.6):queuecommand("Count") end,
		TWSearchResultsMessageCommand = function(self) self:queuecommand("Count") end,
		TWSortChangedMessageCommand = function(self) self:queuecommand("Count") end,
		TWCollectionChangedMessageCommand = function(self) self:sleep(0.2):queuecommand("Count") end,
		CountCommand = function(self)
			local n = 0
			pcall(function() n = #SCREENMAN:GetTopScreen():GetMusicWheel():GetSongs() end)
			self:settextf("%s %s", commas(n), n == 1 and "match" or "matches")
		end,
	},
	TW.button(SW, M(46), function() MESSAGEMAN:Broadcast("TWStartSearch") end) .. { InitCommand = function(self) self:align(0, 0):zoomto(SW, M(46)):diffusealpha(0) end },
}

-- lazer's star rating slider, for Etterna's MSD: the overall rating the list is cut to, from the
-- low end to the high one (the right end: no limit), on a band of lazer's star colours. Drag an end.
local MSD_MAX = 40
local function msdLo() local v = 0; pcall(function() v = FILTERMAN:GetSSFilter(1, 0) end); return v or 0 end
local function msdHi() local v = 0; pcall(function() v = FILTERMAN:GetSSFilter(1, 1) end); return (v or 0) > 0 and v or MSD_MAX end
local function setMsd(lo, hi)
	lo = math.max(0, math.min(MSD_MAX - 0.5, lo))
	hi = math.max(lo + 0.5, math.min(MSD_MAX, hi))
	pcall(function()
		FILTERMAN:SetSSFilter(lo, 1, 0)
		FILTERMAN:SetSSFilter(hi >= MSD_MAX and 0 or hi, 1, 1)
	end)
	TW.searchAgain()
	MESSAGEMAN:Broadcast("TWMsdRange")
end
local SLY = M(108)
local LBL = M(84)
local TRX, TRW = LBL + M(10), SW - LBL - M(10)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(SX, SLY) end,
	OnCommand = function(self) self:addx(M(80)):diffusealpha(0):decelerate(0.35):addx(-M(80)):diffusealpha(1); self:playcommand("Range") end,
	TWMsdRangeMessageCommand = function(self) self:playcommand("Range") end,
	TW.shadow { w = SW, h = M(26), ay = 0.5, spread = M(6), alpha = 0.35 },
	LZ.panel { w = SW, h = M(26), r = M(7), ay = 0.5, col = LZ.a(LZ.bg4, 0.94) },
	LZ.panel { w = LBL, h = M(26), r = M(7), ay = 0.5, col = LZ.a(LZ.bg2, 0.98) },
	LZ.text(M(11.5), "bold", function(self) self:align(0.5, 0.5):x(LBL / 2 + M(1)):settext("Rating") end),
	-- the band of star colours
	Def.ActorFrame {
		InitCommand = function(self)
			self:x(TRX)
		end,
		Def.ActorMultiVertex {
			InitCommand = function(self)
				local verts = {}
				local n = 16
				local h = M(10)
				for i = 0, n do
					local v = i / n * MSD_MAX
					local c = LZ.starColour(v)
					local x = i / n * TRW
					verts[#verts + 1] = { { x, -h / 2, 0 }, c }
					verts[#verts + 1] = { { x, h / 2, 0 }, c }
				end
				self:SetDrawState { Mode = "DrawMode_QuadStrip" }:SetVertices(verts)
			end,
		},
		-- the parts outside the range, darkened
		Def.Quad { Name = "DimL", InitCommand = function(self) self:align(0, 0.5):zoomto(0, M(10)):diffuse({ 0, 0, 0, 0.7 }) end },
		Def.Quad { Name = "DimR", InitCommand = function(self) self:align(1, 0.5):x(TRW):zoomto(0, M(10)):diffuse({ 0, 0, 0, 0.7 }) end },
		-- the two ends: a knob each with its value
		Def.ActorFrame { Name = "Lo",
			TW.box { w = M(44), h = M(18), r = M(9), ax = 0.5, ay = 0.5, col = LZ.a(LZ.bg5, 0.98) },
			TW.box { w = M(44), h = M(18), r = M(9), ax = 0.5, ay = 0.5, tex = "ring", col = { 1, 1, 1, 0.5 } },
			LZ.text(M(10), "bold", function(self) self:align(0.5, 0.5) end) .. { Name = "V" } },
		Def.ActorFrame { Name = "Hi",
			TW.box { w = M(44), h = M(18), r = M(9), ax = 0.5, ay = 0.5, col = LZ.a(LZ.bg5, 0.98) },
			TW.box { w = M(44), h = M(18), r = M(9), ax = 0.5, ay = 0.5, tex = "ring", col = { 1, 1, 1, 0.5 } },
			LZ.text(M(10), "bold", function(self) self:align(0.5, 0.5) end) .. { Name = "V" } },
		RangeCommand = function(self)
			local lo, hi = msdLo(), msdHi()
			local c = self:GetChildren()
			local xl, xh = lo / MSD_MAX * TRW, hi / MSD_MAX * TRW
			c.Lo:x(xl); c.Hi:x(xh)
			c.Lo:GetChild("V"):settextf("%.1f", lo)
			c.Hi:GetChild("V"):settext(hi >= MSD_MAX and "∞" or string.format("%.1f", hi))
			c.DimL:zoomto(xl, M(10))
			c.DimR:zoomto(TRW - xh, M(10))
		end,
		-- a press on the band takes the nearer end there and drags it along
		TW.button(TRW + M(44), M(26), function(self)
			local band = self:GetParent()
			local mx = INPUTFILTER:GetMouseX() - (self:GetTrueX() + M(22))
			local v = mx / TRW * MSD_MAX
			local lo, hi = msdLo(), msdHi()
			band.drag = math.abs(v - lo) <= math.abs(v - hi) and "lo" or "hi"
			band.left = self:GetTrueX() + M(22)
			if band.drag == "lo" then setMsd(v, hi) else setMsd(lo, v) end
		end) .. {
			InitCommand = function(self)
				self:align(0, 0.5):x(-M(22)):zoomto(TRW + M(44), M(26)):diffusealpha(0)
				local band = self:GetParent()
				TW.everyFrame(band)
				band:SetUpdateFunction(function(b)
					if not b.drag then return end
					if not INPUTFILTER:IsBeingPressed("left mouse button", "Mouse") then b.drag = nil return end
					local v = math.floor((INPUTFILTER:GetMouseX() - b.left) / TRW * MSD_MAX * 2 + 0.5) / 2
					local lo, hi = msdLo(), msdHi()
					if b.drag == "lo" and math.abs(v - lo) > 0.01 then setMsd(v, hi)
					elseif b.drag == "hi" and math.abs(v - hi) > 0.01 then setMsd(lo, v) end
				end)
			end,
		},
	},
}

-- lazer's filter row: Sort, Group, Collection; each a dark pill with its name in a darker part
TW.dropOpen = nil
local FY = M(146)
local function filterPill(name, label, x, w, onClick, value)
	local LW = M(22) + #label * M(7.4) -- (the darker part with the filter's name)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(x, FY) end,
		TW.shadow { w = w, h = M(28), ay = 0.5, spread = M(6), alpha = 0.35 },
		LZ.panel { w = w, h = M(28), r = M(6), ay = 0.5, col = LZ.a(LZ.bg4, 0.94) } .. { Name = "Bg" },
		LZ.panel { w = LW, h = M(28), r = M(6), ay = 0.5, col = LZ.a(LZ.bg2, 0.96) },
		LZ.text(M(12), "bold", function(self) self:align(0.5, 0.5):x(LW / 2 + M(1)):settext(label) end),
		LZ.text(M(12), "regular", function(self) self:align(0, 0.5):x(LW + M(10)) end) .. {
			OnCommand = function(self) self:playcommand("TWSortChanged") end,
			TWCollectionChangedMessageCommand = function(self) self:playcommand("TWSortChanged") end,
			TWSortChangedMessageCommand = function(self) self:settext(value()):maxwidth((w - LW - M(38)) / self:GetZoom()) end,
		},
		TW.icon("chevron-down", M(10), function(self) self:x(w - M(16)):diffusealpha(0.8) end),
		TW.button(w, M(28), onClick, function(self, on)
			TW.setBox(self:GetParent():GetChild("Bg"), { col = on and LZ.a(LZ.bg3, 0.96) or LZ.a(LZ.bg4, 0.94) })
		end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(w, M(28)):diffusealpha(0) end },
	}
end
local PW3 = (SW - M(16)) / 3
local function toggleDrop(name)
	TW.dropOpen = TW.dropOpen ~= name and name or nil
	MESSAGEMAN:Broadcast("TWDrop", { name = TW.dropOpen })
end
t[#t + 1] = filterPill("sort", "Sort", SX, PW3, function() toggleDrop("sort") end, function() return labelFor(sortItems) end)
t[#t + 1] = filterPill("group", "Group", SX + PW3 + M(8), PW3, function() toggleDrop("group") end, function() return labelFor(groupItems) end)
t[#t + 1] = filterPill("collection", "Collection", SX + 2 * (PW3 + M(8)), PW3, function() TW.openCollections() end, function()
	if TW.collection then return (TW.collection.pattern and "Pattern: " or "") .. TW.collection.name end
	return "All charts"
end)

-- the open list under Sort or Group
local function dropList(name, x, w, list)
	local rowH = M(26)
	local f = Def.ActorFrame {
		InitCommand = function(self) self:xy(x, FY + M(20)):visible(false):z(30) end,
		TWDropMessageCommand = function(self, p)
			self:stoptweening()
			if p.name == name then
				self:visible(true):diffusealpha(0):addy(-M(8)):decelerate(0.15):diffusealpha(1):addy(M(8))
				self:playcommand("Fill")
			else
				self:visible(false)
			end
		end,
		-- a click anywhere else closes it
		TW.button(1, 1, function() TW.dropOpen = nil; MESSAGEMAN:Broadcast("TWDrop", {}) end) ..
			{ InitCommand = function(self) self:xy(-x, -FY):zoomto(SCREEN_WIDTH * 4, SCREEN_HEIGHT * 4) end },
		TW.shadow { w = w, h = #list * rowH + M(12), spread = M(14), alpha = 0.6 },
		TW.box { w = w, h = #list * rowH + M(12), r = M(8), col = LZ.a(LZ.bg5, 0.98) },
	}
	for i, it in ipairs(list) do
		f[#f + 1] = Def.ActorFrame {
			InitCommand = function(self) self:y(M(6) + (i - 0.5) * rowH):z(1) end,
			FillCommand = function(self)
				local on = it[2] == curSort() or (it[2] == "@collections" and TW.collection ~= nil and not TW.collection.pattern)
					or (it[2] == "@patterns" and TW.collection ~= nil and TW.collection.pattern ~= nil)
				self:GetChild("Text"):diffuse(on and LZ.pinkLight or white)
				self:GetChild("Tick"):visible(on)
			end,
			TW.box { w = w - M(12), h = rowH - M(2), r = M(5), ay = 0.5, col = LZ.a(LZ.bg2, 1), init = function(self) self:x(M(6)):diffusealpha(0) end } .. { Name = "Hl" },
			TW.icon("check", M(10), function(self) self:x(M(18)):diffuse(LZ.pinkLight) end) .. { Name = "Tick" },
			LZ.text(M(12.5), "regular", function(self) self:align(0, 0.5):x(M(32)):settext(it[1]) end) .. { Name = "Text" },
			TW.button(w, rowH, function()
				TW.dropOpen = nil
				MESSAGEMAN:Broadcast("TWDrop", {})
				setSort(it[2])
			end, function(self, on) self:GetParent():GetChild("Hl"):stoptweening():linear(0.08):diffusealpha(on and 1 or 0) end) ..
				{ InitCommand = function(self) self:align(0, 0.5):zoomto(w, rowH):diffusealpha(0) end },
		}
	end
	return f
end
t[#t + 1] = dropList("sort", SX, PW3 + M(40), sortItems)
t[#t + 1] = dropList("group", SX + PW3 + M(8), PW3 + M(40), groupItems)

-- the toolbar, over everything at the top
t[#t + 1] = LZ.toolbar {
	home = function() local s = SCREENMAN:GetTopScreen(); if s then s:Cancel() end end,
	profile = function() if TWOpenProfile then TWOpenProfile() end end,
	collections = function() TW.openCollections() end,
}
return t
