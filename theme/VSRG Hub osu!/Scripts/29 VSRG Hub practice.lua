-- Practice mode in the osu! and Quaver looks, as Etterna has it: the song plays on Etterna's
-- practice screen (nothing is scored), with a bar along the bottom showing how dense the chart is
-- through the whole song.
--   click the bar             jump there
--   right click (Ctrl+click)  set where a loop starts, then where it ends (the part then repeats);
--                             right click the same spot again to go back to just a bookmark
--   Backspace                 back to the bookmark / start of the loop
--   Esc                       pause (the pause menu quits)
-- Turned on with the Practice mod (osu!: PR on the mods panel; Quaver: PRACTICE in Modifiers), and
-- Tab on song select still plays from the preview's position in practice mode.

TW.practiceOn = TW.practiceOn or false
function TW.setPractice(on)
	TW.practiceOn = on == true
	pcall(function() GAMESTATE:SetPracticeMode(TW.practiceOn) end)
	MESSAGEMAN:Broadcast("TWPracticeChanged")
end
-- song select puts practice mode back on when it comes up (Etterna turns it off there)
function TW.keepPractice()
	if TW.practiceOn then pcall(function() GAMESTATE:SetPracticeMode(true) end) end
end
function TW.inPractice()
	local replay = GAMESTATE:GetPlayerState():GetPlayerController() == "PlayerController_Replay"
	return GAMESTATE:IsPracticeMode() and not replay and not TW.customize
end

local function fmt(s)
	s = math.max(0, s)
	return string.format("%d:%04.1f", math.floor(s / 60), s % 60)
end

