-- Quaver's bars on the results screen.
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
return Def.ActorFrame {
	TW.mouse(),
	OnCommand = function(self) SCREENMAN:GetTopScreen():AddInputCallback(input) end,
	OffCommand = function(self) TW.closeOptions() end,
	QV.navbar(),
	QV.bottombar({ { "< BACK", leave, nil, 95 }, { "OPTIONS", function() TW.toggleOptions() end, nil, 120 } },
		-- Quaver's Watch Replay (when the score has one)
		TW.canWatchReplay() and { { "WATCH REPLAY", function() TW.watchReplay() end, nil, 150 }, { "CONTINUE >", leave } }
			or { { "CONTINUE >", leave } }),
	QV.optionsPanel(),
	QV.windowsDialog(),
	TW.listPanel(),
	TW.danOverlay("ScreenEvaluation overlay/dan_overlay_eval.lua"),
}
