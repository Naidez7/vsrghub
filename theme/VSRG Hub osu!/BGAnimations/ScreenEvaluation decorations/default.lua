-- osu!'s results screen, laid out where osu! stable puts things: the skin's ranking-panel at the
-- top left with the hit counts, max combo and accuracy written over it in the skin's score font,
-- the ranking graph with your life line, the big grade letter on the right and the song lines at
-- the top. Etterna's Wife% is the score; its grades map to osu!'s letters.
TW.useInterfaceSkin()
local U = TW.U
local function O(v) return v * U end -- osu! 768-tall pixels to Etterna pixels
local OW = SCREEN_WIDTH / U -- screen width in osu! pixels

local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
local hs = pss:GetHighScore()
-- the accuracy at J4 (what Etterna ranks by), whatever the timing was; it can go below 0 as in
-- Etterna. Played on an osu! OD, osu!'s own accuracy shows under it too.
local accData = TW.accData and TW.accData()
local pct = TW.accJ4 and TW.accJ4(accData) or pss:GetWifeScore() * 100
local playedMode = TW.playedTiming and TW.playedTiming(hs)
-- the big accuracy is on the timing it was played on (osu!'s OD or Etterna's judge; a failed play's
-- on what was played), J4 small under it, the other timings when the mouse is over it
local mainPct, mainName = pct, "J4"
if TW.mainAcc then mainPct, mainName = TW.mainAcc(accData, hs) end
-- the big grade: osu!'s letter for the accuracy on the timing played (97% on OD 8 is an S); a failed
-- play is an F (osu! skins have no F art, so it is drawn as a letter). Etterna's grade is written
-- small under the accuracy.
local failedPlay = pss:GetWifeGrade() == "Grade_Failed"
pcall(function() if pss:GetFailed() then failedPlay = true end end)
local rank = failedPlay and "F" or (TW.accRank and TW.accRank(mainPct)) or TW.GradeToRank[pss:GetWifeGrade()] or "D"
local ettGrade = TW.etternaGrade and TW.etternaGrade(pss:GetWifeGrade()) or ""
local function count(tns) return pss:GetTapNoteScores(tns) end

local t = Def.ActorFrame {}

-- the grade, drawn first so it sits behind the panels and numbers: a skin's big grade art often
-- reaches over the pattern ratings and the numbers beside them
local rankId = "rank_" .. rank
local grade = TW.has(rankId) and Def.Sprite {
	Texture = TW.img(rankId),
	InitCommand = function(self) TW.inset(self):xy(O(OW - 192), O(320)) end,
	OnCommand = function(self)
		local z = TW.scale(rankId)
		self:diffusealpha(0):zoom(z * 1.3):decelerate(0.4):zoom(z):diffusealpha(1)
	end
} or ((TW.fallback(rankId) or rank == "F") and TW.text(O(150), true, function(self)
	self:align(0.5, 0.5):xy(O(OW - 192), O(320)):settext(TW.RankLetter[rank] or rank):diffuse(TW.RankColour[rank] or color("#999999"))
end) or Def.Actor {})
t[#t + 1] = grade

-- osu!'s header: a dark band behind the song lines (as osu!'s, nearly opaque) and the skin's
-- ranking-title on the right, or the word
t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, O(97)):diffuse({ 0.09, 0.09, 0.09, 0.9 }) end }
if not TW.has("ranking_panel") then
	t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(0, O(97)):zoomto(SCREEN_WIDTH, O(14)):diffuse({ 0, 0, 0, 0.35 }):diffusebottomedge({ 0, 0, 0, 0 }) end }
end
if TW.has("ranking_title") then
	t[#t + 1] = TW.sprite("ranking_title", function(self)
		self:align(1, 0):xy(SCREEN_WIDTH - O(32), 0)
		self:addx(O(30)):diffusealpha(0):decelerate(0.4):addx(-O(30)):diffusealpha(1)
	end)
