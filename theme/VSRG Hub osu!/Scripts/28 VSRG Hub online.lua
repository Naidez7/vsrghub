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
-- how the scoreboard is ordered (every scope): by the play's rating, its accuracy, its combo or
-- its date. TW.sortBoard(list) gives the list in that order (the places follow it).
TW.boardSorts = { { "Rating", "ssr" }, { "Accuracy", "acc" }, { "Combo", "combo" }, { "Newest", "date" } }
TW.boardSort = 1
for i, s in ipairs(TW.boardSorts) do if TW.settings and TW.settings.boardSort == s[2] then TW.boardSort = i end end
function TW.setBoardSort(i)
	TW.boardSort = (i - 1) % #TW.boardSorts + 1
	TW.saveSetting("boardSort", TW.boardSorts[TW.boardSort][2])
	MESSAGEMAN:Broadcast("TWBoardSort")
end
function TW.boardSortName() return TW.boardSorts[TW.boardSort][1] end
local function scoreKeyOf(hs, how)
	local v = 0
	pcall(function()
		if how == "acc" then v = hs:GetWifeScore()
		elseif how == "combo" then v = hs:GetMaxCombo()
		elseif how == "date" then v = tostring(hs:GetDate() or "")
		else v = (type(hs) == "table" and hs.vhOnline) and hs:GetSkillsetSSR() or hs:GetSkillsetSSR("Overall") end
	end)
	return v or 0
end
function TW.sortBoard(list)
	local how = TW.boardSorts[TW.boardSort][2]
	local out = {}
	for i, hs in ipairs(list) do out[i] = hs end
	-- (ties: Etterna's calculator stops raising a play's rating past about 97%, so plays tied on
	-- rating go by accuracy, then the earlier one first)
	local keys, acc, when = {}, {}, {}
	for _, hs in ipairs(out) do keys[hs] = scoreKeyOf(hs, how); acc[hs] = scoreKeyOf(hs, "acc"); when[hs] = scoreKeyOf(hs, "date") end
	table.sort(out, function(a, b)
		if keys[a] ~= keys[b] then return keys[a] > keys[b] end
		if acc[a] ~= acc[b] then return acc[a] > acc[b] end
		return tostring(when[a]) < tostring(when[b])
	end)
	return out
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
TW.jsonObj = jsonObj

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
-- a score as VSRG Hub's server takes it (its replay's offsets with it, so the server can check the
-- accuracy: d is { dvt = offsets, totalTaps, holdsMissed, minesHit }, or nil without a replay)
local function scoreJSON(hs, steps, song, d, failed)
	local keys = TW.keys(steps)
	local rate = hs:GetMusicRate()
	local wife = hs:GetWifeScore()
	pcall(function() local n = hs:GetSSRNormPercent(); if n and n > 0 then wife = n end end)
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
	if failed then s.failed = true end
	local d8 = try(function() return hs:GetDate() end, "")
	if d8 ~= "" then
		-- (Etterna's date is the PC's local time: with its offset from UTC)
		local off = 0
		pcall(function() local now = os.time(); off = os.difftime(now, os.time(os.date("!*t", now))) end)
		local sign = off < 0 and "-" or "+"
		off = math.abs(off)
		s.played_at = d8:gsub(" ", "T") .. string.format("%s%02d:%02d", sign, math.floor(off / 3600), math.floor(off % 3600 / 60))
	end
	for k, name in pairs(SSR) do s["ssr_" .. k] = try(function() return hs:GetSkillsetSSR(name) end, 0) end
	for k, tns in pairs(JUDGE) do s[k] = try(function() return hs:GetTapNoteScore(tns) end, 0) end
	local json = jsonObj(s)
	if d and d.dvt and #d.dvt > 0 and (d.totalTaps or 0) > 0 then
		local o = {}
		for i, v in ipairs(d.dvt) do o[i] = string.format("%.2f", v) end
		json = json:sub(1, -2) .. string.format(',"total_taps":%d,"holds_missed":%d,"offsets":[%s]}', d.totalTaps, d.holdsMissed or 0, table.concat(o, ","))
	end
	return json, s.score_key
