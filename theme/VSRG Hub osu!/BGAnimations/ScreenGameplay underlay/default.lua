-- osu!mania's stage behind the notes: black columns between the skin's stage-left and
-- stage-right art, with the columns spaced to the noteskin's osu! column width.
-- Til Death's underlay still runs first (it applies your receptor size and background settings).
TW.useGameplaySkin() -- the HUD comes from the skin of the notes you play with
TW.stage = nil
local t = Def.ActorFrame { TW.base("BGAnimations/ScreenGameplay underlay") }

-- Work out the stage once the player exists, apply Customize gameplay's notefield settings, space
-- the columns, and tell everything else. Run again whenever the notefield settings change.
local colBase = nil
local noteShift = {}
local recX = {}
local function layout()
	local top = SCREENMAN:GetTopScreen()
	local pl = top and top:GetChild("PlayerP1")
	if not pl then return nil end
	local nf = pl:GetChild("NoteField")
	local cols = GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()
	local po = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions()
	local reverse = po:UsingReverse()
	local zoom = 1 - po:Mini() * 0.5
	local ns = (po:NoteSkin() or ""):lower()
	local info = TW.noteskinInfo(ns)
	local w = (info and info.width or 64) + (TW.columnExtra and TW.columnExtra() or 0)
	if nf then
		TW.applyFieldLayout(pl, nf, reverse)
		local actors = nf:get_column_actors()
		if not colBase then
			colBase = {}
			for i, col in ipairs(actors) do colBase[i] = col:GetX() end
		end
		-- (osu! skins with columns of different widths or gaps between them place each column)
		local colX = info and info.colX and #info.colX == #actors and info.colX
		local extra = w - (info and info.width or 64)
		-- Note spacing: the columns (notes, holds) spread further than the receptors, which the
		-- VSRG Hub noteskins move back onto the column spacing (noteShift)
		local nd = TW.noteSpacingExtra and TW.noteSpacingExtra() or 0
		noteShift = {}
		recX = {}
		for i, col in ipairs(actors) do
			local off = (i - (#actors + 1) / 2)
			local x = colX and (colBase[i] - off * 64 + colX[i] + off * extra) or (colBase[i] + off * (w - 64))
			col:x(x + off * nd)
			noteShift[i] = -off * nd
			recX[i] = off * 64 + x -- (the style's own 64-pixel spacing plus the column's x)
		end
	end
	-- (the notefield's zoom is Mini itself, which Etterna puts on the notefield each frame: zoom
	-- above is the whole of it)
	local fz = 1
	local half = cols * w * zoom * fz / 2
	-- (the notefield's own x isn't scaled by Mini: Etterna zooms the field about its own origin, so
	-- a field moved with Customize gameplay moves the same whatever the receptor size)
	local cx = pl:GetX() + (nf and nf:GetX() or 0) * pl:GetZoom()
	local ry = THEME:GetMetric("Player", reverse and "ReceptorArrowsYReverse" or "ReceptorArrowsYStandard")
	TW.stage = { cx = cx, left = cx - half, right = cx + half, width = half * 2, cols = cols, colWidth = w * zoom * fz,
		fieldScale = zoom * fz, -- the notefield's size (Mini, Customize gameplay's notefield size)
		recX = recX, stageW = cols * w, -- each receptor's x in the notefield, and the stage's width there
		noteShift = noteShift, -- per column: the receptors' x inside their column (Note spacing)
		reverse = reverse, keys = cols, plX = pl:GetX(), plY = pl:GetY(), receptorY = pl:GetY() + (nf and nf:GetY() or 0) + ry * zoom }
	MESSAGEMAN:Broadcast("TWStage")
	return TW.stage
end

t[#t + 1] = Def.ActorFrame {
	TWRelayoutMessageCommand = function(self) self:playcommand("On") end,
	OnCommand = function(self)
		local s = layout()
		if not s then return end
		self:GetChild("Black"):x(s.cx):zoomto(s.width, SCREEN_HEIGHT)
		self:GetChild("L"):x(s.left)
		self:GetChild("R"):x(s.right)
		-- a Quaver skin's notes: its own stage borders, as tall as the screen at their own width
		-- (Quaver's 768-pixel-tall screen, scaled), outside the columns
		local ok, ns = pcall(function() return GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin() end)
		local info = ok and ns and TW.noteskinInfo(ns)
		local qv = info and info.qv
		for _, b in ipairs({ { "QL", qv and qv.stageL, s.left, 1 }, { "QR", qv and qv.stageR, s.right, 0 } }) do
			local a = self:GetChild(b[1])
			if b[2] then
				a:Load(b[2]):visible(true):halign(b[4]):valign(0):x(b[3]):y(0)
				a:zoomto(a:GetTexture():GetSourceWidth() * SCREEN_HEIGHT / 768, SCREEN_HEIGHT)
			else
				a:visible(false)
			end
		end
	end,
	Def.Quad { Name = "Black", InitCommand = function(self) self:valign(0):zoomto(0, SCREEN_HEIGHT):diffuse(color("#000000")) end },
	-- osu! stretches the stage art to the screen's height and keeps its width at the skin's scale
	TW.sprite("stage_left", function(self) self:align(1, 0):zoomx(TW.scale("stage_left")):zoomy(SCREEN_HEIGHT / self:GetHeight()) end) .. { Name = "L" },
	TW.sprite("stage_right", function(self) self:align(0, 0):zoomx(TW.scale("stage_right")):zoomy(SCREEN_HEIGHT / self:GetHeight()) end) .. { Name = "R" },
	Def.Sprite { Name = "QL", InitCommand = function(self) self:visible(false) end },
	Def.Sprite { Name = "QR", InitCommand = function(self) self:visible(false) end },
}
return t
