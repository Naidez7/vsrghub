-- Written by VSRG Hub next to its theme picker in Etterna's own themes and loaded by every look
-- (the VSRG Hub looks fall back to Til Death). Your profile as a full page, like osu!'s: Etterna's
-- ratings for 4K and VSRG Hub's for 7K (Etterna rates 4K only: 7K uses Etterna's own formula on your
-- 7K scores), play time, plays, grades, your top plays, recent plays and most played charts, each
-- with its banner, difficulty, MSD, rate, accuracy and date. Drawn in the look's own style.
--
-- TWOpenProfile() opens it (the osu! and Quaver looks' player card / PROFILE button, Til' Death's
-- and Rebirth's profile corner on song select, or their Ctrl+O menu). Esc, right click or a click
-- outside the page closes it.

local THEMENAME = THEME:GetCurThemeName()
local LAZER = THEMENAME == "VSRG Hub lazer"
local LOOK = ((THEMENAME == "VSRG Hub osu!" or LAZER) and "osu") or (THEMENAME == "VSRG Hub Quaver" and "quaver")
	or (THEMENAME == "Rebirth" and "rebirth") or "tildeath"
local u = SCREEN_HEIGHT / 720
local W = math.min(SCREEN_WIDTH, 1280 * u)
local X0 = (SCREEN_WIDTH - W) / 2
local PAD = 32 * u

-- ------------------------------------------------------------------------------------------------
-- colours: each look's own
-- ------------------------------------------------------------------------------------------------
local function rgb(r, g, b, a) return { r / 255, g / 255, b / 255, a or 1 } end
local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t } end
local function alpha(c, a) return { c[1], c[2], c[3], a } end
local function try(f, fallback)
	local ok, v = pcall(f)
	if ok and v ~= nil then return v end
	return fallback
end
local S
if LOOK == "osu" then
	local pink = (TW and TW.pink) or rgb(255, 102, 170)
	S = { bg = rgb(34, 30, 44), head = rgb(26, 23, 34), card = rgb(44, 40, 56), row = rgb(255, 255, 255, 0.04), rowOn = rgb(255, 255, 255, 0.1),
		accent = pink, text = rgb(255, 255, 255), dim = rgb(168, 162, 186), track = rgb(255, 255, 255, 0.1), tab = rgb(26, 23, 34),
		chip = rgb(0, 0, 0, 0.35), upper = false, font = (TW and TW.font) or "Common Normal", bold = (TW and TW.bold) or "Common Normal" }
	-- (osu!lazer's look: its overlay greys, a little pink)
	if LAZER and LZ then
		S.bg, S.head, S.card, S.tab = LZ.bg5, LZ.bg6, LZ.bg3, LZ.bg6
		S.dim, S.accent = LZ.dim, (TW and TW.pink) or LZ.pink
	end
elseif LOOK == "quaver" then
	local cyan = rgb(69, 211, 255)
	S = { bg = rgb(36, 36, 36), head = rgb(28, 28, 28), card = rgb(44, 44, 44), row = rgb(40, 40, 40), rowOn = rgb(40, 52, 56),
		accent = cyan, text = rgb(255, 255, 255), dim = rgb(150, 150, 155), track = rgb(25, 25, 25), tab = rgb(31, 31, 31),
		chip = rgb(25, 25, 25), upper = true, font = (TW and TW.font) or "Common Normal", bold = (TW and TW.bold) or "Common Normal" }
elseif LOOK == "rebirth" then
	local function rc(k, f) return try(function() return COLORS:getMainColor(k) end, color(f)) end
	local bg, sec = rc("PrimaryBackground", "#111111"), rc("SecondaryBackground", "#222222")
	S = { bg = alpha(bg, 0.98), head = mix(bg, { 0, 0, 0, 1 }, 0.35), card = alpha(sec, 0.9), row = rgb(255, 255, 255, 0.04), rowOn = rgb(255, 255, 255, 0.1),
		accent = rc("PrimaryText", "#FFFFFF"), text = rc("PrimaryText", "#FFFFFF"), dim = rc("SecondaryText", "#AAAAAA"),
		track = rgb(255, 255, 255, 0.08), tab = mix(bg, { 0, 0, 0, 1 }, 0.35), chip = rgb(0, 0, 0, 0.35), upper = false,
		font = "Common Normal", bold = "Common Normal", rebirth = true }
else
	local function tc(k, f) return try(function() return getMainColor(k) end, color(f)) end
	S = { bg = alpha(tc("frames", "#000111"), 0.97), head = mix(tc("frames", "#000111"), { 0, 0, 0, 1 }, 0.4), card = alpha(tc("tabs", "#2E2E2E"), 0.95),
		row = rgb(255, 255, 255, 0.04), rowOn = rgb(255, 255, 255, 0.1), accent = tc("highlight", "#614080"), text = rgb(255, 255, 255),
		dim = rgb(170, 170, 170), track = rgb(255, 255, 255, 0.08), tab = mix(tc("frames", "#000111"), { 0, 0, 0, 1 }, 0.4),
		chip = rgb(0, 0, 0, 0.35), upper = false, font = "Common Normal", bold = "Common Normal", titles = tc("positive", "#9654FD") }
	S.accentText = mix(S.accent, { 1, 1, 1, 1 }, 0.45)
end
S.accentText = S.accentText or S.accent
-- skillset colours (one for each, used by the bars)
local SKILLS = { "Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical" }
local SKILL_COL = { rgb(255, 255, 255), rgb(102, 204, 255), rgb(255, 170, 102), rgb(255, 102, 153), rgb(170, 136, 255),
	rgb(255, 221, 85), rgb(119, 221, 119), rgb(255, 136, 102) }
local function msdColour(x)
	local c = try(function() return byMSD(x) end) or try(function() return colorByMSD(x) end)
	if c then return c end
	x = x or 0
	if x < 10 then return rgb(102, 204, 255) elseif x < 15 then return rgb(119, 221, 119) elseif x < 20 then return rgb(255, 221, 85)
	elseif x < 25 then return rgb(255, 136, 102) elseif x < 30 then return rgb(255, 85, 136) end
	return rgb(187, 119, 255)
end
local function gradeColour(g)
	return try(function() return getGradeColor(g) end) or try(function() return colorByGrade(g) end) or rgb(255, 255, 255)
end
local function diffColour(d)
	return try(function() return byDifficulty(d) end) or try(function() return colorByDifficulty(d) end) or rgb(200, 200, 200)
end
local function gradeName(g)
	if not g then return "" end
	return try(function() return THEME:GetString("Grade", ToEnumShortString(g)) end, (g:gsub("Grade_", "")))
end
local DIFF = { Difficulty_Beginner = "Beginner", Difficulty_Easy = "Easy", Difficulty_Medium = "Medium", Difficulty_Hard = "Hard",
	Difficulty_Challenge = "Insane", Difficulty_Edit = "Edit" }

-- ------------------------------------------------------------------------------------------------
-- the numbers
-- ------------------------------------------------------------------------------------------------
-- Etterna's rating: per skillset, aggregate_skill over your personal bests' SSRs (0.1, x1.05, from
-- 0 in steps of 10.24 halved 11 times), overall the average of the seven
local function erfc(x)
	local z = math.abs(x)
	local t = 1 / (1 + 0.5 * z)
	local r = t * math.exp(-z * z - 1.26551223 + t * (1.00002368 + t * (0.37409196 + t * (0.09678418 + t * (-0.18628806
		+ t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 + t * (-0.82215223 + t * 0.17087277)))))))))
	if x >= 0 then return r end
	return 2 - r
end
local function aggregate(v)
	if #v == 0 then return 0 end
	local rating, res = 0, 10.24
	for _ = 1, 11 do
		local sum
		repeat
			rating = rating + res
			sum = 0
			for i = 1, #v do
				local e = erfc(0.1 * (v[i] - rating))
				if e > 0 then sum = sum + math.max(0, 2 / e - 2) else sum = math.huge end
			end
		until not (2 ^ (rating * 0.1) < sum)
		rating = rating - res
		res = res / 2
	end
	rating = rating + res * 2
	return math.max(0, math.min(100, rating * 1.05))
end

local function newMode()
	return { plays = 0, secs = 0, recent = {}, charts = {}, chartList = {}, pbs = {}, top = {}, most = {}, skills = {},
		grades = { 0, 0, 0, 0, 0, 0 }, acc = 0, best = nil }
end
local cache = { n = -1 }
local function profile()
	local p = PROFILEMAN:GetProfile(PLAYER_1)
	if p and p:GetDisplayName() ~= "" then return p end
	local ok, id = pcall(function() return PREFSMAN:GetPreference("DefaultLocalProfileIDP1") end)
	if ok and id and id ~= "" then
		local lp = PROFILEMAN:GetLocalProfile(id)
		if lp then return lp end
	end
	return p
end
local function gradeClass(g)
	-- 1 AAAAA, 2 AAAA, 3 AAA, 4 AA, 5 A, 6 below
	local n = tonumber((g or ""):match("Tier(%d+)"))
	if not n then return 6 end
	if n == 1 then return 1 elseif n <= 4 then return 2 elseif n <= 7 then return 3 elseif n <= 10 then return 4 elseif n <= 13 then return 5 end
	return 6
