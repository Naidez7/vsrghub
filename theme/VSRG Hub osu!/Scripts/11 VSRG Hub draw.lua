-- Drawing pieces the looks share: rounded (and slanted) boxes with smooth corners, soft shadows,
-- glows, icons, and drifting triangles. Boxes are one ActorMultiVertex each, nine-sliced from a
-- small round texture, so corners stay smooth at any size and colour; a box can be redrawn at a
-- new size or colour with TW.setBox.
TW.GFX = "/Themes/VSRG Hub osu!/Graphics/_vh/"
-- one screen pixel in Etterna's units
-- (kept, not asked of Etterna for every shape drawn; TW.pxReset forgets it when the window changes)
local pxCache = nil
function TW.px()
	if not pxCache then pxCache = SCREEN_HEIGHT / math.max(1, DISPLAY:GetDisplayHeight()) end
	return pxCache
end
function TW.pxReset() pxCache = nil end

-- An icon (Font Awesome Free, white, square): name as in Graphics/_vh/icons ("gear", "heart-o").
-- (a 64 pixel copy for icons drawn small, so they aren't shrunk from far bigger pictures)
function TW.iconPath(name, size)
	if size and size / TW.px() <= 56 then return TW.GFX .. "icons64/" .. name .. ".png" end
	return TW.GFX .. "icons/" .. name .. ".png"
end
function TW.icon(name, size, init)
	return Def.Sprite {
		Texture = TW.iconPath(name, size),
		InitCommand = function(self)
			self:zoomto(size, size)
			if init then init(self) end
		end,
	}
end

local function lerpc(a, b, f)
	return { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * f }
end
TW.lerpc = lerpc
local function clear(c) return { c[1], c[2], c[3], 0 } end

-- Edges are drawn smooth (antialiased) by the shapes themselves: Etterna draws without multisampling,
-- so every edge gets a band about one screen pixel wide that fades from the shape's colour to clear.
-- TW.px is one screen pixel in Etterna's units.
local function feather() return TW.px() * 1.1 end

-- Vertex lists. A list can be kept and refilled every frame (TW.vbegin, then the shapes, then
-- TW.vend): its vertex tables are reused instead of made anew, which matters for the shapes redrawn
-- every frame (the visualizer, drifting triangles). A fresh table works as before.
local function put(v, x, y, c)
	local n = (v._n or 0) + 1
	v._n = n
	local e = v[n]
	if e then
		local q = e[1]
		q[1], q[2] = x, y
		e[2] = c
	else
		v[n] = { { x, y, 0 }, c }
	end
end
function TW.vbegin(v) v._n = 0 return v end
TW.vput = put
function TW.vend(v)
	local n = v._n or #v
	for i = #v, n + 1, -1 do v[i] = nil end
	return v
end
local function tri(v, a, b, c, ca, cb, cc)
	put(v, a[1], a[2], ca)
	put(v, b[1], b[2], cb)
	put(v, c[1], c[2], cc)
end
local function quad(v, a, b, c, d, ca, cb, cc, cd)
	tri(v, a, b, c, ca, cb, cc)
	tri(v, a, c, d, ca, cc, cd)
end
local function quadxy(v, ax, ay, bx, by, cx, cy, dx, dy, ca, cb, cc, cd)
	put(v, ax, ay, ca); put(v, bx, by, cb); put(v, cx, cy, cc)
	put(v, ax, ay, ca); put(v, cx, cy, cc); put(v, dx, dy, cd)
end
TW.aaTri, TW.aaQuad = tri, quad

-- (the colours of the last line, kept: lines drawn in a row usually share them)
local lc0, lc1, lk, la0, la1, lz0, lz1
-- A smooth line (or bar) from p0 to p1, w wide, colour c0 at p0 fading to c1 at p1, appended to the
-- triangle list v.
function TW.aaLine(v, x0, y0, x1, y1, w, c0, c1)
	c1 = c1 or c0
	local dx, dy = x1 - x0, y1 - y0
	local len = math.sqrt(dx * dx + dy * dy)
	if len <= 0 then return end
	local f = feather()
	local nx, ny = -dy / len, dx / len
	local hi = math.max(0, w / 2 - f / 2)
	local ho = w / 2 + f / 2
	-- (a line thinner than a pixel is drawn a pixel wide, fainter)
	local k = math.min(1, w / f)
	if c0 ~= lc0 or c1 ~= lc1 or k ~= lk then
		lc0, lc1, lk = c0, c1, k
		la0 = { c0[1], c0[2], c0[3], (c0[4] or 1) * k }
		la1 = { c1[1], c1[2], c1[3], (c1[4] or 1) * k }
		lz0, lz1 = clear(la0), clear(la1)
	end
	local a0, a1, z0, z1 = la0, la1, lz0, lz1
	local ox, oy, ix, iy = nx * ho, ny * ho, nx * hi, ny * hi
	-- across the line: outer edge, inner edge, inner edge, outer edge (A at p0, B at p1)
	local A1x, A1y, A2x, A2y, A3x, A3y, A4x, A4y = x0 - ox, y0 - oy, x0 - ix, y0 - iy, x0 + ix, y0 + iy, x0 + ox, y0 + oy
	local B1x, B1y, B2x, B2y, B3x, B3y, B4x, B4y = x1 - ox, y1 - oy, x1 - ix, y1 - iy, x1 + ix, y1 + iy, x1 + ox, y1 + oy
	quadxy(v, A1x, A1y, B1x, B1y, B2x, B2y, A2x, A2y, z0, z1, a1, a0)
	quadxy(v, A2x, A2y, B2x, B2y, B3x, B3y, A3x, A3y, a0, a1, a1, a0)
	quadxy(v, A3x, A3y, B3x, B3y, B4x, B4y, A4x, A4y, a0, a1, z1, z0)
end
-- A smooth filled triangle (equilateral-ish: corners pulled in along their bisectors)
function TW.aaTriangle(v, a, b, c, col)
	local f = feather()
	local cx, cy = (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3
	local function off(p, d)
		local dx, dy = cx - p[1], cy - p[2]
		local l = math.sqrt(dx * dx + dy * dy)
		if l <= 0 then return { p[1], p[2] } end
		return { p[1] + dx / l * d, p[2] + dy / l * d }
	end
	-- (half a feather inwards and outwards; at a 60 degree corner the bisector is twice that)
	local ai, bi, ci = off(a, f), off(b, f), off(c, f)
	local ao, bo, co = off(a, -f), off(b, -f), off(c, -f)
	tri(v, ai, bi, ci, col, col, col)
	local z = clear(col)
	quad(v, ai, bi, bo, ao, col, col, z, z)
	quad(v, bi, ci, co, bo, col, col, z, z)
	quad(v, ci, ai, ao, co, col, col, z, z)
end

-- The outline of a rounded rectangle w x h with corner radius r, grown by d (negative: shrunk), as
-- points round it (n per corner), the same points for any d.
local function contour(w, h, r, d, n)
	local rd = math.max(0, r + d)
	local pts = {}
	local cs = { { w + d - rd, h + d - rd, 0 }, { -d + rd, h + d - rd, 0.5 }, { -d + rd, -d + rd, 1 }, { w + d - rd, -d + rd, 1.5 } }
	for _, c in ipairs(cs) do
		for k = 0, n do
			local a = (c[3] + k / n * 0.5) * math.pi
			pts[#pts + 1] = { c[1] + math.cos(a) * rd, c[2] + math.sin(a) * rd }
		end
	end
	return pts
end

-- The box as triangles. spec fields:
--   w, h        size
--   r           corner radius (0: square corners; half the height: a pill; half of both: a circle)
--   shear       slant: the top moves right by shear * h relative to the bottom (osu!lazer's 0.15)
--   ax, ay      which point of the box sits at the actor's position (0 left/top .. 1 right/bottom)
--   col, col2   colour at the top and at the bottom (col2 optional)
--   left, right colour at the left and right edges instead (a gradient across)
--   tex         "round" (filled, the default) or "ring" (an outline, stroke wide: about a screen pixel
--               or a twelfth of the corner radius, whichever is wider)
local function boxVerts(s)
	local w, h = math.max(0, s.w or 0), math.max(0, s.h or 0)
	local r = math.min(s.r or 0, w / 2, h / 2)
	local sh = s.shear or 0
	local ox, oy = -(s.ax or 0) * w, -(s.ay or 0) * h
	local c1 = s.col or { 1, 1, 1, 1 }
	local c2 = s.col2 or c1
	local f = feather()
	local px = TW.px()
	-- (corner points: enough for a smooth curve at the size it is drawn)
	local n = math.max(1, math.min(24, math.ceil(math.sqrt(r / px) * 2.2)))
	local function colAt(x, y)
		if s.left then
			local cr = s.right or s.left
			return lerpc(s.left, cr, w > 0 and math.max(0, math.min(1, x / w)) or 0)
		end
		return lerpc(c1, c2, h > 0 and math.max(0, math.min(1, y / h)) or 0)
	end
	local function P(p) return { p[1] + (h / 2 - p[2]) * sh + ox, p[2] + oy } end
	local v = {}
	local function band(inner, outer, ain, aout)
		for i = 1, #inner do
			local j = i % #inner + 1
			local ci, cj = colAt(inner[i][1], inner[i][2]), colAt(inner[j][1], inner[j][2])
			local oi, oj = colAt(outer[i][1], outer[i][2]), colAt(outer[j][1], outer[j][2])
			if ain == 0 then ci, cj = clear(ci), clear(cj) end
			if aout == 0 then oi, oj = clear(oi), clear(oj) end
			quad(v, P(inner[i]), P(inner[j]), P(outer[j]), P(outer[i]), ci, cj, oj, oi)
		end
	end
	if s.tex == "ring" then
		local st = s.stroke or math.max(px * 1.3, r * 0.08)
		local o2 = contour(w, h, r, f / 2, n)
		local o1 = contour(w, h, r, -f / 2, n)
		local i1 = contour(w, h, r, -(st - f / 2), n)
		local i2 = contour(w, h, r, -(st + f / 2), n)
		band(o1, o2, 1, 0)
		if st > f then band(i1, o1, 1, 1) end
		band(i2, i1, 0, 1)
	else
		local inner = contour(w, h, r, -f / 2, n)
		local outer = contour(w, h, r, f / 2, n)
		local cx, cy = w / 2, h / 2
		local cc = colAt(cx, cy)
		for i = 1, #inner do
			local j = i % #inner + 1
			tri(v, P({ cx, cy }), P(inner[i]), P(inner[j]), cc, colAt(inner[i][1], inner[i][2]), colAt(inner[j][1], inner[j][2]))
		end
		band(inner, outer, 1, 0)
	end
	return v
end

TW.boxVerts = boxVerts

-- The old nine-slice drawing, for soft textures (the shadow)
local function sliceVerts(s)
	local w, h = math.max(0, s.w or 0), math.max(0, s.h or 0)
	local r = math.min(s.r or 0, w / 2, h / 2)
	local sh = s.shear or 0
	local ox, oy = -(s.ax or 0) * w, -(s.ay or 0) * h
	local c1 = s.col or { 1, 1, 1, 1 }
	local c2 = s.col2 or c1
	local xs = { 0, r, w - r, w }
	local ys = { 0, r, h - r, h }
	local us = { 0, 0.5, 0.5, 1 }
	local cols = {}
	for j = 1, 4 do cols[j] = lerpc(c1, c2, h > 0 and ys[j] / h or 0) end
	local function v(i, j)
		local y = ys[j]
		local x = xs[i] + (h / 2 - y) * sh
		return { { x + ox, y + oy, 0 }, cols[j], { us[i], us[j] } }
	end
	local verts = {}
	for j = 1, 3 do
		for i = 1, 3 do
			verts[#verts + 1] = v(i, j)
			verts[#verts + 1] = v(i + 1, j)
			verts[#verts + 1] = v(i + 1, j + 1)
			verts[#verts + 1] = v(i, j + 1)
		end
	end
	return verts
end

-- (re)draws a box made by TW.box or TW.shadow with changes (any of the spec's fields)
-- (a table value, a colour say, is kept as a copy: a caller may change its own table in place)
local function boxValueSame(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if b[k] ~= v then return false end end
	for k, v in pairs(b) do if a[k] ~= v then return false end end
	return true
end
local function boxValueCopy(v)
	if type(v) ~= "table" then return v end
	local c = {}
	for k, x in pairs(v) do c[k] = x end
	return c
end
function TW.setBox(self, changes)
	-- (a box is a frame holding the drawing, so a caller can add its own Init command to it)
	local amv = self
	if self.GetChild then
		local c = self:GetChild("AMV")
		if c then amv = c end
	end
	local s = amv.twBox or {}
	-- (nothing changed, as when a song panel is set again with the same song while the list moves:
	-- the shape is left as it is)
	local same = amv.twBoxDrawn and changes ~= nil
	if changes then
		for k, v in pairs(changes) do
			if same and not boxValueSame(s[k], v) then same = false end
			s[k] = boxValueCopy(v)
		end
	end
	amv.twBox = s
	if same then return self end
	amv.twBoxDrawn = true
	if amv.twSliced then amv:SetVertices(sliceVerts(s)) else amv:SetVertices(boxVerts(s)) end
	return self
end

local function boxActor(spec, tex, prepare)
	return Def.ActorFrame {
		InitCommand = function(self) if spec.init then spec.init(self) end end,
		Def.ActorMultiVertex {
			Name = "AMV",
			InitCommand = function(self)
				if tex then
					self:LoadTexture(TW.GFX .. tex .. ".png")
					self:SetDrawState { Mode = "DrawMode_Quads" }
					self.twSliced = true
				else
					self:SetDrawState { Mode = "DrawMode_Triangles" }
				end
				if spec.blend then self:blend(spec.blend) end
				local s = {}
				for k, v in pairs(spec) do s[k] = v end
				if prepare then prepare(self, s) end
				self.twBox = s
				TW.setBox(self)
			end,
		},
	}
end

function TW.box(spec) return boxActor(spec, nil) end
-- a smooth filled circle of radius r centred on the actor (col at the top, col2 at the bottom)
function TW.disc(r, col, col2, init)
	return TW.box { w = r * 2, h = r * 2, r = r, ax = 0.5, ay = 0.5, col = col, col2 = col2, init = init }
end
-- a smooth ring of radius r (outer edge), stroke wide
function TW.ringShape(r, stroke, col, init)
	return TW.box { w = r * 2, h = r * 2, r = r, ax = 0.5, ay = 0.5, tex = "ring", stroke = stroke, col = col, init = init }
end

-- A soft shadow (or glow, in a light colour) under a box of w x h: spread is how far it fades out.
-- drop moves it down a little (light from above).
function TW.shadow(spec)
	local spread = spec.spread or TW.M(18)
	local ax, ay = spec.ax or 0, spec.ay or 0
	return boxActor(spec, "shadow", function(self, s)
		s.w, s.h = (spec.w or 0) + spread * 2, (spec.h or 0) + spread * 2
		s.r = spread * 2
		s.col = spec.col or { 0, 0, 0, spec.alpha or 0.5 }
		-- (centred on the box it shades)
		self:xy((spec.x or 0) + (ax * 2 - 1) * spread, (spec.y or 0) + (ay * 2 - 1) * spread + (spec.drop or 0))
	end)
end

-- A round glow (light that fades out from the middle).
function TW.glow(size, col, init)
	return Def.Sprite {
		Texture = TW.GFX .. "glow.png",
		InitCommand = function(self)
			self:zoomto(size, size):diffuse(col or { 1, 1, 1, 0.5 }):blend("BlendMode_Add")
			if init then init(self) end
		end,
	}
end

-- Triangles drifting up over an area, as osu! draws them on its logo and lazer behind its menus.
-- spec: w, h, count, colour (or colours, a list to pick from), alpha (min, max), size (min, max),
-- speed (pixels per second), outline (true: only their edges)
function TW.triangles(spec)
	local w, h = spec.w, spec.h
	local n = spec.count or 40
	local tris = {}
	local smin, smax = (spec.size or {})[1] or TW.M(20), (spec.size or {})[2] or TW.M(80)
	local amin, amax = (spec.alpha or {})[1] or 0.05, (spec.alpha or {})[2] or 0.2
	local cols = spec.colours or { spec.colour or { 1, 1, 1, 1 } }
	local function new(t, anywhere)
		local s = smin + (smax - smin) * math.random() ^ 2
		t.s = s
		t.x = math.random() * w
		t.y = anywhere and math.random() * (h + s) or h + s
		t.a = amin + (amax - amin) * math.random()
		t.v = (spec.speed or TW.M(30)) * (0.5 + s / smax)
		t.c = cols[math.random(1, #cols)]
		t.col = { t.c[1], t.c[2], t.c[3], t.a }
	end
	for i = 1, n do tris[i] = {}; new(tris[i], true) end
	local outline = spec.outline
	-- (only frames have update functions: the frame redraws its triangles every frame; every edge
	-- is smooth)
	return Def.ActorFrame {
		InitCommand = function(frame)
			local self = frame:GetChild("T")
			self:SetDrawState { Mode = "DrawMode_Triangles" }
			local lw = spec.lineWidth or TW.M(1.6)
			local verts = {}
			TW.everyRefresh(frame)
			frame:SetUpdateFunction(function(_, dt)
				TW.vbegin(verts)
				for _, t in ipairs(tris) do
					t.y = t.y - t.v * (dt or 0)
					if t.y < -t.s then new(t, false) end
					local c = t.col
					local x0, x1, x2 = t.x - t.s / 2, t.x + t.s / 2, t.x
					local yb, yt = t.y + t.s * 0.433, t.y - t.s * 0.433
					if outline then
						TW.aaLine(verts, x0, yb, x1, yb, lw, c)
						TW.aaLine(verts, x1, yb, x2, yt, lw, c)
						TW.aaLine(verts, x2, yt, x0, yb, lw, c)
					else
						TW.aaTriangle(verts, { x0, yb }, { x1, yb }, { x2, yt }, c)
					end
				end
				self:SetVertices(TW.vend(verts))
			end)
			if spec.init then spec.init(frame) end
		end,
		Def.ActorMultiVertex { Name = "T" },
	}
end

-- Moves an actor a little with the mouse (osu!'s parallax on its menu backgrounds); amount in pixels
-- at the screen's edge. (self must be an ActorFrame: only frames have update functions)
function TW.parallax(self, amount)
	local bx, by = self:GetX(), self:GetY()
	TW.everyFrame(self)
	self:SetUpdateFunction(function(s)
		local mx = (INPUTFILTER:GetMouseX() / SCREEN_WIDTH - 0.5) * 2
		local my = (INPUTFILTER:GetMouseY() / SCREEN_HEIGHT - 0.5) * 2
		mx, my = math.max(-1, math.min(1, mx)), math.max(-1, math.min(1, my))
		local tx, ty = bx - mx * amount, by - my * amount
		s:xy(s:GetX() + (tx - s:GetX()) * 0.08, s:GetY() + (ty - s:GetY()) * 0.08)
	end)
end

-- The cookie (osu!'s logo shape with VSRG Hub's word): a white rim, a face in the interface colour
-- lighter at the top, triangles drifting up inside it, and the word (a picture, so it stays sharp at
-- any size). col: the face's colour (the interface colour when nil). Every edge is smooth. Its soft
-- shadow is TW.cookieShadow, drawn under the visualizer so the bars meet the rim.
function TW.cookieShadow(r) return TW.glow(r * 2.5, { 0, 0, 0, 0.5 }, function(self) self:blend("BlendMode_Normal") end) end
function TW.cookie(r, word, col)
	local face = col or TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.08)
	local light = TW.mix(face, { 1, 1, 1, 1 }, 0.28)
	local dark = TW.mix(face, { 0, 0, 0, 1 }, 0.12)
	local inner = r * 0.875
	local tris = {}
	for i = 1, 16 do tris[i] = { x = math.random() * 2 - 1, y = math.random() * 2 - 1, s = 0.12 + math.random() * 0.22, v = 0.03 + math.random() * 0.05 } end
	local t = Def.ActorFrame {
		-- rim, face
		TW.disc(r, color("#FFFFFF")),
		TW.disc(inner, light, dark),
		-- triangles drifting up inside the face (fading out towards its edge)
		Def.ActorFrame {
			InitCommand = function(frame)
				local self = frame:GetChild("T")
				self:SetDrawState { Mode = "DrawMode_Triangles" }
				local verts = {}
				TW.everyRefresh(frame)
				frame:SetUpdateFunction(function(_, dt)
					TW.vbegin(verts)
					for _, tr in ipairs(tris) do
						tr.y = tr.y - tr.v * (dt or 0)
						if tr.y < -1.1 then tr.y = 1.1; tr.x = math.random() * 1.6 - 0.8 end
						local d = math.sqrt(tr.x * tr.x + tr.y * tr.y)
						local a = math.max(0, 1 - d) * 0.32
						if a > 0.01 then
							local c = { 1, 1, 1, a }
							local cx, cy, s = tr.x * inner * 0.8, tr.y * inner * 0.8, tr.s * inner
							TW.aaTriangle(verts, { cx - s / 2, cy + s * 0.43 }, { cx + s / 2, cy + s * 0.43 }, { cx, cy - s * 0.43 }, c)
						end
					end
					self:SetVertices(TW.vend(verts))
				end)
			end,
			Def.ActorMultiVertex { Name = "T" },
		},
		-- a faint line where the face meets the rim, as if the rim stood out of it
		TW.ringShape(inner + TW.px() * 0.5, TW.px() * 2.5, { 0, 0, 0, 0.12 }),
	}
	-- (the word: a picture of it in a rounded black typeface, like osu!'s logo)
	local pics = { ["VSRG Hub"] = { "logo-word.png", 1.66 }, play = { "logo-play.png", 1.3 }, ["play!"] = { "logo-play2.png", 1.4 } }
	local pic = pics[word]
	if pic then
		t[#t + 1] = Def.Sprite { Texture = TW.GFX .. pic[1], InitCommand = function(self)
			self:zoomto(inner * pic[2], inner * pic[2] * self:GetHeight() / math.max(1, self:GetWidth()))
		end }
	else
		local f, z = TW.fontFor(r * 0.32, true)
		t[#t + 1] = LoadFont(f) .. { Text = word, InitCommand = function(self)
			self:zoom(z):shadowlength(r * 0.012):diffuse(color("#FFFFFF"))
			self:maxwidth(inner * 1.7 / z)
		end }
	end
	return t
end

-- The cookie's colour: osu!'s bright pink, or the interface colour picked in the options (when it
-- isn't taken from the skin).
function TW.cookieColour()
	local key = TW.settings and TW.settings.accent or "skin"
	if key ~= "skin" and key ~= "" then return TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.1) end
	return TW.rgb(255, 102, 170)
end

-- osu!'s logo visualiser (osu.Game/Screens/Menu/LogoVisualisation.cs): the music's spectrum as 200
-- bars round the logo, each the loudness of one band of frequencies (low to high going round),
-- drawn five times over turned a fifth further each time. Every 50 ms each bar jumps up to its band's
-- loudness (the bands shift five bars along each time, so the shape wanders round) and between
-- those it falls back. White, faint, added onto what's under it.
-- The spectrum comes from Etterna (SOUND:SetPlayBackCallback: the music being played, cut into
-- frequencies as it plays); TW.fft holds the latest, 256 bands from 0 to about 22 kHz.
TW.visualLevel = 0
function TW.visualKick(f) TW.visualLevel = math.max(TW.visualLevel, f or 1) end
TW.fft = TW.fft or {}
for i = 1, 256 do TW.fft[i] = TW.fft[i] or 0 end
TW.fftAt = TW.fftAt or -10
local function receiveSpectrum(power)
	-- (Etterna hands the power of each frequency of the last 1024 samples, both channels one after
	-- the other: the first half of the bins is the music's 0 to 22 kHz; as osu!'s audio library gives
	-- them, scaled so a full-volume tone is 1)
	local out, n = TW.fft, #power
	local norm = 2 / math.max(2, (n - 1) * 2)
	for k = 1, 256 do
		local v = power[k + 1]
		out[k] = v and math.sqrt(v) * norm or 0
	end
	TW.fftAt = GetTimeSinceStart()
end
-- the music's spectrum is wanted on this screen (Etterna stops sending it when the screen changes)
function TW.listenMusic()
	pcall(function() SOUND:SetPlayBackCallback(receiveSpectrum, 1024) end)
end
function TW.visualizer(r, col)
	local BARS, ROUNDS = 200, 5
	-- osu!lazer's bars are wide, touching each other; osu!stable's are thin lines, many more of
	-- them (its five rounds don't land on the same places)
	local stable = not TW.isLazer
	local amp = {}
	for i = 1, BARS do amp[i] = 0 end
	local offset, acc, listening = 0, 0, false
	-- (osu!'s sizes for a logo of this size: osu!'s logo is 480 across with bars up to 600 long)
	local maxLen = r * 2 * 600 / 480
	local width = stable and math.max(1, TW.M(1.1)) or r * 2 * math.sqrt(2 * (1 - math.cos(math.rad(360 / BARS)))) / 2
	local c = { (col or {})[1] or 1, (col or {})[2] or 1, (col or {})[3] or 1, stable and 0.4 or 0.2 }
	local dead = 1 / 600
	local cosT, sinT = {}, {}
	for i = 1, BARS do
		local a = (i - 1) / BARS * math.pi * 2
		cosT[i], sinT[i] = math.cos(a), math.sin(a)
	end
	local t = Def.ActorFrame {
		InitCommand = function(frame)
			local self = frame:GetChild("V")
			self:SetDrawState { Mode = "DrawMode_Quads" }:blend("BlendMode_Add")
			local verts = {}
			TW.everyRefresh(frame)
			frame:SetUpdateFunction(function(_, dt)
				dt = dt or 0
				if not listening then listening = true; TW.listenMusic() end
				TW.visualLevel = TW.visualLevel * math.exp(-dt * 4)
				-- every 50 ms: each bar up to its band (shifted along), when that's higher
				acc = acc + dt
				if acc >= 0.05 then
					acc = 0
					local fresh = GetTimeSinceStart() - TW.fftAt < 0.3
					local fft = TW.fft
					for i = 1, BARS do
						-- (Etterna's spectrum falls off faster towards the highs than osu!'s audio library
						-- gives it: its square root reads as osu!'s bars do)
						local v = fresh and (fft[(i - 1 + offset) % BARS + 1] or 0) or 0
						local target = math.min(1, math.sqrt(v) * 0.9) * 0.5
						if target > amp[i] then amp[i] = target end
					end
					offset = (offset + 5) % BARS
				end
				-- falling back (a little faster near the bottom)
				local decay = dt * 1000 * 0.0024
				TW.vbegin(verts)
				local hw = width / 2
				for i = 1, BARS do
					local a = amp[i] - decay * (amp[i] + 0.03)
					if a < 0 then a = 0 end
					amp[i] = a
					if a >= dead then
						local ca, sa = cosT[i], sinT[i]
						local len = maxLen * a
						local bx, by = ca * r, sa * r
						local ox, oy = -sa * hw, ca * hw
						local ex, ey = ca * len, sa * len
						TW.vput(verts, bx - ox, by - oy, c)
						TW.vput(verts, bx - ox + ex, by - oy + ey, c)
						TW.vput(verts, bx + ox + ex, by + oy + ey, c)
						TW.vput(verts, bx + ox, by + oy, c)
					end
				end
				self:SetVertices(TW.vend(verts))
			end)
		end,
		OnCommand = function() TW.listenMusic() end,
		Def.ActorMultiVertex { Name = "V" },
	}
	-- the other four rounds: the same bars turned a fifth further each
	for j = 1, ROUNDS - 1 do
		t[#t + 1] = Def.ActorProxy {
			OnCommand = function(self) self:SetTarget(self:GetParent():GetChild("V")):rotationz(j * 360 / ROUNDS + (stable and j * 360 / BARS / ROUNDS or 0)) end,
		}
	end
	return t
end

-- Light flashing in from the screen's sides on the music's strong beats (osu!'s menu side flashes):
-- MESSAGEMAN:Broadcast("TWBeatFlash") lights them.
function TW.sideFlashes(col, w)
	col = col or { 1, 1, 1, 1 }
	w = w or TW.M(240)
	local function side(left)
		-- (bright at the screen's edge, fading to nothing inwards; the frame holding it does the flashing,
		-- so the fade stays a fade)
		return Def.ActorFrame {
			InitCommand = function(self) self:diffusealpha(0) end,
			TWBeatFlashMessageCommand = function(self)
				self:stoptweening():linear(0.05):diffusealpha(1):decelerate(0.9):diffusealpha(0)
			end,
			Def.Quad {
				InitCommand = function(self)
					self:align(left and 0 or 1, 0):xy(left and 0 or SCREEN_WIDTH, 0):zoomto(w, SCREEN_HEIGHT):blend("BlendMode_Add")
					self:diffuse({ col[1], col[2], col[3], 0 })
					if left then self:diffuseleftedge({ col[1], col[2], col[3], 0.18 }) else self:diffuserightedge({ col[1], col[2], col[3], 0.18 }) end
				end,
			},
		}
	end
	return Def.ActorFrame { side(true), side(false) }
end
