-- Searching song select as you type, without the list jumping on every letter: the search runs once
-- you stop typing for a moment (Enter runs it at once), and the new results slide in.

local pending, pendingAt = nil, 0
local DELAY = 0.28

local function wheel()
	local s = SCREENMAN:GetTopScreen()
	return s and s.GetMusicWheel and s:GetMusicWheel() or nil
end

local function run(text)
	local w = wheel()
	if not w then return end
	w:SongSearch(text)
	MESSAGEMAN:Broadcast("TWSearchResults")
end

-- the search box changed: search after a short pause (empty: at once, the whole list back)
function TW.searchSoon(text)
	if text == "" then
		pending = nil
		run("")
		return
	end
	pending, pendingAt = text, GetTimeSinceStart()
end

-- run a search still waiting (Enter, or before playing)
function TW.searchNow()
	if pending then
		local t = pending
		pending = nil
		run(t)
	end
end

function TW.searchPending() return pending ~= nil end

-- the actor that runs the waiting search (in the song select overlay)
function TW.searchRunner()
	return Def.ActorFrame {
		InitCommand = function(self)
			self:SetUpdateFunction(function()
				if pending and GetTimeSinceStart() - pendingAt >= DELAY then TW.searchNow() end
			end)
		end,
		OffCommand = function() pending = nil end,
	}
end

-- each song panel slides in after a search, the ones nearest the middle first (stepped by the panel,
-- not tweened: a tween inside the wheel stops it placing its panels, see TW.ianim)
function TW.searchSlideIn(self, drawIndex, middle)
	local off = math.abs((drawIndex or middle) - middle)
	TW.ianim(self, self, "alpha", 1, 0.2, "dec", 0.02 * off, 0)
	TW.ianim(self, self, "x", 0, 0.2, "dec", 0.02 * off, TW.M(36))
end
