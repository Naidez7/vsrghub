-- osu!mania's HUD from the skin: the HP bar standing up at the stage's right edge, score and
-- accuracy at the top right (Etterna's Wife%, which is what Etterna scores you by), and the
-- active mods. Judgments and combo are Graphics/Player judgment and Graphics/Player combo.
TW.useGameplaySkin() -- the HUD comes from the skin of the notes you play with
local M = TW.M
local U = TW.U
local inReplay = GAMESTATE:GetPlayerState():GetPlayerController() == "PlayerController_Replay"
if not inReplay and not GAMESTATE:IsPracticeMode() then Arch.setCursorVisible(false) end

local t = Def.ActorFrame { TW.practiceSeek(),
	OnCommand = function(self)
		if not inReplay then GAMESTATE:SetAutoplay(TW.autoplay == true) end
	end
}

-- the skin's mania-stage-bottom (a lane cover in many skins), over the notes and under the HUD
t[#t + 1] = TW.laneCover()

-- HP bar: scorebar-colour turned upright, its top edge against the stage's right edge
local barZoom = 0.7 * (TW.has("scorebar_colour") and TW.scale("scorebar_colour") or U)
local bar = Def.ActorFrame {
	InitCommand = function(self) self:visible(false) end,
	TWStageMessageCommand = function(self)
		self:visible(true):xy(TW.stage.right, SCREEN_HEIGHT)
	end,
	OnCommand = function(self)
		self:SetUpdateFunction(function()
			local top = SCREENMAN:GetTopScreen()
			local lm = top and top.GetLifeMeter and top:GetLifeMeter(PLAYER_1)
			local fill = self:GetChild("Fill")
			if lm and fill then fill:cropright(1 - lm:GetLife()) end
		end)
	end,
}
if TW.has("scorebar_bg") then
	bar[#bar + 1] = Def.Sprite { Texture = TW.img("scorebar_bg"), InitCommand = function(self) TW.inset(self):align(0, 0):rotationz(-90):zoom(0.7 * TW.scale("scorebar_bg")) end }
end
if TW.has("scorebar_colour") then
	bar[#bar + 1] = Def.Sprite { Name = "Fill", Texture = TW.img("scorebar_colour"), InitCommand = function(self) TW.inset(self):align(0, 0):rotationz(-90):zoom(barZoom) end }
elseif TW.fallback("scorebar_colour") then
	bar[#bar + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):rotationz(-90):zoomto(M(480), M(8)):x(M(6)):diffuse(color("#00000088")) end }
	bar[#bar + 1] = Def.Quad { Name = "Fill", InitCommand = function(self) self:align(0, 0):rotationz(-90):zoomto(M(480), M(6)):x(M(7)):diffuse(TW.rgb(170, 255, 80)) end }
end
t[#t + 1] = TW.movable("hp", "Health bar", function()
	return (TW.stage and TW.stage.right or SCREEN_CENTER_X + 128) + M(14), SCREEN_HEIGHT - M(240), M(32), M(480)
end, { bar })

-- score (0 - 1,000,000 from Wife%) and accuracy, right-aligned at the top right like osu! (the
-- accuracy is Wife%, below 0 if it goes there as in Etterna, or osu!'s accuracy with an OD in force)
local accOf = TW.accTracker and TW.accTracker() or function(p) return p.WifePercent end
local scoreZoom, accZoom = 1, 0.6
-- notes from a Quaver skin: its own score digits (and decimal / percent) at its display scales
local qv = not TW.notesSkin and TW.quaverHud and TW.qvDigits and TW.quaverHud()
if qv and qv.score then
	t[#t + 1] = TW.movable("score", "Score and accuracy", function() return SCREEN_WIDTH - M(130), M(40), M(260), M(80) end, { Def.ActorFrame {
		InitCommand = function(self) self:xy(SCREEN_WIDTH - M(8), M(8)) end,
		TW.qvDigits(qv.score, qv.scoreScale or 18, 1) .. { Name = "Score" },
		TW.qvDigits(qv.score, qv.accScale or 18, 1, qv) .. { Name = "Acc" },
		OnCommand = function(self)
			local sc, acc = self:GetChild("Score"), self:GetChild("Acc")
			sc:playcommand("Set", { text = "0000000" })
			acc:playcommand("Set", { text = "100.00%" })
			-- one row under the other (the digits are drawn from their middle)
			local d1, a1 = sc:GetChild("D1"), acc:GetChild("D1")
			local h = d1 and d1:GetZoomedHeight() or M(30)
			sc:y(h / 2)
			acc:y(h + M(4) + (a1 and a1:GetZoomedHeight() or M(20)) / 2)
		end,
		JudgmentMessageCommand = function(self, p)
			local acc = accOf(p)
			if not p.WifePercent then return end
			self:GetChild("Score"):playcommand("Set", { text = string.format("%07d", math.floor(math.max(0, p.WifePercent) * 10000)) })
			self:GetChild("Acc"):playcommand("Set", { text = string.format("%.2f%%", acc or p.WifePercent) })
		end
	} })
elseif qv then
	-- a Quaver skin without score digits of its own: plain numbers, as Quaver's default skin has
	t[#t + 1] = TW.movable("score", "Score and accuracy", function() return SCREEN_WIDTH - M(130), M(40), M(260), M(80) end, { Def.ActorFrame {
		InitCommand = function(self) self:xy(SCREEN_WIDTH - M(8), M(8)) end,
		LoadFont((TW.fontFor(M(30)))) .. { Name = "Score", InitCommand = function(self) self:align(1, 0):zoom(select(2, TW.fontFor(M(30)))):settext("0000000") end },
		LoadFont((TW.fontFor(M(20)))) .. { Name = "Acc", InitCommand = function(self) self:align(1, 0):y(M(36)):zoom(select(2, TW.fontFor(M(20)))):settext("100.00%") end },
		JudgmentMessageCommand = function(self, p)
			local acc = accOf(p)
			if not p.WifePercent then return end
			self:GetChild("Score"):settext(string.format("%07d", math.floor(math.max(0, p.WifePercent) * 10000)))
			self:GetChild("Acc"):settext(string.format("%.2f%%", acc or p.WifePercent))
		end
	} })
else
t[#t + 1] = TW.movable("score", "Score and accuracy", function() return SCREEN_WIDTH - M(130), M(40), M(260), M(80) end, { Def.ActorFrame {
	InitCommand = function(self) self:xy(SCREEN_WIDTH - M(4), 0) end,
	TW.number("score", 8, "Score", scoreZoom, 1),
	TW.number("score", 8, "Acc", accZoom, 1),
	OnCommand = function(self)
		self:GetChild("Score"):playcommand("SetText", { text = "00000000" })
		self:GetChild("Acc"):playcommand("SetText", { text = "100.00%" })
		-- accuracy sits under the score, as tall as the skin's score digits
		local h = M(30)
		local sc = self:GetChild("Score")
		local c1 = sc.GetChild and sc:GetChild("c1")
		if c1 then h = c1:GetZoomedHeight() end
		-- (a skin whose digits sit in big padded images: about as tall as a character is wide)
		local padded, vis = TW.digitsPadded(sc, "score")
		if padded then h = vis * 1.7 * scoreZoom * TW.U end
		self:GetChild("Acc"):y(h)
	end,
	JudgmentMessageCommand = function(self, p)
		local acc = accOf(p)
		if not p.WifePercent then return end
		self:GetChild("Score"):playcommand("SetText", { text = string.format("%08d", math.floor(math.max(0, p.WifePercent) * 10000)) })
		self:GetChild("Acc"):playcommand("SetText", { text = string.format("%.2f%%", acc or p.WifePercent) })
	end
} })
end

-- active mods as the skin's mod icons (text when it has none), right-aligned under the score
local po = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions()
local active = {}
if TW.autoplay then active[#active + 1] = { "mod_autoplay", "AT" } end
if po:FailSetting() == "FailType_Off" then active[#active + 1] = { "mod_nofail", "NF" } end
if po:Hidden() > 0 then active[#active + 1] = { "mod_hidden", "HD" } end
if po:Sudden() > 0 then active[#active + 1] = { "mod_fadein", "FI" } end
if po:Mirror() then active[#active + 1] = { "mod_mirror", "MR" } end
if po:Shuffle() then active[#active + 1] = { "mod_random", "RD" } end
if TW.lnOrig and TW.lnMod == "INV" then active[#active + 1] = { "mod_invert", "IN" } end
if TW.lnOrig and TW.lnMod == "FLN" then active[#active + 1] = { "mod_fln", "FLN" } end
local rate = getCurRateValue()
if math.abs(rate - 1.5) < 0.001 then active[#active + 1] = { "mod_doubletime", "DT" }
elseif math.abs(rate - 0.75) < 0.001 then active[#active + 1] = { "mod_halftime", "HT" }
elseif math.abs(rate - 1) > 0.001 then active[#active + 1] = { "", getCurRateDisplayString(true) } end
local modIcons = {}
for n, m in ipairs(active) do
	local x, y = SCREEN_WIDTH - M(51) - (#active - n) * TW.U * 66, M(160)
	if TW.has(m[1]) then
		modIcons[#modIcons + 1] = TW.sprite(m[1], function(self) self:xy(x, y) end)
	elseif not TW.blank(m[1]) then
		modIcons[#modIcons + 1] = TW.text(M(26), false, function(self) self:align(0.5, 0.5):xy(x, y):settext(m[2]):diffusealpha(0.75) end)
	end
end
t[#t + 1] = TW.movable("mods", "Mods", function()
	local n = math.max(1, #active)
	return SCREEN_WIDTH - M(51) - (n - 1) * TW.U * 33, M(160), n * TW.U * 66, M(56)
end, modIcons)

-- Etterna's extra parts (error bar, progress, judgment counter, mean, NPS, pace) and the editor
t[#t + 1] = TW.hudExtras()
if TW.customizeActive() then t[#t + 1] = TW.mouse() end
t[#t + 1] = TW.customizeEditor()
t[#t + 1] = TW.danOverlay("ScreenGameplay overlay/dan_overlay_gameplay.lua")
-- practice mode: the bar to move through the song (29 VSRG Hub practice.lua)
t[#t + 1] = TW.practiceBar { text = TW.text, accent = TW.pink }
t[#t + 1] = TW.failNotice()
-- the new scroll speed after F3 / F4 (Scripts/24 VSRG Hub scroll.lua)
t[#t + 1] = TW.scrollToast()
return t
