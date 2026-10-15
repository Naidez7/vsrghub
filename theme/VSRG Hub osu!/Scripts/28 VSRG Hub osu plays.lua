-- Your osu! plays on VSRG Hub's ranking. The launcher reads your osu! stable and osu!lazer
-- replays, judges them as Etterna would and writes them to Save/VSRGHub/online/osu/jobs.txt
-- (cmd/triwheel/osureplay.go); here, on song select, each is rated with Etterna's calculator for
-- its chart and written to the outbox like any play (28 VSRG Hub online.lua), a few a frame so the
-- game doesn't stall. done.txt says how it went.
--
-- A job line (tab-separated): key, source (osu / lazer), the library song folder ("osu!/<name>"),
-- the steps type, the chart's description, keys, rate, Wife%, the six judgement counts, max combo,
-- taps, holds missed, when it was played, the mods, the offsets (ms, comma-separated).
local ONLINE = "Save/VSRGHub/online/"
local STEPS = { ["dance-single"] = "StepsType_Dance_Single", ["kb7-single"] = "StepsType_Kb7_Single" }
local SSR_ORDER = { "overall", "stream", "jumpstream", "handstream", "stamina", "jackspeed", "chordjack", "technical" }

local function split(s, sep)
	local out, i = {}, 1
	while true do
		local j = s:find(sep, i, true)
		if not j then out[#out + 1] = s:sub(i); break end
		out[#out + 1] = s:sub(i, j - 1)
		i = j + 1
	end
	return out
end

-- the songs VSRG Hub made from osu!, by their library folder
local function songIndex()
	local byDir = {}
	for _, song in ipairs(SONGMAN:GetAllSongs() or {}) do
		local dir = (song:GetSongDir() or ""):gsub("\\", "/"):gsub("/+$", "")
		local a, b = dir:match("([^/]+)/([^/]+)$")
		if a then byDir[(a .. "/" .. b):lower()] = song end
	end
	return byDir
end
local function findSteps(song, stepsType, diff)
	local want = STEPS[stepsType]
	diff = (diff or ""):lower()
	local loose
	for _, st in ipairs(song:GetAllSteps() or {}) do
		local ok, ty = pcall(function() return st:GetStepsType() end)
		if ok and ty == want then
			local d = ""
			pcall(function() d = st:GetDescription() or "" end)
			if d:lower() == diff then return st end
			if d == "" and (TW.diffName(st) or ""):lower() == diff then return st end
			loose = loose or st
		end
	end
	return nil, loose
end

-- one job: the play as VSRG Hub's server takes it (the fields of 28 VSRG Hub online.lua's scoreJSON)
local function rateJob(f, byDir)
	local key, source, dir, stepsType, diff = f[1], f[2], f[3], f[4], f[5]
	local keys, rate, wife = tonumber(f[6]), tonumber(f[7]), tonumber(f[8])
	local song = byDir[(dir or ""):lower()]
	if not song then return nil, "song" end
	local steps = findSteps(song, stepsType, diff)
	if not steps then return nil, "chart" end
	if TW.keys(steps) ~= keys then return nil, "keys" end
	local ssrs = {}
	local ok = pcall(function() ssrs = steps:GetSSRs(rate, wife / 100) or {} end)
	if not ok or #ssrs < 8 then return nil, "calc" end
	local s = {
		score_key = key, chart_key = steps:GetChartKey(), keys = keys, rate = rate, wife = wife,
		msd = 0, max_combo = tonumber(f[15]) or 0,
		modifiers = (source == "lazer" and "osu!lazer" or source == "quaver" and "Quaver" or "osu!") .. ((f[19] or "") ~= "" and (" " .. f[19]) or ""),
		song_title = song:GetDisplayMainTitle() or "", song_artist = song:GetDisplayArtist() or "",
		chart_name = TW.diffName(steps) or "", holds_ok = 0, holds_ng = tonumber(f[17]) or 0, mines_hit = 0,
		played_at = f[18] or "", source = source,
		marvelous = tonumber(f[9]) or 0, perfect = tonumber(f[10]) or 0, great = tonumber(f[11]) or 0,
		good = tonumber(f[12]) or 0, bad = tonumber(f[13]) or 0, miss = tonumber(f[14]) or 0,
	}
	pcall(function() s.msd = steps:GetMSD(rate, 1) end)
	for i, name in ipairs(SSR_ORDER) do s["ssr_" .. name] = ssrs[i] or 0 end
	local json = TW.jsonObj(s)
	json = json:sub(1, -2) .. string.format(',"total_taps":%d,"holds_missed":%d,"offsets":[%s]}', tonumber(f[16]) or 0, tonumber(f[17]) or 0, f[20] or "")
	return json
end

function TW.osuPlaysActor()
	return Def.Actor {
		OnCommand = function(self)
			local ok, txt = pcall(function() return File.Read(ONLINE .. "osu/jobs.txt") end)
			if not ok or not txt or txt == "" then return end
			local done = false
			pcall(function() local d = File.Read(ONLINE .. "osu/done.txt"); done = d ~= nil and d ~= "" end)
			if done then return end
			self.lines = split(txt:gsub("\r", ""), "\n")
			self.i, self.sent, self.bad = 0, 0, {}
			-- (left song select half way last time: goes on from where it was)
			pcall(function()
				local pr = File.Read(ONLINE .. "osu/progress.txt")
				local i, sent = (pr or ""):match("^(%d+)\t(%d+)")
				if i and tonumber(i) < #self.lines then self.i, self.sent = tonumber(i), tonumber(sent) end
			end)
			self.byDir = songIndex()
			SCREENMAN:SystemMessage("Rating your osu! plays for VSRG Hub's ranking...")
			self:queuecommand("Step")
		end,
		StepCommand = function(self)
			local lines = self.lines
			if not lines then return end
			local last = math.min(#lines, self.i + 8)
			for n = self.i + 1, last do
				local line = lines[n]
				if line ~= "" then
					local f = split(line, "\t")
					local json, why = nil, "bad"
					if #f >= 20 then
						local ok, j, w = pcall(rateJob, f, self.byDir)
						if ok then json, why = j, w else why = "error" end
					end
					if json then
						File.Write(ONLINE .. "outbox/" .. f[1] .. ".json", json)
						self.sent = self.sent + 1
					else
						self.bad[why or "bad"] = (self.bad[why or "bad"] or 0) + 1
					end
				end
			end
			self.i = last
			if self.i < #lines then
				if self.i % 80 == 0 then File.Write(ONLINE .. "osu/progress.txt", self.i .. "\t" .. self.sent .. "\n") end
				self:sleep(0.02):queuecommand("Step")
				return
			end
			File.Write(ONLINE .. "osu/progress.txt", "")
			local parts = {}
			for k, v in pairs(self.bad) do parts[#parts + 1] = k .. "=" .. v end
			table.sort(parts)
			File.Write(ONLINE .. "osu/done.txt", string.format("done %d\t%s\n", self.sent, table.concat(parts, " ")))
			SCREENMAN:SystemMessage(string.format("%d osu! plays ready for VSRG Hub's ranking", self.sent))
			TW.hubWaiting = TW.hubWaiting or "osu"
			self.lines = nil
		end,
	}
end
