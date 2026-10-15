-- Online rankings: EtternaOnline's leaderboard for a chart, for the osu! and Quaver scoreboards
-- (their ranking box switches between your local scores and the online ones).
-- TW.rankSource is "local" or "online" and is kept in VSRG Hub's settings.
TW.rankSource = (TW.settings and TW.settings.rankSource == "online") and "online" or "local"
function TW.setRankSource(src)
	TW.rankSource = src == "online" and "online" or "local"
	TW.saveSetting("rankSource", TW.rankSource)
	MESSAGEMAN:Broadcast("TWRankSource")
end
function TW.loggedIn()
	local ok, on = pcall(function() return DLMAN:IsLoggedIn() end)
	return ok and on
end

-- the scores that came from EtternaOnline (a local score shown beside them, e.g. your personal best,
-- isn't one: it opens as usual)
TW.onlineScores = setmetatable({}, { __mode = "k" })
function TW.isOnlineScore(hs) return hs ~= nil and TW.onlineScores[hs] == true end

-- done(list, status) with status "ok", "empty", "loading", "login", "unranked" or "none".
-- (it can be called twice: "loading" first, then the answer once EtternaOnline replies; the answer
-- is dropped when another chart was picked meanwhile)
function TW.onlineRanking(steps, done)
	local function call(list, status) pcall(done, list, status) end
	if not steps then return call({}, "none") end
	if not TW.loggedIn() then return call({}, "login") end
	local ck = steps:GetChartKey()
	local function answer()
		local ok, lb = pcall(function() return DLMAN:GetChartLeaderBoard(ck) end)
		-- (nil: the chart isn't ranked online)
		if not ok or lb == nil then return call({}, "unranked") end
		for _, hs in ipairs(lb) do TW.onlineScores[hs] = true end
		call(lb, #lb == 0 and "empty" or "ok")
	end
	call({}, "loading")
	local screen = SCREENMAN:GetTopScreen()
	pcall(function()
		DLMAN:RequestChartLeaderBoardFromOnline(ck, function()
			-- (the song select it was asked from may be gone, or on another chart now)
			if SCREENMAN:GetTopScreen() ~= screen then return end
			local cur = GAMESTATE:GetCurrentSteps()
			if not cur or cur:GetChartKey() ~= ck then return end
			answer()
		end)
	end)
end

-- the name shown for a score: an online score's player, or your profile's name for your own plays
-- (Etterna leaves "#P1#" as the name of some plays, e.g. paused ones)
function TW.scoreName(hs)
	local who = hs:GetDisplayName()
	if who == nil or who == "" or who:find("^#P%d#$") then
		local prof = PROFILEMAN:GetProfile(PLAYER_1)
		who = prof and prof:GetDisplayName() or "You"
	end
	return who
end
function TW.isMyScore(hs)
	if not TW.isOnlineScore(hs) then return true end
	local me = ""
	pcall(function() me = DLMAN:GetUsername() or "" end)
	return me ~= "" and hs:GetDisplayName() == me
end

-- clicking an online score: watch its replay (Etterna fetches it from EtternaOnline first)
local fetching = nil
function TW.openOnlineScore(hs, watch)
	-- (one at a time: a second click while EtternaOnline answers would open it twice)
	if fetching and GetTimeSinceStart() - fetching < 8 then return end
	fetching = GetTimeSinceStart()
	SCREENMAN:SystemMessage("Getting the replay from EtternaOnline...")
	local ok = pcall(function()
		DLMAN:RequestOnlineScoreReplayData(hs, function()
			fetching = nil
			-- (HasReplayData is true for any online score: what counts is that the hits arrived; when
			-- EtternaOnline fails to send them, playing it would show every note missed, and Etterna can
			-- crash on the next play)
			local has = false
			pcall(function()
				local r = hs:GetReplay()
				local offs = r:GetOffsetVector()
				has = offs ~= nil and #offs > 0
			end)
			if not has then SCREENMAN:SystemMessage("EtternaOnline couldn't send this score's replay") return end
			if watch then TW.playReplay(hs)
			elseif not TW.showScore(hs) then TW.playReplay(hs) end
		end)
	end)
	if not ok then fetching = nil; SCREENMAN:SystemMessage("Couldn't get this score's replay") end
end
