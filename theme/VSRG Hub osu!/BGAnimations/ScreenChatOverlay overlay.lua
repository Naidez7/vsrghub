-- Etterna's multiplayer chat, only where multiplayer is: on the online screens (lobby, room, their
-- song select and results). Etterna's own overlay keeps showing it after you have once been online,
-- even back in single player (e.g. on every results screen); here it stays out of the way, and its
-- keys (Insert, /, typing) do nothing off the online screens.
local function onNetScreen()
	local s = SCREENMAN:GetTopScreen()
	local n = s and s:GetName() or ""
	return n:sub(1, 9) == "ScreenNet" and n ~= "ScreenNetSelectProfile"
end

local inner = LoadActor("/Themes/_fallback/BGAnimations/ScreenChatOverlay overlay.lua")
local orig = MPinput
if orig then
	MPinput = function(event)
		if not onNetScreen() then return false end
		return orig(event)
	end
end

return Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function(s) s:visible(onNetScreen()) end)
		self:SetUpdateFunctionInterval(0.1)
	end,
	inner,
}
