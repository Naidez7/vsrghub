-- Goals: "I want 95% on this chart at this rate". Etterna keeps them in the profile and marks one
-- reached when a play beats it; here they're set with a key (Ctrl+G on song select), shown by the
-- selected chart, and the results screen says when one was reached.
--   TW.goalKey(event)                 song select's keys: Ctrl+G sets (or changes) the goal
--   TW.goalLine(x, y, textFn, align)  the goal for the selected chart at the current rate
--   TW.goalResult(x, y, textFn)       results: "Goal reached: 95%"
local function profile() return PROFILEMAN:GetProfile(PLAYER_1) end
local function rateNow() local ok, r = pcall(getCurRateValue); return ok and r or 1 end

-- the goal (ScoreGoal) for a chart at a rate: the easiest one not yet reached, else any
local function goalFor(ck, rate)
	local p = profile()
	if not p or not ck then return nil end
	local g
	pcall(function() g = p:GetEasiestGoalForChartAndRate(ck, rate) end)
	if g then return g end
	local best
	pcall(function()
		for _, sg in ipairs(p:GetGoalTable() or {}) do
			if sg:GetChartKey() == ck and math.abs(sg:GetRate() - rate) < 0.001 then
				if not best or sg:GetPercent() > best:GetPercent() then best = sg end
			end
		end
	end)
	return best
end

function TW.goalText(steps, rate)
	if not steps then return nil end
	local ck
	pcall(function() ck = steps:GetChartKey() end)
	local g = goalFor(ck, rate or rateNow())
	if not g then return nil end
	local pct, done = 0, false
	pcall(function() pct = g:GetPercent() * 100; done = g:IsAchieved() end)
	return string.format("%s %.2f%%", done and "Goal reached:" or "Goal:", pct), done
end

-- sets (or changes) the goal for the selected chart at the current rate
function TW.setGoal()
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps or not TW.openInput then return end
	local ck = steps:GetChartKey()
	local rate = rateNow()
	local cur = goalFor(ck, rate)
	local now = ""
	if cur then pcall(function() now = string.format("%.2f", cur:GetPercent() * 100) end) end
	TW.openInput { title = string.format("Goal on this chart at %.2fx (Wife%%)", rate), value = now,
		hint = "A number from 1 to 100; empty to drop the goal.",
		onDone = function(text)
			text = (text or ""):gsub("[%s%%]", "")
			local p = profile()
			if not p then return end
			if text == "" then
				if cur then pcall(function() cur:Delete() end) end
				MESSAGEMAN:Broadcast("TWGoalChanged")
				SCREENMAN:SystemMessage("Goal dropped")
				return
			end
			local pct = tonumber(text)
			if not pct or pct <= 0 or pct > 100 then SCREENMAN:SystemMessage("A goal is a number from 1 to 100") return end
			local g = goalFor(ck, rate)
			if g then
				pcall(function() g:SetPercent(pct / 100) end)
			else
				-- (Etterna makes the goal at the current rate; the newest one for the chart is ours)
				pcall(function() p:AddGoal(ck) end)
				local newest
				pcall(function()
					for _, sg in ipairs(p:GetGoalTable() or {}) do
						if sg:GetChartKey() == ck and math.abs(sg:GetRate() - rate) < 0.001 and (not newest or sg:WhenAssigned() > newest:WhenAssigned()) then newest = sg end
					end
				end)
				if newest then pcall(function() newest:SetPercent(pct / 100) end) end
			end
			MESSAGEMAN:Broadcast("TWGoalChanged")
			SCREENMAN:SystemMessage(string.format("Goal: %.2f%% at %.2fx", pct, rate))
		end }
end

-- song select's keys: Ctrl+G sets the goal (a letter on its own starts the search)
function TW.goalKey(event)
	if event.type ~= "InputEventType_FirstPress" or event.DeviceInput.is_mouse then return false end
	if event.DeviceInput.button ~= "DeviceButton_g" or not INPUTFILTER:IsControlPressed() or (TW.altHeld and TW.altHeld()) then return false end
	TW.setGoal()
	return true
end

-- the selected chart's goal, by the chart (click to change it)
function TW.goalLine(x, y, textFn, align)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(x, y) end,
		OnCommand = function(self) self:queuecommand("Goal") end,
		CurrentStepsChangedMessageCommand = function(self) if not (TW.browsingSkip and TW.browsingSkip()) then self:queuecommand("Goal") end end,
		CurrentSongChangedMessageCommand = function(self) if not (TW.browsingSkip and TW.browsingSkip()) then self:queuecommand("Goal") end end,
		CurrentRateChangedMessageCommand = function(self) self:queuecommand("Goal") end,
		TWGoalChangedMessageCommand = function(self) self:queuecommand("Goal") end,
		GoalCommand = function(self)
			local text, done = TW.goalText(GAMESTATE:GetCurrentSteps())
			local t = self:GetChild("T")
			t:settext(text or "")
			t:diffuse(done and TW.rgb(120, 230, 160) or TW.rgb(255, 210, 122))
			self:visible(text ~= nil)
		end,
		textFn(function(self) self:align(align or 0, 0.5):shadowlength(1) end) .. { Name = "T" },
		TW.button(TW.M(200), TW.M(22), function() TW.setGoal() end) .. { InitCommand = function(self) self:align(align or 0, 0.5):zoomto(TW.M(200), TW.M(22)):diffusealpha(0) end },
	}
end

-- results: the goal this play reached, if any
function TW.goalResult(x, y, textFn)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(x, y):diffusealpha(0) end,
		OnCommand = function(self) self:sleep(0.3):queuecommand("Look") end,
		LookCommand = function(self)
			local hs = TW.resultsScore and TW.resultsScore()
			local steps = GAMESTATE:GetCurrentSteps()
			if not hs or not steps then return end
			local reached
			pcall(function()
				local key = hs:GetScoreKey()
				for _, sg in ipairs(profile():GetGoalTable() or {}) do
					if sg:GetChartKey() == steps:GetChartKey() and sg:IsAchieved() and sg:AchievedBy() == key then
						if not reached or sg:GetPercent() > reached then reached = sg:GetPercent() end
					end
				end
			end)
			if not reached then return end
			self:GetChild("T"):settext(string.format("Goal reached: %.2f%%", reached * 100))
			self:zoom(0.9):decelerate(0.3):zoom(1):diffusealpha(1)
		end,
		textFn(function(self) self:align(0.5, 0.5):shadowlength(1):diffuse(TW.rgb(120, 230, 160)) end) .. { Name = "T" },
	}
end
