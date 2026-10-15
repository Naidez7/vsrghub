-- Quaver's results: the song header with the big grade, the stat strip (max combo, accuracy,
-- performance rating, MSD, score), the judgment list and the hit deviance graph. Etterna's Wife%
-- is the accuracy, its Overall SSR the performance rating.
local M, R = TW.M, TW.R
local white = color("#FFFFFF")
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
local hs = pss:GetHighScore()
-- the accuracy at J4 (what Etterna ranks by), whatever the timing was; it can go below 0 as in
-- Etterna. Played on an osu! OD, osu!'s own accuracy shows too.
local accData = TW.accData and TW.accData()
local pct = TW.accJ4 and TW.accJ4(accData) or pss:GetWifeScore() * 100
local playedMode = TW.playedTiming and TW.playedTiming(hs)
-- the big accuracy is on the timing it was played on (osu!'s OD or Etterna's judge; a failed play's
-- on what was played), J4 small with it, the other timings when the mouse is over it
local mainPct, mainName = pct, "J4"
if TW.mainAcc then mainPct, mainName = TW.mainAcc(accData, hs) end
local failed = false
pcall(function() failed = pss:GetFailed() end)
-- (a past score opened from the leaderboard: its grade says whether it failed)
pcall(function() if hs:GetWifeGrade() == "Grade_Failed" then failed = true end end)
-- the big grade: Quaver's for the accuracy on the timing played (Etterna's grade written small by
-- the accuracy)
local grade = failed and "F" or QV.accGrade(mainPct)
local ettGrade = TW.etternaGrade and TW.etternaGrade(pss:GetWifeGrade()) or ""
local autoplay = TW.autoplay == true
local judgeScale = 1
pcall(function() judgeScale = hs:GetJudgeScale() end)
local function commas(n)
	local neg = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (neg and "-" or "") .. (out:gsub("^,", ""))
end

local L, RR = M(94), R(1369)
local t = Def.ActorFrame {}

