-- osu!lazer's results: the score card on the left (your picture and name, the song, lazer's accuracy
-- ring filling up round the grade with the grade badges at their thresholds, the score, the chart on
-- its star pill, accuracy / max combo / J4 and the judgement counts in lazer's colours), and lazer's
-- statistics beside it: the life graph, Til' Death's facts (MA / PA ratios, clear type, holds, mines,
-- the score's ratings) and the hit offsets across the chart (judge rescoring, column filter, stats).
TW.useInterfaceSkin()
local M = TW.M
local white = color("#FFFFFF")

local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
local hs = pss:GetHighScore()
local accData = TW.accData and TW.accData()
local pct = TW.accJ4 and TW.accJ4(accData) or pss:GetWifeScore() * 100
local mainPct, mainName = pct, "J4"
if TW.mainAcc then mainPct, mainName = TW.mainAcc(accData, hs) end
local failedPlay = pss:GetWifeGrade() == "Grade_Failed"
pcall(function() if pss:GetFailed() then failedPlay = true end end)
local rank = failedPlay and "F" or (TW.accRank and TW.accRank(mainPct)) or TW.GradeToRank[pss:GetWifeGrade()] or "D"
local ettGrade = TW.etternaGrade and TW.etternaGrade(pss:GetWifeGrade()) or ""
local function count(tns) return pss:GetTapNoteScores(tns) end
local function commas(n)
	local s = tostring(math.floor(math.abs(n)))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- A number that counts up from 0 to v (lazer's rolling score and counts): wraps a text actor.
local function countUp(textActor, v, delay, dur)
	return Def.ActorFrame {
		InitCommand = function(self)
			local txt = self:GetChild("N")
			local start = nil
			local done = false
			TW.everyFrame(self)
			self:SetUpdateFunction(function()
				if done then return end
				start = start or GetTimeSinceStart()
				local tt = math.max(0, math.min(1, (GetTimeSinceStart() - start - delay) / dur))
				local e = 1 - (1 - tt) ^ 3
				txt:settext(commas(v * e))
				if tt >= 1 then done = true end
			end)
		end,
		textActor .. { Name = "N" },
	}
end

local t = Def.ActorFrame {}

-- ------------------------------------------------------------------------------------------------
-- the score card
-- ------------------------------------------------------------------------------------------------
local CX, CW = M(240), M(400)
local CT, CB = M(108), M(746) -- the card's top and bottom (the picture sits over its top edge)
local card = Def.ActorFrame {
	InitCommand = function(self) self:x(CX) end,
	OnCommand = function(self) self:diffusealpha(0):addy(M(40)):decelerate(0.45):diffusealpha(1):addy(-M(40)) end,
	TW.shadow { w = CW, h = CB - CT, ax = 0.5, spread = M(20), alpha = 0.6, drop = M(5), init = function(self) self:y(CT) end },
	TW.box { w = CW, h = CB - CT, r = M(16), ax = 0.5, col = LZ.a(LZ.bg4, 0.97), col2 = LZ.a(LZ.bg5, 0.97), init = function(self) self:y(CT) end },
	-- the lighter part with the song and the ring
	TW.box { w = CW, h = M(414), r = M(16), ax = 0.5, col = LZ.a(LZ.bg2, 0.95), col2 = LZ.a(LZ.bg3, 0.95), init = function(self) self:y(CT + M(40)) end },
	-- your picture over the card's top edge, and your name
	TW.shadow { w = M(70), h = M(70), ax = 0.5, spread = M(10), alpha = 0.5, init = function(self) self:y(M(46)) end },
	Def.Sprite { InitCommand = function(self)
		local _, av = TW.profile()
		self:Load(av):align(0.5, 0):y(M(46)):zoomto(M(70), M(70))
	end },
	TW.box { w = M(72), h = M(72), r = M(12), ax = 0.5, tex = "ring", col = { 1, 1, 1, 0.3 }, init = function(self) self:y(M(45)) end },
	LZ.text(M(13), "bold", function(self)
		self:align(0.5, 0.5):y(CT + M(22)):maxwidth((CW - M(40)) / self:GetZoom())
		local p = TW.profile()
		local n = p and p:GetDisplayName() or ""
		self:settext(n ~= "" and n or "Guest")
	end),
	-- the song
	LZ.text(M(17), "bold", function(self)
		self:align(0.5, 0.5):y(CT + M(62)):maxwidth((CW - M(40)) / self:GetZoom()):settext(song and song:GetDisplayMainTitle() or "")
	end),
	LZ.text(M(12.5), "regular", function(self)
		self:align(0.5, 0.5):y(CT + M(82)):diffuse(LZ.content2):maxwidth((CW - M(40)) / self:GetZoom()):settext(song and song:GetDisplayArtist() or "")
	end),
}

-- lazer's accuracy ring: the outer band fills up to your accuracy (cyan to green), the inner one shows
-- where each grade starts (D red ... SS pink), the grades' badges sit at their places round it, and
-- the grade you got is written large in the middle
local RY = CT + M(234)
local RR = M(104)
local segs = { { 0, 0.7, "D" }, { 0.7, 0.8, "C" }, { 0.8, 0.9, "B" }, { 0.9, 0.95, "A" }, { 0.95, 0.995, "S" }, { 0.995, 1, "X" } }
local function arcVerts(verts, a0, a1, r0, r1, c0, c1, gap)
	gap = gap or 0
	a0, a1 = a0 + gap, a1 - gap
	if a1 <= a0 then return end
	-- (smooth edges: the band fades out over a screen pixel on both sides)
	local f = TW.px() * 1.1
	local rs = { r0 - f / 2, r0 + f / 2, r1 - f / 2, r1 + f / 2 }
	local n = math.max(2, math.ceil((a1 - a0) * 180))
	for k = 0, n - 1 do
		local f0, f1 = k / n, (k + 1) / n
		local t0, t1 = a0 + (a1 - a0) * f0, a0 + (a1 - a0) * f1
		local ca = c1 and TW.mix(c0, c1, f0) or c0
		local cb = c1 and TW.mix(c0, c1, f1) or c0
		ca[4], cb[4] = c0[4] or 1, c0[4] or 1
		local za, zb = { ca[1], ca[2], ca[3], 0 }, { cb[1], cb[2], cb[3], 0 }
		local s0, k0 = math.sin(t0 * 2 * math.pi), -math.cos(t0 * 2 * math.pi)
		local s1, k1 = math.sin(t1 * 2 * math.pi), -math.cos(t1 * 2 * math.pi)
		local cols = { { za, zb }, { ca, cb }, { ca, cb }, { za, zb } }
		for band = 1, 3 do
			local ri, ro = rs[band], rs[band + 1]
			local ci, co = cols[band], cols[band + 1]
			verts[#verts + 1] = { { s0 * ro, k0 * ro, 0 }, co[1] }
			verts[#verts + 1] = { { s1 * ro, k1 * ro, 0 }, co[2] }
			verts[#verts + 1] = { { s1 * ri, k1 * ri, 0 }, ci[2] }
			verts[#verts + 1] = { { s0 * ri, k0 * ri, 0 }, ci[1] }
		end
	end
end
local accFrac = math.max(0, math.min(1, mainPct / 100))
local ring = Def.ActorFrame {
	InitCommand = function(self) self:y(RY) end,
	-- the band's track
	Def.ActorMultiVertex { InitCommand = function(self)
		local v = {}
		arcVerts(v, 0, 1, RR - M(20), RR, { 1, 1, 1, 0.07 })
		self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(v)
	end },
	-- the grade segments
	Def.ActorMultiVertex { InitCommand = function(self)
		local v = {}
		for _, s in ipairs(segs) do arcVerts(v, s[1], s[2], RR - M(32), RR - M(26), LZ.rankColour(s[3]), nil, 0.002) end
		self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(v)
	end },
	-- the band, filling up
	Def.ActorFrame {
		InitCommand = function(frame)
			local amv = frame:GetChild("Fill")
			amv:SetDrawState { Mode = "DrawMode_Quads" }
			local start, done = nil, false
			TW.everyRefresh(frame)
			frame:SetUpdateFunction(function()
				if done then return end
				start = start or GetTimeSinceStart()
				local tt = math.min(1, (GetTimeSinceStart() - start - 0.4) / 1.6)
				if tt < 0 then return end
				local e = 1 - (1 - tt) ^ 3
				local v = {}
				arcVerts(v, 0, accFrac * e, RR - M(20), RR, TW.rgb(124, 246, 255), TW.rgb(186, 255, 169))
				amv:SetVertices(v)
				if tt >= 1 then done = true end
			end)
		end,
		Def.ActorMultiVertex { Name = "Fill" },
	},
	-- the grade, large, glowing in its colour
	TW.glow(RR * 1.6, LZ.a(LZ.rankColour(rank), 0.22)),
	TW.bigText(M(62), "bold", function(self)
		self:align(0.5, 0.5):y(-M(2)):settext(TW.RankLetter[rank] or rank):diffuse(LZ.rankColour(rank))
		self:zoom(self:GetZoom() * 1.5):diffusealpha(0):sleep(1.6):decelerate(0.35):zoom(self:GetZoom()):diffusealpha(1)
	end),
}
-- the badges round it
local badgeAt = { D = 0.35, C = 0.7, B = 0.8, A = 0.9, S = 0.95, X = 0.995 }
for r, f in pairs(badgeAt) do
	local a = f * 2 * math.pi
	local bx, by = math.sin(a) * (RR + M(26)), -math.cos(a) * (RR + M(26))
	if r == "X" then bx = bx + M(16) end
	ring[#ring + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(bx, by) end,
		TW.box { w = M(36), h = M(18), r = M(9), ax = 0.5, ay = 0.5, col = LZ.rankColour(r) },
		LZ.text(M(10), "bold", function(self) self:align(0.5, 0.5):settext(TW.RankLetter[r] or r):diffuse(LZ.rankText(r)) end),
	}
end
card[#card + 1] = ring
-- a full combo or a failed play, on a pill over the ring
local fc = false
pcall(function() fc = pss:FullComboOfScore("TapNoteScore_W3") end)
if fc or failedPlay then
	card[#card + 1] = Def.ActorFrame {
		InitCommand = function(self) self:y(RY + M(54)) end,
		OnCommand = function(self) self:zoom(1.4):diffusealpha(0):sleep(1.9):decelerate(0.3):zoom(1):diffusealpha(1) end,
		TW.box { w = M(130), h = M(22), r = M(11), ax = 0.5, ay = 0.5, col = failedPlay and TW.rgb(255, 90, 110) or LZ.yellow },
		LZ.text(M(11), "bold", function(self) self:align(0.5, 0.5):settext(failedPlay and "FAILED" or "FULL COMBO"):diffuse(TW.rgb(40, 25, 20)) end),
	}
end
-- the score
card[#card + 1] = countUp(TW.bigText(M(40), "light", function(self)
	self:align(0.5, 0.5):y(CT + M(372)):settext("0")
end), math.max(0, mainPct) * 10000, 0.4, 1.6)
-- the chart: star pill and rate, its name and mapper
card[#card + 1] = Def.ActorFrame {
	InitCommand = function(self) self:y(CT + M(406)) end,
	OnCommand = function(self)
		local c = self:GetChildren()
		c.Star:playcommand("Msd", { v = TW.msd(steps) })
		local w = (c.Star.w or M(60))
		local rate = getCurRateValue()
		local showRate = math.abs(rate - 1) > 0.001
		c.Rate:visible(showRate)
		local rw = showRate and (M(56) + M(6)) or 0
		local x0 = -(w + rw) / 2
		c.Star:x(x0)
		c.Rate:x(x0 + w + M(6))
	end,
	LZ.starPill(M(20)) .. { Name = "Star" },
	Def.ActorFrame { Name = "Rate",
		TW.box { w = M(56), h = M(20), r = M(10), ay = 0.5, col = LZ.purpleDark },
		LZ.text(M(10.5), "bold", function(self) self:align(0.5, 0.5):x(M(28)):settext(getCurRateDisplayString(true)) end),
	},
}
card[#card + 1] = LZ.text(M(13), "bold", function(self)
	self:align(0.5, 0.5):y(CT + M(428)):diffuse(LZ.pinkLight):settext(steps and TW.diffName(steps) or ""):maxwidth((CW - M(40)) / self:GetZoom())
end)
card[#card + 1] = LZ.text(M(10.5), "regular", function(self)
	local by = song and TW.author(song) or ""
	self:align(0.5, 0.5):y(CT + M(444)):diffuse(LZ.dim):settext(by ~= "" and ("mapped by " .. by) or (song and song:GetGroupName() or ""))
	self:maxwidth((CW - M(40)) / self:GetZoom())
end)
-- accuracy / max combo / J4 (or Etterna's grade): lazer's small headed columns
local SY = CT + M(478)
local function statCol(x, w, head, value, col)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(x, SY) end,
		TW.box { w = w, h = M(16), r = M(8), ax = 0.5, ay = 0.5, col = LZ.a(LZ.bg6, 0.9) },
		LZ.text(M(8.5), "bold", function(self) self:align(0.5, 0.5):settext(head):diffuse(LZ.dim) end),
		LZ.text(M(17), "regular", function(self) self:align(0.5, 0.5):y(M(23)):settext(value):diffuse(col or white) end),
	}
end
local total = 0
pcall(function() total = steps:GetRadarValues(PLAYER_1):GetValue("RadarCategory_Notes") end)
local third = (CW - M(40)) / 3
card[#card + 1] = statCol(-third, third - M(8), "ACCURACY " .. (mainName or ""), string.format("%.2f%%", mainPct))
card[#card + 1] = statCol(0, third - M(8), "MAX COMBO", string.format("%sx", commas(pss:MaxCombo())))
card[#card + 1] = statCol(third, third - M(8), mainName == "J4" and "ETTERNA" or "J4",
	mainName == "J4" and (ettGrade ~= "" and ettGrade or "-") or string.format("%.2f%%", pct))
-- the judgements, in lazer's colours
local judges = {
	{ "TapNoteScore_W1", "PERFECT", TW.rgb(153, 238, 255) }, { "TapNoteScore_W2", "GREAT", TW.rgb(102, 204, 255) },
	{ "TapNoteScore_W3", "GOOD", TW.rgb(179, 217, 68) }, { "TapNoteScore_W4", "OK", TW.rgb(136, 179, 0) },
	{ "TapNoteScore_W5", "MEH", TW.rgb(255, 204, 34) }, { "TapNoteScore_Miss", "MISS", TW.rgb(237, 60, 70) },
}
local JW = (CW - M(36)) / 6
for i, j in ipairs(judges) do
	local x = -CW / 2 + M(18) + (i - 0.5) * JW
	card[#card + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(x, SY + M(56)) end,
		TW.box { w = JW - M(4), h = M(15), r = M(7.5), ax = 0.5, ay = 0.5, col = LZ.a(LZ.bg6, 0.9) },
		LZ.text(M(8), "bold", function(self) self:align(0.5, 0.5):settext(j[2]):diffuse(j[3]) end),
		countUp(LZ.text(M(15), "regular", function(self) self:align(0.5, 0.5):y(M(21)):settext("0") end), count(j[1]), 0.6 + i * 0.05, 1.2),
	}
end
card[#card + 1] = LZ.text(M(9.5), "regular", function(self)
	self:align(0.5, 0.5):y(CB - M(16)):diffuse(LZ.dim):settext("Played on " .. (hs and hs:GetDate() or ""))
end)
t[#t + 1] = card

-- ------------------------------------------------------------------------------------------------
-- the statistics, right of the card
-- ------------------------------------------------------------------------------------------------
local RX = M(470)
local RW = SCREEN_WIDTH - RX - M(16)
local function statPanel(x, y, w, h, title)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(x, y) end,
		OnCommand = function(self) self:diffusealpha(0):addx(M(40)):sleep(0.15):decelerate(0.4):diffusealpha(1):addx(-M(40)) end,
		TW.shadow { w = w, h = h, spread = M(12), alpha = 0.5, drop = M(3) },
		TW.box { w = w, h = h, r = M(12), col = LZ.a(LZ.bg4, 0.94), col2 = LZ.a(LZ.bg5, 0.94) },
		title and LZ.text(M(12), "bold", function(self) self:align(0, 0.5):xy(M(14), M(16)):settext(title):diffuse(LZ.light2) end) or Def.Actor {},
	}
end
-- the life graph
local GW, GH = M(440), M(186)
local life = statPanel(RX, M(56), GW, GH, "Life")
life[#life + 1] = Def.ActorMultiVertex {
	OnCommand = function(self)
		local len = song and song:GetLastSecond() or 1
		local rec = pss:GetLifeRecord(len, 100)
		local w, h = GW - M(28), GH - M(46)
		local x0, y0 = M(14), M(34)
		local v = {}
		for i = 1, #rec - 1 do
			local a, b = rec[i], rec[i + 1]
			local xa = x0 + (i - 1) / math.max(1, #rec - 1) * w
			local xb = x0 + i / math.max(1, #rec - 1) * w
			local c = (a + b) / 2 < 0.5 and { 1, 0.35, 0.4, 0.4 } or LZ.a(LZ.lime, 0.35)
			local c0 = { c[1], c[2], c[3], 0.02 }
			v[#v + 1] = { { xa, y0 + (1 - a) * h, 0 }, c }
			v[#v + 1] = { { xb, y0 + (1 - b) * h, 0 }, c }
			v[#v + 1] = { { xb, y0 + h, 0 }, c0 }
			v[#v + 1] = { { xa, y0 + h, 0 }, c0 }
		end
		if #v > 0 then self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(v) end
	end,
}
life[#life + 1] = Def.ActorMultiVertex {
	OnCommand = function(self)
		local len = song and song:GetLastSecond() or 1
		local rec = pss:GetLifeRecord(len, 100)
		local w, h = GW - M(28), GH - M(46)
		local verts = {}
		local function pt(i) return M(14) + (i - 1) / math.max(1, #rec - 1) * w, M(34) + (1 - rec[i]) * h end
		for i = 1, #rec - 1 do
			local x0, y0 = pt(i)
			local x1, y1 = pt(i + 1)
			local c = (rec[i] + rec[i + 1]) / 2 < 0.5 and TW.rgb(255, 90, 110) or LZ.lime
			TW.aaLine(verts, x0, y0, x1, y1, M(2.2), c)
		end
		if #verts > 0 then self:SetDrawState { Mode = "DrawMode_Triangles" }:SetVertices(verts) end
	end,
}
t[#t + 1] = life
-- Til' Death's facts
local FX = RX + GW + M(14)
t[#t + 1] = statPanel(FX, M(56), SCREEN_WIDTH - FX - M(16), GH, "Details")
t[#t + 1] = TW.evalPanel {
	x = FX + M(4), y = M(56) + M(30), w = SCREEN_WIDTH - FX - M(24), h = GH - M(34), cols = 2, px = M(12), pad = M(10),
	text = function(px, bold, init) return LZ.text(px, bold and "bold" or "regular", init) end, accent = LZ.pinkLight,
	bg = { 0, 0, 0, 0 }, label = LZ.dim,
}
-- the hit offsets
local OY = M(56) + GH + M(14)
t[#t + 1] = statPanel(RX, OY, RW, M(746) - OY, nil)
t[#t + 1] = TW.offsetPlot {
	x = RX + M(6), y = OY + M(4), w = RW - M(12), h = M(746) - OY - M(8),
	text = function(px, bold, init) return LZ.text(px, bold and "bold" or "regular", init) end, accent = LZ.pink,
	bg = { 0, 0, 0, 0 },
	colour = function(i) return judges[i] and judges[i][3] or white end,
}

-- hovering the accuracy: what it is on the other judges and ODs
if TW.accTooltip then
	t[#t + 1] = TW.accTooltip(function() return CX - third - (third - M(8)) / 2, SY - M(10), third, M(46) end,
		{ text = function(px, bold, init) return LZ.text(px, bold and "bold" or "regular", init) end, px = M(13), accent = LZ.pink, bg = LZ.a(LZ.bg5, 0.98) })
end
return t
