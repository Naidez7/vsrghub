-- Til Death's system layer plus the pointer picked in the options (Quaver's by default; hidden while playing).
-- Etterna draws the system layer's "error" part (where VSRG Hub's pause menu lives) after this one:
-- once loaded this part moves on top, so the pointer shows over the pause menu.
return Def.ActorFrame {
	TW.base("BGAnimations/ScreenSystemLayer overlay"),
	TW.volumeHook(),
	TW.volumeDisplay(TW.rgb(5, 155, 172)),
	TW.choosablePointer(),
	InitCommand = function(self) self:queuecommand("Lift") end,
	LiftCommand = function(self)
		local p = self:GetParent()
		if p and p.SortByDrawOrder then self:draworder(100); p:SortByDrawOrder() end
	end,
}
