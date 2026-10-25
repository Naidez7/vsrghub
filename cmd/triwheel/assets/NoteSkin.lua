-- VSRG Hub noteskin: draws notes and receptors from the player's own osu! or Quaver skin,
-- read in place through the "src" folder link next to this file. SKIN is filled in at launch.
local ret = ... or {}
local SKIN = SKIN_DATA
local W = SKIN.width or 64 -- osu! column width; VSRG Hub spaces the columns to match
-- Til' Death and Rebirth keep Etterna's own 64-wide columns (and their screen filter, lane cover...
-- are drawn for those): fit the notes to them there
-- The notefield settings (Customize gameplay's note size, receptors, stage hint, LN tail...) come
-- from the look's own VSRG Hub scripts (TW) in the osu! and Quaver looks, and from TWL (written
-- next to VSRG Hub's menu in Til' Death and Rebirth) in those; same file, same values.
local TW = TW
do
	local ok, theme = pcall(function() return THEME:GetCurThemeName() end)
	if ok and theme and not theme:find("^VSRG Hub") then W = 64; TW = TWL end
end
-- a column's notes' own width: Quaver skins can leave room between columns (NotePadding), osu!
-- skins can make columns of different widths (ColumnWidth list) with gaps (ColumnSpacing)
local function colNW(c)
	return ((c and c.w) or SKIN.noteW or SKIN.width or 64) * W / (SKIN.width or 64)
