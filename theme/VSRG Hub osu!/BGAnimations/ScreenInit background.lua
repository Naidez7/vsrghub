-- The splash Etterna shows while it starts (and after a theme switch), in osu!'s style: the pink
-- cookie pulsing on black with "welcome" under it, instead of Til Death's name.
local r = TW.M(150)
local function skip() local s = SCREENMAN:GetTopScreen(); if s then s:StartTransitioningScreen("SM_GoToNextScreen") end end
return Def.ActorFrame {
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(color("#000000")) end },
	Def.ActorFrame {
		InitCommand = function(self) self:Center() end,
		LeftClickMessageCommand = skip,
		-- a soft glow ring that swells out behind the cookie
		TW.circle(r * 1.15, TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.2)) .. { OnCommand = function(self)
			self:diffusealpha(0):zoom(0.8):sleep(0.35):linear(0.05):diffusealpha(0.35)
				:decelerate(0.9):zoom(1.45):diffusealpha(0)
		end },
		TW.cookie(r, "VSRG Hub") .. { OnCommand = function(self)
			self:zoom(0.6):diffusealpha(0):decelerate(0.4):zoom(1):diffusealpha(1)
				:bounceend(0.15):zoom(0.96):bouncebegin(0.15):zoom(1)
				:sleep(1.4):accelerate(0.4):zoom(1.08):diffusealpha(0)
		end },
		LoadFont(TW.font) .. { Text = "welcome", InitCommand = function(self)
			self:y(r * 1.45):zoom(TW.M(30) / 24):diffuse(color("#FFFFFF")):diffusealpha(0)
		end, OnCommand = function(self)
			self:sleep(0.5):linear(0.4):diffusealpha(0.8):sleep(1):linear(0.4):diffusealpha(0)
		end },
	},
}
