-- osu! stable's song select carousel, measured from osu!'s own layout (McOsu's re-implementation of
-- it, which uses the same numbers, checked against osu! itself): the skin's menu-button-background
-- drawn at its own size; the transparent edge the art has (9 pixels of the 699x103 original)
-- is left out of the spacing, so neighbouring panels overlap there; the panels sit on a gentle curve
-- on the right, the middle ones furthest out to the left; an open song's difficulties sit further
-- left still, each its own panel with a tenth of a panel's height above it.
--
-- TW.stableGeom(): the sizes for the skin in use (screen units):
--   bw, bh   the panel as drawn (the art's own shape)
--   ox, oy   the art's transparent edge at that size
--   aw, ah   the panel inside that edge (where its text and thumbnail go; ah is the list's spacing)
--   V        the width of osu!'s list area (the screen right of the info at the top left)
--   half     half the list area's height (the curve flattens out over it)
-- TW.stableX(c, p): the panel's left edge for curve c (1 in the middle of the list, 0 at its
-- top and bottom) and pull p (0.075 for an open song's difficulties)

local G
TW.stablePanelSize = TW.stablePanelSize or {}

-- (the panel sprite reports the art's size the first time it loads it)
function TW.stableSawPanel(spr)
	local key = TW_SKIN and TW_SKIN.folder or "-"
	if TW.stablePanelSize[key] then return end
	local w, h
	pcall(function()
		local tex = spr:GetTexture()
		w, h = tex:GetSourceWidth(), tex:GetSourceHeight()
	end)
	if not (w and h and w > 0 and h > 0) then w, h = spr:GetWidth(), spr:GetHeight() end
	if w and h and w > 0 and h > 0 then
		TW.stablePanelSize[key] = { w, h }
		G = nil
	end
end

function TW.stableGeom()
	local key = TW_SKIN and TW_SKIN.folder or "-"
	if G and G.key == key and G.sw == SCREEN_WIDTH then return G end
	local m = math.min(SCREEN_WIDTH / 640, SCREEN_HEIGHT / 480)
	local art = TW.has("songpanel")
	local k2 = (art and TW.hd("songpanel")) and 2 or 1
	local size = art and TW.stablePanelSize[key] or nil
	local iw, ih = 699 * k2, 103 * k2
	if size then iw, ih = size[1], size[2] end
	-- (osu! stable draws the art at its own size, in osu!'s 768-tall screen: a skin's art that is
	-- shorter than the usual 103 makes shorter panels, closer together. McOsu instead stretches every
	-- skin's art to the same height.)
	local f = SCREEN_HEIGHT / 768 / k2
	local bw, bh = iw * f, ih * f
	local ox = 9 * f * k2
	local oy = math.max(0, ((18 + ih / k2 - 103) / 2) * f * k2)
	G = {
		key = key, sw = SCREEN_WIDTH, m = m, art = art,
		bw = bw, bh = bh, ox = ox, oy = oy, aw = bw - 2 * ox, ah = bh - 2 * oy,
		V = SCREEN_WIDTH * 0.735,
		-- (measured on osu! stable itself: McOsu's list area is a little wider and flatter)
		half = TW.M(250),
		thumbs = (TW_SKIN == nil) or ((TW_SKIN.version or 99) >= 2.2),
	}
	return G
end

function TW.stableX(c, p)
	local g = TW.stableGeom()
	local x = SCREEN_WIDTH - 0.85 * g.aw + g.V * (0.11 - 0.035 * c - (p or 0)) - TW.M(48)
	return math.min(x, SCREEN_WIDTH - 0.15 * g.aw)
end
-- the curve for a panel whose middle is dy from the list's middle
function TW.stableCurve(dy)
	return 1 - math.min(1, math.abs(dy) / TW.stableGeom().half)
end

-- osu!'s panels go under the top and bottom bars; the list fades them just before, so panels don't
-- show through skins whose bars are see-through (y: the panel's middle on screen)
function TW.stableFade(y)
	local M = TW.M
	return math.max(0, math.min(1, (y - M(70)) / M(60), (SCREEN_HEIGHT - M(40) - y) / M(70)))
end

-- the list's middle on screen (metrics.ini's MusicWheelY)
function TW.stableCentre() return TW.M(376) end

-- metrics.ini's ItemTransformFunction: the list's spacing is the panel's inner height. The panel is
-- put at the curve's far end; each panel adds the curve itself for where it ends up once an open
-- song's difficulties have moved it (TW.wheelShift, with TW.wheelCurve).
function TW.stableWheelItem(self, offset)
	local dy = offset * TW.stableGeom().ah
	self:x(TW.stableX(0, 0)):y(dy)
	self:diffusealpha(TW.stableFade(TW.stableCentre() + dy))
end
function TW.stableCurveX(y)
	return TW.stableX(TW.stableCurve(y - TW.stableCentre()), 0) - TW.stableX(0, 0)
end
