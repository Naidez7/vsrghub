-- osu!'s song select, left side: the local ranking (your scores on this chart at every rate) and
-- your personal best. The top bar is in the overlay so the carousel slides under it, like osu!.
TW.useInterfaceSkin()
local M, R = TW.M, TW.R
local white = color("#FFFFFF")
local function commas(n)
	local neg = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (neg and "-" or "") .. (out:gsub("^,", ""))
end
local t = Def.ActorFrame {}
-- local ranking on the left: your scores on this chart, at every rate
local ROWS = 8
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
-- (more scores than rows: the mouse wheel over the board scrolls them, TW.boardScroll)
local boardOff = 0
local function fillBoard(self, list, status, pb, keepOff)
	self.boardArgs = { list, status, pb }
	list = TW.sortBoard(list)
	if not keepOff then boardOff = 0 end
	boardOff = math.max(0, math.min(boardOff, #list - ROWS))
	for i = 1, ROWS do self:GetChild("Row" .. i):playcommand("Fill", { hs = list[boardOff + i], n = boardOff + i }) end
	self:GetChild("PB"):playcommand("Fill", { hs = pb })
	local msg = ({
		loading = "Loading the online ranking...", login = "Log in to EtternaOnline to see the online ranking (click)",
		unranked = "This chart isn't ranked online", empty = "No online scores on this chart yet",
		offline = "VSRG Hub's ranking can't be reached right now",
		nohub = "VSRG Hub's ranking needs the game started from VSRG Hub",
		hublogin = "Sign in on VSRG Hub's Online page to send your scores",
	})[status] or ""
	if TW.rankSource == "hub" and status == "loading" then msg = "Loading VSRG Hub's ranking..." end
	if TW.rankSource == "hub" and status == "empty" then msg = "Nobody has a score on this chart yet: be the first!" end
	self:GetChild("Status"):settext(msg)
	self:GetChild("StatusBtn"):visible(status == "login")
end
local function myBest(list)
	for _, hs in ipairs(list) do if TW.isMyScore and TW.isMyScore(hs) then return hs end end
	return allScores()[1]
end
local board = Def.ActorFrame {
	CurrentStepsChangedMessageCommand = function(self) if not TW.browsingSkip() then self:stoptweening():queuecommand("Board") end end,
	CurrentSongChangedMessageCommand = function(self) if not TW.browsingSkip() then self:stoptweening():queuecommand("Board") end end,
	CurrentRateChangedMessageCommand = function(self) if TW.rankSource == "online" or TW.rankSource == "hub" then self:stoptweening():queuecommand("Board") end end,
	TWRankSourceMessageCommand = function(self) self:queuecommand("Board") end,
	LoginMessageCommand = function(self) self.boardSig = nil; self:queuecommand("Board") end,
	LogOutMessageCommand = function(self) self.boardSig = nil; self:queuecommand("Board") end,
	OnCommand = function(self)
		self:queuecommand("Board")
		local frame = self
		TW.boardScroll = function(dir)
			local a = frame.boardArgs
			if not a or #a[1] <= ROWS or TW.osuLeft == "Preview" then return false end
			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			if mx < M(6) or mx > M(421) or my < M(161) or my > M(161 + (ROWS - 1) * 56 + 54) then return false end
			boardOff = boardOff + dir
			fillBoard(frame, a[1], a[2], a[3], true)
			return true
		end
	end,
	OffCommand = function(self) TW.boardScroll = nil end,
	TWBoardSortMessageCommand = function(self)
		local a = self.boardArgs
		if a then fillBoard(self, a[1], a[2], a[3]) end
	end,
	BoardCommand = function(self)
		-- (the same chart again, e.g. the game's song put back to the picked one after a scroll:
		-- the board stays as it is instead of loading over)
		local ck = ""
		pcall(function() ck = GAMESTATE:GetCurrentSteps():GetChartKey() end)
		local sig = ck .. "|" .. tostring(TW.rankSource) .. "|" .. tostring(getCurRateValue())
		if sig == self.boardSig and ck ~= "" then return end
		self.boardSig = sig
		self:stoptweening()
		if TW.rankSource == "hub" and TW.hubRanking then
			fillBoard(self, {}, "loading", allScores()[1])
			self:sleep(0.35):queuecommand("Hub")
			return
		end
		if TW.rankSource == "online" and TW.onlineRanking then
			-- (asked a moment after the chart settles, not for every chart scrolled past)
			fillBoard(self, {}, TW.loggedIn() and "loading" or "login", allScores()[1])
			self:sleep(0.35):queuecommand("Online")
			return
		end
		local list = allScores()
		fillBoard(self, list, "ok", list[1])
	end,
	HubCommand = function(self)
		if TW.rankSource ~= "hub" then return end
		TW.hubRanking(GAMESTATE:GetCurrentSteps(), function(list, status) if TW.rankSource ~= "hub" then return end
			-- (your best on it from VSRG Hub's ranking, else your local best)
			local pb
			for _, hs in ipairs(list) do if TW.isMyScore(hs) then pb = hs break end end
			fillBoard(self, list, status, pb or allScores()[1])
		end, self)
	end,
	HubPollCommand = function(self) if self.hubPoll then self.hubPoll() end end,
	OnlineCommand = function(self)
		if TW.rankSource ~= "online" then return end
		TW.onlineRanking(GAMESTATE:GetCurrentSteps(), function(list, status) if TW.rankSource ~= "online" then return end fillBoard(self, list, status, myBest(list)) end)
	end,
	TW.text(M(13), false, function(self) self:align(0.5, 0.5):xy(M(210), M(200)):maxwidth(M(390) / self:GetZoom()):diffuse(color("0.85,0.85,0.85,1")) end) .. { Name = "Status" },
	-- (when logged out, clicking the message opens the log-in box)
	TW.button(M(404), M(60), function()
		if TW.rankSource == "online" and not TW.loggedIn() and TWProfileLogin then TWProfileLogin() end
	end) .. { Name = "StatusBtn", InitCommand = function(self) self:align(0.5, 0.5):xy(M(210), M(200)):zoomto(M(404), M(60)):diffusealpha(0):visible(false) end },
	-- "Personal Best"
	TW.text(M(13), true, function(self) self:align(0.5, 0.5):xy(M(205), M(628)):settext("Personal Best") end),
}
-- clicking a score opens its results (Etterna's results for that play, from its replay)
local function openScore(hs, watch)
	if hs and TW.isHubScore and TW.isHubScore(hs) then
		TW.openHubScore(hs) -- (its card: 29 VSRG Hub score card.lua; no replay, Etterna can't play one it doesn't own)
		return
	end
	if hs and TW.isOnlineScore and TW.isOnlineScore(hs) and TW.openOnlineScore then return TW.openOnlineScore(hs, watch) end
	if watch then if hs then TW.playReplay(hs) end return end
	local top = SCREENMAN:GetTopScreen()
	if hs and top and top.ShowEvalScreenForScore then
		if not TW.showScore(hs) then SCREENMAN:SystemMessage("This score has no replay to show") end
	end
end
-- a score, as osu!'s ranking shows one: the skin's panel art darkened behind it (darker under the
-- mouse), your avatar (or the place on the ranking), the skin's small grade, the name, the score and
-- combo; the accuracy on the right, and the rate and timing it was played on under it
local RW, RH = M(415), M(54)
local rankArt = { X = "rank_X_small", S = "rank_S_small", A = "rank_A_small", B = "rank_B_small", C = "rank_C_small", D = "rank_D_small" }
local function scoreRow(name, y, isPB)
	local shown = nil
	return Def.ActorFrame {
		Name = name,
		InitCommand = function(self) self:xy(M(6), y):visible(isPB) end,
		FillCommand = function(self, p)
			local hs = p.hs
			shown = hs
			local c = self:GetChildren()
			if not hs then
				self.lastShown = nil
				self:stoptweening():x(M(6)):diffusealpha(1)
				self:visible(isPB)
				c.Avatar:visible(false); c.RankNo:visible(false); c.Grade:visible(false)
				c.Letter:settext(""); c.Name:settext(isPB and "No personal record set" or "")
				-- (osu! writes it in the middle of the box)
				c.Name:halign(isPB and 0.5 or 0):x(isPB and RW / 2 or M(102)):y(RH / 2)
				c.Score:settext(""); c.Acc:settext(""); c.Extra:settext("")
				return
			end
			self:visible(true)
			-- (the scores slide in one after the other, as osu!'s ranking does)
			if hs ~= self.lastShown then
				self:stoptweening():x(M(6) - M(40)):diffusealpha(0):sleep(isPB and 0.15 or 0.04 * ((p.n or 1) - 1)):decelerate(0.3):x(M(6)):diffusealpha(1)
			end
			self.lastShown = hs
			-- the grade for the accuracy on the timing it was played on, as on the results (a failed play
			-- shows as F); Etterna's grade beside the rate
			local g = hs:GetWifeGrade()
			local pct, timing, failed = hs:GetWifeScore() * 100, "J4", g == "Grade_Failed"
			if TW.scoreAcc then pct, timing, failed = TW.scoreAcc(hs) end
			local rank = failed and "F" or (TW.accRank and TW.accRank(pct)) or TW.GradeToRank[g] or "D"
			local ett = TW.etternaGrade and TW.etternaGrade(g) or ""
			local av = isPB or not TW.isMyScore or TW.isMyScore(hs)
			c.Avatar:visible(av)
			-- (other players' scores: their place on the ranking where the avatar would be)
			c.RankNo:visible(not av):settext(p.n and ("#" .. p.n) or "")
			local id = rankArt[rank]
			if id and TW.has(id) then
				if c.Grade.loaded ~= id then c.Grade:Load(TW.img(id)); c.Grade.loaded = id; TW.inset(c.Grade) end
				local h = c.Grade:GetHeight()
				c.Grade:zoom(h > 0 and (RH * 0.62 / h) or 1):visible(true)
				c.Letter:settext("")
			else
				c.Grade:visible(false)
				c.Letter:settext(TW.RankLetter[rank] or rank):diffuse(TW.RankColour[rank] or white)
			end
			local who = TW.scoreName and TW.scoreName(hs) or hs:GetDisplayName()
			c.Name:settext(who):halign(0):x(M(102)):y(M(16))
			c.Score:settextf("Score: %s (%dx)", commas(math.max(0, pct) * 10000), hs:GetMaxCombo())
			c.Acc:settextf("%.2f%%", pct)
			local r = (string.format("%.2f", hs:GetMusicRate()):gsub("0$", ""))
			-- an invalid score (a paused play, or one invalidated in Etterna) doesn't count for the rating
			local valid = true
			pcall(function() valid = hs:GetEtternaValid() end)
			c.Extra:settext(r .. "x  " .. timing .. (ett ~= "" and ("  " .. ett) or "") .. (valid and "" or "  invalid"))
				:diffuse(valid and color("#FFFFFF") or color("#FF9999"))
		end,
		(TW.has("songpanel") and Def.Sprite { Texture = TW.img("songpanel"), InitCommand = function(self)
			TW.inset(self); self:align(0, 0):zoomto(RW, RH):diffuse({ 0, 0, 0, 0.3 }) end }
			or Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(RW, RH):diffuse({ 0, 0, 0, 0.35 }) end }) .. { Name = "Panel" },
		TW.text(M(14), true, function(self) self:align(0.5, 0.5):xy(M(28), RH / 2):diffusealpha(0.9) end) .. { Name = "RankNo" },
		Def.Sprite {
			Name = "Avatar",
			InitCommand = function(self) self:Load(getAvatarPath(PLAYER_1)):align(0, 0):xy(M(3), M(3)):zoomto(RH - M(6), RH - M(6)):visible(false) end
		},
		Def.Sprite { Name = "Grade", InitCommand = function(self) self:xy(M(80), RH / 2):visible(false) end },
		TW.text(M(20), true, function(self) self:align(0.5, 0.5):xy(M(80), RH / 2) end) .. { Name = "Letter" },
		TW.text(M(17), false, function(self) self:align(0, 0.5):maxwidth(M(230) / self:GetZoom()):shadowlength(1) end) .. { Name = "Name" },
		TW.text(M(12), false, function(self) self:align(0, 0.5):xy(M(102), M(39)):shadowlength(1) end) .. { Name = "Score" },
		TW.text(M(12), false, function(self) self:align(1, 0.5):xy(RW - M(16), M(25)):shadowlength(1) end) .. { Name = "Acc" },
		TW.text(M(9.5), false, function(self) self:align(1, 0.5):xy(RW - M(16), M(42)):shadowlength(1) end) .. { Name = "Extra" },
		-- (right click: watch its replay, 25 VSRG Hub results.lua)
		TW.button(RW, RH, function() openScore(shown) end, function(self, on)
			local panel = self:GetParent():GetChild("Panel")
			panel:stoptweening():linear(0.12):diffusealpha((on and shown) and 0.59 or (TW.has("songpanel") and 0.3 or 0.35))
		end, function() if shown then openScore(shown, true) end end) .. { InitCommand = function(self) self:align(0, 0):zoomto(RW, RH):diffusealpha(0) end },
	}
end
for i = 1, ROWS do board[#board + 1] = scoreRow("Row" .. i, M(161 + (i - 1) * 56), false) end
board[#board + 1] = scoreRow("PB", M(648), true)
board.InitCommand = function(self) self:visible(TW.osuLeft ~= "Preview") end
board.TWOsuLeftMessageCommand = function(self) self:visible(TW.osuLeft ~= "Preview") end
t[#t + 1] = board

-- the chart preview in place of the ranking (picked in the "Local Ranking" box)
local preview = Def.ActorFrame {
	InitCommand = function(self) self:visible(TW.osuLeft == "Preview") end,
	OnCommand = function(self) if TW.osuLeft == "Preview" then MESSAGEMAN:Broadcast("TWOsuPreview") end end,
	TWOsuLeftMessageCommand = function(self)
		self:visible(TW.osuLeft == "Preview")
		if TW.osuLeft == "Preview" then MESSAGEMAN:Broadcast("TWOsuPreview") end
	end,
	-- a thin frame in the interface colour round it
	Def.Quad { InitCommand = function(self) self:align(0, 0):xy(M(8) - 1, M(160) - 1):zoomto(M(404) + 2, 1):diffuse(TW.pink):diffusealpha(0.7) end },
	Def.Quad { InitCommand = function(self) self:align(0, 0):xy(M(8) - 1, M(160) + M(455)):zoomto(M(404) + 2, 1):diffuse(TW.pink):diffusealpha(0.7) end },
	Def.Quad { InitCommand = function(self) self:align(0, 0):xy(M(8) - 1, M(160)):zoomto(1, M(455)):diffuse(TW.pink):diffusealpha(0.7) end },
	Def.Quad { InitCommand = function(self) self:align(0, 0):xy(M(8) + M(404), M(160)):zoomto(1, M(455)):diffuse(TW.pink):diffusealpha(0.7) end },
	TW.mapPreview {
		x = M(8), y = M(160), w = M(404), h = M(455), openMessage = "TWOsuPreview",
		isOpen = function() return TW.osuLeft == "Preview" end,
		colour = function(v)
			-- osu!'s star-rating colours, by MSD: blue, green, yellow, orange, red, purple, black
			local stops = { { 0, TW.rgb(79, 192, 255) }, { 10, TW.rgb(124, 255, 79) }, { 17, TW.rgb(246, 240, 92) },
				{ 23, TW.rgb(255, 128, 104) }, { 28, TW.rgb(255, 78, 111) }, { 33, TW.rgb(198, 69, 184) }, { 38, TW.rgb(101, 99, 222) } }
			local c = stops[1][2]
			for _, st in ipairs(stops) do if v >= st[1] then c = st[2] end end
			return c
		end,
	},
	TW.text(M(10), false, function(self)
		self:align(0, 0):xy(M(10), M(618)):settext("Click the graph to jump  -  Tab to play from there"):diffuse(color("0.85,0.85,0.85,1"))
	end),
}
t[#t + 1] = preview
-- (your older plays for VSRG Hub's ranking, when asked: 28 VSRG Hub online.lua)
t[#t + 1] = TW.backfillActor and TW.backfillActor() or Def.Actor {}
-- the selected chart's goal (Ctrl+G), over the bottom bar on the left
t[#t + 1] = TW.goalLine and TW.goalLine(M(14), SCREEN_HEIGHT - M(100), function(init) return TW.text(M(13), true, init) end) or Def.Actor {}
t[#t + 1] = TW.osuPlaysActor and TW.osuPlaysActor() or Def.Actor {}
t[#t + 1] = TW.hubPlaceWatch and TW.hubPlaceWatch() or Def.Actor {}
t[#t + 1] = TW.danOverlay("ScreenSelectMusic decorations/dan_overlay_bridge.lua")
return t
