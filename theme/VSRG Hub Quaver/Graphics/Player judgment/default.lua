-- Judgments: Quaver's coloured words (MARV, PERF, GREAT, GOOD, OKAY, MISS) in the middle of the
-- stage. When your notes come from an osu! skin, that skin's hit art is used instead.
TW.useGameplaySkin()
if TW_SKIN and TW.has("judge_W1") then return LoadActor("/Themes/VSRG Hub osu!/Graphics/Player judgment") end
local M = TW.M
local t = Def.ActorFrame(TW.playerItem("judge", "Judgment", function()
	return TW.stageCX(), (TW.stage and TW.stage.plY or SCREEN_CENTER_Y) + M(4)
end, M(200), M(40)))
-- the Quaver skin's own judgement pictures (as tall as its JudgementHitBurstScale; a skin that sets
-- it to 0 shows none, as in Quaver): they bump up and fade out like Quaver's
local hud = QV.hud()
if hud and next(hud.judge) then
	local H = QV.size(hud.judgeScale or 100)
	local current
	t[#t + 1] = Def.Sprite {
		Name = "Pic",
		InitCommand = function(self) self:visible(false) end,
		JudgmentMessageCommand = function(self, param)
			if param.HoldNoteScore or param.FromReplay or H <= 0 then return end
			local key = (param.TapNoteScore or ""):gsub("^TapNoteScore_", "")
			local pic = hud.judge[key]
			if not pic then return end
			if current ~= pic then self:Load(pic); TW.inset(self); current = pic end
			local h = self:GetHeight()
			self:finishtweening():visible(true):zoom(h > 0 and H / h or 1):diffusealpha(1)
				:y(-5 * SCREEN_HEIGHT / 1080):decelerate(0.183):y(0):decelerate(0.5):diffusealpha(0)
		end
	}
	return t
end
t[#t + 1] = QV.text(M(26), TW.bold, function(self) self:align(0.5, 0.5):visible(false) end) .. {
		Name = "Word",
		JudgmentMessageCommand = function(self, param)
			if param.HoldNoteScore or param.FromReplay then return end
			local j = QV.judge[param.TapNoteScore]
			if not j then return end
			local z = M(26) / 17
			self:finishtweening():visible(true):settext(j[1]):diffuse(j[2]):diffusealpha(1)
				:zoom(z * 1.12):linear(0.06):zoom(z):sleep(0.3):linear(0.2):diffusealpha(0)
		end
	}
return t
