-- Scroll speed in each game's own numbers, and F3 / F4 at the start of a song.
--
-- Etterna's CMod (C700: notes move as at 700 BPM, 64 pixels a beat, whatever the song) is what is
-- kept; the looks show and change it in their game's scroll speed, worked out from how fast each
-- game's notes move on a 480-pixel-tall screen:
--   osu! (stable and lazer): speed S takes 11485 / S ms over osu!'s default scroll length (from the
--     top to hit position 402 of 480, lazer keeps that speed for any hit position): 402 * S / 11485
--     pixels a millisecond. Stable has whole numbers (1 to 40); lazer tenths.
--   Quaver: speed Q (shown as 26.4, kept as 264) moves Q / 20 virtual pixels a millisecond on a
--     768-tall screen: Q / 32 pixels a millisecond on a 480-tall one. Tenths.
--   Etterna: C * 64 / 60000 pixels a millisecond.
-- (All three keep the speed the same at any music rate, as CMod does.)
local PER = {
	osu = 402 * 60000 / (11485 * 64), -- C per osu! scroll speed (about 32.8)
	quaver = (1 / 32) * 60000 / 64,   -- C per Quaver scroll speed (about 29.3)
}
local RANGE = { osu = { 1, 40 }, lazer = { 1, 40 }, quaver = { 5, 100 } }

-- the look's game: "osu", "lazer" or "quaver"
function TW.scrollGame()
	local n = ""
	pcall(function() n = THEME:GetCurThemeName() end)
	if n == "VSRG Hub Quaver" then return "quaver" end
	if n == "VSRG Hub lazer" then return "lazer" end
	return "osu"
end
local function per(game) return game == "quaver" and PER.quaver or PER.osu end
-- the look's scroll speed for a CMod, and back
function TW.scrollFromC(c, game)
	game = game or TW.scrollGame()
	return c / per(game)
end
function TW.cFromScroll(v, game)
	game = game or TW.scrollGame()
	return math.max(10, math.floor(v * per(game) + 0.5))
end
-- written as the game writes it: stable whole numbers, lazer and Quaver one decimal
function TW.scrollNumber(v, game)
	game = game or TW.scrollGame()
	-- (stable has whole numbers only: a CMod between two of them shows its tenth, so it's clear the
	-- next step goes to a whole one)
	if game == "osu" and math.abs(v - math.floor(v + 0.5)) < 0.6 / per(game) then return string.format("%d", math.floor(v + 0.5)) end
	return string.format("%.1f", math.floor(v * 10 + 0.5) / 10)
end

local function po(lvl) return GAMESTATE:GetPlayerState():GetPlayerOptions(lvl or "ModsLevel_Preferred") end
local function currentC()
	local c = nil
	pcall(function() c = po():CMod() end)
	if c and c > 0 then return c end
	return nil
end
-- "27 (C886)": the scroll speed in the look's numbers with the CMod it is; nil when the speed isn't
-- a CMod (an XMod or MMod has no fixed speed to compare)
function TW.scrollLabel(c)
	c = c or currentC()
	if not c then return nil end
	local game = TW.scrollGame()
	local v = TW.scrollFromC(c, game)
	local txt = TW.scrollNumber(v, game)
	if game == "lazer" then txt = txt .. string.format(" (%d ms)", math.floor(11485 / math.max(0.1, v) + 0.5)) end
	return txt, string.format("C%d", math.floor(c + 0.5))
end
-- sets the CMod everywhere Etterna reads it (now, too, when a song is playing)
function TW.setCMod(c, playing)
	local lv = { "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song" }
	if playing then lv[#lv + 1] = "ModsLevel_Current" end
	for _, l in ipairs(lv) do pcall(function() po(l):CMod(c) end) end
end
-- one step of the look's scroll speed up (dir 1) or down (-1): to the next whole number (stable,
-- lazer and Quaver) or tenth (fine: lazer and Quaver with Ctrl), from wherever the CMod is now.
-- Returns the new CMod, or nil when the speed isn't a CMod.
function TW.scrollStep(dir, fine, playing)
	local c = currentC()
	if not c then return nil end
	local game = TW.scrollGame()
	local step = (fine and game ~= "osu") and 0.1 or 1
	local v = TW.scrollFromC(c, game)
	local k = v / step
	-- (a speed between two steps goes to the next one that way; one on a step, a whole step. The
	-- CMod is a whole number, so a step comes back a little off its exact value: anything within
	-- about half a C of a step counts as on it, or the next press would land on the same step again)
	local tol = 0.6 / (per(game) * step)
	local nk = dir > 0 and math.floor(k + tol) + 1 or math.ceil(k - tol) - 1
	local r = RANGE[game]
	local nv = math.max(r[1], math.min(r[2], nk * step))
	local nc = TW.cFromScroll(nv, game)
	if nc == c then return c end
	TW.setCMod(nc, playing)
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
	return nc
