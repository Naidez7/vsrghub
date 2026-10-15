-- Quaver's Full LN and Inverse mods (osu!lazer calls Inverse "Invert"). Etterna can't change a
-- chart's notes while playing, so when you start a song with one of them on, VSRG Hub writes the
-- converted chart to Songs/VSRG Hub Mods (once per chart), loads it, and plays that instead; it has
-- its own MSD and scores. Song select goes back to the original chart afterwards.
--
-- The conversion follows Quaver's Qua.ApplyInverse: every note becomes a long note held until a
-- quarter beat (at least 36 ms) before the next note in its column; long notes turn into the gaps
-- between them; notes shorter than 36 ms stay taps. Full LN is "no long notes" then Inverse.

TW.lnMods = { FLN = "Full LN", INV = "Inverse" }
TW.lnMod = nil -- nil, "FLN" or "INV"
function TW.setLnMod(m)
	if TW.lnMod == m then m = nil end
	TW.lnMod = m
	MESSAGEMAN:Broadcast("TWLnModChanged")
end

local MODS_GROUP = "VSRG Hub Mods"
local MIN_LN, MIN_GAP = 0.036, 0.036

local function safe(s) return (s or ""):gsub("[\\/:%*%?\"<>|%[%]]", ""):gsub("^%s+", ""):gsub("%s+$", "") end
local function smEscape(s) return (s or ""):gsub("[;:#\\]", "") end

