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
