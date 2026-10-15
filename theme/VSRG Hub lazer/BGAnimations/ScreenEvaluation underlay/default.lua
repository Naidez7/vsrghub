-- osu!lazer's results behind the card: the song's picture, darkened, with lazer's wine-red tint.
TW.useInterfaceSkin()
local function cover(self) self:scaletocover(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT) end
return Def.ActorFrame { Def.ActorFrame {
	InitCommand = function(self) TW.frostTarget = self end,
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(LZ.hsl(333, 0.2, 0.08)) end },
	Def.Sprite { OnCommand = function(self)
		local s = GAMESTATE:GetCurrentSong()
		local p = s and s:GetBackgroundPath()
		if p then self:LoadBackground(p); cover(self); self:diffusealpha(0):linear(0.5):diffusealpha(0.3) end
	end },
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse({ 0, 0, 0, 0.2 }):diffusebottomedge({ 0.05, 0.02, 0.05, 0.6 }) end },
}, TW.frostSource() }
