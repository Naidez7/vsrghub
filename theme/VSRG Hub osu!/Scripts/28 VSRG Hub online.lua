-- Online rankings: EtternaOnline's leaderboard for a chart, for the osu! and Quaver scoreboards
-- (their ranking box switches between your local scores and the online ones).
-- TW.rankSource is "local" or "online" and is kept in VSRG Hub's settings.
-- ("hub": VSRG Hub's own ranking, below)
local SOURCES = { online = true, hub = true }
TW.rankSource = (TW.settings and SOURCES[TW.settings.rankSource]) and TW.settings.rankSource or "local"
function TW.setRankSource(src)
	TW.rankSource = SOURCES[src] and src or "local"
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
	if type(hs) == "table" and hs.vhOnline then
		local me = TW.hubMe and TW.hubMe()
		return me ~= nil and hs.name == me.name
	end
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

-- ---------------------------------------------------------------------------------------------
-- VSRG Hub's own online ranking (VSRG Hub accounts, every chart ranked). Etterna's theme can't reach
-- the internet: VSRG Hub's program does it while the game runs (cmd/triwheel/online.go), and the two
-- talk through files in Save/VSRGHub/online:
--   outbox/<score key>.json   your plays, written here on the results screen, sent when you're signed in
--   want.txt / board.txt      the chart whose ranking is wanted / that ranking
--   me.txt                    who's signed in ("name<TAB>4K rating<TAB>7K rating")
local ONLINE = "Save/VSRGHub/online/"

local function jsonStr(s)
	s = tostring(s or "")
	s = s:gsub('[%c"\\]', function(c)
		if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
		return string.format("\\u%04x", c:byte())
	end)
	return '"' .. s .. '"'
end
local function jsonObj(t)
	local parts = {}
	for k, v in pairs(t) do
		local val
		if type(v) == "number" then val = (v ~= v or v == math.huge or v == -math.huge) and "0" or string.format("%.6g", v)
		elseif type(v) == "boolean" then val = v and "true" or "false"
		else val = jsonStr(v) end
		parts[#parts + 1] = jsonStr(k) .. ":" .. val
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- the results screen's play, written to the outbox: only a real play of yours, saved by Etterna
-- (not autoplay, practice, a replay of someone else's score or a score looked at again), valid for
-- Etterna's rating, not failed, on a 4K or 7K chart
local SSR = { overall = "Overall", stream = "Stream", jumpstream = "Jumpstream", handstream = "Handstream",
	stamina = "Stamina", jackspeed = "JackSpeed", chordjack = "Chordjack", technical = "Technical" }
local JUDGE = { marvelous = "TapNoteScore_W1", perfect = "TapNoteScore_W2", great = "TapNoteScore_W3",
	good = "TapNoteScore_W4", bad = "TapNoteScore_W5", miss = "TapNoteScore_Miss" }
local function try(f, d)
	local ok, v = pcall(f)
	if ok and v ~= nil then return v end
	return d
end
function TW.exportScore()
	pcall(function()
		if TW.rateBeforeView then return end -- (a score looked at again from song select)
		if TW.inPractice and TW.inPractice() then return end
		local pc = GAMESTATE:GetPlayerState():GetPlayerController()
		if pc == "PlayerController_Autoplay" or pc == "PlayerController_Cpu" then return end
		local hs = TW.resultsScore and TW.resultsScore()
		if not hs then return end
		if not try(function() return hs:GetEtternaValid() end, true) or try(function() return hs:GetChordCohesion() end, false) then return end
		if hs:GetWifeGrade() == "Grade_Failed" then return end
		local steps = GAMESTATE:GetCurrentSteps()
		if not steps or steps:GetChartKey() ~= hs:GetChartKey() then return end
		local keys = TW.keys(steps)
		if keys ~= 4 and keys ~= 7 then return end
		local rate = hs:GetMusicRate()
		local wife = hs:GetWifeScore()
		pcall(function() local n = hs:GetSSRNormPercent(); if n and n > 0 then wife = n end end)
		local song = GAMESTATE:GetCurrentSong()
		local s = {
			score_key = hs:GetScoreKey(), chart_key = hs:GetChartKey(), keys = keys, rate = rate, wife = wife * 100,
			msd = try(function() return steps:GetMSD(rate, 1) end, 0), max_combo = try(function() return hs:GetMaxCombo() end, 0),
			modifiers = try(function() return hs:GetModifiers() end, ""),
			song_title = song and song:GetDisplayMainTitle() or "", song_artist = song and song:GetDisplayArtist() or "",
			chart_name = TW.diffName and TW.diffName(steps) or "",
			holds_ok = try(function() return hs:GetHoldNoteScore("HoldNoteScore_Held") end, 0),
			holds_ng = try(function() return hs:GetHoldNoteScore("HoldNoteScore_LetGo") end, 0),
			mines_hit = try(function() return hs:GetTapNoteScore("TapNoteScore_HitMine") end, 0),
		}
		local d = try(function() return hs:GetDate() end, "")
		if d ~= "" then
			-- (Etterna's date is the PC's local time: with its offset from UTC)
			local off = 0
			pcall(function() local now = os.time(); off = os.difftime(now, os.time(os.date("!*t", now))) end)
			local sign = off < 0 and "-" or "+"
			off = math.abs(off)
			s.played_at = d:gsub(" ", "T") .. string.format("%s%02d:%02d", sign, math.floor(off / 3600), math.floor(off % 3600 / 60))
		end
		for k, name in pairs(SSR) do s["ssr_" .. k] = try(function() return hs:GetSkillsetSSR(name) end, 0) end
		for k, tns in pairs(JUDGE) do s[k] = try(function() return hs:GetTapNoteScore(tns) end, 0) end
		File.Write(ONLINE .. "outbox/" .. s.score_key .. ".json", jsonObj(s))
	end)
end

-- who's signed in to VSRG Hub (nil when nobody, or the game wasn't started from VSRG Hub)
function TW.hubMe()
	local ok, txt = pcall(function() return File.Read(ONLINE .. "me.txt") end)
	if not ok or not txt or txt == "" then return nil end
	local name, r4, r7 = txt:match("^([^\t\r\n]+)\t([%d%.]+)\t([%d%.]+)")
	if not name then return nil end
	return { name = name, r4 = tonumber(r4) or 0, r7 = tonumber(r7) or 0 }
end

-- a score from VSRG Hub's ranking, made to answer what the scoreboards ask a HighScore
local function hubScore(f)
	local wife = (tonumber(f[3]) or 0) / 100
	local g = "Grade_Tier16"
	for _, step in ipairs({ { 0.999935, 1 }, { 0.99955, 4 }, { 0.997, 7 }, { 0.93, 10 }, { 0.8, 13 }, { 0.7, 14 }, { 0.6, 15 } }) do
		if wife >= step[1] then g = string.format("Grade_Tier%02d", step[2]) break end
	end
	local tns = { TapNoteScore_W1 = tonumber(f[6]) or 0, TapNoteScore_W2 = tonumber(f[7]) or 0, TapNoteScore_W3 = tonumber(f[8]) or 0,
		TapNoteScore_W4 = tonumber(f[9]) or 0, TapNoteScore_W5 = tonumber(f[10]) or 0, TapNoteScore_Miss = tonumber(f[11]) or 0 }
	local hs = { vhOnline = true, place = tonumber(f[1]), name = f[2] }
	function hs:GetDisplayName() return self.name end
	function hs:GetWifeScore() return wife end
	function hs:GetSSRNormPercent() return wife end
	function hs:GetWifeGrade() return g end
	function hs:GetMusicRate() return tonumber(f[4]) or 1 end
	function hs:GetSkillsetSSR() return tonumber(f[5]) or 0 end
	function hs:GetTapNoteScore(k) return tns[k] or 0 end
	function hs:GetMaxCombo() return tonumber(f[12]) or 0 end
	function hs:GetDate() return (f[13] or ""):sub(1, 19):gsub("T", " ") end
	function hs:GetModifiers() return f[14] or "" end
	function hs:GetEtternaValid() return true end
	return hs
end
function TW.isHubScore(hs) return type(hs) == "table" and hs.vhOnline == true end

-- done(list, status) as TW.onlineRanking: "loading", then "ok", "empty", "offline" (the server can't
-- be reached) or "nohub" (the game wasn't started from VSRG Hub, nobody to ask)
local asked = 0
function TW.hubRanking(steps, done, actor)
	local function call(list, status) pcall(done, list, status) end
	if not steps then return call({}, "none") end
	local ck = steps:GetChartKey()
	asked = asked + 1
	local n = asked
	pcall(function() File.Write(ONLINE .. "want.txt", ck .. "\t" .. n .. "\n") end)
	call({}, "loading")
	local t0 = GetTimeSinceStart()
	-- (the answer is read back a few times a second until it comes, for at most 6 seconds)
	local function poll()
		if n ~= asked then return end
		local cur = GAMESTATE:GetCurrentSteps()
		if not cur or cur:GetChartKey() ~= ck then return end
		local ok, txt = pcall(function() return File.Read(ONLINE .. "board.txt") end)
		if ok and txt and txt:sub(1, #ck) == ck then
			local list, status = {}, "ok"
			local first = true
			for line in txt:gmatch("[^\r\n]+") do
				local f = {}
				for v in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
				if first then status = f[2] or "ok"; first = false
				elseif #f >= 12 then list[#list + 1] = hubScore(f) end
			end
			return call(list, status)
		end
		if GetTimeSinceStart() - t0 > 6 then return call({}, "nohub") end
		actor:sleep(0.25):queuecommand("HubPoll")
	end
	actor.hubPoll = poll
	actor:sleep(0.25):queuecommand("HubPoll")
end