end
function TWProfileData(force)
	local n = 0
	pcall(function() n = SCOREMAN:GetTotalNumberOfScores() end)
	if not force and cache.n == n and cache.data then return cache.data end
	local D = { ["4K"] = newMode(), ["7K"] = newMode() }
	local info = {} -- chart key -> { mode, steps, song }
	pcall(function() SCOREMAN:SortRecentScores() end)
	local i = 1
	while true do
		local ok, hs = pcall(function() return SCOREMAN:GetRecentScore(i) end)
		if not ok or not hs then break end
		i = i + 1
		local ck = hs:GetChartKey()
		local ci = info[ck]
		if not ci then
			ci = { mode = nil }
			local st = SONGMAN:GetStepsByChartKey(ck)
			if st then
				local t = tostring(st:GetStepsType())
				ci.mode = (t == "StepsType_Dance_Single" and "4K") or (t == "StepsType_Kb7_Single" and "7K") or nil
				ci.steps = st
				ci.song = SONGMAN:GetSongByChartKey(ck)
			end
			info[ck] = ci
		end
		local M = ci.mode and D[ci.mode]
		if M and ci.song then
			local e = {
				ck = ck, steps = ci.steps, song = ci.song, rate = hs:GetMusicRate(), wife = hs:GetWifeScore() * 100,
				ssr = hs:GetSkillsetSSR("Overall"), date = hs:GetDate(), grade = hs:GetWifeGrade(),
				valid = hs:GetEtternaValid() and not hs:GetChordCohesion(),
			}
			local secs = 0
			pcall(function() secs = hs:GetPlayedSeconds() or 0 end)
			M.plays = M.plays + 1
			M.secs = M.secs + secs
			M.recent[#M.recent + 1] = e
			-- per chart: plays, the last play (scores come newest first), the best accuracy
			local c = M.charts[ck]
			if not c then
				c = { ck = ck, steps = ci.steps, song = ci.song, count = 0, last = e.date, bestWife = -1, best = nil, rate = e.rate }
				M.charts[ck] = c
				M.chartList[#M.chartList + 1] = c
			end
			c.count = c.count + 1
			if e.wife > c.bestWife then c.bestWife, c.best, c.rate = e.wife, e, e.rate end
			-- personal bests per rate (what Etterna's rating counts)
			if e.valid and e.wife > 0 then
				local key = ck .. "@" .. string.format("%.2f", e.rate)
				local pb = M.pbs[key]
				if not pb or e.wife > pb.wife then
					e.ssrs = {}
					for k = 2, #SKILLS do e.ssrs[k] = hs:GetSkillsetSSR(SKILLS[k]) end
					M.pbs[key] = e
				end
			end
		end
	end
	for _, M in pairs(D) do
		-- top plays: each chart's best SSR among its personal bests
		local bestByChart = {}
		for _, e in pairs(M.pbs) do
			local b = bestByChart[e.ck]
			if not b or e.ssr > b.ssr then bestByChart[e.ck] = e end
		end
		for _, e in pairs(bestByChart) do M.top[#M.top + 1] = e end
		table.sort(M.top, function(a, b) return a.ssr > b.ssr end)
		M.best = M.top[1]
		-- skills
		for k = 2, #SKILLS do
			local v = {}
			for _, e in pairs(M.pbs) do v[#v + 1] = e.ssrs[k] or 0 end
			table.sort(v)
			M.skills[k] = aggregate(v)
		end
		local sum = 0
		for k = 2, #SKILLS do sum = sum + M.skills[k] end
		M.skills[1] = sum / (#SKILLS - 1)
		-- most played; grades and accuracy from each chart's best
		for _, c in ipairs(M.chartList) do M.most[#M.most + 1] = c end
		table.sort(M.most, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.last > b.last end)
		local accSum, accN = 0, 0
		for _, c in ipairs(M.chartList) do
			if c.best then
				local g = gradeClass(c.best.grade)
				M.grades[g] = M.grades[g] + 1
				accSum, accN = accSum + c.best.wife, accN + 1
			end
		end
		M.acc = accN > 0 and accSum / accN or 0
		M.chartCount = #M.chartList
	end
	-- 4K: Etterna's own numbers (the ones its other screens show)
	local p = profile()
	if p then
		pcall(function()
			D["4K"].skills[1] = p:GetPlayerRating()
			for k = 2, #SKILLS do D["4K"].skills[k] = p:GetPlayerSkillsetRating(SKILLS[k]) end
		end)
	end
	cache = { n = n, data = D }
	return D
end

-- ------------------------------------------------------------------------------------------------
-- EtternaOnline: asked through VSRG Hub (eo.go), which fetches it while the game runs. A request is
-- a line in Save/VSRGHub/eo/req.txt; its answer comes back as a Lua table in res-<slot>.lua.
-- ------------------------------------------------------------------------------------------------
local EODIR = "Save/VSRGHub/eo/"
local SLOTS = 24
local EO = { seq = 0, lines = {}, pending = {}, cache = {} }
do
	-- (after a look switch: go on from the last request, which VSRG Hub has already answered)
	local ok, txt = pcall(function() return File.Read(EODIR .. "req.txt") end)
	if ok and type(txt) == "string" then
		for n in txt:gmatch("(%d+)|") do EO.seq = math.max(EO.seq, tonumber(n)) end
	end
end
local function now() return try(function() return GetTimeSinceStart() end, 0) end
-- the answer to kind/arg: { state = "loading" / "ok" / "error", data, err }; asked again after
-- maxAge seconds
local function eo(kind, arg, maxAge)
	local key = kind .. "|" .. (arg or "")
	local c = EO.cache[key]
	if c and (c.state == "loading" or now() - c.at < (maxAge or 600)) then return c end
	EO.seq = EO.seq + 1
	local slot = (EO.seq - 1) % SLOTS + 1
	EO.lines[#EO.lines + 1] = EO.seq .. "|" .. slot .. "|" .. kind .. "|" .. (arg or "")
	while #EO.lines > SLOTS do table.remove(EO.lines, 1) end
	pcall(function() File.Write(EODIR .. "req.txt", table.concat(EO.lines, "\n") .. "\n") end)
	local nc = { state = "loading", at = now(), data = c and c.data }
	EO.cache[key] = nc
	EO.pending[#EO.pending + 1] = { seq = EO.seq, slot = slot, key = key, asked = now() }
	return nc
end
-- answers that came in since the last look (true when one did)
local function eoPoll()
	local got = false
	for i = #EO.pending, 1, -1 do
		local p = EO.pending[i]
		local txt = try(function() return File.Read(string.format("%sres-%02d.lua", EODIR, p.slot)) end)
		if txt and txt:find("%-%-end" .. p.seq .. "%s*$") then
			table.remove(EO.pending, i)
			local f = loadstring(txt)
			local ok, r = false, nil
			if f then ok, r = pcall(f) end
			local c = EO.cache[p.key] or {}
			if ok and type(r) == "table" and r.ok then c.state, c.data, c.err = "ok", r.data, nil
			else c.state, c.err = "error", (ok and type(r) == "table" and r.err) or "no answer" end
			c.at = now()
			EO.cache[p.key] = c
			got = true
		elseif now() - p.asked > 300 then
			-- (no answer: VSRG Hub isn't running alongside, or EtternaOnline is down)
			table.remove(EO.pending, i)
			local c = EO.cache[p.key] or {}
			c.state, c.err, c.at = "error", "EtternaOnline didn't answer (is the game started from VSRG Hub?)", now()
			EO.cache[p.key] = c
			got = true
		end
	end
	return got
end
local function eoName()
	local n = nil
	pcall(function() if DLMAN:IsLoggedIn() then n = DLMAN:GetUsername() end end)
	if n == "" then n = nil end
	return n
end
-- Logging in to EtternaOnline, in every look (Etterna's own login, DLMAN:Login, from the profile
-- page). The session is kept in Save/VSRGHub/online.ini (the name and Etterna's session token, as
-- Til' Death keeps them), so the next start logs in again by itself, whichever look it is in;
-- Log out forgets it.
local LOGINFILE = "Save/VSRGHub/online.ini"
local function savedLogin()
	local txt = try(function() return File.Read(LOGINFILE) end, "") or ""
	return { user = txt:match("user=([^\r\n]*)") or "", token = txt:match("token=([^\r\n]*)") or "" }
end
local function saveLogin(user, token)
	pcall(function() File.Write(LOGINFILE, "user=" .. (user or "") .. "\ntoken=" .. (token or "") .. "\n") end)
end
-- (Til' Death and Rebirth keep their own copy, and log in with it: theirs is cleared on Log out)
local function forgetThemeLogin()
	pcall(function()
		local slot = pn_to_profile_slot(PLAYER_1)
		local d = playerConfig:get_data(slot)
		if d.PasswordToken ~= nil then
			d.UserName, d.PasswordToken = "", ""
			playerConfig:set_dirty(slot)
			playerConfig:save(slot)
		end
	end)
end
local function autoLogin()
	if TWAutoLoginTried then return end
	TWAutoLoginTried = true
	local logged = false
	pcall(function() logged = DLMAN:IsLoggedIn() end)
	if logged then return end
	local s = savedLogin()
	if s.token ~= "" then pcall(function() DLMAN:LoginWithToken(s.user, s.token) end) end
end
-- the login box over the page: { field = 1 / 2, user, pass, busy, msg, clip }
local loginForm = nil

-- EtternaOnline's grades as Etterna's
local function eoGrade(g)
	g = (g or ""):upper()
	if g:find("^F") then return "Grade_Failed" end
	local a = select(2, g:gsub("A", ""))
	local suf = g:match("A([:%.]?)$") or ""
	local tiers = { [5] = { "", 1 }, [4] = { 4, 2, 3 }, [3] = { 7, 5, 6 }, [2] = { 10, 8, 9 }, [1] = { 13, 11, 12 } }
	local t
	if a >= 5 then t = 1
	elseif a >= 1 then local r = tiers[a]; t = (suf == ":" and r[2]) or (suf == "." and r[3]) or r[1]
	elseif g:find("^B") then t = 14 elseif g:find("^C") then t = 15 else t = 16 end
	return string.format("Grade_Tier%02d", t)
end
-- an online profile in the shape of the local one (TWProfileData)
local ONLINE_SKILL = { 2, 3, 4, 5, 6, 7, 8 } -- EtternaOnline's order (stream ... technical) in SKILLS
local onlineCache = {}
-- a player's online scores, a page (200) at a time, newest first: the pages in so far, and how
-- the rest is going ({ state, data = pages, err, loaded, pages })
local function onlineScores(name)
	local p1 = eo("scores", name .. "|1")
	if not p1.data then return { state = p1.state, err = p1.err, loaded = 0, pages = 0 } end
	local pages = math.min(p1.data.pages or 1, 60)
	local parts = { p1.data }
	local sc = { state = "ok", data = parts, loaded = 1, pages = pages }
	for p = 2, pages do
		-- (one page at a time, in order: the next is asked for once the one before is in)
		local c = eo("scores", name .. "|" .. p)
		if not c.data then
			sc.state, sc.err = c.state == "error" and "partial" or "loading", c.err
			break
		end
		parts[#parts + 1] = c.data
		sc.loaded = p
	end
	return sc
end
local function onlineData(name)
	local us, sc = eo("user", name), onlineScores(name)
	local key = name:lower()
	local oc = onlineCache[key]
	local sig = tostring(us.data) .. "|" .. sc.loaded .. "|" .. tostring(sc.data and sc.data[1])
	if oc and oc.sig == sig and oc.data then return oc.data, us, sc end
	local D = { ["4K"] = newMode(), ["7K"] = newMode() }
	D.user = us.data
	local all = {}
	for _, part in ipairs(sc.data or {}) do for _, x in ipairs(part.list or {}) do all[#all + 1] = x end end
	for _, s in ipairs(all) do
		local M = (s.keys == 4 and D["4K"]) or (s.keys == 7 and D["7K"]) or nil
		if M then
			local e = { ck = s.ck, rate = s.rate, wife = s.wife, ssr = s.ssr, date = s.date, grade = eoGrade(s.grade), valid = s.valid,
				title = s.title, artist = s.artist, diffName = s.diff, msd = s.msd, ssrs = {} }
			e.song = try(function() return SONGMAN:GetSongByChartKey(s.ck) end)
			e.steps = try(function() return SONGMAN:GetStepsByChartKey(s.ck) end)
			for i, k in ipairs(ONLINE_SKILL) do e.ssrs[k] = s.s and s.s[i] or 0 end
			M.plays = M.plays + 1
			M.recent[#M.recent + 1] = e
			local c = M.charts[s.ck]
			if not c then
				c = { ck = s.ck, steps = e.steps, song = e.song, title = e.title, artist = e.artist, diffName = e.diffName, msd = e.msd,
					count = 0, last = e.date, bestWife = -1, best = nil, rate = e.rate }
				M.charts[s.ck] = c
				M.chartList[#M.chartList + 1] = c
			end
			c.count = c.count + 1
			if e.wife > c.bestWife then c.bestWife, c.best, c.rate = e.wife, e, e.rate end
			if e.valid and e.wife > 0 then
				local k = s.ck .. "@" .. string.format("%.2f", e.rate)
				if not M.pbs[k] or e.wife > M.pbs[k].wife then M.pbs[k] = e end
			end
		end
	end
	for _, M in pairs({ D["4K"], D["7K"] }) do
		local bestByChart = {}
		for _, e in pairs(M.pbs) do
			local b = bestByChart[e.ck]
			if not b or e.ssr > b.ssr then bestByChart[e.ck] = e end
		end
		for _, e in pairs(bestByChart) do M.top[#M.top + 1] = e end
		table.sort(M.top, function(a, b) return a.ssr > b.ssr end)
		M.best = M.top[1]
		for k = 2, #SKILLS do
			local v = {}
			for _, e in pairs(M.pbs) do v[#v + 1] = e.ssrs[k] or 0 end
			table.sort(v)
			M.skills[k] = aggregate(v)
		end
		local sum = 0
		for k = 2, #SKILLS do sum = sum + M.skills[k] end
		M.skills[1] = sum / (#SKILLS - 1)
		for _, c in ipairs(M.chartList) do M.most[#M.most + 1] = c end
		table.sort(M.most, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.last > b.last end)
		local accSum, accN = 0, 0
		for _, c in ipairs(M.chartList) do
			if c.best then
				local g = gradeClass(c.best.grade)
				M.grades[g] = M.grades[g] + 1
				accSum, accN = accSum + c.best.wife, accN + 1
			end
		end
		M.acc = accN > 0 and accSum / accN or 0
		M.chartCount = #M.chartList
	end
	-- 4K: EtternaOnline's own rating
	if us.data then
		D["4K"].skills[1] = us.data.overall or D["4K"].skills[1]
		for i, k in ipairs(ONLINE_SKILL) do D["4K"].skills[k] = us.data.skills and us.data.skills[i] or D["4K"].skills[k] end
	end
	onlineCache[key] = { sig = sig, data = D }
	return D, us, sc
end

-- formatting
local function fmtTime(s)
	s = math.floor(s or 0)
	local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
	if h > 0 then return string.format("%dh %02dm", h, m) end
	return string.format("%dm", m)
end
local function fmtInt(n)
	local s = tostring(math.floor(n or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local function parseDate(d)
	local y, mo, da, h, mi, se = (d or ""):match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
	if not y then return nil end
	return { year = tonumber(y), month = tonumber(mo), day = tonumber(da), hour = tonumber(h), min = tonumber(mi), sec = tonumber(se) }
end
local function fmtAgo(d)
	local t = parseDate(d)
	if not t then return d or "" end
	local ok, then_ = pcall(os.time, t)
	local ok2, now = pcall(os.time)
	if not (ok and ok2 and then_ and now) then return string.format("%04d-%02d-%02d", t.year, t.month, t.day) end
	local s = now - then_
	if s < 60 then return "just now" elseif s < 3600 then return math.floor(s / 60) .. "m ago"
	elseif s < 86400 then return math.floor(s / 3600) .. "h ago" elseif s < 86400 * 30 then return math.floor(s / 86400) .. "d ago" end
	return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end
local function up(s) if S.upper then return s:upper() end return s end

-- ------------------------------------------------------------------------------------------------
-- the page
-- ------------------------------------------------------------------------------------------------
local open = false
local tab = "overview"
local mode = "4K"
local first = 1
local skill = 1 -- top plays: which skillset ranks them
local SHORT = { "Overall", "Stream", "JS", "HS", "Stamina", "Jack", "CJ", "Tech" }
local regions = {}
local page -- the frame
local TABS = { { "overview", "Overview" }, { "top", "Top plays" }, { "recent", "Recent plays" }, { "most", "Most played" } }
-- your plays here (local) or on EtternaOnline (online: anyone's, and the rankings)
local source = "local"
local who = nil -- the online player shown (nil: you)
local rankKind = "world" -- Rankings: the world or a country
local query = "" -- Rankings: a name being typed, to look that player up
local TABS_ONLINE = { TABS[1], TABS[2], TABS[3], TABS[4], { "rank", "Rankings" } }
local function tabs() return source == "online" and TABS_ONLINE or TABS end
local HEAD, TABH = 168 * u, 48 * u
local CY = HEAD + TABH + 18 * u
local ROWH = 54 * u
local LISTN = math.max(4, math.floor((SCREEN_HEIGHT - CY - 26 * u - 50 * u) / ROWH))

-- text px tall (the look's font measured once, so every look's text comes out the same size)
-- (the themes' fonts draw their letters large for their line height: px is about the cap height
-- plus a little, measured against the game)
-- big text (the rating, your name) takes a sharper copy of the font when there is one: VSRG Hub's
-- own looks have them (TW.fontBig), Til' Death and Rebirth get VSRG Hub's copy of their Open Sans
local function bigFont(name)
	if TW and TW.fontBig and TW.fontBig[name] then return TW.fontBig[name] end
	if name == "Common Normal" then
		local ok, path = pcall(function() return THEME:GetPathF("", "_vhx sans", true) end)
		if ok and path and path ~= "" then return "_vhx sans" end
	end
	return nil
end
local function T(px, bold, init)
	local font = bold and S.bold or S.font
	-- (px on screen, about: the big copy once it is larger than the normal font's letters)
	local dh = 720
	pcall(function() dh = DISPLAY:GetDisplayHeight() end)
	if px * dh / 720 > 44 then font = bigFont(font) or font end
	return LoadFont(font) .. {
		InitCommand = function(self)
			self:settext("Ag")
			local h = self:GetHeight()
			if not h or h <= 0 then h = 24 end
			self:zoom(px * u * (S.fscale or 0.72) / h):halign(0):settext("")
			pcall(function() self:shadowlength(0) end)
			if init then init(self) end
		end,
	}
end
local function Q(name, init) return Def.Quad { Name = name, InitCommand = function(self) self:align(0, 0); if init then init(self) end end } end

local function region(x0, y0, x1, y1, fn) regions[#regions + 1] = { x0, y0, x1, y1, fn } end

-- a row of a list: banner, title, chart, numbers
local COLS = { rank = 0, banner = 44, title = 210, diff = 640, rate = 770, acc = 860, grade = 960, ssr = 1050, date = 1216 }
local function rowActor(name)
	return Def.ActorFrame {
		Name = name,
		Q("Bg"),
		Q("Hl", function(self) self:diffuse(S.accent) end),
		T(15, true, function(self) self:align(0.5, 0.5) end) .. { Name = "Rank" },
		Q("BannerBg", function(self) self:diffuse(S.chip) end),
		Def.Sprite { Name = "Banner" },
		T(18, true, function(self) self:align(0, 0.5) end) .. { Name = "Title" },
		T(13, false, function(self) self:align(0, 0.5) end) .. { Name = "Sub" },
		Q("DiffBg"),
		T(13, true, function(self) self:align(0.5, 0.5) end) .. { Name = "Diff" },
		T(15, true, function(self) self:align(0, 0.5) end) .. { Name = "Msd" },
		T(15, false, function(self) self:align(0, 0.5) end) .. { Name = "Rate" },
		T(17, true, function(self) self:align(0, 0.5) end) .. { Name = "Acc" },
		T(17, true, function(self) self:align(0, 0.5) end) .. { Name = "Grade" },
		T(17, true, function(self) self:align(0, 0.5) end) .. { Name = "Ssr" },
		T(13, false, function(self) self:align(1, 0.5) end) .. { Name = "Date" },
	}
end
-- fill a row: kind "score" (a play) or "chart" (most played), w its width, compact for Overview
local function fillRow(a, e, kind, rank, x, y, w, compact)
	a:visible(e ~= nil):xy(x, y)
	if not e then return end
	local c = a:GetChildren()
	local h = ROWH - 6 * u
	c.Bg:zoomto(w, h):diffuse(rank % 2 == 1 and S.row or alpha(S.row, (S.row[4] or 1) * 0.5))
	c.Hl:zoomto(3 * u, h):visible(LOOK == "quaver")
	local cx = function(k) return COLS[k] * u * (w / (1216 * u)) end
	if compact then cx = function(k) local m = { rank = 0, banner = 10, title = 140, diff = 0, rate = 0, acc = w / u - 300, grade = w / u - 210, ssr = w / u - 150, date = w / u - 8 } return m[k] * u end end
	c.Rank:visible(not compact):xy(cx("rank") + 20 * u, h / 2):settext(rank):diffuse(S.dim)
	local bw, bh = (compact and 120 or 150) * u, h - 8 * u
	c.BannerBg:xy(cx("banner"), 4 * u):zoomto(bw, bh)
	local song = e.song
	local path = song and (try(function() return song:GetBannerPath() end) or try(function() return song:GetBackgroundPath() end) or try(function() return song:GetJacketPath() end))
	if path then
		c.Banner:visible(true)
		pcall(function() c.Banner:Load(path) end)
		pcall(function() c.Banner:scaletoclipped(bw, bh) end)
		c.Banner:xy(cx("banner") + bw / 2, 4 * u + bh / 2)
	else
		c.Banner:visible(false)
	end
	local tx = cx("banner") + bw + 14 * u
	local titleW = (compact and (cx("acc") - tx - 12 * u)) or (cx("diff") - tx - 16 * u)
	-- (an online play of a chart you don't have: EtternaOnline's names and MSD)
	c.Title:xy(tx, h * 0.34):settext(song and song:GetDisplayMainTitle() or e.title or "?"):diffuse(S.text):maxwidth(titleW / c.Title:GetZoom())
	local st = e.steps
	local diffName = st and DIFF[st:GetDifficulty()] or e.diffName or ""
	local msd = st and try(function() return st:GetMSD(e.rate or 1, 1) end, 0) or (e.msd or 0)
	local sub = song and song:GetDisplayArtist() or e.artist or ""
	if compact then sub = string.format("%s  ·  %s %.2f  ·  %.2fx", sub, diffName, msd, e.rate or 1) end
	c.Sub:xy(tx, h * 0.7):settext(sub):diffuse(S.dim):maxwidth(titleW / c.Sub:GetZoom())
	-- chart: difficulty and MSD at the play's rate
	c.DiffBg:visible(not compact):xy(cx("diff"), h / 2 - 11 * u):zoomto(70 * u, 22 * u):diffuse(alpha(st and diffColour(st:GetDifficulty()) or S.dim, 0.9))
	c.Msd:visible(not compact)
	c.Rate:visible(not compact)
	c.Diff:visible(not compact):xy(cx("diff") + 35 * u, h / 2):settext(diffName):diffuse(rgb(15, 15, 20)):maxwidth(64 * u / c.Diff:GetZoom())
	c.Msd:visible(not compact):xy(cx("diff") + 78 * u, h / 2):settext(string.format("%.2f", msd)):diffuse(msdColour(msd))
	c.Rate:visible(not compact):xy(cx("rate"), h / 2):settext(string.format("%.2fx", e.rate or 1)):diffuse(S.text)
	local play = kind == "chart" and e.best or e
	if kind == "chart" then
		c.Acc:xy(cx("acc"), h / 2):settext("x" .. e.count):diffuse(S.accentText)
		c.Grade:xy(cx("grade"), h / 2):settext(play and string.format("%.2f%%", play.wife) or "")
			:diffuse(play and gradeColour(play.grade) or S.dim)
		c.Ssr:xy(cx("ssr"), h / 2):settext(play and gradeName(play.grade) or ""):diffuse(play and gradeColour(play.grade) or S.dim)
		c.Date:xy(cx("date"), h / 2):settext(fmtAgo(e.last)):diffuse(S.dim)
	else
		c.Acc:xy(cx("acc"), h / 2):settext(string.format("%.2f%%", e.wife)):diffuse(gradeColour(e.grade))
		c.Grade:xy(cx("grade"), h / 2):settext(gradeName(e.grade)):diffuse(gradeColour(e.grade))
		local v = e.ssr or 0
		if tab == "top" and skill > 1 and e.ssrs then v = e.ssrs[skill] or 0 end
		c.Ssr:xy(cx("ssr"), h / 2):settext(string.format("%.2f", v)):diffuse(msdColour(v))
		c.Date:xy(cx("date"), h / 2):settext(fmtAgo(e.date)):diffuse(S.dim)
	end
	-- (every column stays inside its own room, whatever the look's font)
	local gap = 8 * u
	c.Acc:maxwidth(math.max(10, cx("grade") - cx("acc") - gap) / c.Acc:GetZoom())
	c.Grade:maxwidth(math.max(10, cx("ssr") - cx("grade") - gap) / c.Grade:GetZoom())
	local dateW = (compact and 72 or 90) * u
	c.Ssr:maxwidth(math.max(10, cx("date") - dateW - cx("ssr") - gap) / c.Ssr:GetZoom())
	c.Date:maxwidth(dateW / c.Date:GetZoom())
end

local t = Def.ActorFrame {
	Name = "TWProfilePage",
	InitCommand = function(self)
		page = self
		self:visible(false)
		-- EtternaOnline's answers, as they come in
		self:SetUpdateFunction(function(s)
			if open and #EO.pending > 0 and eoPoll() then
				-- (Ctrl+V in the login box: the clipboard's text, into the field, then forgotten)
				local f = loginForm
				local cc = f and f.clip and EO.cache[f.clip]
				if cc and cc.state ~= "loading" then
					if cc.state == "ok" and type(cc.data) == "string" then
						local txt = cc.data:gsub("[\r\n\t]", "")
						if f.field == 1 then f.user = (f.user .. txt):sub(1, 128) else f.pass = (f.pass .. txt):sub(1, 128) end
					end
					EO.cache[f.clip] = nil
					f.clip = nil
				end
				s:playcommand("Render")
			end
		end)
		self:SetUpdateFunctionInterval(0.25)
	end,
	ScreenChangedMessageCommand = function(self) if open then TWCloseProfile() end end,
	-- logged in (here or with the theme's own login): kept for the next start
	LoginMessageCommand = function(self)
		pcall(function() saveLogin(DLMAN:GetUsername(), DLMAN:GetToken()) end)
		if loginForm then
			loginForm = nil
			source, who, tab, first = "online", nil, "overview", 1
		end
		onlineCache = {}
		if open then self:playcommand("Render") end
	end,
	LoginFailedMessageCommand = function(self, p)
		if not loginForm then return end
		loginForm.busy = false
		loginForm.field = 2
		loginForm.msg = "Couldn't log in: " .. tostring(p and p.why or "unknown reason")
		if open then self:playcommand("Render") end
	end,
	TWProfileOpenMessageCommand = function(self) self:visible(true):stoptweening():diffusealpha(0):linear(0.12):diffusealpha(1):playcommand("Render") end,
	TWProfileCloseMessageCommand = function(self) self:stoptweening():linear(0.1):diffusealpha(0):queuecommand("Hide") end,
	HideCommand = function(self) self:visible(false) end,
	-- the page
	Q("Dim", function(self) self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(rgb(0, 0, 0, 0.75)) end),
	Q("Bg", function(self) self:x(X0):zoomto(W, SCREEN_HEIGHT):diffuse(S.bg) end),
	-- header: the cover (your last chart's background), avatar, name, ratings
	Def.Sprite { Name = "Cover" },
	Q("CoverShade", function(self) self:x(X0):zoomto(W, HEAD):diffuse(alpha(S.head, 0.55)):diffusebottomedge(S.bg) end),
	Q("AvatarBg", function(self) self:xy(X0 + PAD, 28 * u):zoomto(112 * u, 112 * u):diffuse(S.chip) end),
	Def.Sprite { Name = "Avatar" },
	T(38, true, function(self) self:xy(X0 + PAD + 136 * u, 58 * u):align(0, 0.5):diffuse(S.text) end) .. { Name = "Name" },
	T(15, false, function(self) self:xy(X0 + PAD + 138 * u, 92 * u):align(0, 0.5):diffuse(S.dim) end) .. { Name = "Sub" },
	T(15, true, function(self) self:xy(X0 + PAD + 138 * u, 120 * u):align(0, 0.5):diffuse(S.accentText) end) .. { Name = "Online" },
	T(14, true, function(self) self:xy(X0 + W - PAD, 46 * u):align(1, 0.5):diffuse(S.dim) end) .. { Name = "RatingLabel" },
	T(58, true, function(self) self:xy(X0 + W - PAD, 92 * u):align(1, 0.5) end) .. { Name = "Rating" },
	T(15, false, function(self) self:xy(X0 + W - PAD, 134 * u):align(1, 0.5):diffuse(S.dim) end) .. { Name = "OtherRating" },
	-- tab bar
	Q("TabBg", function(self) self:xy(X0, HEAD):zoomto(W, TABH):diffuse(S.tab) end),
}
for i, tb in ipairs(TABS_ONLINE) do
	t[#t + 1] = Def.ActorFrame {
		Name = "Tab" .. i,
		Q("Bg", function(self) self:diffuse(LOOK == "quaver" and rgb(36, 48, 48) or alpha(S.accent, 0)) end),
		Q("Bar", function(self) self:diffuse(S.accent) end),
		T(17, true, function(self) self:align(0.5, 0.5) end) .. { Name = "Label" },
	}
end
for _, m in ipairs({ "4K", "7K" }) do
	t[#t + 1] = Def.ActorFrame {
		Name = "Mode" .. m,
		Q("Bg"),
		T(16, true, function(self) self:align(0.5, 0.5):settext(m) end) .. { Name = "Label" },
	}
end
t[#t + 1] = T(14, false, function(self) self:align(1, 0.5):diffuse(S.dim) end) .. { Name = "Hint" }
for _, n in ipairs({ "SrcLocal", "SrcOnline", "BackToMe", "LoginChip", "RkWorld", "RkCountry" }) do
	t[#t + 1] = Def.ActorFrame {
		Name = n,
		Q("Bg"),
		T(13, true, function(self) self:align(0.5, 0.5) end) .. { Name = "Label" },
	}
end
for k = 1, #SKILLS do
	t[#t + 1] = Def.ActorFrame {
		Name = "Filter" .. k,
		Q("Bg"),
		T(13, true, function(self) self:align(0.5, 0.5) end) .. { Name = "Label" },
	}
end
-- overview: the skills card
t[#t + 1] = Q("SkillCard", function(self) self:diffuse(S.card) end)
t[#t + 1] = T(20, true, function(self) self:align(0, 0.5) end) .. { Name = "SkillTitle" }
t[#t + 1] = T(13, false, function(self) self:align(0, 0.5):diffuse(S.dim) end) .. { Name = "SkillSub" }
for k = 1, #SKILLS do
	t[#t + 1] = Def.ActorFrame {
		Name = "Skill" .. k,
		T(17, k == 1, function(self) self:align(0, 0.5) end) .. { Name = "Label" },
		Q("Track", function(self) self:diffuse(S.track) end),
		Q("Fill"),
		T(18, true, function(self) self:align(1, 0.5) end) .. { Name = "Value" },
	}
end
t[#t + 1] = T(15, true, function(self) self:align(0, 0.5) end) .. { Name = "GradeTitle" }
for g = 1, 6 do
	t[#t + 1] = Def.ActorFrame {
		Name = "Grade" .. g,
		Q("Bg", function(self) self:diffuse(S.chip) end),
		T(15, true, function(self) self:align(0.5, 0.5) end) .. { Name = "Label" },
		T(19, true, function(self) self:align(0.5, 0.5) end) .. { Name = "Value" },
	}
end
-- overview: tiles
for i = 1, 8 do
	t[#t + 1] = Def.ActorFrame {
		Name = "Tile" .. i,
		Q("Bg", function(self) self:diffuse(S.card) end),
		Q("Bar", function(self) self:diffuse(S.accent) end),
		T(13, false, function(self) self:align(0, 0.5):diffuse(S.dim) end) .. { Name = "Label" },
		T(25, true, function(self) self:align(0, 0.5) end) .. { Name = "Value" },
	}
end
t[#t + 1] = T(20, true, function(self) self:align(0, 0.5) end) .. { Name = "MiniTitle" }
t[#t + 1] = T(13, false, function(self) self:align(1, 0.5):diffuse(S.dim) end) .. { Name = "MiniMore" }
for i = 1, 4 do t[#t + 1] = rowActor("Mini" .. i) end
-- lists
t[#t + 1] = Q("ListHead", function(self) self:diffuse(S.chip) end)
for _, k in ipairs({ "rank", "title", "diff", "rate", "acc", "grade", "ssr", "date" }) do
	t[#t + 1] = T(12, true, function(self) self:align(k == "date" and 1 or 0, 0.5):diffuse(S.dim) end) .. { Name = "Col_" .. k }
end
for i = 1, LISTN do t[#t + 1] = rowActor("Row" .. i) end
t[#t + 1] = T(16, false, function(self) self:align(0.5, 0.5):diffuse(S.dim) end) .. { Name = "Empty" }
t[#t + 1] = Def.ActorFrame {
	Name = "Pager",
	Q("PrevBg", function(self) self:diffuse(S.chip) end),
	Q("NextBg", function(self) self:diffuse(S.chip) end),
	T(18, true, function(self) self:align(0.5, 0.5):settext("<") end) .. { Name = "Prev" },
	T(18, true, function(self) self:align(0.5, 0.5):settext(">") end) .. { Name = "Next" },
	T(14, false, function(self) self:align(0.5, 0.5):diffuse(S.dim) end) .. { Name = "Label" },
}
-- the login box (over everything on the page)
local LW, LH = 520 * u, 300 * u
local LX, LY = (SCREEN_WIDTH - LW) / 2, (SCREEN_HEIGHT - LH) / 2
t[#t + 1] = Def.ActorFrame {
	Name = "Login",
	Q("Dim", function(self) self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(rgb(0, 0, 0, 0.6)) end),
	Q("Edge", function(self) self:xy(LX - 2 * u, LY - 2 * u):zoomto(LW + 4 * u, LH + 4 * u):diffuse(S.accent) end),
	Q("Bg", function(self) self:xy(LX, LY):zoomto(LW, LH):diffuse(mix(S.bg, { 0, 0, 0, 1 }, 0.2)) end),
	T(22, true, function(self) self:xy(LX + 24 * u, LY + 32 * u):align(0, 0.5):diffuse(S.text) end) .. { Name = "Title" },
	T(13, false, function(self) self:xy(LX + 24 * u, LY + 58 * u):align(0, 0.5):diffuse(S.dim) end) .. { Name = "Help" },
	T(14, true, function(self) self:xy(LX + 24 * u, LY + 96 * u):align(0, 0.5):diffuse(S.dim) end) .. { Name = "L1" },
	Q("F1", function(self) self:xy(LX + 24 * u, LY + 110 * u):zoomto(LW - 48 * u, 36 * u) end),
	T(17, false, function(self) self:xy(LX + 36 * u, LY + 128 * u):align(0, 0.5):diffuse(S.text) end) .. { Name = "V1" },
	T(14, true, function(self) self:xy(LX + 24 * u, LY + 166 * u):align(0, 0.5):diffuse(S.dim) end) .. { Name = "L2" },
	Q("F2", function(self) self:xy(LX + 24 * u, LY + 180 * u):zoomto(LW - 48 * u, 36 * u) end),
	T(17, false, function(self) self:xy(LX + 36 * u, LY + 198 * u):align(0, 0.5):diffuse(S.text) end) .. { Name = "V2" },
	T(13, false, function(self) self:xy(LX + 24 * u, LY + 236 * u):align(0, 0.5) end) .. { Name = "Msg" },
	Q("OkBg", function(self) self:xy(LX + LW - 284 * u, LY + LH - 46 * u):zoomto(126 * u, 32 * u):diffuse(S.accent) end),
	T(15, true, function(self) self:xy(LX + LW - 221 * u, LY + LH - 30 * u):align(0.5, 0.5) end) .. { Name = "Ok" },
	Q("CancelBg", function(self) self:xy(LX + LW - 150 * u, LY + LH - 46 * u):zoomto(126 * u, 32 * u):diffuse(S.chip) end),
	T(15, true, function(self) self:xy(LX + LW - 87 * u, LY + LH - 30 * u):align(0.5, 0.5):diffuse(S.text) end) .. { Name = "Cancel" },
}

-- ------------------------------------------------------------------------------------------------
-- drawing
-- ------------------------------------------------------------------------------------------------
-- top plays ranked by one skillset: each chart's personal best with the highest SSR in it
local function topFor(M)
	if skill == 1 then return M.top end
	M.topBy = M.topBy or {}
	if not M.topBy[skill] then
		local best, list = {}, {}
		for _, e in pairs(M.pbs) do
			local b = best[e.ck]
			if not b or (e.ssrs[skill] or 0) > (b.ssrs[skill] or 0) then best[e.ck] = e end
		end
		for _, e in pairs(best) do list[#list + 1] = e end
		table.sort(list, function(a, b) return (a.ssrs[skill] or 0) > (b.ssrs[skill] or 0) end)
		M.topBy[skill] = list
	end
	return M.topBy[skill]
end
local function listFor(M)
	if tab == "top" then return topFor(M), "score" elseif tab == "recent" then return M.recent, "score" end
	return M.most, "chart"
end
-- a player in the rankings: place, country, name, rating and their best skillsets
local SK_NAMES = { "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical" }
local function fillUser(a, e, x, y, w, shown)
	a:visible(e ~= nil):xy(x, y)
	if not e then return end
	local c = a:GetChildren()
	local h = ROWH - 6 * u
	c.Bg:zoomto(w, h):diffuse(shown and S.rowOn or (e.rank % 2 == 1 and S.row or alpha(S.row, (S.row[4] or 1) * 0.5)))
	c.Hl:zoomto(3 * u, h):visible(LOOK == "quaver" or shown)
	local cx = function(k) return COLS[k] * u * (w / (1216 * u)) end
	c.Rank:visible(true):xy(cx("rank") + 20 * u, h / 2):settext(fmtInt(e.rank)):diffuse(S.dim):maxwidth(40 * u / c.Rank:GetZoom())
	c.Banner:visible(false)
	c.BannerBg:xy(cx("banner"), 4 * u):zoomto(60 * u, h - 8 * u)
	c.DiffBg:visible(false)
	c.Diff:visible(true):xy(cx("banner") + 30 * u, h / 2):settext(e.country ~= "" and e.country or "-"):diffuse(S.text):maxwidth(54 * u / c.Diff:GetZoom())
	local tx = cx("banner") + 76 * u
	c.Title:xy(tx, h * 0.34):settext(e.name):diffuse(S.text):maxwidth((cx("acc") - tx - 16 * u) / c.Title:GetZoom())
	-- (their three best skillsets)
	local order = {}
	for i = 1, 7 do order[i] = i end
	table.sort(order, function(p, q) return (e.skills[p] or 0) > (e.skills[q] or 0) end)
	local best = {}
	for i = 1, 3 do best[i] = string.format("%s %.2f", SK_NAMES[order[i]], e.skills[order[i]] or 0) end
	c.Sub:xy(tx, h * 0.7):settext(table.concat(best, "  ·  ")):diffuse(S.dim):maxwidth((cx("acc") - tx - 16 * u) / c.Sub:GetZoom())
	c.Msd:visible(false)
	c.Rate:visible(false)
	c.Acc:xy(cx("acc"), h / 2):settext(string.format("%.2f", e.overall)):diffuse(msdColour(e.overall)):maxwidth((cx("grade") - cx("acc")) / c.Acc:GetZoom())
	c.Grade:xy(cx("grade"), h / 2):settext(string.format("%.2f", e.skills[order[1]] or 0)):diffuse(SKILL_COL[order[1] + 1])
		:maxwidth((cx("ssr") - cx("grade")) / c.Grade:GetZoom())
	c.Ssr:xy(cx("ssr"), h / 2):settext(SK_NAMES[order[1]]):diffuse(S.dim):maxwidth((cx("date") - 100 * u - cx("ssr")) / c.Ssr:GetZoom())
	c.Date:xy(cx("date"), h / 2):settext("profile  >"):diffuse(S.accentText)
end
local function renderRankings(c, myCountry)
	local hy = CY - 6 * u
	local CW = W - 2 * PAD
	c.ListHead:xy(X0 + PAD, hy):zoomto(CW, 26 * u)
	local cols = { rank = "#", title = "Player", diff = "", rate = "", acc = "Rating", grade = "Best", ssr = "Skillset", date = "" }
	for k, label in pairs(cols) do
		local cx = (k == "title" and COLS.banner or COLS[k]) * u
		if k == "rank" then cx = 8 * u end
		c["Col_" .. k]:xy(X0 + PAD + cx, hy + 13 * u):settext(up(label))
	end
	local total, at, status = 0, nil, nil
	local country = rankKind == "country"
	if country then
		if not myCountry then
			status = "Your country isn't known yet (log in to EtternaOnline, or open a player's profile)"
		else
			local r = eo("country", myCountry, 3600)
			if r.data then
				total = #r.data.users
				at = function(i) return r.data.users[i] end
			end
			if r.state == "loading" and not r.data then status = "Loading the " .. myCountry .. " rankings (the first time takes a while)..." end
			if r.state == "error" and not r.data then status = "EtternaOnline: " .. (r.err or "no answer") end
		end
	else
		local p1 = eo("board", "1", 600)
		if p1.data then
			total = p1.data.total or 0
			at = function(i)
				local pg = math.floor((i - 1) / 50) + 1
				local r = pg == 1 and p1 or eo("board", tostring(pg), 600)
				return r.data and r.data.users[(i - 1) % 50 + 1] or nil
			end
		end
		if p1.state == "loading" and not p1.data then status = "Loading the world rankings..." end
		if p1.state == "error" and not p1.data then status = "EtternaOnline: " .. (p1.err or "no answer") end
	end
	first = math.max(1, math.min(first, math.max(1, total - LISTN + 1)))
	local shownName = (who or eoName() or ""):lower()
	for i = 1, LISTN do
		local idx = first + i - 1
		local e = (at and idx <= total) and at(idx) or nil
		local y = CY + 26 * u + (i - 1) * ROWH
		fillUser(c["Row" .. i], e, X0 + PAD, y, CW, e and e.name:lower() == shownName)
		if e then
			region(X0 + PAD, y, X0 + PAD + CW, y + ROWH - 6 * u, function() source = "online"; who = e.name; tab = "overview"; first = 1 end)
		end
	end
	if status or total == 0 then c.Empty:visible(true):xy(X0 + W / 2, CY + 140 * u):settext(status or "Nobody here yet") end
	-- pager
	local py = SCREEN_HEIGHT - 22 * u
	local pc = c.Pager:GetChildren()
	local px = X0 + W / 2
	pc.PrevBg:xy(px - 130 * u, py - 14 * u):zoomto(40 * u, 28 * u)
	pc.NextBg:xy(px + 90 * u, py - 14 * u):zoomto(40 * u, 28 * u)
	pc.Prev:xy(px - 110 * u, py):diffuse(first > 1 and S.text or S.dim)
	pc.Next:xy(px + 110 * u, py):diffuse(first + LISTN <= total and S.text or S.dim)
	pc.Label:xy(px, py):settext(string.format("%s - %s of %s", fmtInt(math.min(total, first)), fmtInt(math.min(total, first + LISTN - 1)), fmtInt(total)))
	region(px - 130 * u, py - 14 * u, px - 90 * u, py + 14 * u, function() first = math.max(1, first - LISTN) end)
	region(px + 90 * u, py - 14 * u, px + 130 * u, py + 14 * u, function() first = first + LISTN end)
end
-- the login box: your EtternaOnline name (or e-mail) and password, Etterna logs in with them
local loginRegions = {}
local drawLogin
local function submitLogin()
	local f = loginForm
	if not f or f.busy then return end
	local user = f.user:gsub("^%s+", ""):gsub("%s+$", "")
	if user == "" then f.field, f.msg = 1, "Type your EtternaOnline name or e-mail" return end
	if f.pass == "" then f.field, f.msg = 2, "Type your password" return end
	f.busy, f.msg = true, "Logging in..."
	f.user = user
	local pass = f.pass
	f.pass = ""
	f.passLen = #pass
	pcall(function() DLMAN:Login(user, pass) end)
	pass = nil
end
drawLogin = function(c)
	local L = c.Login
	loginRegions = {}
	local f = loginForm
	L:visible(f ~= nil)
	if not f then return end
	local lc = L:GetChildren()
	lc.Title:settext(up("Log in to EtternaOnline"))
	lc.Help:settext("Etterna logs in with it; next time it logs in by itself, in every look"):maxwidth((LW - 48 * u) / lc.Help:GetZoom())
	lc.L1:settext(up("Name or e-mail"))
	lc.L2:settext(up("Password"))
	local on1, on2 = f.field == 1 and not f.busy, f.field == 2 and not f.busy
	lc.F1:diffuse(on1 and alpha(S.accent, 0.35) or S.chip)
	lc.F2:diffuse(on2 and alpha(S.accent, 0.35) or S.chip)
	lc.V1:settext(f.user .. (on1 and "_" or "")):maxwidth((LW - 72 * u) / lc.V1:GetZoom())
	lc.V2:settext(string.rep("*", f.busy and (f.passLen or 0) or #f.pass) .. (on2 and "_" or "")):maxwidth((LW - 72 * u) / lc.V2:GetZoom())
	local bad = f.msg ~= "" and not f.busy
	lc.Msg:settext(f.msg ~= "" and f.msg or "Tab or Enter: next field   Ctrl+V pastes   Esc cancels")
		:diffuse(bad and rgb(255, 110, 110) or S.dim):maxwidth((LW - 48 * u) / lc.Msg:GetZoom())
	lc.Ok:settext(up(f.busy and "..." or "Log in")):diffuse((LOOK == "quaver" or LOOK == "rebirth") and rgb(15, 15, 20) or S.text)
	lc.Cancel:settext(up("Cancel"))
	local function r(x0, y0, x1, y1, fn) loginRegions[#loginRegions + 1] = { x0, y0, x1, y1, fn } end
	r(LX + 24 * u, LY + 110 * u, LX + LW - 24 * u, LY + 146 * u, function() f.field = 1 end)
	r(LX + 24 * u, LY + 180 * u, LX + LW - 24 * u, LY + 216 * u, function() f.field = 2 end)
	r(LX + LW - 284 * u, LY + LH - 46 * u, LX + LW - 158 * u, LY + LH - 14 * u, submitLogin)
	r(LX + LW - 150 * u, LY + LH - 46 * u, LX + LW - 24 * u, LY + LH - 14 * u, function() loginForm = nil end)
end
t.RenderCommand = function(self)
	if not open then return end
	regions = {}
	local c = self:GetChildren()
	local online = source == "online"
	local oname = online and (who or eoName()) or nil
	local D, us, sc
	if online and oname then D, us, sc = onlineData(oname)
	elseif online then D = { ["4K"] = newMode(), ["7K"] = newMode() }
	else D = TWProfileData() end
	local M = D[mode]
	local p = profile()
	if tab == "rank" and not online then tab = "overview" end
	-- header
	local last = D["4K"].recent[1] or D["7K"].recent[1]
	local bgPath = last and last.song and (try(function() return last.song:GetBackgroundPath() end) or try(function() return last.song:GetBannerPath() end))
	if bgPath then
		c.Cover:visible(true)
		pcall(function() c.Cover:Load(bgPath) end)
		pcall(function() c.Cover:scaletoclipped(W, HEAD) end)
		c.Cover:xy(X0 + W / 2, HEAD / 2):diffusealpha(0.55)
	else
		c.Cover:visible(false)
	end
	local av = try(function() return getAvatarPath(PLAYER_1) end) or try(function() return getAvatarPath() end)
	if online and who then av = nil end -- (someone else: no picture of theirs here)
	if av then
		c.Avatar:visible(true)
		pcall(function() c.Avatar:Load(av) end)
		c.Avatar:xy(X0 + PAD + 56 * u, 84 * u):zoomto(112 * u, 112 * u)
	else
		c.Avatar:visible(false)
	end
	local name = p and p:GetDisplayName() or ""
	if online then name = oname or "EtternaOnline" end
	c.Name:settext(name ~= "" and name or "Guest"):maxwidth((W * 0.5) / c.Name:GetZoom())
	if online then
		local ud = us and us.data
		local sub
		if not oname then sub = "Not logged in to EtternaOnline: Rankings finds anyone"
		elseif us.state == "error" and not ud then sub = "EtternaOnline: " .. (us.err or "no answer")
		elseif not ud then sub = "Loading from EtternaOnline..."
		else
			sub = string.format("EtternaOnline  ·  %s  ·  #%s in the world", ud.country ~= "" and ud.country or "no country", fmtInt(ud.rank or 0))
			if (ud.countryRank or 0) > 0 then sub = sub .. string.format("  ·  #%d of %d in %s", ud.countryRank, ud.countryTotal, ud.country) end
			if sc and sc.state == "loading" then
				sub = sub .. (sc.pages > 1 and string.format("  ·  loading plays (%d of %d)...", sc.loaded, sc.pages) or "  ·  loading plays...")
			end
		end
		c.Sub:settext(sub)
	else
		local total = 0
		pcall(function() total = p:GetTotalSessionSeconds() end)
		local taps = 0
		pcall(function() taps = p:GetTotalTapsAndHolds() end)
		c.Sub:settext(string.format("Local profile  ·  %s in game  ·  %s arrows smashed", fmtTime(total), fmtInt(taps)))
	end
	local onlineText = ""
	if not online then
		pcall(function()
			if DLMAN:IsLoggedIn() then
				onlineText = string.format("EtternaOnline: %.2f  (#%d)", DLMAN:GetSkillsetRating("Overall"), DLMAN:GetSkillsetRank("Overall"))
			end
		end)
	end
	-- local / online, and back to you from someone else's profile
	local chipH = 26 * u
	local cx0 = X0 + PAD + 138 * u
	local function chip(n, x, label, on, fn, w)
		local a = c[n]
		local ac = a:GetChildren()
		w = w or 92 * u
		a:visible(true):xy(x, 120 * u - chipH / 2)
		ac.Bg:zoomto(w, chipH):diffuse(on and S.accent or S.chip)
		ac.Label:xy(w / 2, chipH / 2):settext(up(label)):maxwidth((w - 8 * u) / ac.Label:GetZoom())
			:diffuse(on and ((LOOK == "quaver" or LOOK == "rebirth") and rgb(15, 15, 20) or S.text) or S.dim)
		region(x, 120 * u - chipH / 2, x + w, 120 * u + chipH / 2, fn)
		return x + w + 6 * u
	end
	local nx = chip("SrcLocal", cx0, "Local", not online, function() source = "local"; who = nil; if tab == "rank" then tab = "overview" end; first = 1 end)
	nx = chip("SrcOnline", nx, "Online", online, function() source = "online"; first = 1 end)
	c.BackToMe:visible(false)
	if online and who and eoName() and who:lower() ~= eoName():lower() then
		nx = chip("BackToMe", nx + 6 * u, "Back to you", false, function() who = nil; tab = "overview"; first = 1 end, 120 * u)
	end
	-- log in / log out (EtternaOnline)
	local me = eoName()
	if me then
		nx = chip("LoginChip", nx + 6 * u, "Log out", false, function()
			pcall(function() DLMAN:Logout() end)
			saveLogin("", "")
			forgetThemeLogin()
			who = nil
			if source == "online" and tab ~= "rank" then tab = "overview" end
		end, 100 * u)
	else
		nx = chip("LoginChip", nx + 6 * u, "Log in", false, function()
			loginForm = { field = 1, user = savedLogin().user, pass = "", msg = "" }
		end, 100 * u)
	end
	c.Online:xy(nx + 8 * u, 120 * u):settext(onlineText)
	c.RatingLabel:settext(up(mode .. (online and " rating (online)" or " rating")))
	c.Rating:settext(string.format("%.2f", M.skills[1] or 0)):diffuse(msdColour(M.skills[1] or 0))
	local other = mode == "4K" and "7K" or "4K"
	c.OtherRating:settext(string.format("%s: %.2f", other, D[other].skills[1] or 0))
	region(X0 + W - PAD - 220 * u, 30 * u, X0 + W - PAD, 150 * u, function() mode = other; first = 1 end)
	-- tabs
	local tx = X0 + PAD
	for i = 1, #TABS_ONLINE do c["Tab" .. i]:visible(false) end
	for i, tb in ipairs(tabs()) do
		local a = c["Tab" .. i]
		a:visible(true)
		local ac = a:GetChildren()
		local on = tab == tb[1]
		ac.Label:settext(up(tb[2]))
		local w = ac.Label:GetZoomedWidth() + 36 * u
		a:xy(tx, HEAD)
		ac.Bg:zoomto(w, TABH):visible(on)
		ac.Bar:xy(LOOK == "quaver" and 0 or 14 * u, TABH - 3 * u):zoomto(LOOK == "quaver" and w or w - 28 * u, 3 * u):visible(on)
		ac.Label:xy(w / 2, TABH / 2):diffuse(on and (LOOK == "quaver" and S.accent or S.text) or S.dim)
		region(tx, HEAD, tx + w, HEAD + TABH, function() tab = tb[1]; first = 1 end)
		tx = tx + w + 4 * u
	end
	local mx = X0 + W - PAD
	for _, m in ipairs({ "7K", "4K" }) do
		local a = c["Mode" .. m]
		local ac = a:GetChildren()
		local on = mode == m
		local w = 56 * u
		mx = mx - w
		a:xy(mx, HEAD + 8 * u)
		ac.Bg:zoomto(w - 4 * u, TABH - 16 * u):diffuse(on and S.accent or S.chip)
		ac.Label:xy((w - 4 * u) / 2, (TABH - 16 * u) / 2):diffuse(on and ((LOOK == "quaver" or LOOK == "rebirth") and rgb(15, 15, 20) or S.text) or S.dim)
		region(mx, HEAD, mx + w, HEAD + TABH, function() mode = m; first = 1 end)
	end
	c.Hint:xy(mx - 16 * u, HEAD + TABH / 2):settext(tab == "rank" and (query ~= "" and ("find: " .. query .. "_   Enter") or "type a name")
		or "Esc closes")
	-- top plays: the skillset filter, between the tabs and the hint
	local fx = tx + 16 * u
	local fw = math.min(76 * u, (mx - 16 * u - c.Hint:GetZoomedWidth() - 20 * u - fx) / #SKILLS)
	for k = 1, #SKILLS do
		local a = c["Filter" .. k]
		local ac = a:GetChildren()
		local on = skill == k
		a:visible(tab == "top"):xy(fx + (k - 1) * fw, HEAD + 10 * u)
		ac.Bg:zoomto(fw - 4 * u, TABH - 20 * u):diffuse(on and (k == 1 and S.accent or SKILL_COL[k]) or S.chip)
		ac.Label:xy((fw - 4 * u) / 2, (TABH - 20 * u) / 2):settext(up(SHORT[k])):maxwidth((fw - 10 * u) / ac.Label:GetZoom())
			:diffuse(on and rgb(15, 15, 20) or S.dim)
		if on and k == 1 and LOOK ~= "quaver" and LOOK ~= "rebirth" then ac.Label:diffuse(S.text) end
		if tab == "top" then region(fx + (k - 1) * fw, HEAD, fx + k * fw, HEAD + TABH, function() skill = k; first = 1 end) end
	end
	-- Rankings: the world's or a country's (the shown player's, else yours)
	local myCountry = (D.user and D.user.country ~= "" and D.user.country) or nil
	if not myCountry and eoName() then
		local me = eo("user", eoName())
		myCountry = me.data and me.data.country ~= "" and me.data.country or nil
	end
	for i, rk in ipairs({ { "RkWorld", "world", "World" }, { "RkCountry", "country", myCountry and ("Country: " .. myCountry) or "Country" } }) do
		local a = c[rk[1]]
		local ac = a:GetChildren()
		local on = rankKind == rk[2]
		local w = 132 * u
		a:visible(tab == "rank"):xy(fx + (i - 1) * (w + 6 * u), HEAD + 10 * u)
		ac.Bg:zoomto(w, TABH - 20 * u):diffuse(on and S.accent or S.chip)
		ac.Label:xy(w / 2, (TABH - 20 * u) / 2):settext(up(rk[3])):maxwidth((w - 10 * u) / ac.Label:GetZoom())
			:diffuse(on and ((LOOK == "quaver" or LOOK == "rebirth") and rgb(15, 15, 20) or S.text) or S.dim)
		if tab == "rank" then
			region(fx + (i - 1) * (w + 6 * u), HEAD, fx + (i - 1) * (w + 6 * u) + w, HEAD + TABH, function() rankKind = rk[2]; first = 1 end)
		end
	end
	-- what each tab shows
	local over = tab == "overview"
	-- (what an empty list says: nothing yet, loading, or why not)
	local function emptyText()
		if online then
			if not oname then return "Log in to EtternaOnline in Etterna to see your online plays (Rankings finds anyone)" end
			if sc and sc.state == "loading" and not sc.data then return "Loading the online plays..." end
			if sc and sc.state == "error" and not sc.data then return "EtternaOnline: " .. (sc.err or "no answer") end
			return "No " .. mode .. " plays online"
		end
		return "No " .. mode .. " plays yet"
	end
	for _, n in ipairs({ "SkillCard", "SkillTitle", "SkillSub", "GradeTitle", "MiniTitle", "MiniMore" }) do c[n]:visible(over) end
	for k = 1, #SKILLS do c["Skill" .. k]:visible(over) end
	for g = 1, 6 do c["Grade" .. g]:visible(over) end
	for i = 1, 8 do c["Tile" .. i]:visible(over) end
	for i = 1, 4 do c["Mini" .. i]:visible(over) end
	c.ListHead:visible(not over)
	for _, k in ipairs({ "rank", "title", "diff", "rate", "acc", "grade", "ssr", "date" }) do c["Col_" .. k]:visible(not over) end
	for i = 1, LISTN do c["Row" .. i]:visible(false) end
	c.Pager:visible(not over)
	c.Empty:visible(false)
	local CW = W - 2 * PAD
	if over then
		-- skills
		local SX, SW = X0 + PAD, 500 * u
		local skH = 37 * u
		c.SkillCard:xy(SX, CY):zoomto(SW, SCREEN_HEIGHT - CY - 18 * u)
		c.SkillTitle:xy(SX + 18 * u, CY + 24 * u):settext(up("Skills")):diffuse(LOOK == "tildeath" and S.titles or S.text)
		c.SkillSub:xy(SX + 18 * u, CY + 46 * u):settext(online and (mode == "4K" and "EtternaOnline's ratings" or "Etterna's formula on the 7K scores online")
			or (mode == "4K" and "Etterna's ratings from your 4K personal bests" or "Etterna's formula on your 7K personal bests"))
		local maxv = 0
		for k = 1, #SKILLS do maxv = math.max(maxv, M.skills[k] or 0) end
		maxv = math.max(maxv * 1.08, 10)
		for k = 1, #SKILLS do
			local a = c["Skill" .. k]
			local ac = a:GetChildren()
			local v = M.skills[k] or 0
			local y = CY + 64 * u + (k - 1) * skH
			a:xy(SX + 18 * u, y)
			ac.Label:xy(0, skH / 2):settext(k == 1 and up("Overall") or SKILLS[k]):diffuse(k == 1 and S.text or S.dim)
			local bx, bw = 150 * u, SW - 36 * u - 150 * u - 70 * u
			ac.Track:xy(bx, skH / 2 - 5 * u):zoomto(bw, 10 * u)
			ac.Fill:xy(bx, skH / 2 - 5 * u):zoomto(math.max(1, bw * v / maxv), 10 * u):diffuse(k == 1 and S.accent or SKILL_COL[k])
			ac.Value:xy(SW - 36 * u, skH / 2):settext(string.format("%.2f", v)):diffuse(msdColour(v))
		end
		-- grades
		local gy = CY + 64 * u + #SKILLS * skH + 14 * u
		c.GradeTitle:xy(SX + 18 * u, gy):settext(up("Grades")):diffuse(S.text)
		local labels = { "AAAAA", "AAAA", "AAA", "AA", "A", "B-" }
		local gw = (SW - 36 * u - 5 * 8 * u) / 6
		local gcols = { "Grade_Tier01", "Grade_Tier04", "Grade_Tier07", "Grade_Tier10", "Grade_Tier13", "Grade_Tier14" }
		for g = 1, 6 do
			local a = c["Grade" .. g]
			local ac = a:GetChildren()
			a:xy(SX + 18 * u + (g - 1) * (gw + 8 * u), gy + 18 * u)
			ac.Bg:zoomto(gw, 56 * u)
			ac.Label:xy(gw / 2, 17 * u):settext(labels[g]):diffuse(gradeColour(gcols[g])):maxwidth((gw - 6 * u) / ac.Label:GetZoom())
			ac.Value:xy(gw / 2, 40 * u):settext(fmtInt(M.grades[g])):diffuse(S.text)
		end
		-- tiles
		local RX = SX + SW + 20 * u
		local RW = X0 + W - PAD - RX
		local tw, th = (RW - 3 * 12 * u) / 4, 78 * u
		local tiles = {
			{ mode .. " plays", fmtInt(M.plays) }, { mode .. " charts played", fmtInt(M.chartCount) },
			{ mode .. " average accuracy", string.format("%.2f%%", M.acc) }, { mode .. " best play", M.best and string.format("%.2f", M.best.ssr) or "-" },
			{ "4K play time", fmtTime(D["4K"].secs) }, { "7K play time", fmtTime(D["7K"].secs) },
			{ "Sessions", fmtInt(try(function() return p:GetTotalSessions() end, 0)) }, { "Total play time", fmtTime(D["4K"].secs + D["7K"].secs) },
		}
		if online then
			local ud = D.user or {}
			local function rk(n) return (n and n > 0) and ("#" .. fmtInt(n)) or "-" end
			tiles[5] = { "World rank", rk(ud.rank) }
			tiles[6] = { "Country rank", (ud.countryRank or 0) > 0 and (rk(ud.countryRank) .. " / " .. fmtInt(ud.countryTotal)) or "-" }
			tiles[7] = { "Country", (ud.country and ud.country ~= "") and ud.country or "-" }
			tiles[8] = { "Online plays (4K + 7K)", fmtInt(D["4K"].plays + D["7K"].plays) }
		end
		for i = 1, 8 do
			local a = c["Tile" .. i]
			local ac = a:GetChildren()
			local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
			a:xy(RX + col * (tw + 12 * u), CY + row * (th + 12 * u))
			ac.Bg:zoomto(tw, th)
			ac.Bar:zoomto(3 * u, th):visible(LOOK == "quaver" or LOOK == "osu")
			ac.Label:xy(14 * u, 24 * u):settext(up(tiles[i][1])):maxwidth((tw - 20 * u) / ac.Label:GetZoom())
			ac.Value:xy(14 * u, 52 * u):settext(tiles[i][2]):diffuse(i == 4 and M.best and msdColour(M.best.ssr) or S.text):maxwidth((tw - 20 * u) / ac.Value:GetZoom())
		end
		-- recent plays (four)
		local my = CY + 2 * (th + 12 * u) + 18 * u
		c.MiniTitle:xy(RX, my + 4 * u):settext(up("Recent plays")):diffuse(S.text)
		c.MiniMore:xy(RX + RW, my + 4 * u):settext("all " .. fmtInt(#M.recent) .. "  >")
		region(RX + RW - 160 * u, my - 10 * u, RX + RW, my + 18 * u, function() tab = "recent"; first = 1 end)
		for i = 1, 4 do
			fillRow(c["Mini" .. i], M.recent[i], "score", i, RX, my + 22 * u + (i - 1) * ROWH, RW, true)
		end
		if #M.recent == 0 then c.Empty:visible(true):xy(RX + RW / 2, my + 90 * u):settext(emptyText()) end
	elseif tab == "rank" then
		renderRankings(c, myCountry)
	else
		local list, kind = listFor(M)
		local hy = CY - 6 * u
		c.ListHead:xy(X0 + PAD, hy):zoomto(CW, 26 * u)
		local cols = { rank = "#", title = kind == "chart" and "Chart" or "Song", diff = "Difficulty / MSD", rate = "Rate",
			acc = kind == "chart" and "Plays" or "Accuracy", grade = kind == "chart" and "Best" or "Grade",
			ssr = kind == "chart" and "Grade" or (tab == "top" and skill > 1 and SHORT[skill] .. " SSR") or "SSR",
			date = kind == "chart" and "Last played" or "Played" }
		for k, label in pairs(cols) do
			local cx = (k == "title" and (COLS.banner) or COLS[k]) * u
			if k == "rank" then cx = 8 * u end
			c["Col_" .. k]:xy(X0 + PAD + cx, hy + 13 * u):settext(up(label))
		end
		first = math.max(1, math.min(first, math.max(1, #list - LISTN + 1)))
		for i = 1, LISTN do
			local idx = first + i - 1
			fillRow(c["Row" .. i], list[idx], kind, idx, X0 + PAD, CY + 26 * u + (i - 1) * ROWH, CW, false)
		end
		if #list == 0 then c.Empty:visible(true):xy(X0 + W / 2, CY + 140 * u):settext(emptyText()) end
		-- pager
		local pages = math.max(1, math.ceil(#list / LISTN))
		local pg = math.floor((first - 1) / LISTN) + 1
		local py = SCREEN_HEIGHT - 22 * u
		local pc = c.Pager:GetChildren()
		local px = X0 + W / 2
		pc.PrevBg:xy(px - 130 * u, py - 14 * u):zoomto(40 * u, 28 * u)
		pc.NextBg:xy(px + 90 * u, py - 14 * u):zoomto(40 * u, 28 * u)
		pc.Prev:xy(px - 110 * u, py):diffuse(first > 1 and S.text or S.dim)
		pc.Next:xy(px + 110 * u, py):diffuse(first + LISTN <= #list and S.text or S.dim)
		pc.Label:xy(px, py):settext(string.format("%d - %d of %s", math.min(#list, first), math.min(#list, first + LISTN - 1), fmtInt(#list)))
		region(px - 130 * u, py - 14 * u, px - 90 * u, py + 14 * u, function() first = math.max(1, first - LISTN) end)
		region(px + 90 * u, py - 14 * u, px + 130 * u, py + 14 * u, function() first = first + LISTN end)
	end
	drawLogin(c)
end

-- ------------------------------------------------------------------------------------------------
-- opening, closing, the keyboard and the mouse
-- ------------------------------------------------------------------------------------------------
function TWProfileIsOpen() return open end
function TWOpenProfile()
	if open then return end
	local top = SCREENMAN:GetTopScreen()
	if not top or top:GetName() ~= "ScreenSelectMusic" then return end
	open = true
	tab, first, skill, query = "overview", 1, 1, ""
	mode = "4K"
	pcall(function() if GAMESTATE:GetCurrentGame():GetName() == "kb7" then mode = "7K" end end)
	MESSAGEMAN:Broadcast("TWProfileOpen")
end
function TWCloseProfile()
	if not open then return end
	open = false
	loginForm = nil
	MESSAGEMAN:Broadcast("TWProfileClose")
end
local function rerender() if page then page:playcommand("Render") end end
-- the profile page with the login box open (the looks' options and VSRG Hub's menu: EtternaOnline)
function TWProfileLogin()
	if not open then TWOpenProfile() end
	if not open then return false end
	if not eoName() then loginForm = { field = 1, user = savedLogin().user, pass = "", msg = "" } end
	source = "online"
	rerender()
	return true
end

-- the corner of song select where Til' Death and Rebirth show your profile: a click there opens this
local function profileCorner(mx, my)
	if LOOK == "tildeath" then return mx <= 170 * SCREEN_WIDTH / 854 and my >= SCREEN_HEIGHT - 50 * SCREEN_HEIGHT / 480 end
	if LOOK == "rebirth" then return mx <= 270 * u and my <= 82 * u end
	return false
end
local function input(event)
	local b = event.DeviceInput.button
	local first_ = event.type == "InputEventType_FirstPress"
	if not open then
		if first_ and b == "DeviceButton_left mouse button" and (LOOK == "tildeath" or LOOK == "rebirth") then
			local top = SCREENMAN:GetTopScreen()
			if top and top:GetName() == "ScreenSelectMusic" and not (TWMenuIsOpen and TWMenuIsOpen())
				and profileCorner(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()) then
				-- (Rebirth's corner has its login button in it: not logged in, the login box opens)
				if LOOK == "rebirth" and not eoName() then TWProfileLogin() else TWOpenProfile() end
				return true
			end
		end
		return false
	end
	if event.type == "InputEventType_Release" then return true end
	local rep = event.type == "InputEventType_Repeat"
	-- the login box has the keyboard and the mouse while it is open
	if loginForm then
		local f = loginForm
		if b == "DeviceButton_left mouse button" then
			if first_ then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				for _, r in ipairs(loginRegions) do
					if mx >= r[1] and mx <= r[3] and my >= r[2] and my <= r[4] then r[5]() break end
				end
				rerender()
			end
			return true
		end
		if not (first_ or rep) or f.busy then
			if first_ and b == "DeviceButton_escape" then loginForm = nil; rerender() end
			return true
		end
		if b == "DeviceButton_escape" or b == "DeviceButton_right mouse button" then loginForm = nil
		elseif b == "DeviceButton_tab" or b == "DeviceButton_up" or b == "DeviceButton_down" then f.field = f.field == 1 and 2 or 1
		elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" then
			if f.field == 1 then f.field = 2 else submitLogin() end
		elseif b == "DeviceButton_backspace" then
			if f.field == 1 then f.user = f.user:sub(1, -2) else f.pass = f.pass:sub(1, -2) end
		elseif b == "DeviceButton_v" and INPUTFILTER:IsControlPressed() then
			local key = tostring(math.floor(now() * 1000))
			eo("clip", key, 0)
			f.clip = "clip|" .. key
		elseif event.char and event.char ~= "" and event.char:byte() >= 32 and not INPUTFILTER:IsControlPressed() then
			if f.field == 1 then f.user = (f.user .. event.char):sub(1, 128) else f.pass = (f.pass .. event.char):sub(1, 128) end
		end
		if f.msg ~= "" and not f.busy then f.msg = "" end
		rerender()
		return true
	end
	if b == "DeviceButton_left mouse button" then
		if not first_ then return true end
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
		if mx < X0 or mx > X0 + W then TWCloseProfile() return true end
		for i = #regions, 1, -1 do
			local r = regions[i]
			if mx >= r[1] and mx <= r[3] and my >= r[2] and my <= r[4] then r[5](); rerender(); return true end
		end
		return true
	end
	-- Rankings: typing a name looks that player up (Enter)
	if tab == "rank" and (first_ or rep) then
		if b == "DeviceButton_backspace" and query ~= "" then query = query:sub(1, -2); rerender() return true end
		if b == "DeviceButton_escape" and query ~= "" then query = ""; rerender() return true end
		if (b == "DeviceButton_enter" or b == "DeviceButton_KP enter") and query ~= "" then
			who, source, tab, first, query = query, "online", "overview", 1, ""
			rerender()
			return true
		end
		if event.char and event.char:match("^[%w_%-%.%[%]]$") and not INPUTFILTER:IsControlPressed() and #query < 32 then
			query = query .. event.char
			rerender()
			return true
		end
	end
	if b == "DeviceButton_right mouse button" or b == "DeviceButton_escape" or b == "DeviceButton_backspace" then
		if first_ then TWCloseProfile() end
		return true
	end
	if not (first_ or rep) then return true end
	local TB = tabs()
	-- (how far a list goes is settled when it's drawn)
	if b == "DeviceButton_mousewheel up" or b == "DeviceButton_up" then first = math.max(1, first - (b == "DeviceButton_up" and 1 or 3))
	elseif b == "DeviceButton_mousewheel down" or b == "DeviceButton_down" then first = first + (b == "DeviceButton_down" and 1 or 3)
	elseif b == "DeviceButton_left" or b == "DeviceButton_pgup" then first = math.max(1, first - LISTN)
	elseif b == "DeviceButton_right" or b == "DeviceButton_pgdn" then first = first + LISTN
	elseif b == "DeviceButton_tab" and first_ then
		for i, tb in ipairs(TB) do if tb[1] == tab then tab = TB[i % #TB + 1][1]; first = 1; break end end
	elseif (b == "DeviceButton_space" or b == "DeviceButton_m") and first_ then mode = mode == "4K" and "7K" or "4K"; first = 1
	elseif b == "DeviceButton_o" and first_ then
		-- local / online
		source = source == "online" and "local" or "online"
		if source == "local" then who = nil; if tab == "rank" then tab = "overview" end end
		first = 1
	elseif first_ and tab == "top" and (b == "DeviceButton_s" or b == "DeviceButton_a") then
		skill = (skill + (b == "DeviceButton_s" and 0 or #SKILLS - 2)) % #SKILLS + 1; first = 1
	elseif first_ and b:match("^DeviceButton_[1-5]$") and TB[tonumber(b:sub(-1))] then tab = TB[tonumber(b:sub(-1))][1]; first = 1
	else return true end
	rerender()
	return true
end

return Def.ActorFrame {
	InitCommand = function(self) self:queuecommand("Hook"); self:sleep(1):queuecommand("AutoLogin") end,
	AutoLoginCommand = function(self) autoLogin() end,
	HookCommand = function(self)
		local s = self
		while s:GetParent() do s = s:GetParent() end
		if s.AddInputCallback then s:AddInputCallback(input) end
	end,
	t,
}
