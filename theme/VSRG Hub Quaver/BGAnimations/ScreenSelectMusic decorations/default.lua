-- Quaver's song select, left side: the leaderboard (your scores on this chart, every rate), the
-- chart's MSD for each pattern type with the rate (click: +0.05x, right click: -0.05x) and your
-- personal best.
local M = TW.M
local white = color("#FFFFFF")
local X0, W = M(37), M(427)
local ROWS, RH = 6, M(52)

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
local function ago(date)
	local y, mo, d, h, mi = (date or ""):match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+)")
	if not y then return "" end
	local then_ = os.time { year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi) }
	local s = os.difftime(os.time(), then_)
	if s < 3600 then return math.max(1, math.floor(s / 60)) .. "m" end
	if s < 86400 then return math.floor(s / 3600) .. "h" end
	if s < 86400 * 30 then return math.floor(s / 86400) .. "d" end
	if s < 86400 * 365 then return math.floor(s / (86400 * 30)) .. "mo" end
	return math.floor(s / (86400 * 365)) .. "y"
end

local function scoreRow(name, isPB)
	return Def.ActorFrame {
		Name = name,
		FillCommand = function(self, p)
			local hs = p.hs
			local c = self:GetChildren()
			self:visible(hs ~= nil or isPB)
			c.Hover:diffusealpha(0)
			self.hs = hs
			if not hs then
				c.Avatar:visible(false); c.Grade:settext(""); c.Rank:settext(""); c.Pill:visible(false); c.PillText:settext("")
				c.Name:settext(isPB and "No personal best yet" or ""):diffuse(QV.grey)
				c.When:settext(""); c.Rating:settext(""); c.Line2:settext("")
				return
			end
			-- the grade for the accuracy on the timing it was played on, as on the results; Etterna's
			-- grade written by the accuracy
			local pct, timing, failed = hs:GetWifeScore() * 100, "J4", hs:GetWifeGrade() == "Grade_Failed"
			if TW.scoreAcc then pct, timing, failed = TW.scoreAcc(hs) end
			local g = failed and "F" or QV.accGrade(pct)
			local ett = TW.etternaGrade and TW.etternaGrade(hs:GetWifeGrade()) or ""
			c.Rank:settext(isPB and "" or (p.n .. "."))
			c.Grade:settext(QV.gradeLetter[g]):diffuse(QV.gradeColour[g])
			c.Avatar:visible(isPB or not TW.isMyScore or TW.isMyScore(hs))
			local who = TW.scoreName and TW.scoreName(hs) or hs:GetDisplayName()
			QV.fit(c.Name, who, M(150)):diffuse(QV.blue)
			c.When:settext(ago(hs:GetDate())):x(c.Name:GetX() + c.Name:GetZoomedWidth() + M(8))
			local ssr = 0
			pcall(function() ssr = hs:GetSkillsetSSR("Overall") end)
			c.Rating:settextf("%.2f", ssr)
			-- an invalid score (a paused play, or one invalidated in Etterna): Quaver marks paused scores too
			local valid = true
			pcall(function() valid = hs:GetEtternaValid() end)
			c.Line2:settextf("%dx | %.2f%% %s%s%s", hs:GetMaxCombo(), pct, timing, ett ~= "" and (" | " .. ett) or "", valid and "" or "  (invalid)")
			local r = (string.format("%.2f", hs:GetMusicRate()):gsub("0$", ""))
			c.Pill:visible(true); c.PillText:settext(r .. "x")
		end,
		Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(W, RH):diffuse(color("#FFFFFF")):diffusealpha(0) end } .. { Name = "Hover" },
		QV.t(M(13), true, function(self) self:align(0.5, 0.5):xy(M(23), RH / 2) end) .. { Name = "Rank" },
		QV.t(M(19), true, function(self) self:align(0.5, 0.5):xy(M(62), RH / 2) end) .. { Name = "Grade" },
		Def.Sprite { Name = "Avatar", InitCommand = function(self) self:Load(getAvatarPath(PLAYER_1)):align(0, 0.5):xy(M(89), RH / 2):zoomto(M(34), M(34)) end },
		QV.t(M(14), true, function(self) self:align(0, 0.5):xy(M(132), M(17)) end) .. { Name = "Name" },
		QV.t(M(10.5), false, function(self) self:align(0, 0.5):y(M(17)):diffuse(QV.grey) end) .. { Name = "When" },
		Def.Quad { Name = "Pill", InitCommand = function(self) self:align(0, 0.5):xy(M(132), M(35)):zoomto(M(30), M(11)):diffuse(TW.rgb(60, 60, 60)) end },
		QV.t(M(7.5), true, function(self) self:align(0.5, 0.5):xy(M(147), M(35)):diffuse(TW.rgb(170, 170, 170)) end) .. { Name = "PillText" },
		QV.t(M(19), false, function(self) self:align(1, 0.5):xy(W - M(10), M(16)) end) .. { Name = "Rating" },
		QV.t(M(13), false, function(self) self:align(1, 0.5):xy(W - M(10), M(37)) end) .. { Name = "Line2" },
		-- click a score to see its results, like Quaver
		TW.button(W, RH, function(self)
			local hs = self:GetParent().hs
			local top = SCREENMAN:GetTopScreen()
			if hs and TW.isOnlineScore and TW.isOnlineScore(hs) and TW.openOnlineScore then return TW.openOnlineScore(hs) end
			if hs and top and top.ShowEvalScreenForScore and not TW.showScore(hs) then
				SCREENMAN:SystemMessage("This score has no replay to show")
			end
		end, function(self, on)
			self:GetParent():GetChild("Hover"):diffusealpha((on and self:GetParent().hs) and 0.08 or 0)
		end, function(self)
			-- right click: watch its replay, like Quaver's score menu
			local hs = self:GetParent().hs
			if hs and TW.isOnlineScore and TW.isOnlineScore(hs) and TW.openOnlineScore then return TW.openOnlineScore(hs, true) end
			if hs then TW.playReplay(hs) end
		end) .. { InitCommand = function(self) self:align(0, 0):zoomto(W, RH):diffusealpha(0) end },
	}