-- header: the song's picture, title, difficulty, mapper
t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(M(86), M(110)):zoomto(M(144), M(135)):diffuse(TW.rgb(30, 30, 30)) end }
t[#t + 1] = Def.Sprite { OnCommand = function(self)
	local p = song and (TW.thumbPath(song) or song:GetBannerPath())
	if p and p ~= "" then self:LoadBackground(p):align(0, 0):xy(M(94), M(118)):scaletoclipped(M(128), M(127)) end
end }
t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(M(86), M(249)):zoomto(M(144), M(4)):diffuse(QV.cyan) end }
t[#t + 1] = QV.t(M(19), true, function(self)
	self:align(0, 0.5):xy(M(255), M(131))
	QV.fit(self, song and (song:GetDisplayArtist() .. " - " .. song:GetDisplayMainTitle()) or "", R(1200) - M(255))
end)
t[#t + 1] = QV.t(M(14), false, function(self)
	self:align(0, 0.5):xy(M(255), M(158)):diffuse(QV.diffColour(TW.msd(steps)))
	self:settextf("[%s] (%.2f)%s", steps and TW.diffName(steps) or "?", TW.msd(steps),
		math.abs(getCurRateValue() - 1) > 0.001 and ("  " .. getCurRateDisplayString(true)) or "")
end)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(M(255), M(183)) end,
	QV.t(M(13.5), true, function(self) self:align(0, 0.5):settext("Mapped by:") end) .. { Name = "A" },
	QV.t(M(13.5), true, function(self) self:align(0, 0.5):diffuse(QV.lightCyan) end) .. {
		OnCommand = function(self)
			local by = song and TW.author(song) or ""
			self:settext(by ~= "" and by or (song and song:GetGroupName() or ""))
			self:x(self:GetParent():GetChild("A"):GetZoomedWidth() + M(10))
		end
	},
}
-- the tab strip with the gradient line
t[#t + 1] = QV.gradient(RR - M(243), M(42), 0.12) .. { InitCommand = function(self) self:xy(M(243), M(203)) end }
t[#t + 1] = QV.gradient(RR - M(243), M(3)) .. { InitCommand = function(self) self:xy(M(243), M(243)) end }
t[#t + 1] = QV.t(M(13.5), true, function(self) self:align(0, 0.5):xy(M(253), M(224)):settext("Overview"):diffuse(QV.lightCyan) end)
t[#t + 1] = QV.t(M(13.5), true, function(self) -- the key mode at the strip's far end (not a second tab)
	self:align(1, 0.5):xy(RR - M(12), M(224)):settext(GAMESTATE:GetCurrentGame():GetName() == "kb7" and "7 Keys" or "4 Keys"):diffuse(QV.grey) end)
-- the grade
t[#t + 1] = QV.text(M(110), QV.black, function(self)
	self:align(0.5, 0.5):xy(R(1298), M(140)):settext(QV.gradeLetter[grade]):diffuse(QV.gradeColour[grade])
end) .. { OnCommand = function(self) local z = self:GetZoom(); self:diffusealpha(0):zoom(z * 1.3):decelerate(0.4):zoom(z):diffusealpha(1) end }

if autoplay then
	t[#t + 1] = QV.t(M(14), true, function(self) self:align(1, 0.5):xy(R(1230), M(224)):settext("AUTOPLAY"):diffuse(QV.yellow) end)
end
-- played by / judge
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(L, M(278)) end,
	QV.t(M(13), true, function(self) self:align(0, 0.5):settext("Played by"):diffuse(TW.rgb(200, 200, 200)) end) .. { Name = "A" },
	QV.t(M(13), true, function(self) self:align(0, 0.5):diffuse(TW.rgb(0, 212, 255)) end) .. {
		Name = "B",
		OnCommand = function(self)
			local prof = PROFILEMAN:GetProfile(PLAYER_1)
			self:settext(prof and prof:GetDisplayName() or "you"):x(self:GetParent():GetChild("A"):GetZoomedWidth() + M(6))
			local c = self:GetParent():GetChild("C")
			c:x(self:GetX() + self:GetZoomedWidth() + M(6)):settext("on " .. (hs and hs:GetDate() or ""))
		end
	},
	QV.t(M(13), true, function(self) self:align(0, 0.5):diffuse(TW.rgb(200, 200, 200)) end) .. { Name = "C" },
}
t[#t + 1] = QV.t(M(13), true, function(self)
	self:align(1, 0.5):xy(RR, M(278)):diffuse(QV.yellow)
	-- (Etterna's judge scales: J4 1, J5 0.84, J6 0.66, J7 0.5, J8 0.33, Justice 0.2)
	local judge = 4
	local scales = { [4] = 1, [5] = 0.84, [6] = 0.66, [7] = 0.5, [8] = 0.33, [9] = 0.2 }
	pcall(function() if ms and ms.JudgeScalers then scales = ms.JudgeScalers end end)
	local best = 99
	for j = 4, 9 do local d = math.abs((scales[j] or 1) - judgeScale); if d < best then best, judge = d, j end end
	self:settext(best > 0.01 and string.format("Judge: x%.2f", judgeScale) or (judge == 9 and "Judge: Justice" or ("Judge: J" .. judge)))
end)

-- the stat strip
local ssr = 0
pcall(function() ssr = hs:GetSkillsetSSR("Overall") end)
local stats = {
	{ tostring(pss:MaxCombo()) .. "x", "MAX COMBO" },
	{ string.format("%.2f%%", mainPct), (mainName == "J4" and "ACCURACY (J4)" or string.format("ACCURACY (%s)   J4 %.2f%%", mainName:upper(), pct))
		.. (ettGrade ~= "" and ("   ETTERNA " .. ettGrade) or "") },
	{ string.format("%.2f", ssr), "PERFORMANCE RATING", TW.rgb(246, 187, 35) },
	{ string.format("%.2f", TW.msd(steps)), "MSD" },
	{ commas(math.max(0, mainPct) * 10000), "TOTAL SCORE" },
}
t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(L, M(296)):zoomto(RR - L, M(70)):diffuse(color("#000000")):diffusealpha(0.85) end }
t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(L, M(365)):zoomto(RR - L, M(3)):diffuse(TW.rgb(170, 170, 170)) end }
for i, s in ipairs(stats) do
	local cx = L + (RR - L) * (i - 0.5) / #stats
	t[#t + 1] = QV.text(M(22), TW.font, function(self) self:align(0.5, 0.5):xy(cx, M(320)):settext(s[1]):diffuse(s[3] or white) end)
	t[#t + 1] = QV.t(M(14), true, function(self) self:align(0.5, 0.5):xy(cx, M(348)):settext(s[2]):diffuse(s[3] or white) end)
end

-- judgments
local total = 0
for _, j in ipairs(QV.judgeOrder) do total = total + pss:GetTapNoteScores(j) end
for i, j in ipairs(QV.judgeOrder) do
	local y = M(416) + (i - 1) * M(43)
	local col = QV.judge[j][2]
	local n = pss:GetTapNoteScores(j)
	local pw, ph = M(78), M(20)
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(M(113), y) end,
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):zoomto(M(600), M(34)):diffuse(color("#000000")):diffusealpha(0.35) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):zoomto(M(3), M(34)):diffuse(col) end },
		-- the outlined pill
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):x(M(15)):zoomto(pw, ph):diffuse(col) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):x(M(17)):zoomto(pw - M(4), ph - M(4)):diffuse(TW.rgb(20, 20, 24)) end },
		QV.t(M(11), false, function(self) self:align(0.5, 0.5):x(M(15) + pw / 2):settext(QV.judge[j][1]):diffuse(col) end),
		QV.t(M(12), false, function(self) self:align(0, 0.5):x(M(110)):diffuse(col)
			self:settextf("(%.2f%%)", total > 0 and n / total * 100 or 0) end),
		QV.text(M(19), TW.font, function(self) self:align(1, 0.5):x(M(599)):settext(commas(n)):diffuse(col) end),
	}
end

-- what Etterna's Til' Death shows besides: MA / PA ratios, clear type, holds, mines, the score's ratings
t[#t + 1] = TW.evalPanel {
	x = M(113), y = M(652), w = M(600), h = M(68), cols = 3, pad = M(6), px = M(11),
	text = QV.t, accent = QV.cyan, bg = color("0,0,0,0.35"),
}

-- hit offsets: the deviance graph with Etterna's column filter, judge rescoring and stats
t[#t + 1] = TW.offsetPlot {
	x = R(732), y = M(400), w = R(1369) - R(732), h = M(718) - M(400),
	text = QV.t, accent = QV.cyan, bg = color("0,0,0,0.45"),
	colour = function(i) return QV.judge[QV.judgeOrder[i]][2] end,
}
-- hovering the accuracy: what it is on the other judges and ODs (last, over everything else)
if TW.accTooltip then
	local acx = L + (RR - L) * 1.5 / 5
	t[#t + 1] = TW.accTooltip(function() return acx - (RR - L) / 10, M(296), (RR - L) / 5, M(70) end,
		{ text = QV.t, px = M(13), accent = QV.cyan, bg = TW.rgb(14, 14, 18, 0.96), pad = M(10) })
end
return t
