-- Quaver's main menu buttons: dark boxes with a white underline; the selected one lights up with
-- the cyan-purple-pink gradient. Arrow keys and Enter work as before; clicking a button starts it.
local M = TW.M
local gc = Var("GameCommand")
local i = gc:GetIndex()
local spec = {
	{ label = "SINGLE PLAYER", icon = ">" },
	{ label = "MULTIPLAYER", icon = "*" },
	{ label = "OPTIONS", icon = "=" },
	{ label = "QUIT GAME", icon = "x", col = TW.rgb(255, 40, 70) },
}
local s = spec[i + 1] or spec[#spec]
local W, H = M(329), M(37)
local y = M(345) + i * M(51.6)
return Def.ActorFrame { Def.ActorFrame {
	InitCommand = function(self) self:xy(M(53), y) end,
	Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0):zoomto(W, H):diffuse(color("#000000")):diffusealpha(0.6) end,
		GainFocusCommand = function(self) self:stoptweening():linear(0.1):zoomto(W + M(15), H):diffuse(TW.rgb(60, 60, 75)):diffusealpha(0.75) end,
		LoseFocusCommand = function(self) self:stoptweening():linear(0.1):zoomto(W, H):diffuse(color("#000000")):diffusealpha(0.6) end },
	Def.Quad { Name = "Line", InitCommand = function(self) self:align(0, 0):y(H - M(2)):zoomto(W, M(2)):diffusealpha(0.85) end,
		GainFocusCommand = function(self) self:visible(false) end,
		LoseFocusCommand = function(self) self:visible(true) end },
	QV.gradient(W + M(15), M(4)) .. { Name = "Grad", InitCommand = function(self) self:y(H - M(3)):visible(false) end,
		GainFocusCommand = function(self) self:visible(true) end,
		LoseFocusCommand = function(self) self:visible(false) end },
	QV.t(M(13), true, function(self) self:align(0.5, 0.5):xy(M(21), H / 2):settext(s.icon):diffuse(s.col or color("#FFFFFF")) end),
	QV.t(M(14), true, function(self) self:align(0, 0.5):xy(M(41), H / 2 + M(1)):settext(s.label):diffuse(s.col or color("#FFFFFF")) end),
	-- hovering only lights the button up (Enter still starts the keyboard-selected one)
	TW.button(W, H, function() MESSAGEMAN:Broadcast("TWTitleChoose", { index = i }) end, function(self, on)
		self:GetParent():GetChild("Bg"):glow(on and color("#FFFFFF18") or color("#FFFFFF00"))
	end) .. { InitCommand = function(self) self:align(0, 0):zoomto(W, H):diffusealpha(0) end }
} }
