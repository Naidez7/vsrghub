-- Song select, starting a song: the fade to black, and (with Til Death's "press Start again for the
-- player options" hint on) the hint as a VSRG Hub pill instead of Til Death's purple bar.
local M = TW.M
local t = Def.ActorFrame {
	Def.Quad {
		InitCommand = function(self) self:FullScreen():diffuse({ 0, 0, 0, 0 }) end,
		OnCommand = function(self) self:sleep(0.05):linear(0.2):diffusealpha(1) end,
	},
}
local hint = true
pcall(function() hint = themeConfig:get_data().global.ShowPlayerOptionsHint end)
if not hint then return t end

local W, H = M(520), M(62)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:Center():diffusealpha(0) end,
	ShowPressStartForOptionsCommand = function(self) self:zoom(0.92):decelerate(0.2):diffusealpha(1):zoom(1) end,
	HidePressStartForOptionsCommand = function(self) self:decelerate(0.15):diffusealpha(0) end,
	TW.shadow { w = W, h = H, ax = 0.5, ay = 0.5, spread = M(14), alpha = 0.5, drop = M(3) },
	TW.box { w = W, h = H, r = H / 2, ax = 0.5, ay = 0.5, col = { 0.13, 0.12, 0.18, 0.96 }, col2 = { 0.08, 0.08, 0.12, 0.96 } },
	TW.box { w = W, h = H, r = H / 2, ax = 0.5, ay = 0.5, tex = "ring", col = TW.pink },
	TW.text(M(19), true, function(self) self:align(0.5, 0.5):maxwidth((W - H) / self:GetZoom()) end) .. {
		ShowPressStartForOptionsCommand = function(self) self:settext("Press Enter again for player options") end,
		ShowEnteringOptionsCommand = function(self) self:settext("Opening the player options...") end,
	},
}
return t
