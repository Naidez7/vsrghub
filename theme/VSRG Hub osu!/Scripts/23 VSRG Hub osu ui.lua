-- osu!'s dialogs (exit confirmation, beatmap options): a dark screen, the question at the top left
-- in large type and a column of rounded buttons numbered 1, 2, 3... Number keys, arrows and Enter,
-- Esc or a click work, as in osu!.

local dialogColours = {
	green = { TW.rgb(64, 88, 14), TW.rgb(150, 200, 40) },
	red = { TW.rgb(108, 24, 8), TW.rgb(230, 70, 40) },
	purple = { TW.rgb(82, 46, 96), TW.rgb(180, 120, 210) },
	grey = { TW.rgb(52, 52, 52), TW.rgb(130, 130, 130) },
}

TW.dialogSpec = nil
local dialogSel = 1

-- spec = { lines = { "title", "question" }, buttons = { { "Label", "green", function() end }, ... } }
function TW.openDialog(spec)
	TW.dialogSpec = spec
	dialogSel = 1
	SCREENMAN:set_input_redirected(PLAYER_1, true)
	MESSAGEMAN:Broadcast("TWDialog")
end
function TW.closeDialog()
	if not TW.dialogSpec then return end
	TW.dialogSpec = nil
	SCREENMAN:set_input_redirected(PLAYER_1, TW.optionsOpen == true or TW.keepRedirect == true)
	MESSAGEMAN:Broadcast("TWDialog")
end
local function press(i)
	local spec = TW.dialogSpec
	local b = spec and spec.buttons[i]
	if not b then return end
	TW.closeDialog()
	if b[3] then b[3]() end