end
-- a typed speed in the look's numbers ("27", "30.2"): its CMod
function TW.cFromTyped(v)
	local game = TW.scrollGame()
	local r = RANGE[game]
	if v < r[1] or v > r[2] then return nil end
	if game == "osu" then v = math.floor(v + 0.5) end
	return TW.cFromScroll(v, game)
end

-- F3 / F4 while playing (VSRG Hub's keybinds "scrolldown" / "scrollup"), as in osu! and Quaver:
-- only in the song's first seconds (the first 5 seconds of music, or until shortly before its first
-- note when the intro is longer), and not in the middle of a song. A press is one step; held, it
-- keeps stepping, faster the longer it is held. Ctrl (lazer and Quaver): tenths.
local held = nil -- { dir, fine, next, n }
local function window()
	local now, first = 0, 0
	pcall(function() now = GAMESTATE:GetSongPosition():GetMusicSeconds() end)
	pcall(function() first = GAMESTATE:GetCurrentSteps():GetFirstSecond() end)
	return now < math.max(5, first - 0.3)
end
local function stepNow(dir, fine)
	local c = TW.scrollStep(dir, fine, true)
	if not c then
		MESSAGEMAN:Broadcast("TWScrollToast", { text = "Scroll speed: not a CMod", sub = "set a C speed in the options" })
		return false
	end
	local main, sub = TW.scrollLabel(c)
	MESSAGEMAN:Broadcast("TWScrollToast", { text = "Scroll speed " .. main, sub = sub })
	return true
end
function TWScrollKey(event, top)
	if event.DeviceInput.is_mouse then return false end
	local b = event.DeviceInput.button
	local down = TWKeys and TWKeys.is and TWKeys.is(event, "scrolldown")
	local up = TWKeys and TWKeys.is and TWKeys.is(event, "scrollup")
	-- (Ctrl with the key: the fine step; the binding itself has no Ctrl)
	local fine = false
	if not (down or up) and INPUTFILTER:IsControlPressed() and TWKeys and TWKeys.binding then
		local function plain(id)
			local bind = TWKeys.binding(id) or ""
			local name = bind:match("^[CSA]*#(.+)$")
			return name and not bind:find("C", 1, true) and b == "DeviceButton_" .. name
		end
		down, up = plain("scrolldown"), plain("scrollup")
		fine = down or up
	end
	if not (down or up) then return false end
	local dir = up and 1 or -1
	if event.type == "InputEventType_Release" then
		if held and held.dir == dir then held = nil end
		return window()
	end
	if not window() then held = nil return false end
	if event.type == "InputEventType_FirstPress" then
		stepNow(dir, fine)
		held = { dir = dir, fine = fine, next = GetTimeSinceStart() + 0.4, n = 0, button = b }
	end
	return true -- (Etterna's own repeats are left out: the holding steps on its own, below)
end
-- the held key's steps: the first after 0.4 s, then quicker and quicker
function TW.scrollHeldStep()
	if not held then return end
	if not window() or not INPUTFILTER:IsBeingPressed(held.button:gsub("^DeviceButton_", ""), "Keyboard") then held = nil return end
	local now = GetTimeSinceStart()
	if now < held.next then return end
	stepNow(held.dir, held.fine)
	held.n = held.n + 1
	held.next = now + math.max(0.025, 0.13 * (0.82 ^ held.n))
end

-- the box saying the new speed, at the top of the screen in the middle (put on the gameplay screen
-- of each look): it steps a held key too
function TW.scrollToast()
	local M = TW.M
	return Def.ActorFrame {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, M(70)):diffusealpha(0)
			TW.everyFrame(self)
			self:SetUpdateFunction(function() TW.scrollHeldStep() end)
		end,
		OffCommand = function() held = nil end,
		TWScrollToastMessageCommand = function(self, p)
			local c = self:GetChildren()
			c.T:settext(p.text or "")
			c.S:settext(p.sub or "")
			local w = math.max(c.T:GetZoomedWidth(), c.S:GetZoomedWidth()) + M(44)
			TW.setBox(c.Bg, { w = w })
			self:stoptweening():decelerate(0.08):diffusealpha(1):sleep(1.2):linear(0.3):diffusealpha(0)
		end,
		TW.box { w = M(220), h = M(52), r = M(14), ax = 0.5, ay = 0.5, col = { 0.08, 0.07, 0.12, 0.88 } } .. { Name = "Bg" },
		TW.text(M(17), true, function(self) self:align(0.5, 0.5):y(-M(8)) end) .. { Name = "T" },
		TW.text(M(11), false, function(self) self:align(0.5, 0.5):y(M(13)):diffusealpha(0.7) end) .. { Name = "S" },
	}
end
