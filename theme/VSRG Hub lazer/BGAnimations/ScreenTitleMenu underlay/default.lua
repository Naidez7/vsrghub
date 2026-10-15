-- osu!lazer's main menu, behind the button bar: the menu song's picture, dimmed, over lazer's dark
-- backdrop with big soft triangles, outlined triangles drifting up in pink and orange, and the
-- small print at the bottom.
TW.useInterfaceSkin()
local M = TW.M

local function randomBackground()
	local songs = SONGMAN:GetAllSongs()
	for _ = 1, 20 do
		local s = songs[math.random(1, math.max(1, #songs))]
		local p = s and TW.bigPicture(s)
		if p and p ~= "" and FILEMAN:DoesFileExist(p) then return p end
	end
	return nil
end

-- big dark triangles that stay put (lazer's "triangles" backdrop), drawn once
local function backdrop()
	local verts = {}
	-- (the same pattern every time: a little generator of its own)
	local seed = 7
	local function rnd() seed = (seed * 16807) % 2147483647; return seed / 2147483647 end
	for _ = 1, 46 do
		local s = M(90) + rnd() * M(260)
		local x, y = rnd() * SCREEN_WIDTH, rnd() * (SCREEN_HEIGHT + s) - s / 2
		local a = 0.05 + rnd() * 0.16
		local c = { 0, 0, 0, a }
		local up = rnd() < 0.7
		local h = s * 0.866
		if up then
			verts[#verts + 1] = { { x - s / 2, y + h / 2, 0 }, c }; verts[#verts + 1] = { { x + s / 2, y + h / 2, 0 }, c }; verts[#verts + 1] = { { x, y - h / 2, 0 }, c }
		else
			verts[#verts + 1] = { { x - s / 2, y - h / 2, 0 }, c }; verts[#verts + 1] = { { x + s / 2, y - h / 2, 0 }, c }; verts[#verts + 1] = { { x, y + h / 2, 0 }, c }
		end
	end
	return Def.ActorMultiVertex { InitCommand = function(self) self:SetDrawState { Mode = "DrawMode_Triangles" }:SetVertices(verts) end }
end

local bg = Def.ActorFrame {
	InitCommand = function(self) TW.frostTarget = self end,
	-- lazer's dark blue backdrop (its "triangles" background)
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(LZ.hsl(218, 0.32, 0.17)):diffusebottomedge(LZ.hsl(222, 0.34, 0.09)) end },
}
local pic = Def.Sprite {
	Name = "Pic",
	InitCommand = function(self)
		local p = randomBackground()
		if p then self:LoadBackground(p) end
		self:scaletocover(-M(20), -M(20), SCREEN_WIDTH + M(20), SCREEN_HEIGHT + M(20))
		self:diffusealpha(0):linear(0.8):diffusealpha(0.2)
	end,
	-- the menu's song changed: its picture
	TWMenuMusicMessageCommand = function(self)
		if not TW.menu.song then return end
		local p = TW.bigPicture(TW.menu.song)
		if not p or p == "" or p == self.shown then return end
		self.shown = p
		self:stoptweening():linear(0.3):diffusealpha(0):queuecommand("Swap")
	end,
	SwapCommand = function(self)
		local x, y = self:GetX(), self:GetY()
		self:LoadBackground(self.shown):scaletocover(-M(20), -M(20), SCREEN_WIDTH + M(20), SCREEN_HEIGHT + M(20)):xy(x, y)
		self:linear(0.6):diffusealpha(0.2)
	end,
}
bg[#bg + 1] = Def.ActorFrame { InitCommand = function(self) TW.parallax(self, M(10)) end, pic }
bg[#bg + 1] = Def.ActorFrame { InitCommand = function(self) TW.parallax(self, M(18)) end, backdrop() }
-- the edges darker, so the bar and the toolbar stand out
bg[#bg + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH * 0.35, SCREEN_HEIGHT):diffuse({ 0.05, 0.03, 0.08, 0.5 }):diffuserightedge({ 0, 0, 0, 0 }) end }
bg[#bg + 1] = Def.Quad { InitCommand = function(self) self:align(1, 0):x(SCREEN_WIDTH):zoomto(SCREEN_WIDTH * 0.35, SCREEN_HEIGHT):diffuse({ 0, 0, 0, 0 }):diffuserightedge({ 0.05, 0.03, 0.08, 0.5 }) end }

local t = Def.ActorFrame { bg }
t[#t + 1] = TW.frostSource()
-- outlined triangles drifting up (in front of the picture, behind the buttons)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) TW.parallax(self, M(26)) end,
	LZ.triangles(SCREEN_WIDTH, SCREEN_HEIGHT, 30),
}

-- light from the sides on the music's strong beats (lazer's menu side flashes)
t[#t + 1] = TW.sideFlashes(LZ.pinkLight, TW.M(260))

-- the small print
t[#t + 1] = LZ.text(M(11), "bold", function(self) self:align(0, 1):xy(M(12), SCREEN_HEIGHT - M(26)):settext("VSRG Hub"):diffusealpha(0.9) end)
t[#t + 1] = LZ.text(M(9.5), "regular", function(self)
	self:align(0, 1):xy(M(12), SCREEN_HEIGHT - M(11)):diffusealpha(0.65)
	self:settextf("Etterna %s  ·  %d songs  ·  Quaver, Qwilight and osu! charts", GAMESTATE:GetEtternaVersion(), SONGMAN:GetNumSongs())
end)
return t
