-- Judgments with the osu! skin's mania hit art (300g/300/200/100/50/miss), at the skin's
-- ScorePosition on the stage, sized like osu!mania draws them.
TW.useGameplaySkin() -- the HUD comes from the skin of the notes you play with

-- notes from a Quaver skin: its judgement pictures (as tall as its JudgementHitBurstScale; 0 shows
-- none, as in Quaver), bumping up and fading like Quaver's, in the Quaver look's place
local qv = not TW.notesSkin and TW.quaverHud and TW.qvDigits and TW.quaverHud()
if qv and qv.judge and next(qv.judge) then
	local H = TW.qvSize(qv.judgeScale or 100)
	local current
	local t = Def.ActorFrame(TW.playerItem("judge", "Judgment", function()
		return TW.stageCX(), (TW.stage and TW.stage.plY or SCREEN_CENTER_Y) + TW.M(4)
	end, TW.M(200), TW.M(40)))
	t[#t + 1] = Def.Sprite {
		Name = "Pic",
		InitCommand = function(self) self:visible(false) end,
		JudgmentMessageCommand = function(self, param)
			if param.HoldNoteScore or param.FromReplay or H <= 0 then return end
			local key = (param.TapNoteScore or ""):gsub("^TapNoteScore_", "")
			local pic = qv.judge[key]
			if not pic then return end
			if current ~= pic then self:Load(pic); TW.inset(self); current = pic end
			local h = self:GetHeight()
			self:finishtweening():visible(true):zoom(h > 0 and H / h or 1):diffusealpha(1)
				:y(-5 * SCREEN_HEIGHT / 1080):decelerate(0.183):y(0):decelerate(0.5):diffusealpha(0)
		end
	}
	return t
end
if TW.fallback("judge_W1") and TW.fallback("judge_W2") then return TW.base("Graphics/Player judgment") end

local ids = {
	TapNoteScore_W1 = "judge_W1", TapNoteScore_W2 = "judge_W2", TapNoteScore_W3 = "judge_W3",
	TapNoteScore_W4 = "judge_W4", TapNoteScore_W5 = "judge_W5", TapNoteScore_Miss = "judge_Miss"
}
local function z(id) return (TW.hd(id) and 0.5 or 1) * SCREEN_HEIGHT / 480 end
-- the skin's ScorePosition, then wherever Customize gameplay moved it
local function box()
	local keys = TW.stage and TW.stage.keys or 4
	local m = TW_SKIN and TW_SKIN.mania and TW_SKIN.mania[keys >= 7 and 7 or 4]
	local pos = m and m.scorePosition or 325
	local cy = SCREEN_CENTER_Y
	local py = TW.stage and TW.stage.plY or cy
	return TW.stageCX(), py + ((TW.stage and TW.stage.reverse) and (pos - cy) or (cy - pos))
end
local t = Def.ActorFrame(TW.playerItem("judge", "Judgment", box, 220, 70))
for tns, id in pairs(ids) do
	if TW.has(id) then
		t[#t + 1] = Def.Sprite {
			Name = tns,
			Texture = TW.img(id),
			InitCommand = function(self) TW.inset(self):visible(false) end,
		}
	end
end
t.JudgmentMessageCommand = function(self, param)
	if param.HoldNoteScore or param.FromReplay then return end
	local s = self:GetChild(param.TapNoteScore)
	for k, _ in pairs(ids) do
		local c = self:GetChild(k)
		if c then c:finishtweening():visible(false) end
	end
	if not s then return end
	local zz = z(ids[param.TapNoteScore])
	s:visible(true):diffusealpha(1):zoom(zz * 1.2):linear(0.05):zoom(zz):sleep(0.25):linear(0.15):diffusealpha(0)
end
return t