-- hold ends from the simfile: { [col] = { [headRow] = tailRow } } for the chart whose heads match
local function readTails(steps, headRows)
	local path = steps:GetFilename() or ""
	local ext = path:lower():match("%.(%w+)$")
	if ext ~= "sm" and ext ~= "ssc" then return nil end
	local ok, txt = pcall(function() return File.Read(path) end)
	if not ok or type(txt) ~= "string" then return nil end
	txt = txt:gsub("//[^\n]*", "")
	local cols = steps:GetNumColumns()
	local want = ToEnumShortString(steps:GetStepsType()):lower():gsub("_", "-")
	local lastType = nil
	local pos = 1
	while true do
		local a, b = txt:find("#NOTES2?:", pos)
		if not a then break end
		local before = txt:sub(pos, a)
		for st in before:gmatch("#STEPSTYPE:([^;]*);") do lastType = st:gsub("%s", ""):lower() end
		local e = txt:find(";", b + 1, true) or #txt
		local body = txt:sub(b + 1, e - 1)
		pos = e + 1
		local stype, data
		if ext == "sm" then
			local f = {}
			for field in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = field end
			stype, data = (f[1] or ""):gsub("%s", ""):lower(), f[6]
		else
			stype, data = lastType, body
		end
		if stype == want and data then
			local tails, open, heads = {}, {}, 0
			for c = 0, cols - 1 do tails[c] = {} end
			local m = 0
			for measure in (data .. ","):gmatch("([^,]*),") do
				local lines = {}
				for raw in measure:gmatch("[^\r\n]+") do
					local line = raw:gsub("%s", "")
					if #line == cols then lines[#lines + 1] = line end
				end
				for j, line in ipairs(lines) do
					local row = m * 192 + math.floor((j - 1) * 192 / #lines + 0.5)
					for c = 0, cols - 1 do
						local ch = line:sub(c + 1, c + 1)
						if ch == "2" or ch == "4" then open[c] = row; heads = heads + 1
						elseif ch == "3" and open[c] then tails[c][open[c]] = row; open[c] = nil end
					end
				end
				m = m + 1
			end
			-- the right chart has the same hold heads Etterna loaded
			local match = true
			for _, h in ipairs(headRows) do if not tails[h[1]][h[2]] then match = false break end end
			if match and heads == #headRows then return tails end
		end
	end
	return nil
end

-- The chart's holds, for the map preview (it keeps a hold's head on the receptor while the hold
-- goes by, as osu! and Quaver do): { [col] = { { s = startBeat, e = endBeat }, ... } } in order, or
-- nil when the simfile can't be read (only .sm and .ssc). Kept for the last chart asked about.
local spanCache = { key = nil, spans = nil }
function TW.holdSpans(steps)
	if not steps then return nil end
	local key = steps:GetChartKey()
	if spanCache.key == key then return spanCache.spans end
	local spans = nil
	pcall(function()
		local nd = steps:GetNonEmptyNoteData()
		local rows = nd[1] or {}
		local cols = steps:GetNumColumns()
		local headRows = {}
		for c = 0, cols - 1 do
			local tr = nd[c + 2] or {}
			for i, r in ipairs(rows) do if tr[i] == 2 then headRows[#headRows + 1] = { c, r } end end
		end
		if #headRows == 0 then spans = {}; return end
		local tails = readTails(steps, headRows)
		if not tails then return end
		spans = {}
		for c = 0, cols - 1 do
			local list = {}
			for h, e in pairs(tails[c] or {}) do list[#list + 1] = { s = h / 48, e = e / 48 } end
			table.sort(list, function(a, b) return a.s < b.s end)
			spans[c] = list
		end
	end)
	spanCache.key, spanCache.spans = key, spans
	return spans
end

-- the converted notes: { [col] = { {s=row, e=row|nil}, ... } } plus mines/fakes as they were
local function convert(steps, mode)
	local td = steps:GetTimingData()
	local nd = steps:GetNonEmptyNoteData()
	local cols = steps:GetNumColumns()
	local rows = nd[1] or {}
	local lanes, extra, headRows = {}, {}, {}
	for c = 0, cols - 1 do
		lanes[c] = {}
		local tr = nd[c + 2] or {}
		for i, r in ipairs(rows) do
			local v = tr[i]
			if v == 1 or v == -1 then lanes[c][#lanes[c] + 1] = { s = r }
			elseif v == 2 then lanes[c][#lanes[c] + 1] = { s = r, head = true }; headRows[#headRows + 1] = { c, r }
			elseif v == 4 or v == 5 then extra[#extra + 1] = { c, r, v == 4 and "M" or "F" } end
		end
	end
	if mode == "INV" then
		local tails = readTails(steps, headRows)
		for c = 0, cols - 1 do
			for _, o in ipairs(lanes[c]) do
				if o.head and tails and tails[c][o.s] then o.e = tails[c][o.s] end
			end
		end
	end -- Full LN: every note is a plain note first
	local function t(row) return td:GetElapsedTimeFromNoteRow(row) end
	local function rowAt(sec) return math.floor(td:GetBeatFromElapsedTime(sec) * 48 + 0.5) end
	local bpms = td:GetBPMsAndTimes(true) or {}
	local function gapAt(row)
		local beat = row / 48
		local bpm = td:GetBPMAtBeat(beat)
		for i, seg in ipairs(bpms) do
			-- a note right on a BPM change takes the BPM before it, as Quaver does
			if math.abs(seg[1] - beat) < 0.001 and i > 1 then bpm = bpms[i - 1][2] end
		end
		bpm = math.abs(bpm or 120)
		if bpm < 1 then bpm = 120 end
		return math.max(math.floor(15000 / bpm + 0.5) / 1000, MIN_GAP)
	end
	local out = {}
	for c = 0, cols - 1 do
		local L, res = lanes[c], {}
		for k, cur in ipairs(L) do
			local nxt, second = L[k + 1], L[k + 2]
			if not nxt and k == 1 then
				res[#res + 1] = { s = cur.s, e = cur.e }
			else
				local gap = nxt and gapAt(nxt.s) or 0
				local snap = nxt and ((second == nil) == (nxt.e == nil))
				if cur.e then
					if not nxt then
						res[#res + 1] = { s = cur.s, e = cur.e }
					else
						local st = t(cur.e)
						local en = snap and t(nxt.s) or (t(nxt.s) - gap)
						if en - st >= MIN_LN then res[#res + 1] = { s = cur.e, e = rowAt(en) } end
					end
				elseif nxt then
					local st = t(cur.s)
					local en = snap and t(nxt.s) or (t(nxt.s) - gap)
					local er = rowAt(en)
					if en - st < MIN_LN or er <= cur.s then res[#res + 1] = { s = cur.s } else res[#res + 1] = { s = cur.s, e = er } end
				end -- the last plain note in a column goes; the hold before it reaches its time
			end
		end
		out[c] = res
	end
	return out, extra, cols
end

local function gcd(a, b) while b ~= 0 do a, b = b, a % b end return a end
local function noteText(lanes, extra, cols)
	local grid = {} -- row -> chars
	local maxRow = 0
	local function put(row, c, ch)
		if row < 0 then return end
		local g = grid[row]
		if not g then g = {}; for i = 1, cols do g[i] = "0" end; grid[row] = g end
		if g[c + 1] == "0" then g[c + 1] = ch end
		if row > maxRow then maxRow = row end
	end
	for c = 0, cols - 1 do
		for _, o in ipairs(lanes[c]) do
			if o.e and o.e > o.s then put(o.s, c, "2"); put(o.e, c, "3") else put(o.s, c, "1") end
		end
	end
	for _, x in ipairs(extra) do put(x[2], x[1], x[3]) end
	local measures = {}
	local empty = string.rep("0", cols)
	for m = 0, math.floor(maxRow / 192) do
		local step = 192
		for r = m * 192, m * 192 + 191 do if grid[r] then step = gcd(step, r - m * 192) end end
		local lines = {}
		for r = m * 192, m * 192 + 191, step do lines[#lines + 1] = grid[r] and table.concat(grid[r]) or empty end
		measures[#measures + 1] = table.concat(lines, "\n")
	end
	return table.concat(measures, "\n,\n")
end

local function relPath(from, to)
	-- from a song folder ("/Songs/VSRG Hub Mods/x/") to a file anywhere ("/AdditionalSongs/...")
	if not to or to == "" then return "" end
	return "../../.." .. (to:sub(1, 1) == "/" and to or ("/" .. to))
end

local function findSong(dir)
	for _, s in ipairs(SONGMAN:GetSongsInGroup(MODS_GROUP) or {}) do
		if s:GetSongDir():lower() == dir:lower() then return s end
	end
	return nil
end

-- the converted copy of song/steps for the mod, writing and loading it if needed
function TW.lnModChart(song, steps, mode)
	local key = steps:GetChartKey() or ""
	local folder = safe(song:GetDisplayMainTitle()):sub(1, 40) .. " (" .. mode .. " " .. key:sub(-8) .. ")"
	local dir = "/Songs/" .. MODS_GROUP .. "/" .. folder .. "/"
	local found = findSong(dir)
	if not found then
		local lanes, extra, cols = convert(steps, mode)
		local td = steps:GetTimingData()
		local function segs(list)
			local o = {}
			for _, s in ipairs(list or {}) do o[#o + 1] = string.format("%.6f=%.6f", s[1], s[2]) end
			return table.concat(o, ",\n")
		end
		local stype = ToEnumShortString(steps:GetStepsType()):lower():gsub("_", "-")
		local diff = ToEnumShortString(steps:GetDifficulty())
		local sm = {
			"#TITLE:" .. smEscape(song:GetDisplayMainTitle()) .. " [" .. (mode == "FLN" and "FLN" or "INV") .. "];",
			"#SUBTITLE:" .. smEscape(song:GetDisplaySubTitle()) .. ";",
			"#ARTIST:" .. smEscape(song:GetDisplayArtist()) .. ";",
			"#CREDIT:" .. smEscape(TW.author and TW.author(song) or "") .. ";",
			"#MUSIC:" .. relPath(dir, song:GetMusicPath()) .. ";",
			"#BACKGROUND:" .. relPath(dir, song:GetBackgroundPath()) .. ";",
			"#BANNER:" .. relPath(dir, song:GetBannerPath()) .. ";",
			string.format("#OFFSET:%.6f;", -td:GetElapsedTimeFromBeat(0)),
			string.format("#SAMPLESTART:%.3f;", song:GetSampleStart() or 0),
			string.format("#SAMPLELENGTH:%.3f;", song:GetSampleLength() or 15),
			"#BPMS:" .. segs(td:GetBPMsAndTimes(true)) .. ";",
			"#STOPS:" .. segs(td:GetStops(true)) .. ";",
			"#DELAYS:" .. segs(td:GetDelays(true)) .. ";",
			"#NOTES:",
			"     " .. stype .. ":",
			"     " .. smEscape((steps:GetAuthorCredit() ~= "" and steps:GetAuthorCredit() or (steps:GetChartName() or ""))) .. " " .. mode .. ":",
			"     " .. diff .. ":",
			"     " .. tostring(steps:GetMeter()) .. ":",
			"     0,0,0,0,0:",
			noteText(lanes, extra, cols),
			";", "",
		}
		local ok = pcall(function() File.Write(dir .. "chart.sm", table.concat(sm, "\n")) end)
		if not ok then return nil end
		SONGMAN:DifferentialReload()
		found = findSong(dir)
	end
	if not found then return nil end
	local list = found:GetStepsByStepsType(steps:GetStepsType()) or {}
	return found, list[1]
end

-- called by song select when it closes to start a song
TW.songChosen = false
function TW.applyLnModOnStart()
	if not (TW.songChosen and TW.lnMod) then return end
	TW.songChosen = false
	local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
	if not (song and steps) or song:GetGroupName() == MODS_GROUP then return end
	local ok, s2, st2 = pcall(TW.lnModChart, song, steps, TW.lnMod)
	if ok and s2 and st2 then
		TW.lnOrig = { song = song, steps = steps }
		GAMESTATE:SetCurrentSong(s2)
		GAMESTATE:SetCurrentSteps(PLAYER_1, st2)
	else
		SCREENMAN:SystemMessage("Couldn't convert this chart for " .. TW.lnMods[TW.lnMod])
	end
end
-- back on song select: the original chart again
function TW.restoreLnModSong(wheel)
	TW.songChosen = false
	local o = TW.lnOrig
	TW.lnOrig = nil
	if not (o and wheel) then return end
	pcall(function()
		wheel:SelectSong(o.song)
		GAMESTATE:SetCurrentSteps(PLAYER_1, o.steps)
	end)
end
-- the actor song select adds: notes that a song was chosen
function TW.lnModWatcher()
	return Def.Actor {
		SongChosenMessageCommand = function() TW.songChosen = true end,
		StepsChosenMessageCommand = function() TW.songChosen = true end,
		OffCommand = function() TW.applyLnModOnStart() end,
	}
end
