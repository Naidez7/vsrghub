-- The song's background, dimmed, behind Quaver's results.
return Def.ActorFrame {
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(color("#000000")) end },
	Def.Sprite { OnCommand = function(self)
		local s = GAMESTATE:GetCurrentSong()
		local p = s and TW.bigPicture(s)
		if p then self:LoadBackground(p):scaletocover(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT):diffusealpha(0.16) end
	end },
}
