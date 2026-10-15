-- osu! stable's main menu, behind the buttons: the background (moving a little with the mouse, like
-- osu!'s parallax) and osu!'s dark bars at the top and bottom (the player card, osu!'s three lines of
-- info while the menu is open, the music controls, the small print), shown while the menu is used.
TW.useInterfaceSkin()
local M, R = TW.M, TW.R

local function randomBackground()
	local songs = SONGMAN:GetAllSongs()
	for _ = 1, 20 do
		local s = songs[math.random(1, math.max(1, #songs))]
		local p = s and TW.bigPicture(s)
		if p and p ~= "" and FILEMAN:DoesFileExist(p) then return p end
	end
	return nil
end

-- the background (the frosted bars show it, blurred)
local bg = Def.ActorFrame {
	InitCommand = function(self) TW.frostTarget = self end,
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(TW.rgb(24, 22, 32)) end },
}
local pic = Def.Sprite {
	Name = "Pic",
	InitCommand = function(self)
		if TW.has("menu_bg") then self:Load(TW.img("menu_bg")) else
			local p = randomBackground()
			if p then self:LoadBackground(p) end
		end
		-- (a little larger than the screen, for the parallax)
		self:scaletocover(-M(20), -M(20), SCREEN_WIDTH + M(20), SCREEN_HEIGHT + M(20))
		self:diffusealpha(0):linear(0.6):diffusealpha(TW.has("menu_bg") and 1 or 0.8)
	end,
	-- the menu's song changed: its background, if the skin has none of its own
	TWMenuMusicMessageCommand = function(self)
		if TW.has("menu_bg") or not TW.menu.song then return end
		local p = TW.bigPicture(TW.menu.song)
		if not p or p == "" or p == self.shown then return end
		self.shown = p
		self:stoptweening():linear(0.25):diffusealpha(0):queuecommand("Swap")
	end,
	SwapCommand = function(self)
		local x, y = self:GetX(), self:GetY()
		self:LoadBackground(self.shown):scaletocover(-M(20), -M(20), SCREEN_WIDTH + M(20), SCREEN_HEIGHT + M(20)):xy(x, y)
		self:linear(0.5):diffusealpha(0.8)
	end,
}
-- (in a frame of its own, which moves with the mouse)
bg[#bg + 1] = Def.ActorFrame { InitCommand = function(self) TW.parallax(self, M(14)) end, pic }
local t = Def.ActorFrame { bg }
t[#t + 1] = TW.frostSource()

-- light from the sides on the music's strong beats
t[#t + 1] = TW.sideFlashes()

-- osu! stable's bars: dark bands at the top (your card, the music) and the bottom, shown while you
-- use the menu; left alone, the menu goes back to just the cookie and the picture
local TOP, BOTTOM = M(92), M(93)
local bars = Def.ActorFrame {
	InitCommand = function(self)
		self:diffusealpha(0)
		local lastMove, mx, my, on = 0, nil, nil, false
		self:SetUpdateFunction(function(s)
			local x, y = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			local now = GetTimeSinceStart()
			if mx and (math.abs(x - mx) > 2 or math.abs(y - my) > 2) then lastMove = now end
			mx, my = x, y
			local want = TW.titleAwake == true or now - lastMove < 8
			if want ~= on then
				on = want
				s:stoptweening():linear(on and 0.25 or 0.6):diffusealpha(on and 1 or 0)
			end
		end)
	end,
	Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, TOP):diffuse({ 0, 0, 0, 0.55 }) end },
	Def.Quad { InitCommand = function(self) self:align(0, 1):xy(0, SCREEN_HEIGHT):zoomto(SCREEN_WIDTH, BOTTOM):diffuse({ 0, 0, 0, 0.55 }) end },
	-- player card
	TW.userCard(M(6), M(6), M(80)),
}

-- osu!'s three lines, while the menu is open
local function infoLine(i, f)
	return TW.text(M(13.5), false, function(self) self:align(0, 0.5):xy(M(360), M(13 + (i - 1) * 23.5)):shadowlength(M(1.5)) end) .. {
		OnCommand = function(self) self:playcommand("Tick") end,
		TickCommand = function(self) self:settext(f()):sleep(1):queuecommand("Tick") end
	}
end
local info = Def.ActorFrame {
	InitCommand = function(self) self:diffusealpha(0) end,
	TWTitleMenuMessageCommand = function(self) self:stoptweening():linear(0.2):diffusealpha(TW.titleAwake and 1 or 0) end,
}
info[#info + 1] = infoLine(1, function() return string.format("You have %d beatmaps available!", SONGMAN:GetNumSongs()) end)
info[#info + 1] = infoLine(2, function()
	local secs = math.floor(GetTimeSinceStart())
	return string.format("VSRG Hub has been running for %02d:%02d:%02d.", math.floor(secs / 3600), math.floor(secs / 60) % 60, secs % 60)
end)
info[#info + 1] = infoLine(3, function()
	local h, m = Hour(), Minute()
	return string.format("It is currently %d:%02d %s.", (h % 12 == 0) and 12 or (h % 12), m, h < 12 and "AM" or "PM")
end)
bars[#bars + 1] = info

-- the music controls (top right, as osu!'s: previous, play, pause, stop, next) and how far into the
-- song it is; the song's name shows while the mouse is over them
local controls = {
	{ "backward-step", function() TW.menuMusicPrev() end },
	{ "play", function() if TW.menu.paused then TW.menuMusicToggle() elseif not TW.menu.song then TW.menuMusicNext() end end },
	{ "pause", function() if not TW.menu.paused then TW.menuMusicToggle() end end },
	{ "stop", function() if not TW.menu.paused then TW.menuMusicToggle() end end },
	{ "forward-step", function() TW.menuMusicNext() end },
}
local CX0, CSTEP, CY = M(1221), M(34), M(17.5)
local np = Def.ActorFrame {}
for i, c in ipairs(controls) do
	np[#np + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(CX0 + (i - 1) * CSTEP, CY) end,
		Def.Sprite { Name = "I", Texture = TW.iconPath(c[1]), InitCommand = function(self) self:zoomto(M(17), M(17)) end },
		TW.button(M(32), M(30), c[2], function(self, on)
			self:GetParent():GetChild("I"):stoptweening():linear(0.08):zoomto((on and 1.15 or 1) * M(17), (on and 1.15 or 1) * M(17))
			MESSAGEMAN:Broadcast("TWMusicHover", { on = on })
		end) .. { InitCommand = function(self) self:zoomto(M(32), M(30)):diffusealpha(0) end },
	}
end
-- the song's place in it
local PX0, PX1 = M(1210), SCREEN_WIDTH - M(30)
np[#np + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(PX0, M(36)):zoomto(PX1 - PX0, M(3)):diffuse({ 1, 1, 1, 0.25 }) end }
np[#np + 1] = Def.ActorFrame {
	InitCommand = function(self)
		local q = self:GetChild("Bar")
		q:align(0, 0.5):xy(PX0, M(36)):zoomto(0, M(3)):diffuse({ 1, 1, 1, 0.85 })
		self:SetUpdateFunction(function()
			local m = TW.menu
			local f = 0
			if m.song and m.startedAt then
				local total = 0
				pcall(function() total = m.song:MusicLengthSeconds() end)
				local at = m.paused and (m.pausedAt or m.start) or (m.start + (GetTimeSinceStart() - m.startedAt) % math.max(1, m.len or 1))
				if total > 0 then f = math.max(0, math.min(1, at / total)) end
			end
			q:zoomto((PX1 - PX0) * f, M(3))
		end)
	end,
	Def.Quad { Name = "Bar" },
}
-- the song's name, under the controls while the mouse is on them (and for a moment when it changes)
np[#np + 1] = TW.text(M(13), false, function(self) self:align(1, 0.5):xy(SCREEN_WIDTH - M(12), M(56)):shadowlength(M(1.5)):diffusealpha(0) end) .. {
	OnCommand = function(self) self:playcommand("TWMenuMusic") end,
	TWMenuMusicMessageCommand = function(self)
		local s = TW.menuMusicTitle()
		self:settext(s ~= "" and s or ""):maxwidth(M(600) / self:GetZoom())
		self:stoptweening():linear(0.2):diffusealpha(1):sleep(3):linear(0.4):diffusealpha(0)
	end,
	TWMusicHoverMessageCommand = function(self, p) self:stoptweening():linear(0.15):diffusealpha(p.on and 1 or 0) end,
}
bars[#bars + 1] = np

-- the small print, where osu! has "ppy powered": VSRG Hub's name large, two small lines beside it
bars[#bars + 1] = TW.text(M(26), true, function(self) self:align(0, 0.5):xy(M(10), SCREEN_HEIGHT - M(22)):shadowlength(1):settext("VSRG Hub") end) .. { Name = "Logo" }
bars[#bars + 1] = TW.text(M(10.5), true, function(self)
	self:align(0, 0.5):xy(M(10), SCREEN_HEIGHT - M(29)):shadowlength(1)
	self:settext("Etterna " .. GAMESTATE:GetEtternaVersion() .. " powered")
end) .. { OnCommand = function(self) self:x(M(18) + self:GetParent():GetChild("Logo"):GetZoomedWidth()) end }
bars[#bars + 1] = TW.text(M(10.5), false, function(self)
	self:align(0, 0.5):xy(M(10), SCREEN_HEIGHT - M(15)):shadowlength(1):diffusealpha(0.85)
	self:settext("with Quaver, Qwilight and osu! songs")
end) .. { OnCommand = function(self) self:x(M(18) + self:GetParent():GetChild("Logo"):GetZoomedWidth()) end }
bars[#bars + 1] = TW.text(M(10), false, function(self)
	self:align(1, 0.5):xy(SCREEN_WIDTH - M(12), SCREEN_HEIGHT - M(15)):shadowlength(1):diffusealpha(0.8)
	self:settext(TW_SKIN and ("skin: " .. TW_SKIN.name) or "skin: osu! default")
	self:maxwidth(SCREEN_WIDTH * 0.4 / self:GetZoom())
end)
t[#t + 1] = bars

return t
