-- The back tab at the bottom left to leave the results, Watch replay, and the options panel.
TW.useInterfaceSkin()
local U = TW.U
local function leave() SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen") end
-- osu!'s back button: the skin's menu-back at the bottom left (as on song select), or osu!'s pink
-- back tab
local f
if TW.has("menu_back") then
	f = Def.ActorFrame {
		InitCommand = function(self) self:xy(0, SCREEN_HEIGHT) end,
		TW.sprite("menu_back", function(self) self:align(0, 1) end) .. { Name = "Img" },
		TW.button(U * 200, U * 64, leave, function(self, on)
			self:GetParent():GetChild("Img"):stoptweening():decelerate(0.1):diffuse(on and { 1, 1, 1, 1 } or { 0.92, 0.92, 0.92, 1 })
		end) .. { InitCommand = function(self) self:align(0, 1):zoomto(U * 200, U * 64):diffusealpha(0) end },
	}
else
	f = TW.backTab(leave)
end
-- Ctrl+O opens VSRG Hub's options here too (as on the main menu and song select)
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
-- osu!'s "Watch replay" on the ranking screen (when the score has one). osu! puts it at the bottom
-- right, but that's where VSRG Hub draws the hit offsets, so it goes at the bottom left, above the
-- back tab: the skin's ranking-replay when it has one, VSRG Hub's pill otherwise.
local replay
if not TW.canWatchReplay() then
	replay = Def.Actor {}
elseif TW.has("ranking_replay") then
	replay = Def.ActorFrame {
		InitCommand = function(self) self:xy(U * 16, U * 672) end,
		TW.sprite("ranking_replay", function(self) self:align(0, 0.5) end) .. { Name = "Img" },
		TW.button(U * 170, U * 90, function() TW.watchReplay() end, function(self, on)
			self:GetParent():GetChild("Img"):stoptweening():decelerate(0.1):zoom(TW.scale("ranking_replay") * (on and 1.05 or 1))
		end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(U * 170, U * 90):diffusealpha(0) end },
	}
else
	replay = TW.replayButton(U * 210, U * 46, TW.text, TW.pink) .. {
		InitCommand = function(self) self:xy(U * 121, U * 680) end,
	}
end
return Def.ActorFrame { TW.mouse(), f, replay,
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
		-- (your play, for VSRG Hub's online ranking: 28 VSRG Hub online.lua)
		if TW.exportScore then TW.exportScore() end
	end,
	-- (what VSRG Hub's ranking made of it, at the bottom)
	TW.goalResult and TW.goalResult(SCREEN_CENTER_X, SCREEN_HEIGHT - TW.M(40), function(init) return TW.text(TW.M(14), true, init) end) or Def.Actor {},
	TW.hubResultLine and TW.hubResultLine(SCREEN_CENTER_X, SCREEN_HEIGHT - TW.M(16), function(init) return TW.text(TW.M(13), true, init) end) or Def.Actor {},
	OffCommand = function(self) TW.closeOptions() end,
	TW.optionsPanel(), TW.listPanel(),
	TW.danOverlay("ScreenEvaluation overlay/dan_overlay_eval.lua"),
	TW.failedCover(function(px, init) return TW.text(px, true, init) end, TW.rgb(255, 80, 80)) }
