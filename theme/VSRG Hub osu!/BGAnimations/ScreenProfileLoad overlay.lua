-- Etterna's profile-load moment between the main menu and song select (its "Loading Profiles..."
-- band with a second's wait): nothing to see here, it goes straight on. The menu's song keeps
-- playing through it (metrics.ini: PlayMusic=false), so Play to song select is one motion, as osu!'s.
return Def.ActorFrame {
	Def.Actor {
		BeginCommand = function(self) self:queuecommand("Load") end,
		LoadCommand = function() SCREENMAN:GetTopScreen():Continue() end,
	},
}
