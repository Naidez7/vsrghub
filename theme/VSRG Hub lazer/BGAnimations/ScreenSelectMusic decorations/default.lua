-- osu!lazer's song select, left side: the scores on the selected chart as lazer's leaderboard (your
-- local scores at every rate, or EtternaOnline's ranking: the tabs over it pick), each a slanted row
-- with its place, the player, max combo, accuracy, the score and a tab with the grade; your personal
-- best under them. Or, on the Preview tab, the chart itself (click its graph to jump, Tab to play
-- from there). Click a score for its results, right click to watch its replay.
TW.useInterfaceSkin()
local M = TW.M
local white = color("#FFFFFF")
local function commas(n)
	local neg = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (neg and "-" or "") .. (out:gsub("^,", ""))
end
local t = Def.ActorFrame {}
local ROWS = 6
local X0, Y0, STEP, RH = M(10), M(298), M(54), M(48)
local PANEL_W = M(650)

local function allScores()
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then return {} end
	local byRate = SCOREMAN:GetScoresByKey(steps:GetChartKey())
	local list = {}
	if byRate then
		for _, sar in pairs(byRate) do
			for _, hs in ipairs(sar:GetScores()) do list[#list + 1] = hs end
		end
	end
	table.sort(list, function(a, b) return a:GetWifeScore() > b:GetWifeScore() end)
	return list
end
local function fillBoard(self, list, status, pb, pbPlace)
	for i = 1, ROWS do self:GetChild("Row" .. i):playcommand("Fill", { hs = list[i], n = i }) end
	self:GetChild("PB"):playcommand("Fill", { hs = pb, n = pbPlace })
	local msg = ({
		loading = "Loading the online ranking...", login = "Log in to EtternaOnline to see the online ranking (click)",
		unranked = "This chart isn't ranked online", empty = "No online scores on this chart yet",
	})[status] or ((#list == 0 and status == "ok") and "No scores yet. Go play it!" or "")
	self:GetChild("Status"):settext(msg)
	self:GetChild("StatusBtn"):visible(status == "login")
end
local function myBest(list)
	for i, hs in ipairs(list) do if TW.isMyScore and TW.isMyScore(hs) then return hs, i end end
	return allScores()[1], nil
end
local board = Def.ActorFrame {
	CurrentStepsChangedMessageCommand = function(self) self:queuecommand("Board") end,
	CurrentSongChangedMessageCommand = function(self) self:queuecommand("Board") end,
	CurrentRateChangedMessageCommand = function(self) if TW.rankSource == "online" then self:queuecommand("Board") end end,
	TWRankSourceMessageCommand = function(self) self:queuecommand("Board") end,
	LoginMessageCommand = function(self) self:queuecommand("Board") end,
	LogOutMessageCommand = function(self) self:queuecommand("Board") end,
	OnCommand = function(self) self:queuecommand("Board") end,
	BoardCommand = function(self)
		self:stoptweening()
		if TW.rankSource == "online" and TW.onlineRanking then
			fillBoard(self, {}, TW.loggedIn() and "loading" or "login", allScores()[1], nil)
			self:sleep(0.35):queuecommand("Online")
			return
		end
		local list = allScores()
		fillBoard(self, list, "ok", list[1], list[1] and 1 or nil)
	end,
	OnlineCommand = function(self)
		if TW.rankSource ~= "online" then return end
		TW.onlineRanking(GAMESTATE:GetCurrentSteps(), function(list, status)
			local pb, place = myBest(list)
			fillBoard(self, list, status, pb, place)
		end)
	end,
	LZ.text(M(13), "regular", function(self) self:align(0.5, 0.5):xy(X0 + M(315), Y0 + M(110)):maxwidth(M(560) / self:GetZoom()):diffuse(LZ.dim) end) .. { Name = "Status" },
	TW.button(M(560), M(60), function()
		if TW.rankSource == "online" and not TW.loggedIn() and TWProfileLogin then TWProfileLogin() end
	end) .. { Name = "StatusBtn", InitCommand = function(self) self:xy(X0 + M(315), Y0 + M(110)):zoomto(M(560), M(60)):diffusealpha(0):visible(false) end },
	LZ.text(M(11), "bold", function(self) self:align(0, 0.5):xy(X0 + M(30), M(636)):settext("Personal Best"):diffuse(LZ.dim) end),
}
local function openScore(hs, watch)
	if hs and TW.isOnlineScore and TW.isOnlineScore(hs) and TW.openOnlineScore then return TW.openOnlineScore(hs, watch) end
	if watch then if hs then TW.playReplay(hs) end return end
	local top = SCREENMAN:GetTopScreen()
	if hs and top and top.ShowEvalScreenForScore then
		if not TW.showScore(hs) then SCREENMAN:SystemMessage("This score has no replay to show") end
	end
end
local GX = PANEL_W - M(44) -- where the grade's tab starts
local function scoreRow(name, y, isPB)
	local shown = nil
	return Def.ActorFrame {
		Name = name,
		InitCommand = function(self) self:xy(X0, y):visible(isPB) end,
		FillCommand = function(self, p)
			local hs = p.hs
			shown = hs
			local c = self:GetChildren()
			if not hs then
				self.lastShown = nil
				self:stoptweening():x(X0):diffusealpha(1)
				self:visible(isPB)
				for _, k in ipairs({ "RankBox", "RankNo", "Avatar", "NoAv", "AvBg", "Grade", "GradeL", "ComboL", "AccL", "Combo", "Acc", "Score", "Extra" }) do c[k]:visible(false) end
				c.Name:settext(isPB and "No personal best yet" or ""):xy(M(78), RH / 2):diffuse(LZ.dim)
				return
			end
			self:visible(true)
			-- (the scores come in one after the other from the left, as lazer's leaderboard does)
			if hs ~= self.lastShown then
				self:stoptweening():x(X0 - M(30)):diffusealpha(0):sleep(isPB and 0.2 or 0.035 * ((p.n or 1) - 1)):decelerate(0.3):x(X0):diffusealpha(1)
			end
			self.lastShown = hs
			for _, k in ipairs({ "RankBox", "RankNo", "Grade", "GradeL", "ComboL", "AccL", "Combo", "Acc", "Score", "Extra" }) do c[k]:visible(true) end
			local g = hs:GetWifeGrade()
			local pct, timing, failed = hs:GetWifeScore() * 100, "J4", g == "Grade_Failed"
			if TW.scoreAcc then pct, timing, failed = TW.scoreAcc(hs) end
			local rank = failed and "F" or (TW.accRank and TW.accRank(pct)) or TW.GradeToRank[g] or "D"
			local ett = TW.etternaGrade and TW.etternaGrade(g) or ""
			c.RankNo:settext(p.n and ("#" .. p.n) or "-")
			local mine = isPB or not TW.isMyScore or TW.isMyScore(hs)
			c.Avatar:visible(mine); c.NoAv:visible(not mine); c.AvBg:visible(true)
			local who = TW.scoreName and TW.scoreName(hs) or hs:GetDisplayName()
			c.Name:settext(who):xy(M(130), RH * 0.34):diffuse(white)
			local r = (string.format("%.2f", hs:GetMusicRate()):gsub("0$", ""))
			local valid = true
			pcall(function() valid = hs:GetEtternaValid() end)
			c.Extra:settext(r .. "x  " .. timing .. (ett ~= "" and ("  " .. ett) or "") .. (valid and "" or "  invalid"))
				:diffuse(valid and LZ.dim or TW.rgb(255, 140, 140))
			c.Combo:settextf("%sx", commas(hs:GetMaxCombo()))
			c.Acc:settextf("%.2f%%", pct)
			c.Score:settext(commas(math.max(0, pct) * 10000))
			TW.setBox(c.Grade, { col = LZ.rankColour(rank) })
			c.GradeL:settext(TW.RankLetter[rank] or rank):diffuse(LZ.rankText(rank))
			-- (the row's own colour: a hint of the grade's on the right)
			local rc = LZ.rankColour(rank)
			TW.setBox(c.Panel, { left = LZ.a(LZ.bg4, 0.9), right = { rc[1] * 0.3 + LZ.bg4[1] * 0.7, rc[2] * 0.3 + LZ.bg4[2] * 0.7, rc[3] * 0.3 + LZ.bg4[3] * 0.7, 0.9 } })
		end,
		-- the place
		LZ.panel { w = M(58), h = RH, r = M(8), col = TW.mix(LZ.pink, { 1, 1, 1, 1 }, 0.08), col2 = TW.mix(LZ.pink, { 0, 0, 0, 1 }, 0.15) } .. { Name = "RankBox" },
		LZ.text(M(15), "bold", function(self) self:align(0.5, 0.5):xy(M(29), RH / 2) end) .. { Name = "RankNo" },
		-- the row
		TW.shadow { w = PANEL_W - M(60), h = RH, spread = M(8), alpha = 0.35, init = function(self) self:x(M(62)) end },
		LZ.panel { w = PANEL_W - M(60), h = RH, r = M(8), col = LZ.a(LZ.bg4, 0.9), init = function(self) self:x(M(62)) end } .. { Name = "Panel" },
		-- the player's picture (yours; others' come as a plain silhouette, EtternaOnline doesn't send theirs)
		TW.box { w = M(36), h = M(36), r = M(8), ay = 0.5, col = LZ.a(LZ.bg2, 1), init = function(self) self:xy(M(80), RH / 2) end } .. { Name = "AvBg" },
		Def.Sprite {
			Name = "Avatar",
			InitCommand = function(self) self:Load(getAvatarPath(PLAYER_1)):align(0, 0.5):xy(M(80), RH / 2):zoomto(M(36), M(36)):visible(false) end,
		},
		TW.icon("user", M(16), function(self) self:xy(M(98), RH / 2):diffuse(LZ.dim):visible(false) end) .. { Name = "NoAv" },
		LZ.text(M(14), "bold", function(self) self:align(0, 0.5):maxwidth(M(170) / self:GetZoom()) end) .. { Name = "Name" },
		LZ.text(M(9.5), "regular", function(self) self:align(0, 0.5):xy(M(130), RH * 0.72):maxwidth(M(170) / self:GetZoom()) end) .. { Name = "Extra" },
		-- max combo and accuracy, as lazer's small columns
		LZ.text(M(8), "bold", function(self) self:align(0, 0.5):xy(M(318), RH * 0.3):settext("MAX COMBO"):diffuse(LZ.dim) end) .. { Name = "ComboL" },
		LZ.text(M(12.5), "regular", function(self) self:align(0, 0.5):xy(M(318), RH * 0.66) end) .. { Name = "Combo" },
		LZ.text(M(8), "bold", function(self) self:align(0, 0.5):xy(M(398), RH * 0.3):settext("ACCURACY"):diffuse(LZ.dim) end) .. { Name = "AccL" },
		LZ.text(M(12.5), "regular", function(self) self:align(0, 0.5):xy(M(398), RH * 0.66) end) .. { Name = "Acc" },
		-- the score, large and light
		LZ.text(M(20), "light", function(self) self:align(1, 0.5):xy(GX - M(10), RH / 2) end) .. { Name = "Score" },
		-- the grade's tab on the right end
		LZ.panel { w = M(44), h = RH, r = M(8), init = function(self) self:x(GX) end } .. { Name = "Grade" },
		LZ.text(M(15), "bold", function(self) self:align(0.5, 0.5):xy(GX + M(22), RH / 2) end) .. { Name = "GradeL" },
		TW.button(PANEL_W, RH, function() openScore(shown) end, function(self, on)
			self:GetParent():stoptweening():decelerate(0.1):x(X0 + ((on and shown) and M(8) or 0))
		end, function() if shown then openScore(shown, true) end end) .. { InitCommand = function(self) self:align(0, 0):zoomto(PANEL_W, RH):diffusealpha(0) end },
	}
end
for i = 1, ROWS do board[#board + 1] = scoreRow("Row" .. i, Y0 + (i - 1) * STEP, false) end
board[#board + 1] = scoreRow("PB", M(652), true)
board.InitCommand = function(self) self:visible(TW.osuLeft ~= "Preview") end
board.TWOsuLeftMessageCommand = function(self)
	self:visible(TW.osuLeft ~= "Preview")
	if TW.osuLeft ~= "Preview" then self:stoptweening():diffusealpha(0):linear(0.15):diffusealpha(1) end
end
t[#t + 1] = board

-- the chart preview in place of the scores (the Preview tab)
local PX, PY, PW, PH = X0, Y0, M(620), M(400)
local preview = Def.ActorFrame {
	InitCommand = function(self) self:visible(TW.osuLeft == "Preview") end,
	OnCommand = function(self) if TW.osuLeft == "Preview" then MESSAGEMAN:Broadcast("TWOsuPreview") end end,
	TWOsuLeftMessageCommand = function(self)
		self:visible(TW.osuLeft == "Preview")
		if TW.osuLeft == "Preview" then MESSAGEMAN:Broadcast("TWOsuPreview") end
	end,
	TW.shadow { w = PW + M(8), h = PH + M(8), spread = M(12), alpha = 0.5, init = function(self) self:xy(PX - M(4), PY - M(4)) end },
	TW.box { w = PW + M(8), h = PH + M(8), r = M(10), col = LZ.a(LZ.bg6, 0.92), init = function(self) self:xy(PX - M(4), PY - M(4)) end },
	TW.mapPreview {
		x = PX, y = PY, w = PW, h = PH, openMessage = "TWOsuPreview",
		isOpen = function() return TW.osuLeft == "Preview" end,
		colour = function(v) return LZ.starColour(v) end,
	},
	LZ.text(M(10.5), "regular", function(self)
		self:align(0, 0):xy(PX, PY + PH + M(10)):settext("Click the graph to jump  ·  Tab to play from there"):diffuse(LZ.dim)
	end),
}
t[#t + 1] = preview
t[#t + 1] = TW.danOverlay("ScreenSelectMusic decorations/dan_overlay_bridge.lua")
return t
