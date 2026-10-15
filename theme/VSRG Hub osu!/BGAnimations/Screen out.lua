-- Leaving a screen: a quick, smooth fade to black.
return Def.Quad {
	InitCommand = function(self) self:FullScreen():diffuse({ 0, 0, 0, 0 }) end,
	OnCommand = function(self) self:linear(0.22):diffusealpha(1) end,
}
