-- The combo under the judgment, in Lato like Quaver's default skin (an osu! skin's combo font
-- when your notes come from an osu! skin).
TW.useGameplaySkin()
-- (a combo skin picked in the options, or an osu! skin's notes: the osu! look's combo, which draws both)
if (TW.comboPick and TW.comboPick()) or (TW_SKIN and TW.has("combo_0")) then return LoadActor("/Themes/VSRG Hub osu!/Graphics/Player combo") end
local M = TW.M
local t = Def.ActorFrame(TW.playerItem("combo", "Combo", function()
	return TW.stageCX(), (TW.stage and TW.stage.plY or SCREEN_CENTER_Y) + M(84)
end, M(120), M(36)))
-- the Quaver skin's own combo digits, at its ComboDisplayScale
local hud = QV.hud()
if hud and hud.combo then
	t[#t + 1] = QV.digits(hud.combo, hud.comboScale or 45, 0.5) .. { Name = "N", InitCommand = function(self) self:visible(false) end }
	t.ComboCommand = function(self, param)
		local n = self:GetChild("N")
		local c = param.Combo
		if not c or c < 1 then n:visible(false) return end
		n:visible(true):playcommand("Set", { text = tostring(c) }):stoptweening():zoom(1.08):linear(0.05):zoom(1)
	end
	return t
end
t[#t + 1] = QV.text(M(22), TW.font, function(self) self:align(0.5, 0.5):visible(false) end) .. { Name = "N" }
t.ComboCommand = function(self, param)
		local n = self:GetChild("N")
		local c = param.Combo
		if not c or c < 1 then n:visible(false) return end
		local z = M(22) / 17
		n:visible(true):settext(tostring(c)):stoptweening():zoom(z * 1.08):linear(0.05):zoom(z)
	end
return t
