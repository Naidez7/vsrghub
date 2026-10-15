-- Quaver's HUD: score at the top left with the chart's rating under it, accuracy and combo at the
-- top right, the health bar standing next to the stage (cyan to pink, shrinking as you lose
-- health), the hit error bar under the judgment and the song's time at the bottom.
-- Etterna's Wife% is the accuracy (it is what Etterna scores you by); score is Wife% x 10,000.
local M, R = TW.M, TW.R
local inReplay = GAMESTATE:GetPlayerState():GetPlayerController() == "PlayerController_Replay"
if not inReplay and not GAMESTATE:IsPracticeMode() then Arch.setCursorVisible(false) end
local steps = GAMESTATE:GetCurrentSteps()
local song = GAMESTATE:GetCurrentSong()
local rate = getCurRateValue()
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()

local function spaced(s) return (s:gsub("(.)", "%1 "):gsub(" $", "")) end

local t = Def.ActorFrame { TW.practiceSeek(),
	OnCommand = function(self)
		if not inReplay then GAMESTATE:SetAutoplay(TW.autoplay == true) end
	end
}

-- the lane cover: the osu! skin's stage bottom when the notes have one, else a plain one (off until
-- shown in Customize gameplay); under the HUD
t[#t + 1] = TW.laneCover()

-- the Quaver skin's own digits (score, accuracy and rating) and health bar, when the notes come
-- from a Quaver skin that has them
local hud = QV.hud()
local skinDigits = hud and hud.score
local function digitText(scale, halign, x, y, text)
	return QV.digits(hud.score, scale, halign, hud) .. {
		InitCommand = function(self) self:xy(x, y) end,
		OnCommand = function(self) self:playcommand("Set", { text = text }) end,
	}
end

-- score and rating
do
local parts = {}
if skinDigits then
	parts[#parts + 1] = digitText(hud.scoreScale or 18, 0, M(14), M(28), "0000000") .. {
		JudgmentMessageCommand = function(self, p)
			if p.WifePercent then self:playcommand("Set", { text = string.format("%07d", math.floor(math.max(0, p.WifePercent) * 10000)) }) end
		end
	}
	parts[#parts + 1] = digitText(hud.rateScale or 18, 0, M(14), M(64), string.format("%05.2f", TW.msd(steps)))
else
parts[#parts + 1] = QV.text(M(33), TW.font, function(self) self:align(0, 0.5):xy(M(14), M(28)):settext(spaced("0000000")) end) .. {
	JudgmentMessageCommand = function(self, p)
		if p.WifePercent then self:settext(spaced(string.format("%07d", math.floor(math.max(0, p.WifePercent) * 10000)))) end
	end
}
parts[#parts + 1] = QV.text(M(33), TW.font, function(self)
	self:align(0, 0.5):xy(M(14), M(64)):settext(spaced((string.format("%05.2f", TW.msd(steps)):gsub("%.", ","))))
end)
end
t[#t + 1] = TW.movable("score", "Score and rating", function() return M(120), M(46), M(230), M(76) end, parts)
end

-- accuracy and combo (Wife%, below 0 if it goes there as in Etterna, or osu!'s accuracy with an osu!
-- OD in force)
do
local parts = {}
local accOf = TW.accTracker and TW.accTracker() or function(p) return p.WifePercent end
if skinDigits and hud.percent and hud.decimal then
	parts[#parts + 1] = digitText(hud.accScale or 18, 1, SCREEN_WIDTH - M(10), M(28), "100.00%") .. {
		JudgmentMessageCommand = function(self, p)
			local acc = accOf(p)
			if p.WifePercent then self:playcommand("Set", { text = string.format("%05.2f%%", acc or p.WifePercent) }) end
		end
	}
else
parts[#parts + 1] = QV.text(M(33), TW.font, function(self) self:align(1, 0.5):xy(SCREEN_WIDTH - M(10), M(28)):settext(spaced("100,00%")) end) .. {
	JudgmentMessageCommand = function(self, p)
		local acc = accOf(p)
		if p.WifePercent then self:settext(spaced((string.format("%05.2f%%", acc or p.WifePercent):gsub("%.", ",")))) end
	end
}
end
parts[#parts + 1] = QV.text(M(24), TW.font, function(self) self:align(1, 0.5):xy(SCREEN_WIDTH - M(10), M(60)):settext("0") end) .. {
	JudgmentMessageCommand = function(self, p)
		if p.HoldNoteScore then return end
		local c = 0
		pcall(function() c = pss:GetCurrentCombo() end)
		self:settext(tostring(c))
	end
}
t[#t + 1] = TW.movable("acc", "Accuracy and combo", function() return SCREEN_WIDTH - M(110), M(44), M(210), M(72) end, parts)
end

-- health bar
local HB = M(590)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:visible(false) end,
	TWStageMessageCommand = function(self) self:visible(true):xy(TW.stage.right + M(32), M(800) - HB) end,
	OnCommand = function(self)
		self:SetUpdateFunction(function()
			local top = SCREENMAN:GetTopScreen()
			local lm = top and top.GetLifeMeter and top:GetLifeMeter(PLAYER_1)
			if lm then self:GetChild("Fill"):croptop(1 - lm:GetLife()) end
		end)
	end,
	Def.Quad { Name = "Fill", InitCommand = function(self) self:align(0, 0):zoomto(M(4), HB):diffusetopedge(QV.g1):diffusebottomedge(QV.g3) end },
}
-- the skin's own health bar: its background, and its foreground cut down as health is lost (from
-- the top when it stands, from the right when it lies), at its HealthBarScale, standing on the
-- same spot
if hud and hud.hpBg and hud.hpFg then
	local z = QV.size(hud.hpScale or 100) / 100
	local bar = t[#t]
	bar[1] = Def.Sprite { Texture = hud.hpBg, InitCommand = function(self) self:align(0, 1):y(HB):zoom(z) end }
	bar[2] = Def.Sprite { Name = "Fill", Texture = hud.hpFg, InitCommand = function(self) self:align(0, 1):y(HB):zoom(z) end }
	bar.OnCommand = function(self)
		local fill = self:GetChild("Fill")
		self:SetUpdateFunction(function()
			local top = SCREENMAN:GetTopScreen()
			local lm = top and top.GetLifeMeter and top:GetLifeMeter(PLAYER_1)
			if lm then
				if hud.hpVertical then fill:croptop(1 - lm:GetLife()) else fill:cropright(1 - lm:GetLife()) end
			end
		end)
	end
end
t[#t] = TW.movable("hp", "Health bar", function()
	return (TW.stage and TW.stage.right or SCREEN_CENTER_X + 128) + M(34), M(800) - HB / 2, M(16), HB
end, { t[#t] })

-- hit error bar: a tick for each hit, coloured by its judgment, fading out
local TICKS, HALF = 24, M(70)
local hit = Def.ActorFrame {
	InitCommand = function(self) self:y(M(447)) end,
	TWStageMessageCommand = function(self) self:x(TW.stage.cx) end,
	Def.Quad { InitCommand = function(self) self:zoomto(math.max(1, M(1.5)), M(16)):diffusealpha(0.9) end },
}
local nextTick = 1
for i = 1, TICKS do
	hit[#hit + 1] = Def.Quad { Name = "T" .. i, InitCommand = function(self) self:zoomto(math.max(1, M(2)), M(14)):diffusealpha(0) end }
end
hit.JudgmentMessageCommand = function(self, p)
	if p.HoldNoteScore or not p.TapNoteOffset or p.TapNoteScore == "TapNoteScore_Miss" then return end
	local j = QV.judge[p.TapNoteScore]
	if not j then return end
	local q = self:GetChild("T" .. nextTick)
	nextTick = nextTick % TICKS + 1
	local x = math.max(-1, math.min(1, p.TapNoteOffset / 0.18)) * HALF
	q:finishtweening():x(x):diffuse(j[2]):diffusealpha(1):sleep(0.4):linear(0.6):diffusealpha(0)
end
-- the last hit's arrow
hit[#hit + 1] = Def.ActorMultiVertex {
	Name = "Arrow",
	InitCommand = function(self)
		local s = M(5)
		self:y(-M(14)):SetDrawState { Mode = "DrawMode_Triangles" }:SetVertices {
			{ { -s, -s, 0 }, color("#FFFFFF") }, { { s, -s, 0 }, color("#FFFFFF") }, { { 0, 0, 0 }, color("#FFFFFF") } }
	end,
	JudgmentMessageCommand = function(self, p)
		if p.HoldNoteScore or not p.TapNoteOffset or p.TapNoteScore == "TapNoteScore_Miss" then return end
		self:stoptweening():linear(0.08):x(math.max(-1, math.min(1, p.TapNoteOffset / 0.18)) * HALF)
	end
}
t[#t + 1] = TW.movable("hiterror", "Hit error bar", function() return TW.stageCX(), M(447), HALF * 2 + M(10), M(30) end, { hit })

-- time
local len = song and song:GetLastSecond() or 1
t[#t + 1] = Def.ActorFrame {
	OnCommand = function(self)
		local c = self:GetChildren()
		self:SetUpdateFunction(function()
			local pos = GAMESTATE:GetSongPosition():GetMusicSeconds()
			local f = math.max(0, math.min(1, pos / len))
			c.Bar:zoomx(f)
			c.Left:settext(spaced(QV.clock(pos / rate)))
			c.Right:settext("-" .. spaced(QV.clock((len - pos) / rate)))
		end)
		self:SetUpdateFunctionInterval(0.1)
	end,
	Def.Quad { Name = "Bar", InitCommand = function(self) self:align(0, 1):xy(0, SCREEN_HEIGHT):zoomto(SCREEN_WIDTH, math.max(2, M(3))):diffuse(QV.cyan):zoomx(0) end },
	QV.text(M(12), TW.bold, function(self) self:align(0, 0.5):xy(M(8), SCREEN_HEIGHT - M(15)):diffuse(QV.cyan) end) .. { Name = "Left" },
	QV.text(M(12), TW.bold, function(self) self:align(1, 0.5):xy(SCREEN_WIDTH - M(8), SCREEN_HEIGHT - M(15)):diffuse(QV.cyan) end) .. { Name = "Right" },
}
t[#t] = TW.movable("time", "Song time", function() return SCREEN_CENTER_X, SCREEN_HEIGHT - M(12), SCREEN_WIDTH, M(24) end, { t[#t] })

-- active modifiers under the accuracy
local po = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions()
local active = {}
if math.abs(rate - 1) > 0.001 then active[#active + 1] = getCurRateDisplayString(true) end
if TW.autoplay then active[#active + 1] = "Autoplay" end
if po:FailSetting() == "FailType_Off" then active[#active + 1] = "No Fail" end
if po:Mirror() then active[#active + 1] = "Mirror" end
if po:Shuffle() then active[#active + 1] = "Random" end
if po:Hidden() > 0 then active[#active + 1] = "Hidden" end
if po:Sudden() > 0 then active[#active + 1] = "Fade In" end
if TW.inPractice and TW.inPractice() then active[#active + 1] = "Practice" end
if TW.lnOrig and TW.lnMod then active[#active + 1] = TW.lnMods[TW.lnMod] end
if #active > 0 then
	t[#t + 1] = TW.movable("mods", "Mods", function() return SCREEN_WIDTH - M(110), M(88), M(210), M(20) end, { QV.t(M(13), true, function(self)
		self:align(1, 0.5):xy(SCREEN_WIDTH - M(10), M(88)):diffuse(QV.yellow):settext(table.concat(active, ", "))
	end) })
end

-- Etterna's extra parts (error bar, progress, judgment counter, mean, NPS, pace) and the editor
-- (Quaver's own hit error bar and song time are above: Etterna's error bar and progress bar would
-- only repeat them)
t[#t + 1] = TW.hudExtras { errorbar = true, progress = true }
if TW.customizeActive() then t[#t + 1] = TW.mouse() end
-- practice mode: the bar to move through the song (29 VSRG Hub practice.lua)
t[#t + 1] = TW.practiceBar { text = QV.t, accent = QV.cyan }
t[#t + 1] = TW.customizeEditor()
t[#t + 1] = TW.danOverlay("ScreenGameplay overlay/dan_overlay_gameplay.lua")
t[#t + 1] = TW.failNotice()
-- the new scroll speed after F3 / F4 (Scripts/24 VSRG Hub scroll.lua)
t[#t + 1] = TW.scrollToast()
return t
