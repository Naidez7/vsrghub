-- Two small things that run on every screen (the system layer):
--   TW.statusWriter()  what you're doing, for the launcher's Discord presence: Save/VSRGHub/online/
--                      status.txt, a line "screen<TAB>title<TAB>artist<TAB>difficulty<TAB>keys<TAB>rate",
--                      rewritten when it changes
--   TW.noticeReader()  the launcher's ranking notices (online/notice.txt, a line each: "PraileX
--                      passed you in 4K") shown as they come, then the file emptied
local ONLINE = "Save/VSRGHub/online/"

local function statusLine()
	local s = SCREENMAN:GetTopScreen()
	local name = s and s:GetName() or ""
	local what = "menu"
	if name == "ScreenSelectMusic" then what = "select"
	elseif name:find("Gameplay") then what = "play"
	elseif name:find("Evaluation") then what = "results"
	elseif name:find("Practice") then what = "practice"
	elseif name:find("NetSelectMusic") or name:find("NetRoom") then what = "multi" end
	local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
	local title, artist, diff, keys = "", "", "", ""
	if song and (what == "select" or what == "play" or what == "results" or what == "practice") then
		title = song:GetDisplayMainTitle() or ""
		artist = song:GetDisplayArtist() or ""
		if steps then
			pcall(function() diff = steps:GetDescription() or ""; keys = tostring(steps:GetStepsType()):match("(%d+)K") or "" end)
			if diff == "" then pcall(function() diff = steps:GetChartName() or "" end) end
		end
	end
	local rate = 1
	pcall(function() rate = getCurRateValue() end)
	local clean = function(v) return tostring(v):gsub("[\t\r\n]", " ") end
	return table.concat({ what, clean(title), clean(artist), clean(diff), clean(keys), string.format("%.2f", rate) }, "\t")
end

function TW.statusWriter()
	local last = nil
	return Def.Actor {
		InitCommand = function(self)
			self:SetUpdateFunction(function()
				local ok, line = pcall(statusLine)
				if not ok or line == last then return end
				last = line
				pcall(function() File.Write(ONLINE .. "status.txt", line .. "\n") end)
			end):SetUpdateFunctionInterval(2)
		end,
	}
end

function TW.noticeReader()
	return Def.Actor {
		InitCommand = function(self)
			self:SetUpdateFunction(function()
				local ok, txt = pcall(function() return File.Read(ONLINE .. "notice.txt") end)
				if not ok or not txt or txt == "" then return end
				pcall(function() File.Write(ONLINE .. "notice.txt", "") end)
				for line in txt:gmatch("[^\r\n]+") do
					if line ~= "" then SCREENMAN:SystemMessage(line) end
				end
			end):SetUpdateFunctionInterval(5)
		end,
	}
end

-- The daily challenge (daily.go): today's charts in online/daily.txt, one line per key count:
-- "keys<TAB>chart key<TAB>title<TAB>artist<TAB>chart name<TAB>msd". TW.daily(keys) gives today's for
-- 4 or 7; TW.jumpToChart(ck) puts song select on a chart; the launcher's "Play it" leaves the key in
-- online/jump.txt, which song select takes up (TW.jumpWatcher, in the system layer).
function TW.daily(keys)
	local ok, txt = pcall(function() return File.Read(ONLINE .. "daily.txt") end)
	if not ok or not txt then return nil end
	for line in txt:gmatch("[^\r\n]+") do
		local f = {}
		for v in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
		if tonumber(f[1]) == keys and f[2] and f[2] ~= "" then
			return { keys = keys, chart = f[2], title = f[3] or "", artist = f[4] or "", name = f[5] or "", msd = tonumber(f[6]) or 0 }
		end
	end
	return nil
end
function TW.jumpToChart(ck, what)
	local s = SCREENMAN:GetTopScreen()
	if not s or s:GetName() ~= "ScreenSelectMusic" then return false end
	local song, steps
	pcall(function() song = SONGMAN:GetSongByChartKey(ck); steps = SONGMAN:GetStepsByChartKey(ck) end)
	if not song or not steps then
		SCREENMAN:SystemMessage("You don't have " .. (what or "that chart") .. " in your library")
		return false
	end
	local w = s:GetMusicWheel()
	if not w then return false end
	if TW.browsing ~= nil then TW.browsing = false end
	w:SelectSong(song)
	GAMESTATE:SetCurrentSteps(PLAYER_1, steps)
	if TW.pick then TW.pick = { song = song, steps = steps } end
	MESSAGEMAN:Broadcast("CurrentStepsChanged")
	return true
end
-- the launcher's "Play it" (or the menu's daily challenge): the chart waits in jump.txt
function TW.jumpWatcher()
	return Def.Actor {
		InitCommand = function(self)
			self:SetUpdateFunction(function()
				local s = SCREENMAN:GetTopScreen()
				if not s or s:GetName() ~= "ScreenSelectMusic" then return end
				local ok, txt = pcall(function() return File.Read(ONLINE .. "jump.txt") end)
				if not ok or not txt then return end
				local ck = txt:match("^%s*(%S+)")
				if not ck then return end
				pcall(function() File.Write(ONLINE .. "jump.txt", "") end)
				local w = s:GetMusicWheel()
				if w and not w:IsSettled() then return end
				local d4, d7 = TW.daily(4), TW.daily(7)
				local what = "that chart"
				if d4 and d4.chart == ck then what = "today's 4K chart (" .. d4.title .. ")" elseif d7 and d7.chart == ck then what = "today's 7K chart (" .. d7.title .. ")" end
				if TW.jumpToChart(ck, what) then SCREENMAN:SystemMessage("Daily challenge: " .. (what:gsub("^today's ", "today's ")) ) end
			end):SetUpdateFunctionInterval(1.5)
		end,
	}
end
