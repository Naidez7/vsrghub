-- Coming into a screen: the black lifts smoothly, as osu!'s screens fade in (Til Death's waited,
-- then cut it in a tenth of a second).
return Def.Quad {
	InitCommand = function(self) self:FullScreen():diffuse({ 0, 0, 0, 1 }) end,
	OnCommand = function(self) self:decelerate(0.3):diffusealpha(0) end,
}