end
-- (for a look that draws the dialog its own way: osu!lazer's)
TW.dialogPress = function(i) press(i) end
function TW.dialogSelected() return dialogSel end
function TW.dialogSelect(i) if dialogSel ~= i then dialogSel = i; MESSAGEMAN:Broadcast("TWDialog") end end
function TW.dialogInput(event)
	local spec = TW.dialogSpec
	if not spec then return false end
	-- the mouse goes on to the buttons (Til Death's mouse layer reads it after this callback)
	if event.DeviceInput.is_mouse and not event.DeviceInput.button:find("mousewheel") then return false end
	if event.type ~= "InputEventType_FirstPress" or event.DeviceInput.is_mouse then return true end
	local b = event.DeviceInput.button
	local n = tonumber((b:match("^DeviceButton_(%d)$")))
	if n then press(n)
	elseif b == "DeviceButton_escape" then press(#spec.buttons) -- the last one is always Cancel
	elseif b == "DeviceButton_up" then dialogSel = math.max(1, dialogSel - 1); MESSAGEMAN:Broadcast("TWDialog")
	elseif b == "DeviceButton_down" then dialogSel = math.min(#spec.buttons, dialogSel + 1); MESSAGEMAN:Broadcast("TWDialog")
	elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" then press(dialogSel) end
	return true
end

function TW.dialogPanel()
	local M = TW.M
	local BW, BH = M(722), M(54)
	local cx = SCREEN_CENTER_X
	local t = Def.ActorFrame {
		Name = "TWDialogPanel",
		InitCommand = function(self) self:z(70):visible(false) end,
		TWDialogMessageCommand = function(self)
			local spec = TW.dialogSpec
			if not spec then self:stoptweening():linear(0.1):diffusealpha(0):queuecommand("Hide") return end
			if not self:GetVisible() then self:visible(true):diffusealpha(0):linear(0.12):diffusealpha(1) end
			self:playcommand("Fill")
		end,
		HideCommand = function(self) self:visible(false) end,
		Def.Quad { InitCommand = function(self) TW.shade(self:FullScreen(), 0.86) end },
		-- a darker band under the question, so the screen's own top lines don't show through it
		Def.Quad { Name = "Band", InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, M(80)):diffuse({ 0.02, 0.02, 0.03, 0.96 }):diffusebottomedge({ 0.02, 0.02, 0.03, 0.88 }) end },
		TW.button(1, 1, function() end) .. { InitCommand = function(self) self:FullScreen():diffusealpha(0) end },
		TW.text(M(26), false, function(self) self:align(0, 0):xy(M(10), M(4)):shadowlength(2) end) .. {
			FillCommand = function(self)
				self:settext(table.concat(TW.dialogSpec.lines, "\n")):maxwidth((SCREEN_WIDTH - M(20)) / self:GetZoom())
				self:GetParent():GetChild("Band"):zoomto(SCREEN_WIDTH, math.max(M(100), self:GetZoomedHeight() + M(14)))
			end
		},
	}
	for i = 1, 7 do
		t[#t + 1] = Def.ActorFrame {
			InitCommand = function(self) self:z(2) end,
			FillCommand = function(self)
				local spec = TW.dialogSpec
				local b = spec.buttons[i]
				self:visible(b ~= nil)
				if not b then return end
				local n = #spec.buttons
				local top = SCREEN_CENTER_Y - (n * M(85)) / 2 + M(30)
				self:xy(cx, top + (i - 1) * M(85))
				local col = dialogColours[b[2]] or dialogColours.grey
				local c = self:GetChildren()
				TW.setBox(c.Bg, { col = TW.mix(col[1], { 1, 1, 1, 1 }, 0.1), col2 = col[1] })
				TW.setBox(c.Edge, { col = col[2] })
				c.Label:settext(i .. ". " .. b[1])
				self:stoptweening():decelerate(0.1):zoom(i == dialogSel and 1.04 or 1)
				c.Edge:diffusealpha(i == dialogSel and 1 or 0.6)
			end,
			-- the lighter edge, then the button over it
			TW.shadow { w = BW, h = BH, ax = 0.5, ay = 0.5, spread = M(12), alpha = 0.45, drop = M(3) },
			TW.box { w = BW + M(5), h = BH + M(5), r = (BH + M(5)) / 2, ax = 0.5, ay = 0.5 } .. { Name = "Edge" },
			TW.box { w = BW, h = BH, r = BH / 2, ax = 0.5, ay = 0.5 } .. { Name = "Bg" },
			TW.box { w = BW - M(10), h = BH * 0.45, r = BH * 0.22, ax = 0.5, ay = 0, col = { 1, 1, 1, 0.14 }, col2 = { 1, 1, 1, 0 }, init = function(self) self:y(-BH / 2 + M(3)) end },
			TW.text(M(24), false, function(self) self:align(0.5, 0.5):y(-M(1)):shadowlength(1) end) .. { Name = "Label" },
			TW.button(BW, BH, function() press(i) end, function(self, on)
				if on and dialogSel ~= i then dialogSel = i; MESSAGEMAN:Broadcast("TWDialog") end
			end) .. { InitCommand = function(self) self:zoomto(BW, BH):diffusealpha(0) end },
		}
	end
	return t
end

-- osu!'s "back" button, bottom left: a slanted tab in the interface colour that slides out under
-- the mouse (the results, the options panel...)
function TW.backTab(onClick, label)
	local M = TW.M
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(0, SCREEN_HEIGHT) end,
		TW.shadow { w = M(140), h = M(44), ay = 1, spread = M(10), alpha = 0.45, init = function(self) self:xy(-M(14), -M(8)) end },
		TW.box { w = M(140), h = M(44), r = M(10), shear = 0.15, ay = 1, col = TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.1), col2 = TW.pink, init = function(self) self:xy(-M(14), -M(8)) end } .. { Name = "Bg" },
		TW.text(M(17), true, function(self) self:align(0, 0.5):xy(M(48), -M(30)):settext(label or "back"):shadowlength(1) end),
		TW.icon("chevron-left", M(14), function(self) self:xy(M(30), -M(30)) end),
		TW.button(M(130), M(44), function() onClick() end, function(self, on)
			self:GetParent():GetChild("Bg"):stoptweening():decelerate(0.1):x(on and 0 or -M(14))
		end) .. { InitCommand = function(self) self:align(0, 1):y(-M(8)):zoomto(M(130), M(44)):diffusealpha(0) end },
	}
end
