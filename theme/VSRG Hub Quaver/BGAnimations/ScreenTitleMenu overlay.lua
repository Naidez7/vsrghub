-- Mouse and keys for Quaver's main menu (the buttons are Graphics/ScreenTitleMenu scroll.lua).
-- Clicking does what Enter does: the player is joined first, or song select has no style.
local function choose(name)
	local top = SCREENMAN:GetTopScreen()
	if top then
		top:playcommand("MadeChoicePlayer_1")
		top:playcommand("Choose")
	end
	if name == "GameStart" or name == "Multi" then
		GAMESTATE:JoinPlayer()
		-- starting from the title applies the profile's default modifiers (its noteskin among them);
		-- song select then puts VSRG Hub's saved noteskin back instead of taking that one as a change
		TW.syncedOnce = {}
	end
	GAMESTATE:ApplyGameCommand(THEME:GetMetric("ScreenTitleMenu", "Choice" .. name))
end
local actions = {
	[0] = function() choose("GameStart") end,
	[1] = function() TW.startMulti(function() choose("Multi") end) end,
	[2] = function() TW.openOptions() end,
	[3] = function() MESSAGEMAN:Broadcast("QVAskQuit") end,
}
-- Quaver asks before quitting
local asking = false
local askedAt = 0
local function setAsking(on)
	asking = on
	askedAt = GetTimeSinceStart()
	SCREENMAN:set_input_redirected(PLAYER_1, on or TW.optionsOpen == true)
	MESSAGEMAN:Broadcast("QVQuitDialog", { on = on })
end
local function quit() SCREENMAN:SetNewScreen("ScreenExit") end
local function input(event)
	if asking then
		if event.DeviceInput.is_mouse then return false end -- the YES / NO buttons take clicks
		-- (the Enter that chose Quit reaches this callback too, right after: not an answer)
		if event.type == "InputEventType_FirstPress" and not event.DeviceInput.is_mouse and GetTimeSinceStart() - askedAt > 0.15 then
			local b = event.DeviceInput.button
			if b == "DeviceButton_escape" then setAsking(false)
			elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" then setAsking(false); quit() end
		end
		return true
	end
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
-- Esc on the main menu asks to quit, as in Quaver (Etterna would go back to the splash screen; its
-- screen sees keys before this screen's callbacks, so VSRG Hub's system layer asks this first)
local function gate(event)
	if event.type ~= "InputEventType_FirstPress" or event.DeviceInput.button ~= "DeviceButton_escape" then return false end
	local top = SCREENMAN:GetTopScreen()
	if not top or top:GetName() ~= "ScreenTitleMenu" or asking or TW.optionsOpen or TW.list then return false end
	MESSAGEMAN:Broadcast("QVAskQuit")
	return true
end
local t = Def.ActorFrame {
	TW.mouse(),
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
		TWSystemInput = gate
		-- (Etterna locks the menu's input while the screen's longest opening animation runs: unlocked
		-- on the next frame, after it has set that lock)
		self:queuecommand("Unlock")
		self:sleep(0.05):queuecommand("Theme")
	end,
	UnlockCommand = function(self)
		local top = SCREENMAN:GetTopScreen()
		if top and top.lockinput then top:lockinput(0) end
	end,
	ThemeCommand = function(self)
		if not TW.enforceTheme() and TW.takeResume() then choose("GameStart") end
	end,
	OffCommand = function(self) if TWSystemInput == gate then TWSystemInput = nil end; TW.closeOptions() end,
	TWTitleChooseMessageCommand = function(self, p)
		local f = actions[p.index]
		if f then f() end
	end,
	QVAskQuitMessageCommand = function() setAsking(true) end,
	QV.optionsPanel(),
	QV.windowsDialog(),
	TW.listPanel(),
	TW.multiStatus(),
	TW.updateNotice(),
}
do
	local M = TW.M
	local DW, DH = M(420), M(150)
	local dlg = QV.dialog("QuitDialog", "QUIT GAME", DW, DH)
	dlg.QVQuitDialogMessageCommand = function(self, p) self:visible(p.on) end
	local body = dlg[#dlg]
	body[#body + 1] = QV.t(M(14), true, function(self) self:align(0.5, 0.5):xy(DW / 2, M(46)):settext("Are you sure you want to quit the game?") end)
	body[#body + 1] = QV.pill("YES", TW.rgb(25, 170, 100), M(146), M(28), function() setAsking(false); quit() end,
		function(self) self:xy(DW / 2 - M(80), M(108)) end)
	body[#body + 1] = QV.pill("NO", TW.rgb(244, 100, 99), M(146), M(28), function() setAsking(false) end,
		function(self) self:xy(DW / 2 + M(80), M(108)) end)
	t[#t + 1] = dlg
end
return t
