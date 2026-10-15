-- The song's background, dimmed like osu!'s results, with the skin's ranking-background-overlay.
TW.useInterfaceSkin()
local function cover(self) self:scaletocover(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT) end
return Def.ActorFrame { Def.ActorFrame {
	InitCommand = function(self) TW.frostTarget = self end,
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(color("#000000")) end },
	Def.Sprite { OnCommand = function(self)
		local s = GAMESTATE:GetCurrentSong()
		local p = s and TW.bigPicture(s)
		if p then self:LoadBackground(p); cover(self); self:diffusealpha(0.3) end
	end },
	TW.sprite("ranking_bg_overlay", function(self) cover(self) end),
}, TW.frostSource() }