end
-- Customize gameplay's Note size: notes, hold heads, bodies and ends drawn that much bigger or
-- smaller than the column (TW.noteScale; 1 outside VSRG Hub's looks)
local function noteScale()
	local k = 1
	if TW and TW.noteScale then k = tonumber(TW.noteScale()) or 1 end
	return math.max(0.1, k)
end
-- Customize gameplay's Note width and Note height: notes and hold heads stretched across or along
-- the column on top of the Note size (TW.noteDims; 1, 1 outside VSRG Hub's looks). Hold bodies
-- follow the width; their length is the hold's.
local function noteDims()
	local w, h = 1, 1
	if TW and TW.noteDims then w, h = TW.noteDims() end
	return math.max(0.1, tonumber(w) or 1), math.max(0.1, tonumber(h) or 1)
end
-- a note part's size from its own fitted size (twW, twH) times the Note size, width and height
local function scaled(self)
	if self.twW then
		local k = noteScale()
		local w, h = noteDims()
		if self.twBody then h = 1 end
		self:setsize(self.twW * k * w, self.twH * k * h)
	end
end
local HS = SKIN.noteHS or 1 -- Quaver's WidthForNoteHeightScale: notes drawn taller or flatter
local fallbackLoad = ret.Load
-- the skin's own files are read through "src"; the ones VSRG Hub writes have their full path
local function path(f)
	if f:sub(1, 1) == "/" then return f end
	return SKIN.dir .. f
end
local function rev()
	local ps = GAMESTATE:GetPlayerState(PLAYER_1)
	return ps and ps:GetCurrentPlayerOptions():UsingReverse() or false
end
-- Etterna sets every note actor's zoom itself while drawing, so the art is fitted to the column
-- by resizing the sprite (its drawn size), not by zooming it.
local function fit(self, nw)
	local w, h = self:GetWidth(), self:GetHeight()
	if w and w > 0 then self:setsize(nw, h * nw / w) end
end
-- Etterna puts an image whose sides aren't powers of two into a bigger texture whose rest is
-- leftover memory; drawn right to its edge, the picture blends in a line of it (coloured dots
-- around the note). Half a texel in from each edge keeps to the picture's own pixels.
local function inset(self)
	pcall(function()
		local tex = self:GetTexture()
		if not tex or (tex:GetNumFrames() or 1) > 1 then return end
		local l, t, r, b = tex:GetTextureCoordRect(0)
		local tw, th = tex:GetTextureWidth(), tex:GetTextureHeight()
		if not (l and tw and th and tw > 0 and th > 0) then return end
		local dx, dy = math.min(0.5 / tw, (r - l) / 4), math.min(0.5 / th, (b - t) / 4)
		self:customtexturerect(l + dx, t + dy, r - dx, b - dy)
	end)
end
local function sprite(file, nw)
	return Def.Sprite { Texture = path(file), InitCommand = function(self) fit(self, nw); inset(self) end }
end
-- a hold's end image: as wide as the column, as tall as the column's notes (osu!: hs)
local function fitH(self, nw, hs)
	local w, h = self:GetWidth(), self:GetHeight()
	if w and w > 0 then self:setsize(nw, h * nw / w * (hs or 1)) end
end
-- Customize gameplay's Note spacing spreads the notes further than the receptors: the gameplay
-- screen moves each column (its notes and holds) and tells how far back the receptor, its lighting
-- and the hit line go to stay on the column spacing (TW.stage.noteShift, sent with TWStage)
local function shifted(t, idx)
	t.InitCommand = function(self) self:x(0) end
	t.TWStageMessageCommand = function(self)
		local s = TW and TW.stage and TW.stage.noteShift
		self:x((s and s[idx]) or 0)
	end
	return t
end
local function blank()
	if Var "SpriteOnly" then
		return Def.Sprite { Texture = "/NoteSkins/common/common/_blank.png", InitCommand = function(self) self:visible(false) end }
	end
	return Def.Actor { InitCommand = function(self) self:visible(false) end }
end
-- Customize gameplay's colours (TW.skinColour(part, column) -> r, g, b, a in 0..1, or nil for the
-- skin's own): a part with a colour draws its grey copy (made by VSRG Hub: SKIN.cols[i].g /
-- SKIN.grey; the original until the copy exists) tinted in it. tinted(spec, part, idx, tex, grey,
-- setup): the sprite's texture is picked for the colour in force and set again when it changes;
-- setup(self) does what depends on the texture (fitting, the texture rect) and runs after each load.
local function colourOf(part, idx)
	if TW and TW.skinColour then return TW.skinColour(part, idx) end
	return nil
end
local function fileExists(p)
	local ok, yes = pcall(function() return FILEMAN:DoesFileExist(p) end)
	return ok and yes
end
local function tinted(spec, part, idx, tex, grey, setup)
	local function apply(self)
		local r, g, b, a = colourOf(part, idx)
		local want = tex
		if r and grey then
			if self.twGreyOk == nil then self.twGreyOk = fileExists(grey) end
			if self.twGreyOk then want = grey end
		end
		if self.twTex ~= want then
			-- (the first time the sprite already has tex from its definition)
			if self.twTex ~= nil or want ~= tex then self:Load(want) end
			local first = self.twTex == nil
			self.twTex = want
			if setup and not (first and want == tex) then setup(self) end
		end
		if r then self:diffuse(color(r, g, b, a)) else self:diffuse(color(1, 1, 1, 1)) end
	end
	spec.Texture = tex
	local init, changed = spec.InitCommand, spec.TWLayoutChangedMessageCommand
	spec.InitCommand = function(self)
		if init then init(self) end
		apply(self)
	end
	spec.TWLayoutChangedMessageCommand = function(self, p)
		apply(self)
		if changed then changed(self, p) end
	end
	return spec
end

-- a note, hold head or mine: from the skin's picture, or from the sheet VSRG Hub wrote with one
-- picture per beat snap (sheetN pictures high; Etterna moves down to the note's snap), as tall as
-- the skin draws it (HS), turned for its column and over in upscroll when the skin asks for it
local function note(nw, file, sheet, sheetN, ratio, rot, hs, part, idx, grey)
	local HS = hs or HS
	local flip = SKIN.quaver and SKIN.flipUp and not rev()
	local function setup(self)
		if sheet then
			self:customtexturerect(0, 0, 1, 1 / sheetN)
			self.twW, self.twH = nw, nw * ratio * HS
		else
			local w, h = self:GetWidth(), self:GetHeight()
			if w and w > 0 then self.twW, self.twH = nw, h * nw / w * HS end
			inset(self)
		end
		scaled(self)
	end
	local s = tinted(Def.Sprite {
		InitCommand = function(self)
			setup(self)
			if flip then self:zoomy(-1) end
			if rot and rot ~= 0 then self:rotationz(rot) end
		end,
		TWLayoutChangedMessageCommand = scaled,
	}, part or "note", idx, sheet or path(file), grey, setup)
	-- (Etterna sets the note actor's own zoom and turn while drawing: the picture sits inside)
	if (rot and rot ~= 0) or flip then return Def.ActorFrame { s } end
	return s
end
-- Receptors under or over the notes: Quaver's ReceptorsOverHitObjects puts the key art in front of
-- the notes (Etterna's explosion layer, drawn after the notes and placed with the columns), and
-- Customize gameplay can put any skin's either way (TW.receptorsOrder: 0 as the skin says, 1 under,
-- 2 over). Both copies are made; the one in use shows, and the receptor underneath passes the key
-- presses on to the one on top.
local function overOn()
	local o = 0
	if TW and TW.receptorsOrder then o = tonumber(TW.receptorsOrder()) or 0 end
	if o == 1 then return false elseif o == 2 then return true end
	return SKIN.recOver and true or false
end
-- Customize gameplay's lighting settings (TW.lightLayout(kind): on, x, y, size, width, height) for
-- "lighting" (osu!'s LightingN, Quaver's hit lighting), "holdlight" (LightingL, Quaver's hold
-- lighting) and "collight" (Quaver's column lighting)
local function lightLayout(kind)
	if TW and TW.lightLayout then
		local on, x, y, z, w, h = TW.lightLayout(kind)
		return (tonumber(on) or 1) ~= 0, tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 1, tonumber(w) or 1, tonumber(h) or 1
	end
	return true, 0, 0, 1, 1, 1
end
local function receptor(c, idx, overlay)
	local nw = colNW(c)
	local flip = SKIN.downscrollArt and not rev()
	if SKIN.quaver then flip = SKIN.flipUp and not rev() end
	local hintFlip = SKIN.downscrollArt and not rev()
	local function place(self)
		fit(self, nw)
		inset(self)
		if c.keyRot then self:rotationz(c.keyRot) end
		self:valign(SKIN.receptorTop and 0 or 0.5)
		if SKIN.receptorTop then self:y(-nw / 2) end
		if flip then self:zoomy(-self:GetZoomX()); if SKIN.receptorTop then self:y(nw / 2) end end
	end
	local t = Def.ActorFrame {}
	-- the hit line across the column: the skin's stage hint (osu! bar skins often have no receptor
	-- and use only this) and osu!'s optional judgement line
	-- In VSRG Hub's looks the hit line is one picture across the whole stage, as osu! and Quaver
	-- draw it (drawn per column it doubled up or broke where columns overlap or have gaps): the
	-- first column draws it, from the stage's middle (TW.stage.recX: each receptor's place), moved
	-- and sized by Customize gameplay's Stage hint offset and height (TW.hintLayout). Worked out as
	-- it is drawn: the map preview (TW.previewDrawing) keeps it per column.
	local function hintPlace(self, h0, isLine)
		local s = TW and TW.stage
		local whole = TW and TW.hintLayout and not TW.previewDrawing and s and s.recX and s.recX[idx]
		local off, hm = 0, 1
		if TW and TW.hintLayout then off, hm = TW.hintLayout() end
		local w = W
		if whole then
			-- (Til' Death and Rebirth size the columns themselves: the column's own units are zoomed)
			local zw = s.colZoom or 1
			w = (s.stageW or (W * #s.recX)) / zw
			self:x(((s.hintCX or 0) - s.recX[idx]) / zw)
		else
			self:x(0)
		end
		self:y(rev() and (off or 0) or -(off or 0))
		if isLine then self:zoomto(w, 1) else self:setsize(w, math.max(1, h0 * (hm or 1))) end
		return not whole or idx == 1
	end
	local function hintFrame(child, h0, isLine)
		return Def.ActorFrame {
			InitCommand = function(self)
				self:SetDrawFunction(function(fr)
					local sp = fr:GetChild("H")
					if sp and hintPlace(sp, h0, isLine) then sp:Draw() end
				end)
			end,
			child .. { Name = "H" },
		}
	end
	if SKIN.hint then
		local h = (SKIN.hintH and SKIN.hintH > 0) and SKIN.hintH or 8
		if SKIN.hintR then h = W * SKIN.hintR end -- Quaver: as wide as the stage, its own proportions
		t[#t + 1] = hintFrame(tinted(Def.Sprite { InitCommand = function(self)
			if hintFlip then self:zoomy(-1) end
		end }, "hint", idx, SKIN.dir .. SKIN.hint, SKIN.grey and SKIN.grey.hint, function(self) self:setsize(W, h); inset(self) end), h)
	end
	if SKIN.judgeLine then
		t[#t + 1] = hintFrame(Def.Quad { InitCommand = function(self) self:zoomto(W, 1):diffuse(color("#FFFFFFE6")) end }, 1, true)
	end
	-- the key art, moved and sized by VSRG Hub's Customize gameplay (receptor offset / size)
	local function layout(self)
		local off, z, zw, zh = 0, 1, 1, 1
		if TW and TW.receptorLayout then off, z, zw, zh = TW.receptorLayout() end
		self:y(rev() and off or -off):zoomx(z * (zw or 1)):zoomy(z * (zh or 1))
	end
	local k = Def.ActorFrame { InitCommand = layout, TWLayoutChangedMessageCommand = layout }
	-- Quaver's column lighting, behind the notes: lights up the column above the receptor while the
	-- key is held (in the column's colour) and fades out when it is let go
	if SKIN.colLight and not overlay then
		local base = nil
		local function lightPlace(self)
			if not base then return end
			local on, x, y, z, zw, zh = lightLayout("collight")
			self:visible(on):x(x):zoomx(z * zw):zoomy(z * zh * (base.flip and -1 or 1))
			self:y(base.y + (rev() and -y or y))
		end
		k[#k + 1] = Def.Sprite { Texture = path(SKIN.colLight),
			InitCommand = function(self)
				local w, h = self:GetWidth(), self:GetHeight()
				if w and w > 0 then self:setsize(nw, nw * h / w * (SKIN.colLightScale or 1)) end
				local edge = nw * (c.keyR or 1) / 2 + (SKIN.colLightY or 0)
				local flip = false
				if rev() then self:valign(1); base = { y = -edge } else self:valign(0); base = { y = edge } end
				if SKIN.flipUp and not rev() then self:valign(1); flip = true end
				base.flip = flip
				self:diffusealpha(0)
				lightPlace(self)
			end,
			TWLayoutChangedMessageCommand = lightPlace,
			PressCommand = function(self)
				local col = c.colour or { 255, 255, 255 }
				local r, g, b, a = colourOf("collight", idx)
				if r then self:diffuse(color(r, g, b, 0)) else self:diffuse(color(col[1] / 255, col[2] / 255, col[3] / 255, 0)) end
				self:stoptweening():linear(0.02):diffusealpha(r and a or 1)
			end,
			LiftCommand = function(self) self:stoptweening():decelerate(0.15):diffusealpha(0) end,
		}
	end
	if overlay then
		t = Def.ActorFrame {} -- (the hit line stays under the notes)
		-- pressed or not, as told by the receptor underneath
		k.TWKeyMessageCommand = function(self, p)
			if p.col == idx then self:playcommand(p.down and "Press" or "Lift") end
		end
	else
		t[#t + 1] = Def.Actor {
			PressCommand = function() MESSAGEMAN:Broadcast("TWKey", { col = idx, down = true }) end,
			LiftCommand = function() MESSAGEMAN:Broadcast("TWKey", { col = idx, down = false }) end,
		}
	end
	-- the key art: under the notes, or this copy over them
	local keys = Def.ActorFrame {
		InitCommand = function(self) self:visible(overlay == overOn()) end,
		TWLayoutChangedMessageCommand = function(self) self:visible(overlay == overOn()) end,
	}
	-- (place sets the art's size and turn from its texture: done again when a grey copy loads,
	-- the turn taken back first)
	local function replace(self) if self:GetZoomY() < 0 then self:zoomy(-self:GetZoomY()) end; place(self) end
	if c.key then
		keys[#keys + 1] = tinted(Def.Sprite { InitCommand = place,
			PressCommand = function(self) if c.keyD then self:visible(false) end end,
			LiftCommand = function(self) self:visible(true) end }, "key", idx, path(c.key), c.g and c.g.key, replace)
	end
	if c.keyD then
		keys[#keys + 1] = tinted(Def.Sprite {
			InitCommand = function(self) place(self); self:visible(false) end,
			PressCommand = function(self) self:visible(true) end,
			LiftCommand = function(self) self:visible(false) end }, "keyd", idx, path(c.keyD), c.g and c.g.keyD, replace)
	end
	if #keys > 0 then k[#k + 1] = keys end
	if #k > 0 then t[#t + 1] = k end
	if #t == 0 then t[#t + 1] = Def.Actor {} end
	return shifted(t, idx)
end

-- Quaver's hit lighting (played once when a note is hit) and hold lighting (looped while a hold
-- is held), over the receptor, sized from the picture itself (HitLightingScale, Quaver's screen
-- is 1080 tall) and moved by HitLightingX/Y
local function lighting(c)
	local hit, hold = SKIN.hitLight, SKIN.holdLight
	if not hit and not hold then return blank() end
	local k = W / (SKIN.width or 64) -- (Til' Death / Rebirth columns)
	local mode, t, alpha = nil, 0, 1
	local sprites = {}
	local function part(spec, name)
		if not spec then return Def.Actor {} end
		return tinted(Def.Sprite {
			Name = name,
			InitCommand = function(self)
				sprites[name] = self
				-- (added onto what is under it, as Quaver does: lighting art is drawn on black)
				self:animate(false):setstate(0):visible(false):blend("BlendMode_Add")
				local z = spec.scale / 100 * 480 / 1080 * k
				self:zoom(z)
				self.twZ = z
				-- (Customize gameplay's settings for this kind, also set again by the frame's layout)
				local on, x, y, zz, zw, zh = lightLayout(name == "hit" and "lighting" or "holdlight")
				self.twOn = on
				self:xy(x, rev() and -y or y):zoomx(z * zz * zw):zoomy(z * zz * zh)
				if spec.rotate and c.rot then self:rotationz(c.rot) end
			end
		}, name == "hit" and "lightn" or "lightl", nil, spec.file, SKIN.grey and (name == "hit" and SKIN.grey.hitLight or SKIN.grey.holdLight), function(self) self:animate(false):setstate(0) end)
	end
	local function lightAlpha(n)
		local _, _, _, a = colourOf(n == "hit" and "lightn" or "lightl")
		return a or 1
	end
	local function show(which)
		for n, sp in pairs(sprites) do sp:visible(n == which and sp.twOn ~= false):setstate(0):diffusealpha(lightAlpha(n)) end
	end
	local function update(self, dt)
		if not mode then return end
		local spec = mode == "hit" and hit or hold
		local sp = sprites[mode]
		if not spec or not sp then return end
		t = t + dt
		if spec.n > 1 then
			local f = math.floor(t * spec.fps)
			if mode == "hit" and f >= spec.n then sp:visible(false); mode = nil; return end
			sp:setstate(f % spec.n)
		else
			-- one picture: Quaver fades it out (a hit) or pulses it (a hold) over 120 ms
			local a = t / 0.12
			local la = lightAlpha(mode)
			if mode == "hit" then
				if a >= 1 then sp:visible(false); mode = nil; return end
				sp:diffusealpha((1 - a) * la)
			else
				local p = a % 2
				sp:diffusealpha((p < 1 and 1 - p or p - 1) * la)
			end
		end
	end
	local function start(which)
		if not (which == "hit" and hit or which == "hold" and hold) then return end
		mode, t = which, 0
		show(which)
	end
	local function layout(self)
		local off, z = 0, 1
		if TW and TW.receptorLayout then off, z = TW.receptorLayout() end
		self:xy((SKIN.lightX or 0) * k, (rev() and off or -off) + (SKIN.lightY or 0) * k)
		-- (Customize gameplay: each kind on or off, moved and sized)
		for name, kind in pairs({ hit = "lighting", hold = "holdlight" }) do
			local sp = self:GetChild(name)
			if sp and sp.twZ then
				local on, x, y, zz, zw, zh = lightLayout(kind)
				sp.twOn = on
				if not on then sp:visible(false) end
				sp:xy(x, rev() and -y or y):zoomx(sp.twZ * zz * zw):zoomy(sp.twZ * zz * zh)
			end
		end
	end
	-- (Etterna places the explosion actor itself on the receptor: the lighting sits inside it)
	return Def.ActorFrame { Def.ActorFrame {
		InitCommand = function(self) layout(self); self:SetUpdateFunction(update) end,
		TWLayoutChangedMessageCommand = layout,
		W1Command = function() if mode ~= "hold" then start("hit") end end,
		W2Command = function() if mode ~= "hold" then start("hit") end end,
		W3Command = function() if mode ~= "hold" then start("hit") end end,
		W4Command = function() if mode ~= "hold" then start("hit") end end,
		W5Command = function() if mode ~= "hold" then start("hit") end end,
		HoldingOnCommand = function() start("hold") end,
		RollOnCommand = function() start("hold") end,
		HoldingOffCommand = function() if mode == "hold" then mode = nil; show(nil) end end,
		RollOffCommand = function() if mode == "hold" then mode = nil; show(nil) end end,
		part(hit, "hit"),
		part(hold, "hold"),
	} }
end

-- osu!'s LightingN (a flash over the hit line when a note is hit: fades in for 80 ms, then out for
-- 120 ms) and LightingL (looped over the hit line while a hold is held), added onto what is under
-- them, at the pictures' own size times the column's LightingNWidth / LightingLWidth share
local function osuLighting(c)
	local N, L = SKIN.lightN, SKIN.lightL
	local k = W / (SKIN.width or 64) -- (Til' Death / Rebirth columns)
	local sprites, clock, holding = {}, { N = 0, L = 0 }, false
	local KIND = { N = "lighting", L = "holdlight" }
	local function place(self, name)
		local on, x, y, z, zw, zh = lightLayout(KIND[name])
		self:visible(on):xy(x, rev() and -y or y):zoomx(self.twZ * z * zw):zoomy(self.twZ * z * zh)
	end
	local function part(spec, name, scale)
		if not spec then return Def.Actor {} end
		return tinted(Def.Sprite {
			InitCommand = function(self)
				sprites[name] = self
				self:animate(false):setstate(0):diffusealpha(0):blend("BlendMode_Add")
				self.twZ = spec.px * (scale or 1) * k
				place(self, name)
			end,
			TWLayoutChangedMessageCommand = function(self) place(self, name) end,
		}, name == "N" and "lightn" or "lightl", nil, spec.file, SKIN.grey and (name == "N" and SKIN.grey.lightN or SKIN.grey.lightL), function(self) self:animate(false):setstate(0) end)
	end
	-- (the tint's alpha caps the flash)
	local function lightAlpha(name)
		local _, _, _, a = colourOf(name == "N" and "lightn" or "lightl")
		return a or 1
	end
	local function update(self, dt)
		for name, spec in pairs({ N = N, L = L }) do
			local sp = sprites[name]
			if sp and spec.n > 1 then
				clock[name] = clock[name] + dt
				local f = math.floor(clock[name] / spec.frameLen)
				if name == "N" then f = math.min(f, spec.n - 1) else f = f % spec.n end
				sp:setstate(f)
			end
		end
	end
	local function flash()
		local sp = sprites.N
		if not sp then return end
		clock.N = 0
		sp:setstate(0):stoptweening():diffusealpha(0):linear(0.08):diffusealpha(lightAlpha("N")):linear(0.12):diffusealpha(0)
	end
	local function hold(on)
		local sp = sprites.L
		if not sp or on == holding then return end
		holding = on
		if on then clock.L = 0; sp:setstate(0):stoptweening():linear(0.08):diffusealpha(lightAlpha("L"))
		else sp:stoptweening():linear(0.12):diffusealpha(0) end
	end
	return Def.ActorFrame { Def.ActorFrame {
		InitCommand = function(self) self:SetUpdateFunction(update) end,
		W1Command = flash, W2Command = flash, W3Command = flash, W4Command = flash, W5Command = flash,
		HoldingOnCommand = function() hold(true) end,
		RollOnCommand = function() hold(true) end,
		HoldingOffCommand = function() hold(false) end,
		RollOffCommand = function() hold(false) end,
		part(N, "N", c.lN),
		part(L, "L", c.lL),
	} }
end

ret.Redir = function(b, e) return b, e end
ret.Rotate = {}
ret.PartsToRotate = {}
ret.Blank = {}

-- a hold's head
local function headArt(c, nw, idx)
	local g = c.g or {}
	if c.headS then return note(nw, nil, c.headS, c.headN, c.headR, c.rot, c.hs, "head", idx, g.headS) end
	if c.head then return note(nw, c.head, nil, nil, nil, c.rot, c.hs, "head", idx, g.head) end
	return note(nw, c.note, c.noteS, c.noteN, c.noteR, c.rot, c.hs, "head", idx, g.noteS or g.note)
end

ret.Load = function()
	local idx = SKIN.buttons[Var "Button"] or 0
	local c = SKIN.cols[idx]
	local e = string.lower(Var "Element")
	if not c then return fallbackLoad() end
	local nw = colNW(c)
	local g = c.g or {}
	if e == "tap note" or e == "tap lift" or e == "tap fake" then return note(nw, c.note, c.noteS, c.noteN, c.noteR, c.rot, c.hs, "note", idx, g.noteS or g.note) end
	if e:find("head") then return headArt(c, nw, idx) end
	if e == "tap mine" and c.mine then return note(nw, c.mine, nil, nil, nil, c.rot, c.hs, "mine", idx, g.mine) end
	if e:find("body") then
		-- (a body VSRG Hub copied at a power-of-two size keeps the skin's proportions: bodyR)
		local function bodyFit(self)
			self.twBody = true
			if c.bodyR then self.twW, self.twH = nw, nw * c.bodyR
			else
				local w, h = self:GetWidth(), self:GetHeight()
				if w and w > 0 then self.twW, self.twH = nw, h * nw / w end
			end
			scaled(self)
		end
		if c.body then return tinted(Def.Sprite { InitCommand = bodyFit, TWLayoutChangedMessageCommand = scaled }, "body", idx, path(c.body), g.body, bodyFit) end
		-- the skin's own body can't be used: a plain body in its colour (made by VSRG Hub)
		if c.bodyGen and c.bodyFit then
			return tinted(Def.Sprite { InitCommand = bodyFit, TWLayoutChangedMessageCommand = scaled }, "body", idx, c.bodyGen, g.body, bodyFit)
		end
		if c.bodyGen then
			local function plainFit(self)
				self.twBody = true
				self.twW, self.twH = nw * ((c.bodyW and c.bodyW > 0) and c.bodyW or 0.9), nw
				scaled(self)
			end
			return tinted(Def.Sprite { InitCommand = plainFit, TWLayoutChangedMessageCommand = scaled }, "body", idx, c.bodyGen, g.body, plainFit)
		end
		return blank()
	end
	-- The hold's end image. Etterna draws the bottom cap at the hold's far end (in downscroll it
	-- swaps the caps and turns the hold's art over: FlipHoldBodyWhenReverse=1), and the body stops one
	-- cap height short of that end (metrics), so the image sits inside the hold with its far edge on
	-- the hold's end, as osu! and Quaver draw it; the other end of the body starts in the middle of
	-- the head, behind it. osu! turns its tail art over in downscroll, Quaver turns its end art over
	-- in upscroll (tailFlip says which): Etterna's own turn in downscroll does the one, the art
	-- VSRG Hub writes turned over (tailF) the other.
	-- Customize gameplay's LN tail height and offset (TW.tailLayout: a size and how far the far edge
	-- moves away from the head, in pixels). Etterna draws the end image from where the body stops
	-- (fixed by the noteskin's metrics) for the image's own height: the tail is never drawn over
	-- the body or past the head. A tail moved out (offset > 0) fills the space with its own first
	-- row, so it reads as the body going on to it; a taller tail (or one moved in) is cut where the
	-- body stops.
	local function tailLayout(self)
		local h0 = self.twH0
		if not h0 or h0 <= 0 then return end
		local hm, off = 1, 0
		if TW and TW.tailLayout then hm, off = TW.tailLayout() end
		local k = noteScale()
		local dw, dh = noteDims()
		hm = math.max(0.2, (hm or 1) * k * dh)
		off = off or 0
		local ht = h0 * hm
		local H = math.max(1, h0 + off)
		local f0 = 1 - H / ht
		self:SetStateProperties { { Frame = 0, Delay = 0, { 0, f0 }, { 1, 1 } } }
		self:setsize(nw * k * dw, H)
	end
	local function tailSprite(tex, grey)
		local function setup(self)
			-- (an end VSRG Hub copied at a power-of-two size keeps the skin's proportions: tailR)
			if c.tailR then self:setsize(nw, nw * c.tailR * (c.hs or 1)) else fitH(self, nw, c.hs) end
			self.twH0 = self:GetHeight(); tailLayout(self)
		end
		return tinted(Def.Sprite { InitCommand = setup,
			TWLayoutChangedMessageCommand = function(self) tailLayout(self) end }, "tail", idx, tex, grey, setup)
	end
	local function cap(flip)
		if flip and c.tailF then return tailSprite(c.tailF, g.tailF) end
		return tailSprite(path(c.tail), g.tail)
	end
	if e:find("bottomcap") then
		if not c.tail then return blank() end
		local flip = not SKIN.tailFlip
		-- (a Quaver skin can keep its end art the right way up in upscroll)
		if SKIN.quaver and not SKIN.endFlipUp and not rev() then flip = false end
		return cap(flip)
	end
	if e:find("topcap") then return blank() end
	if e:find("tail") then return blank() end
	if e == "receptor" then return receptor(c, idx, false) end

	-- the skin's own lighting instead of Etterna's stock explosions
	if e:find("explosion") then
		local t = Def.ActorFrame {}
		-- In VSRG Hub's map preview a hold's head stays on the receptor while the hold goes by (the
		-- preview says when: TW.previewHeld); it is never drawn in play, where Etterna does that.
		local held = headArt(c, nw, idx)
		t[#t + 1] = Def.ActorFrame {
			InitCommand = function(self)
				self:SetDrawFunction(function(frame)
					if TW and TW.previewDrawing and TW.previewHeld and TW.previewHeld(idx - 1) then
						frame:GetChild("Head"):Draw()
					end
				end)
			end,
			held .. { Name = "Head" },
		}
		-- the receptor's copy over the notes (shown when they go over: overOn)
		t[#t + 1] = receptor(c, idx, true)
		local lit = shifted(Def.ActorFrame {}, idx)
		t[#t + 1] = lit
		if not SKIN.quaver then
			if SKIN.lightN or SKIN.lightL then lit[#lit + 1] = osuLighting(c) end
			return t
		end
		if SKIN.hitLight or SKIN.holdLight then lit[#lit + 1] = lighting(c) end
		return t
	end
	return fallbackLoad()
end

return ret
