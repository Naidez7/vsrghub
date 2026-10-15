-- The splash Etterna shows while it starts (and after a theme switch), in Quaver's style: the
-- VSRG Hub logo fading in over Quaver's dark blue, instead of Til Death's name.
local h = SCREEN_HEIGHT * 0.09
local function skip() local s = SCREENMAN:GetTopScreen(); if s then s:StartTransitioningScreen("SM_GoToNextScreen") end end
return Def.ActorFrame {
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(TW.rgb(14, 16, 24)) end },
	-- a thin cyan line that draws across under the logo
	Def.Quad { InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + h * 0.95):zoomto(0, math.max(1, h * 0.03)):diffuse(QV.cyan)
	end, OnCommand = function(self)
		self:sleep(0.3):decelerate(0.6):zoomx(h * 6.5):sleep(1.1):linear(0.4):diffusealpha(0)
	end },
	Def.ActorFrame {
		Name = "Logo",
		InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - h * 0.5) end,
		LeftClickMessageCommand = skip,
		OnCommand = function(self)
			-- centre the ring and word as one piece
			local word = self:GetChild("Logo"):GetChild("Word")
			local w = h * 0.42 * 2.35 + (word and word:GetZoomedWidth() or h * 3)
			self:addx(-w / 2):diffusealpha(0):addy(h * 0.15):decelerate(0.5):diffusealpha(1):addy(-h * 0.15)
				:sleep(1.3):linear(0.4):diffusealpha(0)
		end,
		QV.logo(h) .. { Name = "Logo" },
	},
}
