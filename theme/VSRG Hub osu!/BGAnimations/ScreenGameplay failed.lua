-- Failing a song: straight to the results. Etterna keeps judging while this transition plays (Til
-- Death's is a 2-second fade), so every key and miss in it would still change the play's accuracy;
-- with no length the play stops where it was lost, and the results show the accuracy you died with.
return Def.Quad {
	InitCommand = function(self) self:FullScreen():diffuse(color("#000000")) end,
}
