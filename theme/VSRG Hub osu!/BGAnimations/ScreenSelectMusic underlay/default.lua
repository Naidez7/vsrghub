-- The selected song's background fills the screen, barely dimmed, like osu!'s song select (how dark
-- and how blurred: Options > LOOK, Scripts/28 VSRG Hub background.lua).
TW.useInterfaceSkin()
return Def.ActorFrame {
	-- (the frosted panels show this, blurred)
	TW.songBackground { name = "SongBG", base = TW.rgb(20, 20, 30), init = function(self) TW.frostTarget = self end },
	TW.frostSource(),
}
