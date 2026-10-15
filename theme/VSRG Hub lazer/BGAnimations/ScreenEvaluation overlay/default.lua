-- osu!lazer's results, bottom and top: its toolbar, the big pink back button and, when the score
-- has one, a Replay button in the footer (lazer's "watch replay"); Ctrl+O opens the settings here too.
TW.useInterfaceSkin()
local M = TW.M
local function leave() SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen") end
local function input(event)
	if TW.listInput(event) then return true end
	if TW.optionsInput(event) then return true end
	if event.type == "InputEventType_FirstPress" and TW.key(event, "options", event.DeviceInput.button == "DeviceButton_o" and INPUTFILTER:IsControlPressed()) then
		TW.openOptions()
		return true
	end
	if event.type == "InputEventType_FirstPress" and TW.key(event, "keybinds", false) then
		TW.openKeybinds()
		return true
	end
	return false
end
local t = Def.ActorFrame {
	TW.mouse(),
	OnCommand = function(self) SCREENMAN:GetTopScreen():AddInputCallback(input) end,
	OffCommand = function(self) TW.closeOptions() end,
	-- the footer's shade
	Def.Quad { InitCommand = function(self)
		self:align(0, 1):xy(0, SCREEN_HEIGHT):zoomto(SCREEN_WIDTH, M(LZ.FOOT) + M(20)):diffuse({ 0, 0, 0, 0 }):diffusebottomedge({ 0, 0, 0, 0.7 })
	end },
	LZ.backButton(leave),
}
if TW.canWatchReplay() then
	t[#t + 1] = LZ.footerButton { x = SCREEN_CENTER_X - M(80), w = M(160), icon = "circle-play", label = "Watch replay", col = LZ.pink, onClick = function() TW.watchReplay() end }
end
t[#t + 1] = LZ.toolbar { home = leave }
t[#t + 1] = TW.optionsPanel()
t[#t + 1] = TW.listPanel()
t[#t + 1] = TW.danOverlay("ScreenEvaluation overlay/dan_overlay_eval.lua")
return t