-- o: text(px, bold, init), accent (colour)
function TW.practiceBar(o)
	if not TW.inPractice() then return Def.Actor {} end
	local M = TW.M
	local text = o and o.text or TW.text
	local accent = o and o.accent or TW.pink
	local W, H = math.floor(SCREEN_WIDTH * 0.62), M(34)
	local X, Y = SCREEN_CENTER_X - W / 2, SCREEN_HEIGHT - M(26) - H
	local last = 1
	pcall(function() last = math.max(1, GAMESTATE:GetCurrentSteps():GetLastSecond()) end)
	local loopStart, loopEnd = nil, nil
	local function top() return SCREENMAN:GetTopScreen() end
	local function posAt(mx) return math.max(0, math.min(1, (mx - X) / W)) * last end

	local function region(pos)
		local s = top()
		if pos < 0 or not s then return end
		if not loopStart and not loopEnd then loopStart = pos
		elseif pos == loopStart or pos == loopEnd then
			loopEnd = nil; loopStart = pos
			pcall(function() s:ResetLoopRegion() end)
		elseif not loopEnd then
			if loopStart < pos then loopEnd = pos else loopEnd = loopStart; loopStart = pos end
		else
			if math.abs(pos - loopStart) < math.abs(pos - loopEnd) then loopStart = pos else loopEnd = pos end
		end
		if loopStart and loopEnd then pcall(function() s:SetLoopRegion(loopStart, loopEnd) end) end
		MESSAGEMAN:Broadcast("TWPracticeRegion")
	end
	local function seek(pos)
		local s = top()
		if s and s.SetSongPosition then pcall(function() s:SetSongPosition(pos, 0, false) end) end
	end

	local function input(event)
		if event.type ~= "InputEventType_FirstPress" then return false end
		local b = event.DeviceInput.button
		if b == "DeviceButton_backspace" and loopStart then
			local s = top()
			if s and s.SetSongPositionAndUnpause then pcall(function() s:SetSongPositionAndUnpause(loopStart, 1, true) end) end
			return true
		end
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
		local over = mx >= X and mx <= X + W and my >= Y - M(6) and my <= Y + H + M(6)
		if not over then return false end
		if b == "DeviceButton_left mouse button" then
			if INPUTFILTER:IsControlPressed() then region(posAt(mx)) else seek(posAt(mx)) end
			return true
		elseif b == "DeviceButton_right mouse button" then
			region(posAt(mx))
			return true
		end
		return false
	end

	local f = Def.ActorFrame {
		OnCommand = function(self)
			Arch.setCursorVisible(true)
			top():AddInputCallback(input)
			self:SetUpdateFunction(function()
				local s = top()
				local pos = 0
				pcall(function() pos = s:GetSongPosition() end)
				local p = math.max(0, math.min(1, pos / last))
				self:GetChild("Fill"):zoomto(W * p, H)
				self:GetChild("Head"):x(X + W * p)
				self:GetChild("Now"):settext(fmt(pos / getCurRateValue()) .. " / " .. fmt(last / getCurRateValue()))
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				local over = mx >= X and mx <= X + W and my >= Y - M(6) and my <= Y + H + M(6)
				local hov, tip = self:GetChild("Hover"), self:GetChild("Tip")
				hov:visible(over); tip:visible(over)
				if over then
					hov:x(mx)
					tip:x(math.max(X + M(30), math.min(X + W - M(30), mx))):settext(fmt(posAt(mx) / getCurRateValue()))
				end
			end)
		end,
		-- a dark see-through bar like osu!'s bottom bar
		Def.Quad { InitCommand = function(self)
			self:align(0, 0):xy(X - M(6), Y - M(6)):zoomto(W + M(12), H + M(26))
			TW.glassify(self, "panel", { 0.05, 0.05, 0.07, 0.72 })
		end },
		Def.Quad { Name = "Fill", InitCommand = function(self) self:align(0, 0):xy(X, Y):zoomto(0, H):diffuse(accent):diffusealpha(0.18) end },
		-- how dense the chart is through the song
		Def.ActorMultiVertex {
			InitCommand = function(self) self:xy(X, Y + H) end,
			OnCommand = function(self)
				local v = nil
				pcall(function() v = GAMESTATE:GetCurrentSteps():GetCDGraphVectors(math.max(0.05, getCurRateValue()))[1] end)
				local verts = {}
				if v and #v > 0 then
					local maxv = 1
					for i = 1, #v do maxv = math.max(maxv, v[i]) end
					local bw = W / #v
					for i = 1, #v do
						local h = H * 0.92 * v[i] / maxv
						local a = 0.25 + 0.55 * v[i] / maxv
						local c = { 1, 1, 1, a }
						local x0, x1 = (i - 1) * bw, i * bw
						verts[#verts + 1] = { { x0, 0, 0 }, c }; verts[#verts + 1] = { { x1, 0, 0 }, c }
						verts[#verts + 1] = { { x1, -h, 0 }, c }; verts[#verts + 1] = { { x0, -h, 0 }, c }
					end
				end
				if #verts > 0 then self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(verts) end
			end,
		},
		-- the loop (purple) or bookmark (blue line)
		Def.Quad {
			Name = "Loop",
			InitCommand = function(self) self:align(0, 0):y(Y):visible(false) end,
			TWPracticeRegionMessageCommand = function(self)
				if not loopStart then self:visible(false) return end
				self:visible(true):x(X + W * loopStart / last)
				if loopEnd then
					self:zoomto(math.max(2, W * (loopEnd - loopStart) / last), H):diffuse(color("0.7,0.2,0.7,0.45"))
				else
					self:zoomto(2, H):diffuse(color("0.2,0.5,1,1"))
				end
			end,
		},
		Def.Quad { Name = "Head", InitCommand = function(self) self:align(0.5, 0):y(Y):zoomto(2, H):diffuse(accent) end },
		Def.Quad { Name = "Hover", InitCommand = function(self) self:align(0.5, 0):y(Y):zoomto(1, H):diffuse(color("1,1,1,0.8")):visible(false) end },
		text(M(11), true, function(self) self:align(0.5, 1):y(Y - M(8)):visible(false) end) .. { Name = "Tip" },
		text(M(10), false, function(self) self:align(0, 0.5):xy(X, Y + H + M(8)):diffusealpha(0.75)
			self:settext("PRACTICE   click: jump   right click: loop start / end   Backspace: back to it   Esc: pause")
			self:maxwidth((W * 0.75) / self:GetZoom())
		end),
		text(M(10), true, function(self) self:align(1, 0.5):xy(X + W, Y + H + M(8)):diffusealpha(0.9) end) .. { Name = "Now" },
	}
	return Def.ActorFrame { f, TW.mouse() }
end