elseif TW.fallback("ranking_title") then
	t[#t + 1] = TW.text(O(46), false, function(self)
		self:align(1, 0.5):xy(SCREEN_WIDTH - O(24), O(44)):settext("Ranking"):diffusealpha(0.95)
		self:addx(O(30)):diffusealpha(0):decelerate(0.4):addx(-O(30)):diffusealpha(0.95)
	end)
	t[#t + 1] = TW.box { w = O(70), h = O(4), r = O(2), ax = 1, col = TW.pink, init = function(self) self:xy(SCREEN_WIDTH - O(26), O(74)) end }
end

-- song lines
t[#t + 1] = TW.text(TW.M(23), false, function(self)
	self:align(0, 0.5):xy(TW.M(6), TW.M(18)):maxwidth(SCREEN_WIDTH * 0.7 / self:GetZoom())
	self:settext(song and (song:GetDisplayArtist() .. " - " .. song:GetDisplayMainTitle() .. (steps and (" [" .. TW.diffName(steps) .. "]") or "")) or "")
end)
t[#t + 1] = TW.text(TW.M(17), false, function(self)
	self:align(0, 0.5):xy(TW.M(6), TW.M(47))
	local by = song and TW.author(song) or ""
	self:settextf("Beatmap by %s   %.2f MSD at %s", by ~= "" and by or (song and song:GetGroupName() or "?"), TW.msd(steps), getCurRateDisplayString(true))
end)
t[#t + 1] = TW.text(TW.M(17), false, function(self)
	self:align(0, 0.5):xy(TW.M(6), TW.M(71))
	local prof = PROFILEMAN:GetProfile(PLAYER_1)
	local who = prof and prof:GetDisplayName() or "you"
	self:settextf("Played by %s on %s.", who, hs and hs:GetDate() or "")
end)

-- the panel
if TW.has("ranking_panel") then
	t[#t + 1] = TW.sprite("ranking_panel", function(self) self:align(0, 0):xy(0, O(102)) end)
elseif TW.fallback("ranking_panel") then
	-- a rounded card coming in from the left edge, with a soft shadow and the interface colour along its top
	t[#t + 1] = Def.ActorFrame {
		OnCommand = function(self) self:addx(-O(60)):diffusealpha(0):decelerate(0.35):addx(O(60)):diffusealpha(1) end,
		TW.shadow { w = O(636), h = O(480), spread = O(18), alpha = 0.55, drop = O(4), init = function(self) self:xy(-O(16), O(108)) end },
		TW.box { w = O(636), h = O(480), r = O(18), col = { 0.11, 0.11, 0.15, 0.88 }, col2 = { 0.06, 0.06, 0.09, 0.9 }, init = function(self) self:xy(-O(16), O(108)) end },
		TW.box { w = O(600), h = O(3), r = O(1.5), col = TW.pink, init = function(self) self:xy(O(10), O(110)):diffusealpha(0.8) end },
		-- the lines between the score, the counts and the combo / accuracy
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(O(16), O(204)):zoomto(O(588), 1):diffuse({ 1, 1, 1, 0.08 }) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(O(16), O(498)):zoomto(O(588), 1):diffuse({ 1, 1, 1, 0.08 }) end },
	}
end

-- numbers on it
-- (with a value and its format, the number rolls up to it as osu!'s results do: quickly, easing out)
local function num(name, text, x, y, zoom, chars, v, fmt)
	return TW.number("score", chars or 10, name, zoom, 0, function(self) self:xy(O(x), O(y)) end) .. {
		OnCommand = function(self)
			if not v or v <= 0 or not self.SetUpdateFunction then self:playcommand("SetText", { text = text }) return end
			local t0, dur, delay, last = GetTimeSinceStart(), 0.9, 0.25, nil
			self:playcommand("SetText", { text = fmt(0) })
			-- (the skin's digits are a frame of sprites, which can run an update function; the font's
			-- text can't, and just shows the number)
			TW.everyFrame(self)
			self:SetUpdateFunction(function(a)
				local k = math.min(1, math.max(0, (GetTimeSinceStart() - t0 - delay) / dur))
				local txt = k >= 1 and text or fmt(v * (1 - (1 - k) ^ 3))
				if txt ~= last then last = txt; a:playcommand("SetText", { text = txt }) end
				if k >= 1 then a:SetUpdateFunction(nil) end
			end)
		end
	}
end
local function int(n) return tostring(math.floor(n + 0.5)) end
local scoreV = math.floor(math.max(0, mainPct) * 10000)
-- (seven digits, as osu!mania's score: Wife% 100 is 1,000,000)
t[#t + 1] = num("Score", string.format("%07d", scoreV), 220, 128, 1.1, nil, scoreV, function(n) return string.format("%07d", math.floor(n)) end)
local rows = {
	{ "TapNoteScore_W2", 133, 230, "300" }, { "TapNoteScore_W1", 456, 230, "MAX" },
	{ "TapNoteScore_W4", 133, 326, "100" }, { "TapNoteScore_W3", 456, 326, "200" },
	{ "TapNoteScore_W5", 133, 422, "50" }, { "TapNoteScore_Miss", 456, 422, "MISS" },
}
-- each judgement's colour (its chip over the count)
local judgeCol = { TapNoteScore_W1 = TW.rgb(225, 240, 255), TapNoteScore_W2 = TW.rgb(255, 214, 80), TapNoteScore_W3 = TW.rgb(130, 225, 80),
	TapNoteScore_W4 = TW.rgb(80, 165, 255), TapNoteScore_W5 = TW.rgb(190, 120, 255), TapNoteScore_Miss = TW.rgb(255, 80, 80) }
local ids = { TapNoteScore_W1 = "judge_W1", TapNoteScore_W2 = "judge_W2", TapNoteScore_W3 = "judge_W3",
	TapNoteScore_W4 = "judge_W4", TapNoteScore_W5 = "judge_W5", TapNoteScore_Miss = "judge_Miss" }
for _, r in ipairs(rows) do
	-- just the count: some skins draw their score font's "x" as a word ("Score")
	t[#t + 1] = num(r[1], tostring(count(r[1])), r[2], r[3], 1.1, 7, count(r[1]), int)
	-- osu! draws the judgement's hit art left of each count
	local id = ids[r[1]]
	do
		if TW.has(id) then
			t[#t + 1] = TW.sprite(id, function(self) self:align(1, 0.5):xy(O(r[2] - 14), O(r[3] + 24))
				-- the judgment's hit art beside its count, as tall as the numbers and kept inside the
				-- panel column (osu! skins' hit art can be very wide)
				local h = self:GetHeight()
				if h and h > 0 then self:zoom(O(56) / h) end
				local room = O(r[2] - 14) - (r[2] > 300 and O(330) or O(4))
				local fit = 1
				if self:GetZoomedWidth() > room then fit = room / self:GetZoomedWidth(); self:zoom(self:GetZoom() * fit) end
				-- art that would only fit shrunk to a speck (wide images, mostly empty) is left out; the
				-- caption over the count says which judgment it is
				if self:GetZoomedHeight() < O(22) or fit < 0.6 then self:visible(false) end
			end)
		end
		-- (no art: the caption over the count names it, a second label beside it would repeat it)
	end
	-- without the skin's hit art (or with it blanked: some skins point osu!mania at hit art elsewhere),
	-- a small caption over the count, so it's clear which judgment it is
	if not TW.has(id) then
		t[#t + 1] = TW.box { w = O(58), h = O(20), r = O(10), ay = 1, col = judgeCol[r[1]], init = function(self) self:xy(O(r[2] + 2), O(r[3] - 4)) end }
		t[#t + 1] = TW.text(O(13), true, function(self)
			self:align(0.5, 0.5):xy(O(r[2] + 31), O(r[3] - 14)):settext(r[4]):diffuse(TW.rgb(24, 22, 32))
		end)
	end
end
t[#t + 1] = num("Combo", tostring(pss:MaxCombo()), 32, 528, 1.1, nil, pss:MaxCombo(), int)
t[#t + 1] = num("Acc", string.format("%.2f%%", mainPct), 319, 528, 1.1, nil, math.max(0, mainPct), function(n) return string.format("%.2f%%", n) end)
-- (under the accuracy's digits, however tall the skin's number font is)
t[#t + 1] = TW.text(O(13), true, function(self)
	self:align(0, 0):xy(O(321), O(568)):diffuse(color("1,1,1,0.75"))
	local g = ettGrade ~= "" and ("   Etterna " .. ettGrade) or ""
	self:settext((mainName == "J4" and "J4" or string.format("%s   J4 %.2f%%", mainName, pct)) .. g)
end) .. {
	OnCommand = function(self) self:sleep(0.02):queuecommand("Place") end,
	PlaceCommand = function(self)
		local acc = self:GetParent():GetChild("Acc")
		if not acc then return end
		local h = 0
		pcall(function()
			-- (the first digit shown: a minus takes the first place without a picture of its own)
			local c
			for i = 1, 10 do
				local ci = acc.GetChild and acc:GetChild("c" .. i)
				if ci and ci:GetVisible() then c = ci break end
			end
			if c and c.GetZoomedHeight then h = c:GetZoomedHeight() * acc:GetZoom() else h = acc:GetZoomedHeight() end
			-- (a padded skin's digit pictures are much taller than the digits: their ink)
			local t, b = TW_SKIN and TW_SKIN.scoreInkT, TW_SKIN and TW_SKIN.scoreInkB
			if t and b and b > t then h = h * b end
		end)
		if h and h > 0 then self:y(O(528) + h + O(4)) end
	end,
}
-- osu!'s "Max Combo" and "Accuracy" art: the skin's (none when it blanks them: its panel has the
-- words), or VSRG Hub writes them
if TW.has("ranking_maxcombo") then
	t[#t + 1] = TW.sprite("ranking_maxcombo", function(self) self:align(0, 1):xy(O(8), O(520)) end)
elseif TW.fallback("ranking_maxcombo") then
	t[#t + 1] = TW.text(O(17), true, function(self) self:align(0, 1):xy(O(32), O(522)):settext("Max Combo"):diffuse(TW.pinkLight or TW.pink) end)
end
if TW.has("ranking_accuracy") then
	t[#t + 1] = TW.sprite("ranking_accuracy", function(self) self:align(0, 1):xy(O(291), O(520)) end)
elseif TW.fallback("ranking_accuracy") then
	t[#t + 1] = TW.text(O(17), true, function(self) self:align(0, 1):xy(O(319), O(522)):settext("Accuracy"):diffuse(TW.pinkLight or TW.pink) end)
end

-- graph with the life line
local GX, GY = 256, 608
if TW.has("ranking_graph") then
	t[#t + 1] = TW.sprite("ranking_graph", function(self) self:align(0, 0):xy(O(GX), O(GY)) end)
elseif TW.fallback("ranking_graph") then
	t[#t + 1] = TW.shadow { w = O(308), h = O(158), spread = O(10), alpha = 0.5, drop = O(3), init = function(self) self:xy(O(GX), O(GY)) end }
	t[#t + 1] = TW.box { w = O(308), h = O(158), r = O(10), col = { 0.1, 0.1, 0.14, 0.86 }, col2 = { 0.06, 0.06, 0.09, 0.86 }, init = function(self) self:xy(O(GX), O(GY)) end }
	t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(O(GX + 6), O(GY + 9 + 70)):zoomto(O(296), 1):diffuse({ 1, 1, 1, 0.12 }) end }
end
-- the area under the life line, filled (green above half, red below)
t[#t + 1] = Def.ActorMultiVertex {
	OnCommand = function(self)
		local len = song and song:GetLastSecond() or 1
		local rec = pss:GetLifeRecord(len, 100)
		local w, h = O(296), O(140)
		local v = {}
		local base = O(GY + 9) + h
		for i = 1, #rec - 1 do
			local x1 = O(GX + 6) + (i - 1) / math.max(1, #rec - 1) * w
			local x2 = O(GX + 6) + i / math.max(1, #rec - 1) * w
			local a, b = rec[i], rec[i + 1]
			local c = (a + b) / 2 < 0.5 and { 1, 0.3, 0.3, 0.32 } or { 0.66, 0.9, 0.16, 0.3 }
			local c0 = { c[1], c[2], c[3], 0.02 }
			v[#v + 1] = { { x1, O(GY + 9) + (1 - a) * h, 0 }, c }
			v[#v + 1] = { { x2, O(GY + 9) + (1 - b) * h, 0 }, c }
			v[#v + 1] = { { x2, base, 0 }, c0 }
			v[#v + 1] = { { x1, base, 0 }, c0 }
		end
		if #v > 0 then self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(v) end
	end
}
t[#t + 1] = Def.ActorMultiVertex {
	OnCommand = function(self)
		local len = song and song:GetLastSecond() or 1
		local samples = 100
		local rec = pss:GetLifeRecord(len, samples)
		local verts = {}
		local w, h = O(296), O(140)
		local function pt(i) return O(GX + 6) + (i - 1) / math.max(1, #rec - 1) * w, O(GY + 9) + (1 - rec[i]) * h end
		for i = 1, #rec - 1 do
			local x0, y0 = pt(i)
			local x1, y1 = pt(i + 1)
			local c = (rec[i] + rec[i + 1]) / 2 < 0.5 and TW.rgb(255, 60, 60) or TW.rgb(170, 230, 40)
			TW.aaLine(verts, x0, y0, x1, y1, O(2.6), c)
		end
		if #verts > 0 then self:SetDrawState { Mode = "DrawMode_Triangles" }:SetVertices(verts) end
	end
}

-- hit offsets across the chart, as on Etterna's results (column filter, judge rescoring, stats)
local osuJudge = { TW.rgb(255, 255, 255), TW.rgb(255, 230, 90), TW.rgb(120, 230, 70), TW.rgb(70, 160, 255), TW.rgb(190, 110, 255), TW.rgb(255, 60, 60) }
t[#t + 1] = TW.offsetPlot {
	x = O(640), y = O(560), w = SCREEN_WIDTH - O(656), h = O(196),
	text = TW.text, accent = TW.pink,
	colour = function(i) return osuJudge[i] end,
}

-- what Til' Death shows besides: MA / PA ratios, clear type, holds, mines, the score's ratings. A
-- strip right above the hit offsets, left of "Watch replay", so the skin's big grade on the right
-- stays in view as in osu!
t[#t + 1] = TW.evalPanel {
	x = O(640), y = O(462), w = SCREEN_WIDTH - O(640) - O(236), h = O(92), cols = 4, px = O(12.5), pad = O(8),
	text = TW.text, accent = TW.pink,
}

-- full combo stamp
local fc = false
pcall(function() fc = pss:FullComboOfScore("TapNoteScore_W3") end)
if fc then
	if TW.has("ranking_perfect") then
		t[#t + 1] = TW.sprite("ranking_perfect", function(self) self:xy(O(416), O(688)) end)
	else
		-- a golden "full combo" pill on the graph's corner
		t[#t + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(O(GX + 300), O(GY - 2)) end,
			OnCommand = function(self) self:zoom(1.4):diffusealpha(0):sleep(0.5):decelerate(0.3):zoom(1):diffusealpha(1) end,
			TW.shadow { w = O(150), h = O(30), ax = 1, ay = 0.5, spread = O(8), alpha = 0.5 },
			TW.box { w = O(150), h = O(30), r = O(15), ax = 1, ay = 0.5, col = TW.rgb(255, 222, 110), col2 = TW.rgb(240, 170, 40) },
			TW.text(O(16), true, function(self) self:align(0.5, 0.5):x(-O(75)):settext("FULL COMBO"):diffuse(TW.rgb(70, 40, 0)) end),
		}
	end
end

-- (last, over everything else)
-- hovering the accuracy: what it is on the other judges and ODs
if TW.accTooltip then
	t[#t + 1] = TW.accTooltip(function() return O(300), O(512), O(320), O(80) end, { text = TW.text, px = O(14), accent = TW.pink })
end
return t