end
-- (a score counts when Etterna counts it for its rating: valid, not failed, 4K or 7K. A failed play
-- of the day's challenge is sent too, marked failed: it goes on the day's board and nowhere else)
-- counts(hs, steps) -> sent, failed, why (why: the reason it isn't sent, for the results screen)
local function counts(hs, steps)
	if not try(function() return hs:GetEtternaValid() end, true) then return false, false, "Etterna marks this play invalid (paused, or a mod that doesn't count)" end
	if try(function() return hs:GetChordCohesion() end, false) then return false, false, "played with chord cohesion on" end
	local keys = TW.keys(steps)
	if keys ~= 4 and keys ~= 7 then return false, false, "only 4K and 7K plays are ranked" end
	if try(function() return hs:GetWifeGrade() end, "") == "Grade_Failed" then
		local d = TW.daily and TW.daily(keys)
		if d ~= nil and d.chart == hs:GetChartKey() then return true, true end
		return false, true, "failed plays aren't sent"
	end
	return true, false
end

-- (TW.hubSkipped: why the play on the results screen wasn't sent, for the results screen's line;
-- nil for a play that was, or a score only looked at again)
function TW.exportScore()
	TW.hubSkipped = nil
	pcall(function()
		if TW.rateBeforeView then return end -- (a score looked at again from song select)
		if TW.inPractice and TW.inPractice() then TW.hubSkipped = "practice mode" return end
		local pc = GAMESTATE:GetPlayerState():GetPlayerController()
		if pc == "PlayerController_Autoplay" or pc == "PlayerController_Cpu" then TW.hubSkipped = "autoplay" return end
		local hs = TW.resultsScore and TW.resultsScore()
		if not hs then TW.hubSkipped = "Etterna didn't save this play" return end
		local steps = GAMESTATE:GetCurrentSteps()
		if not steps or steps:GetChartKey() ~= hs:GetChartKey() then TW.hubSkipped = "the chart changed" return end
		local ok, failed, why = counts(hs, steps)
		if not ok then TW.hubSkipped = why or "not a ranked play" return end
		local d = (not failed) and TW.accData and TW.accData() or nil
		local json, key = scoreJSON(hs, steps, GAMESTATE:GetCurrentSong(), d, failed)
		File.Write(ONLINE .. "outbox/" .. key .. ".json", json)
		TW.hubWaiting = key
	end)
end

-- Your older plays, sent once (asked from the launcher's Online page: it writes backfill.txt with
-- "want"): the best score at each rate on every 4K and 7K chart, with its replay when Etterna has
-- one. Done a few charts a frame on song select, so the game doesn't stall.
local function replayData(hs)
	local d = nil
	pcall(function()
		local r = hs:GetReplay()
		r:LoadAllData()
		local offs, types = r:GetOffsetVector() or {}, r:GetTapNoteTypeVector() or {}
		if #offs == 0 then return end
		local dvt = {}
		for i, o in ipairs(offs) do
			local ty = types[i]
			if ty == nil or ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then dvt[#dvt + 1] = o end
		end
		local taps = 0
		for _, tns in pairs(JUDGE) do taps = taps + try(function() return hs:GetTapNoteScore(tns) end, 0) end
		d = { dvt = dvt, totalTaps = taps,
			holdsMissed = try(function() return hs:GetHoldNoteScore("HoldNoteScore_LetGo") end, 0) + try(function() return hs:GetHoldNoteScore("HoldNoteScore_MissedHold") end, 0) }
	end)
	return d
end
function TW.backfillActor()
	return Def.Actor {
		OnCommand = function(self)
			local ok, txt = pcall(function() return File.Read(ONLINE .. "backfill.txt") end)
			if not ok or not txt or not txt:find("^want") then return end
			self.songs = SONGMAN:GetAllSongs() or {}
			self.i, self.sent = 0, 0
			SCREENMAN:SystemMessage("Getting your older plays ready for VSRG Hub's ranking...")
			self:queuecommand("Step")
		end,
		StepCommand = function(self)
			local songs = self.songs
			if not songs then return end
			local last = math.min(#songs, self.i + 25)
			for n = self.i + 1, last do
				local song = songs[n]
				pcall(function()
					for _, steps in ipairs(song:GetAllSteps() or {}) do
						local keys = TW.keys(steps)
						if keys == 4 or keys == 7 then
							local byRate = SCOREMAN:GetScoresByKey(steps:GetChartKey())
							if byRate then
								for _, sar in pairs(byRate) do
									local best
									for _, hs in ipairs(sar:GetScores() or {}) do
										local ok, failed = counts(hs, steps)
										if ok and not failed and (not best or hs:GetWifeScore() > best:GetWifeScore()) then best = hs end
									end
									if best then
										local json, key = scoreJSON(best, steps, song, replayData(best))
										File.Write(ONLINE .. "outbox/" .. key .. ".json", json)
										self.sent = self.sent + 1
									end
								end
							end
						end
					end
				end)
			end
			self.i = last
			if last >= #songs then
				pcall(function() File.Write(ONLINE .. "backfill.txt", "done " .. self.sent .. "\n") end)
				SCREENMAN:SystemMessage(string.format("%d older plays are on their way to VSRG Hub's ranking", self.sent))
				self.songs = nil
				return
			end
			self:sleep(0.02):queuecommand("Step")
		end,
	}
end

-- the results screen: what VSRG Hub's ranking made of this play (written by the program once sent:
-- results/<score key>.txt, "ok<TAB>keys<TAB>old rating<TAB>new rating<TAB>old place<TAB>new place" or
-- "refused<TAB>why"), shown in a line at the bottom
function TW.hubResultLine(x, y, textFn)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(x, y):diffusealpha(0) end,
		-- (a frame later: the screen's own OnCommand writes the play first)
		OnCommand = function(self) self:queuecommand("Start") end,
		StartCommand = function(self)
			self.key = TW.hubWaiting
			TW.hubWaiting = nil
			if not TW.hubMe() then return end
			if not self.key then
				-- (not sent: say why, so a missing play is no mystery)
				if TW.hubSkipped then
					self:GetChild("T"):settext("Not sent to VSRG Hub: " .. TW.hubSkipped)
					self:linear(0.2):diffusealpha(1)
				end
				return
			end
			self.t0 = GetTimeSinceStart()
			self:GetChild("T"):settext("Sending your play to VSRG Hub's ranking...")
			self:linear(0.2):diffusealpha(1):queuecommand("Poll")
		end,
		PollCommand = function(self)
			local ok, txt = pcall(function() return File.Read(ONLINE .. "results/" .. self.key .. ".txt") end)
			local t = self:GetChild("T")
			if ok and txt and txt ~= "" then
				local f = {}
				for v in (txt:gsub("[\r\n]+$", "") .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
				if f[1] == "ok" then
					local old, new, op, np = tonumber(f[3]) or 0, tonumber(f[4]) or 0, tonumber(f[5]) or 0, tonumber(f[6]) or 0
					local d = new - old
					local line = string.format("VSRG Hub %sK rating: %.2f", f[2] or "4", new)
					if math.abs(d) >= 0.005 then line = line .. string.format(" (%s%.2f)", d > 0 and "+" or "", d) end
					if np > 0 then
						line = line .. "   #" .. np
						if op > 0 and op ~= np then line = line .. string.format(" (%s%d)", op > np and "+" or "-", math.abs(op - np)) end
					end
					-- (and your place on this chart, among everyone's best on it)
					local cp = tonumber(f[7]) or 0
					if cp > 0 then line = line .. string.format("   #%d on this chart", cp) end
					t:settext(line)
				else
					t:settext("VSRG Hub didn't take this play: " .. (f[2] or ""))
				end
				return
			end
			if GetTimeSinceStart() - self.t0 > 20 then t:settext("Your play will be sent to VSRG Hub's ranking later") return end
			self:sleep(0.5):queuecommand("Poll")
		end,
		Def.Quad { Name = "Bg", InitCommand = function(self) self:zoomto(1, 1):diffuse({ 0, 0, 0, 0.6 }) end },
		-- (textFn(init): the look's text actor, init run on it)
		textFn(function(self) self:align(0.5, 0.5):shadowlength(1) end) .. { Name = "T" },
		-- (the dark band behind fits the words)
		Def.ActorFrame { InitCommand = function(self)
			self:SetUpdateFunction(function(a)
				local p = a:GetParent()
				local t = p:GetChild("T")
				p:GetChild("Bg"):zoomto(t:GetZoomedWidth() + 28, t:GetZoomedHeight() + 12)
			end)
		end },
	}
end

-- "someone passed you": your 4K / 7K places are kept between starts (settings hubPlace4 / 7) and
-- compared with me.txt's when song select comes up; a drop is told once
function TW.hubPlaceWatch()
	return Def.Actor {
		OnCommand = function(self) self:sleep(2):queuecommand("Look") end,
		LookCommand = function(self)
			local me = TW.hubMe()
			if not me or not TW.settings then return end
			for _, k in ipairs({ 4, 7 }) do
				local now = k == 4 and me.p4 or me.p7
				local was = tonumber(TW.settings["hubPlace" .. k] or "") or 0
				if now and now > 0 then
					if was > 0 and now > was then
						SCREENMAN:SystemMessage(string.format("Someone passed you in %dK on VSRG Hub's ranking: you're #%d now (were #%d)", k, now, was))
					end
					if now ~= was then pcall(function() TW.saveSetting("hubPlace" .. k, tostring(now)) end) end
				end
			end
		end,
	}
end

-- who's signed in to VSRG Hub (nil when nobody, or the game wasn't started from VSRG Hub)
function TW.hubMe()
	local ok, txt = pcall(function() return File.Read(ONLINE .. "me.txt") end)
	if not ok or not txt or txt == "" then return nil end
	local name, r4, r7 = txt:match("^([^\t\r\n]+)\t([%d%.]+)\t([%d%.]+)")
	if not name then return nil end
	local p4, p7 = txt:match("^[^\t]+\t[%d%.]+\t[%d%.]+\t(%d+)\t(%d+)")
	return { name = name, r4 = tonumber(r4) or 0, r7 = tonumber(r7) or 0, p4 = tonumber(p4) or 0, p7 = tonumber(p7) or 0 }
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
	local hs = { vhOnline = true, place = tonumber(f[1]), name = f[2], source = f[15] or "", id = f[16] or "" }
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
