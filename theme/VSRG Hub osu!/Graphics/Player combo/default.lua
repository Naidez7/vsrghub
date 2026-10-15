-- The combo counter in the skin's combo font, at the skin's ComboPosition on the stage.
TW.useGameplaySkin() -- the HUD comes from the skin of the notes you play with

-- the combo skin picked in the options (any osu! skin's digits, or a Quaver skin's), else the notes'
local pick = TW.comboPick and TW.comboPick()
local comboSkin = nil
if pick and pick.kind == "osu" then
	local keys = 4
	pcall(function() if GAMESTATE:GetCurrentGame():GetName() == "kb7" then keys = 7 end end)
	comboSkin = TW.skinForKeys(pick.skin, keys)
end
-- notes from a Quaver skin: its combo digits at its ComboDisplayScale, under the judgement as in
-- Quaver (the same place as in the Quaver look)
local qv = (pick and pick.kind == "qv" and pick.hud)
	or (not pick and not TW.notesSkin and TW.quaverHud and TW.qvDigits and TW.quaverHud())
if qv then
	local t = Def.ActorFrame(TW.playerItem("combo", "Combo", function()
		return TW.stageCX(), (TW.stage and TW.stage.plY or SCREEN_CENTER_Y) + TW.M(84)
	end, TW.M(120), TW.M(36)))
	if qv.combo then
		t[#t + 1] = TW.qvDigits(qv.combo, qv.comboScale or 45, 0.5) .. { Name = "N", InitCommand = function(self) self:visible(false) end }
		t.ComboCommand = function(self, param)
			local n = self:GetChild("N")
			local c = param.Combo
			if not c or c < 1 then n:visible(false) return end
			n:visible(true):playcommand("Set", { text = tostring(c) }):stoptweening():zoom(1.08):linear(0.05):zoom(1)
		end
		return t
	end
	-- a Quaver skin without combo digits of its own: plain numbers, as Quaver's default skin has
	local cf, z = TW.fontFor(TW.M(22))
	t[#t + 1] = LoadFont(cf) .. { Name = "N", InitCommand = function(self) self:align(0.5, 0.5):visible(false) end }
	t.ComboCommand = function(self, param)
		local n = self:GetChild("N")
		local c = param.Combo
		if not c or c < 1 then n:visible(false) return end
		n:visible(true):settext(tostring(c)):stoptweening():zoom(z * 1.08):linear(0.05):zoom(z)
	end
	return t
end

-- (the picked skin's pictures while its digits are made and set)
local function withSkin(f)
	if not comboSkin then return f() end
	local keep = TW_SKIN
	TW_SKIN = comboSkin
	local ok, r = pcall(f)
	TW_SKIN = keep
	if not ok then error(r) end
	return r
end
if not comboSkin then
	if TW.fallback("combo_0") then return TW.base("Graphics/Player combo") end
	if TW.blank("combo_0") then return Def.Actor {} end
end

local MAX = 6
local zoom = (SCREEN_HEIGHT / 480) / TW.U -- TW.setDigits multiplies by TW.U
local function box()
	local keys = TW.stage and TW.stage.keys or 4
	local m = TW_SKIN and TW_SKIN.mania and TW_SKIN.mania[keys >= 7 and 7 or 4]
	local pos = m and m.comboPosition or 111
	-- a skin that puts its combo off the screen (e.g. ComboPosition: 1111) hides it; VSRG Hub shows it at
	-- osu!'s usual place instead (it can still be switched off or moved in Customize gameplay)
	if pos < 0 or pos > SCREEN_HEIGHT then pos = 111 end
	local cy = SCREEN_CENTER_Y
	local py = TW.stage and TW.stage.plY or cy
	return TW.stageCX(), py + ((TW.stage and TW.stage.reverse) and (pos - cy) or (cy - pos))
end
local t = Def.ActorFrame(TW.playerItem("combo", "Combo", box, 160, 60))
t[#t + 1] = withSkin(function() return TW.digits("combo", MAX, "Digits") end)
t.ComboCommand = function(self, param)
	local d = self:GetChild("Digits")
	local n = param.Combo
	if not n or n < 1 then
		d:visible(false)
		return
	end
	d:visible(true)
	withSkin(function() TW.setDigits(d, "combo", tostring(n), MAX, zoom, 0.5) end)
	d:stoptweening():zoomy(1.15):linear(0.06):zoomy(1)
end
return t