end

local root = Def.ActorFrame {}
-- everything here is the leaderboard side; Quaver swaps it for the modifiers, map preview or
-- profile (those are in the overlay)
local t = Def.ActorFrame {
	Name = "LB",
	QVLeftMessageCommand = function(self, p) self:visible(p.name == "Leaderboard") end,
}
root[#root + 1] = t
local function fillBoard(root, list, status, pb)
	local board = root:GetChild("Board")
	for i = 1, ROWS do board:GetChild("Row" .. i):playcommand("Fill", { hs = list[i], n = i }) end
	local msg = ({
		ok = "", loading = "Loading the online leaderboard...", unranked = "This map isn't ranked online",
		login = "Log in to EtternaOnline to see the online leaderboard (click)", none = "",
		offline = "VSRG Hub's leaderboard can't be reached right now",
		nohub = "VSRG Hub's leaderboard needs the game started from VSRG Hub",
	})[status] or "No scores yet. Be the first!"
	if TW.rankSource == "hub" and status == "loading" then msg = "Loading VSRG Hub's leaderboard..." end
	board:GetChild("Empty"):settext(msg):visible(#list == 0)
	board:GetChild("EmptyBtn"):visible(status == "login")
	root:GetChild("PBFrame"):GetChild("PBInner"):GetChild("PB"):playcommand("Fill", { hs = pb })
end
local function myBest(list)
	for _, hs in ipairs(list) do if TW.isMyScore and TW.isMyScore(hs) then return hs end end
	return allScores()[1]
end
-- (the layer's root frame doesn't get the song messages, so a child does the work)
t[#t + 1] = Def.Actor {
	CurrentStepsChangedMessageCommand = function(self) if not TW.browsingSkip() then self:queuecommand("Board") end end,
	CurrentSongChangedMessageCommand = function(self) if not TW.browsingSkip() then self:queuecommand("Board") end end,
	CurrentRateChangedMessageCommand = function(self) if TW.rankSource == "online" or TW.rankSource == "hub" then self:queuecommand("Board") end end,
	TWRankSourceMessageCommand = function(self) self:queuecommand("Board") end,
	LoginMessageCommand = function(self) self.boardSig = nil; self:queuecommand("Board") end,
	LogOutMessageCommand = function(self) self.boardSig = nil; self:queuecommand("Board") end,
	OnCommand = function(self) self:queuecommand("Board") end,
	BoardCommand = function(self)
		-- (the same chart again, e.g. the game's song put back to the picked one after a scroll: the
		-- board stays as it is instead of loading over)
		local ck = ""
		pcall(function() ck = GAMESTATE:GetCurrentSteps():GetChartKey() end)
		local sig = ck .. "|" .. tostring(TW.rankSource) .. "|" .. tostring(getCurRateValue())
		if sig == self.boardSig and ck ~= "" then return end
		self.boardSig = sig
		self:stoptweening()
		local root = self:GetParent()
		if TW.rankSource == "hub" and TW.hubRanking then
			fillBoard(root, {}, "loading", allScores()[1])
			self:sleep(0.35):queuecommand("Hub")
			return
		end
		if TW.rankSource == "online" and TW.onlineRanking then
			-- (asked a moment after the chart settles, not for every chart scrolled past)
			fillBoard(root, {}, TW.loggedIn() and "loading" or "login", allScores()[1])
			self:sleep(0.35):queuecommand("Online")
			return
		end
		local list = allScores()
		fillBoard(root, list, "empty", list[1])
	end,
	OnlineCommand = function(self)
		if TW.rankSource ~= "online" then return end
		local root = self:GetParent()
		TW.onlineRanking(GAMESTATE:GetCurrentSteps(), function(list, status) fillBoard(root, list, status, myBest(list)) end)
	end,
	-- VSRG Hub's own leaderboard (28 VSRG Hub online.lua)
	HubCommand = function(self)
		if TW.rankSource ~= "hub" then return end
		local root = self:GetParent()
		TW.hubRanking(GAMESTATE:GetCurrentSteps(), function(list, status) fillBoard(root, list, status, myBest(list)) end, self)
	end,
	HubPollCommand = function(self) if self.hubPoll then self.hubPoll() end end,
}
t[#t + 1] = Def.ActorFrame {
	QV.t(M(19), true, function(self) self:align(0, 0.5):xy(X0, M(136)):settext("LEADERBOARD") end),
	QV.t(M(14), true, function(self) self:align(0, 0.5):xy(X0 + M(247), M(136)):settext("RANKING:") end),
	Def.Quad { Name = "SrcBg", InitCommand = function(self) self:align(0, 0.5):xy(X0 + M(333), M(136)):zoomto(M(94), M(24)):diffuse(TW.rgb(25, 25, 25)) end },
	QV.t(M(13.5), true, function(self) self:align(0, 0.5):xy(X0 + M(343), M(136)):diffuse(TW.rgb(6, 202, 250)) end) .. {
		OnCommand = function(self) self:playcommand("TWRankSource") end,
		TWRankSourceMessageCommand = function(self) self:settext(TW.rankSource == "online" and "Etterna" or (TW.rankSource == "hub" and "Global" or "Local")) end,
	},
	-- Quaver's ranking box: Local (your scores), Global (VSRG Hub's leaderboard) or Etterna
	-- (EtternaOnline's)
	TW.button(M(94), M(24), function()
		local nextSrc = ({ ["local"] = "hub", hub = "online", online = "local" })[TW.rankSource] or "local"
		if TW.setRankSource then TW.setRankSource(nextSrc) end
	end, function(self, on)
		self:GetParent():GetChild("SrcBg"):diffuse(on and TW.rgb(50, 50, 50) or TW.rgb(25, 25, 25))
	end) .. { InitCommand = function(self) self:align(0, 0.5):xy(X0 + M(333), M(136)):zoomto(M(94), M(24)):diffusealpha(0) end },
}
local board = Def.ActorFrame {
	Name = "Board",
	InitCommand = function(self) self:xy(X0, M(155)) end,
	QV.box(W, M(318), 0.85),
	QV.t(M(13), false, function(self) self:align(0.5, 0.5):xy(W / 2, M(150)):diffuse(QV.grey):settext("No scores yet. Be the first!"):maxwidth((W - M(20)) / self:GetZoom()) end) .. { Name = "Empty" },
	-- (when logged out, clicking the message opens the log-in box)
	TW.button(W, M(60), function()
		if TW.rankSource == "online" and not TW.loggedIn() and TWProfileLogin then TWProfileLogin() end
	end) .. { Name = "EmptyBtn", InitCommand = function(self) self:xy(W / 2, M(150)):zoomto(W, M(60)):diffusealpha(0):visible(false) end },
}
for i = 1, ROWS do board[#board + 1] = scoreRow("Row" .. i, false) .. { InitCommand = function(self) self:y((i - 1) * RH) end } end
t[#t + 1] = board

-- the chart's MSD per pattern, with the rate
local skills = { "Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical" }
local msd = Def.ActorFrame {
	InitCommand = function(self) self:xy(X0, M(496)) end,
	CurrentStepsChangedMessageCommand = function(self) if not TW.browsingSkip() then self:queuecommand("Fill") end end,
	CurrentSongChangedMessageCommand = function(self) if not TW.browsingSkip() then self:queuecommand("Fill") end end,
	CurrentRateChangedMessageCommand = function(self) self:queuecommand("Fill") end,
	OnCommand = function(self) self:queuecommand("Fill") end,
	FillCommand = function(self)
		local steps = GAMESTATE:GetCurrentSteps()
		for i = 1, 8 do
			local v = steps and TW.msd(steps, i) or 0
			self:GetChild("V" .. i):settext(steps and string.format("%.2f", v) or "-"):diffuse(steps and QV.diffColour(v) or white)
			self:GetChild("B" .. i):zoomx(math.min(1, v / 40))
		end
		self:GetChild("Rate"):settext(getCurRateDisplayString(true))
	end,
	QV.t(M(19), true, function(self) self:align(0, 0.5):settext("DIFFICULTY") end),
	QV.t(M(14), true, function(self) self:align(0, 0.5):x(M(247 + 33)):settext("RATE:") end),
	Def.Quad { Name = "RateBg", InitCommand = function(self) self:align(0, 0.5):x(M(333)):zoomto(M(94), M(24)):diffuse(TW.rgb(25, 25, 25)) end },
	QV.t(M(13.5), true, function(self) self:align(0.5, 0.5):x(M(380)):diffuse(QV.yellow) end) .. { Name = "Rate" },
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self) self:align(0, 0.5):x(M(333)):zoomto(M(94), M(24)):diffusealpha(0) end,
		MouseOverCommand = function(self) self:GetParent():GetChild("RateBg"):diffuse(TW.rgb(50, 50, 50)) end,
		MouseOutCommand = function(self) self:GetParent():GetChild("RateBg"):diffuse(TW.rgb(25, 25, 25)) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then ChangeMusicRate(nil, { Name = "PrevRate" })
			elseif params.event == "DeviceButton_right mouse button" then ChangeMusicRate(nil, { Name = "NextRate" }) end
		end
	},
	QV.box(W, M(150), 0.85) .. { InitCommand = function(self) self:y(M(17)) end },
}
for i, name in ipairs(skills) do
	local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
	local x, y = M(14) + col * (W / 2), M(36) + row * M(33)
	local bw = W / 2 - M(28)
	msd[#msd + 1] = QV.t(M(12), true, function(self) self:align(0, 0.5):xy(x, y):settext(name) end)
	msd[#msd + 1] = QV.t(M(13), true, function(self) self:align(1, 0.5):xy(x + bw, y) end) .. { Name = "V" .. i }
	msd[#msd + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(x, y + M(13)):zoomto(bw, M(3)):diffuse(TW.rgb(60, 60, 60)) end }
	msd[#msd + 1] = QV.gradient(bw, M(3)) .. { Name = "B" .. i, InitCommand = function(self) self:xy(x, y + M(11.5)) end }
end
t[#t + 1] = msd

-- personal best
t[#t + 1] = Def.ActorFrame {
	Name = "PBFrame",
	InitCommand = function(self) self:xy(X0, M(690)) end,
	QV.t(M(19), true, function(self) self:align(0, 0.5):settext("PERSONAL BEST") end),
	Def.ActorFrame {
		Name = "PBInner",
		InitCommand = function(self) self:y(M(16)) end,
		QV.box(W, RH, 0.85),
		scoreRow("PB", true),
	}
}
-- (your older plays for VSRG Hub's ranking, when asked: 28 VSRG Hub online.lua)
root[#root + 1] = TW.backfillActor and TW.backfillActor() or Def.Actor {}
root[#root + 1] = TW.goalLine and TW.goalLine(TW.M(14), SCREEN_HEIGHT - TW.M(70), function(init) return TW.text(TW.M(13), true, init) end) or Def.Actor {}
root[#root + 1] = TW.osuPlaysActor and TW.osuPlaysActor() or Def.Actor {}
root[#root + 1] = TW.hubPlaceWatch and TW.hubPlaceWatch() or Def.Actor {}
root[#root + 1] = TW.danOverlay("ScreenSelectMusic decorations/dan_overlay_bridge.lua")
return root
