-- Helpers for drawing an osu!-style interface from an osu! skin.
-- vsrghub.exe writes "00 VSRG Hub skin.lua" at launch: TW_SKINS describes every osu! skin
-- (files[id] = the skin's image for an element, blank[id] = the skin hides it on purpose) and
-- TW_OSU_SKIN names the one selected in osu!. TW_SKIN is the one the interface uses: the osu!
-- one, or the one picked in VSRG Hub's options. Elements a skin leaves out fall back to plain
-- shapes in osu!'s default colours; elements it blanks are not drawn at all, exactly like osu!.
TW = {}
TW.TilDeath = "/Themes/Til Death/"

-- Keybinds (TWKeys): VSRG Hub writes "VSRG Hub keys.lua" next to its theme picker in Etterna's themes;
-- Etterna's system layer loads it too (it takes the key being picked there). Loaded here as well, so
-- the keys are known from the start.
if not TWKeys then pcall(function() LoadActor(TW.TilDeath .. "BGAnimations/VSRG Hub keys.lua") end) end
-- true when this key press is the shortcut `id` (its key may have been changed in Keybinds); without
-- TWKeys, `default` says
function TW.key(event, id, default)
	if TWKeys and TWKeys.is then return TWKeys.is(event, id) end
	return default == true
end
-- Etterna's rate keys (EffectUp / EffectDown, = and - unless changed in Keybinds): on song select they
-- change the rate (Etterna does it), so they don't start a search
function TW.rateKey(event)
	return event.GameButton == "EffectUp" or event.GameButton == "EffectDown"
end
-- song select (osu! and Quaver looks): the rate keys change the rate here, before Etterna's screen
-- (which may not be listening while VSRG Hub holds the keyboard): 0.1x a press, 0.05x with Shift
function TW.rateInput(event)
	if not TW.rateKey(event) or event.DeviceInput.is_mouse then return false end
	if event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat" then
		local up = event.GameButton == "EffectUp"
		local step = INPUTFILTER:IsShiftPressed() and 0.05 or 0.1
		local cur = (getCurRateValue and getCurRateValue()) or 1
		-- (Etterna's range; rates land on 0.05 steps)
		local r = math.floor((cur + (up and step or -step)) * 20 + 0.5) / 20
		r = math.max(0.05, math.min(3, r))
		for _, l in ipairs({ "ModsLevel_Preferred", "ModsLevel_Song", "ModsLevel_Current" }) do
			pcall(function() GAMESTATE:GetSongOptionsObject(l):MusicRate(r) end)
		end
		MESSAGEMAN:Broadcast("CurrentRateChanged")
		MESSAGEMAN:Broadcast("TWModsChanged")
	end
	return true
end
function TW.keyLabel(id, default)
	if TWKeys and TWKeys.label then return TWKeys.label(id) end
	return default
end

-- Frame rate. Etterna runs an ActorFrame's update function at most every 16 ms (60 times a second)
-- unless told otherwise, so everything VSRG Hub moves from one (the pointer, the song list, the
-- logo's visualizer, the beat) moved at 60 per second on a 200 Hz monitor, however fast the game ran.
-- TW.everyFrame makes a frame's update function run every frame drawn; TW.everyRefresh at about
-- twice the monitor's refresh rate, for the heavier ones (shapes redrawn from scratch).
function TW.everyFrame(self) self:SetUpdateFunctionInterval(0.0001) return self end
local refreshInterval = nil
function TW.everyRefresh(self)
	if not refreshInterval then
		local hz = 0
		pcall(function() hz = DISPLAY:GetDisplayRefreshRate() end)
		if not hz or hz < 30 then hz = 144 end
		refreshInterval = 0.5 / math.min(hz, 500)
	end
	self:SetUpdateFunctionInterval(refreshInterval)
	return self
end
-- An ActorMultiVertex given fewer vertices than it had kept drawing the old ones past the new end
-- (Etterna only ever adds); a whole new list now sets the count too.
if ActorMultiVertex then
	-- (Etterna's own, kept once: the scripts can be loaded again over it)
	TW_AMV_SETVERTICES = TW_AMV_SETVERTICES or ActorMultiVertex.SetVertices
	local setVertices = TW_AMV_SETVERTICES
	-- (passed on with exactly the arguments given: Etterna reads the list from the last one)
	ActorMultiVertex.SetVertices = function(self, a, ...)
		if select("#", ...) == 0 then
			if type(a) == "table" then self:SetNumVertices(#a) end
			return setVertices(self, a)
		end
		return setVertices(self, a, ...)
	end
end

-- VSRG Hub's own settings, kept in Etterna's Save folder: interfaceSkin (an osu! skin folder, or
-- empty to follow osu!), notes_dance / notes_kb7 (the noteskin for 4K / 7K).
TW.settingsFile = "Save/VSRGHub/settings.ini"
function TW.loadSettings()
	local t = {}
	local ok, txt = pcall(function() return File.Read(TW.settingsFile) end)
	if ok and type(txt) == "string" then
		for k, v in txt:gmatch("([%w_]+)=([^\r\n]*)") do t[k] = v end
	end
	-- the 1.3.0 file
	local ok2, old = pcall(function() return File.Read("Save/VSRGHub/noteskins.ini") end)
	if ok2 and type(old) == "string" then
		for k, v in old:gmatch("([%w]+)=([^\r\n]+)") do
			if t["notes_" .. k] == nil then t["notes_" .. k] = v:gsub(" ", "_"):lower() end
		end
	end
	return t
end
function TW.saveSetting(key, value)
	TW.settings[key] = value
	local out = {}
	for k, v in pairs(TW.settings) do out[#out + 1] = k .. "=" .. tostring(v) end
	table.sort(out)
	pcall(function() File.Write(TW.settingsFile, table.concat(out, "\n") .. "\n") end)
end
TW.settings = TW.loadSettings()

-- the skin the interface is drawn with
function TW.useSkin(folder)
	TW_SKINS = TW_SKINS or {}
	if folder ~= nil and folder ~= "" and TW_SKINS[folder] then
		TW_SKIN = TW_SKINS[folder]
	elseif TW_OSU_SKIN and TW_OSU_SKIN ~= "" and TW_SKINS[TW_OSU_SKIN] then
		TW_SKIN = TW_SKINS[TW_OSU_SKIN]
	else
		TW_SKIN = nil
	end
end
TW.useSkin(TW.settings.interfaceSkin)
function TW.useInterfaceSkin()
	TW.useSkin(TW.settings.interfaceSkin)
	if TW.applyAccent then TW.applyAccent() end
end
-- In play, like gucci!mania, the HUD (stage, judgments, combo, score, HP bar) comes from the skin
-- whose notes you play with; an Etterna noteskin keeps the interface skin.
-- A skin as seen in 7K: skin.ini's 7-key [Mania] section can name its own stage art (stage sides,
-- stage bottom), which then replaces the 4K one.
local keyedCache = setmetatable({}, { __mode = "k" })
function TW.skinForKeys(skin, keys)
	if not skin or keys ~= 7 or not skin.keyed7 then return skin end
	if keyedCache[skin] then return keyedCache[skin] end
	local k = skin.keyed7
	local function merge(base, over)
		local out = {}
		for id, v in pairs(base or {}) do out[id] = v end
		for id, v in pairs(over or {}) do out[id] = v or nil end
		return out
	end
	local files = merge(skin.files, k.files)
	local hd = merge(skin.hd, {})
	local blank = merge(skin.blank, {})
	for id in pairs(k.files or {}) do hd[id] = k.hd and k.hd[id] or nil; blank[id] = nil end
	for id in pairs(k.blank or {}) do blank[id] = true; files[id] = nil end
	local view = setmetatable({ files = files, hd = hd, blank = blank }, { __index = skin })
	keyedCache[skin] = view
	return view
end
-- a VSRG Hub noteskin's facts (column width, skin) for the key mode being played: an osu! skin's 4K
-- and 7K noteskins have the same name
function TW.noteskinInfo(ns, game)
	ns = (ns or ""):lower()
	game = game or (TW.gameName and TW.gameName())
	local byGame = TW_NOTESKINS_GAME and game and TW_NOTESKINS_GAME[game]
	return (byGame and byGame[ns]) or (TW_NOTESKINS and TW_NOTESKINS[ns])
end
function TW.useGameplaySkin()
	local ok, ns = pcall(function()
		return GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin()
	end)
	local info = ok and ns and TW.noteskinInfo(ns)
	-- (TW.notesSkin: the notes come from this osu! skin, so its stage art belongs to them)
	if info and info.skin and TW_SKINS and TW_SKINS[info.skin] then
		TW_SKIN = TW_SKINS[info.skin]
		TW.notesSkin = true
	else
		TW.useInterfaceSkin()
		TW.notesSkin = false
	end
	local keys = 4
	pcall(function() if GAMESTATE:GetCurrentGame():GetName() == "kb7" then keys = 7 end end)
	TW_SKIN = TW.skinForKeys(TW_SKIN, keys)
end

-- osu! lays its interface out on a 768-pixel-tall screen; Etterna's is 480 tall.
TW.U = SCREEN_HEIGHT / 768
-- Positions measured off osu! stable at 1456x819 (16:9), scaled to Etterna's screen.
function TW.M(v) return v * SCREEN_HEIGHT / 819 end
-- the same, measured from the right edge
function TW.R(v) return SCREEN_WIDTH - (1456 - v) * SCREEN_HEIGHT / 819 end

-- Interface art VSRG Hub draws itself instead of taking it from the skin: these images carry
-- osu!'s own words and buttons (the top and bottom bars, the results panel...; the song panels do come
-- from the skin, tinted as osu! tints them), which
-- don't match what VSRG Hub does. From the skin the interface keeps the backgrounds, the cursor, the
-- mod icons and the grade letters; gameplay keeps everything (notes, judgements, numbers, HP bar).
TW.plainUI = {
	menu_back = true, sel_mode = true, sel_mode_over = true, sel_mods = true,
	sel_mods_over = true, sel_random = true, sel_random_over = true, sel_options = true,
	sel_options_over = true, songselect_top = true, songselect_bottom = true, selection_tab = true,
	mode_icon = true, mode_icon_med = true, btn_left = true, btn_middle = true, btn_right = true,
	ranking_panel = true, ranking_title = true, ranking_maxcombo = true, ranking_accuracy = true,
	ranking_graph = true, ranking_perfect = true, ranking_retry = true, ranking_replay = true,
	ranking_bg_overlay = true, star = true,
}
-- The stable look is osu! stable itself: its song select takes these from the skin after all, at
-- osu!'s own places (osu!lazer doesn't use them)
TW.stableSkinArt = {
	menu_back = true, sel_mode = true, sel_mode_over = true, sel_mods = true, sel_mods_over = true,
	sel_random = true, sel_random_over = true, sel_options = true, sel_options_over = true,
	songselect_top = true, songselect_bottom = true, mode_icon = true, mode_icon_med = true, star = true,
	selection_tab = true, btn_left = true, btn_middle = true, btn_right = true,
	-- (and the ranking screen's, at osu!'s places on the stable look's results)
	ranking_panel = true, ranking_title = true, ranking_maxcombo = true, ranking_accuracy = true,
	ranking_graph = true, ranking_perfect = true, ranking_retry = true, ranking_replay = true,
	ranking_bg_overlay = true,
}
local function plainArt(id) return TW.plainUI[id] and not (TW.stableSkinArt[id] and not TW.isLazer) end
function TW.has(id) return TW_SKIN ~= nil and TW_SKIN.files[id] ~= nil and not plainArt(id) end
function TW.blank(id) return TW_SKIN ~= nil and TW_SKIN.blank ~= nil and TW_SKIN.blank[id] == true and not plainArt(id) end
-- true when VSRG Hub should draw its own stand-in (the skin neither has nor hides the element)
function TW.fallback(id) return not TW.has(id) and not TW.blank(id) end
function TW.img(id)
	if not TW.has(id) then return nil end
	return TW_SKIN.dir .. TW_SKIN.files[id]
end
function TW.hd(id) return TW_SKIN ~= nil and TW_SKIN.hd[id] == true end
-- zoom that draws a skin image at osu!'s size: 1x art is in osu! pixels, @2x art is twice that.
function TW.scale(id) return TW.U * (TW.hd(id) and 0.5 or 1) end
function TW.rgb(r, g, b, a) return color(string.format("%f,%f,%f,%f", r / 255, g / 255, b / 255, a or 1)) end
function TW.colour(name, fallback)
	local c = TW_SKIN and TW_SKIN.colours and TW_SKIN.colours[name]
	if not c then return fallback end
	return TW.rgb(c[1], c[2], c[3])
end
function TW.mouse() return LoadActor(TW.TilDeath .. "BGAnimations/_cursor") end

-- Where the look's own pointer shows: everywhere but while playing (as in osu! and Quaver), and in
-- play too when the mouse is needed (Customize gameplay, the pause menu).
function TW.pointerWanted()
	local top = SCREENMAN:GetTopScreen()
	local name = top and top:GetName() or ""
	if not name:find("Gameplay") then return true end
	-- (practice: the bar along the bottom is clicked)
	return TW.customize == true or TW.paused == true or (TW.inPractice ~= nil and TW.inPractice())
end

-- The game's pointer: Windows' arrow is hidden over the game's picture and the look's pointer is
-- drawn instead. Etterna brings Windows' arrow back on every new screen, so it is hidden again then;
-- it comes back while the mouse is outside the picture (the window's title bar and borders).
function TW.pointer(art, trail)
	local hidden, again = false, 0
	local function osArrow(show) pcall(function() Arch.setCursorVisible(show) end) end
	local f = Def.ActorFrame {
		-- Til Death's small pointer (shown only in true fullscreen) would sit on top of this one
		ScreenChangedMessageCommand = function(self) hidden = false; TW.pxReset(); self:stoptweening():sleep(0.2):queuecommand("NoTooltip") end,
		WindowedChangedMessageCommand = function(self) TW.pxReset(); self:stoptweening():sleep(0.2):queuecommand("NoTooltip") end,
		NoTooltipCommand = function() pcall(function() TOOLTIP:HidePointer() end) end,
		-- (started at Init: the system layer's actors never get an On command)
		InitCommand = function(self)
			self:draworder(10001)
			local arrow
			TW.everyFrame(self)
			self:SetUpdateFunction(function(_, dt)
				arrow = arrow or self:GetChild("Arrow")
				if not arrow then return end
				local x, y = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				local inside = x >= 0 and y >= 0 and x <= SCREEN_WIDTH and y <= SCREEN_HEIGHT
				-- (and every second, in case something else showed it)
				again = again + (dt or 0)
				if again > 1 then again = 0; if inside and hidden then osArrow(true); hidden = false end end
				if inside ~= hidden then hidden = inside; osArrow(not inside) end
				local show = inside and TW.pointerWanted()
				arrow:visible(show):xy(x, y)
				self:playcommand("Pointer", { x = x, y = y, show = show, dt = dt or 0 })
			end)
		end,
	}
	if trail then f[#f + 1] = trail end
	f[#f + 1] = Def.ActorFrame { Name = "Arrow", art }
	return f
end

function TW.base(path) return LoadActor(TW.TilDeath .. path) end
-- Dan Overlay (a separate program) installs small hooks into Til Death that tell it the selected
-- chart, the play and the result; VSRG Hub's looks load the same hooks when they're there.
function TW.danOverlay(rel)
	local p = TW.TilDeath .. "BGAnimations/" .. rel
	local ok, exists = pcall(function() return FILEMAN:DoesFileExist(p) end)
	if ok and exists then return LoadActor(p) end
	return Def.Actor {}
end

-- A sprite of a skin element at osu!'s size; nothing when the skin lacks or hides it.
function TW.sprite(id, init)
	-- (no Name: callers often name it, and Etterna warns when a name is overridden)
	if not TW.has(id) then return Def.Actor {} end
	return Def.Sprite { Texture = TW.img(id), InitCommand = function(self)
		TW.inset(self) -- (before init: a caller may cut the picture to a rect of its own)
		self:zoom(TW.scale(id))
		if init then init(self) end
	end }
end

-- osu!'s own colours
TW.osuPink = TW.rgb(235, 73, 153)
TW.pink = TW.osuPink
TW.purple = TW.rgb(129, 98, 226)
TW.blue = TW.rgb(94, 167, 241)
TW.yellow = TW.rgb(255, 204, 34)
TW.green = TW.rgb(170, 220, 40)
TW.white = color("#FFFFFF")
-- The accent of the parts VSRG Hub draws itself (mode / mods / random / options, tabs, highlights):
-- the interface skin's own colour, worked out by VSRG Hub from the skin's art, instead of osu!'s
-- strong pink; a softer pink when the skin has no clear colour. (The Quaver look keeps its cyan.)
function TW.mix(c, other, f)
	return { c[1] + (other[1] - c[1]) * f, c[2] + (other[2] - c[2]) * f, c[3] + (other[3] - c[3]) * f, c[4] or 1 }
end
-- (Options > Interface colour can also pick one of these instead of the skin's)
TW.ACCENTS = {
	{ key = "skin", label = "From the skin" },
	{ key = "softpink", label = "Soft pink", rgb = { 206, 96, 152 } },
	{ key = "osupink", label = "osu! pink", rgb = { 235, 73, 153 } },
	{ key = "blue", label = "Blue", rgb = { 78, 140, 206 } },
	{ key = "purple", label = "Purple", rgb = { 133, 98, 206 } },
	{ key = "green", label = "Green", rgb = { 84, 168, 110 } },
	{ key = "orange", label = "Orange", rgb = { 214, 132, 70 } },
	{ key = "grey", label = "Grey", rgb = { 110, 112, 124 } },
}
function TW.applyAccent()
	if TW.isQuaver then return end
	local a = TW_SKIN and TW_SKIN.accent
	for _, c in ipairs(TW.ACCENTS) do
		if c.key == (TW.settings and TW.settings.accent) and c.rgb then a = c.rgb end
	end
	TW.pink = a and TW.rgb(a[1], a[2], a[3]) or TW.rgb(206, 96, 152)
	TW.pinkLight = TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.3)
end
TW.applyAccent()
TW.black = color("#000000")

-- The osu! look's see-through greys (like its bottom bar), in layers: what has to be read first is
-- more solid and lighter, what only sits behind things is fainter.
--   back   behind everything: wide shades under text over the background
--   bar    the screen's top and bottom bars
--   panel  boxes on the screen (the ranking, the map preview's graph, results)
--   card   things inside a panel or bar (buttons, fields, rows)
--   float  what opens over the rest (lists, dialogs, menus, the options, tooltips)
--   hud    boxes while playing
--   field  behind notes (the map preview), dark so the notes stand out
-- A number instead of a layer is a "panel" that much more (or less) solid. old is what a part shared
-- with the Quaver look keeps there (the Quaver look stays as Quaver draws it).
local GLASS = {
	back = { { 0.05, 0.05, 0.07, 0.48 }, { 0.10, 0.10, 0.13, 0.42 } },
	bar = { { 0.06, 0.06, 0.08, 0.70 }, { 0.12, 0.12, 0.15, 0.62 } },
	panel = { { 0.09, 0.09, 0.115, 0.72 }, { 0.15, 0.15, 0.185, 0.64 } },
	card = { { 0.21, 0.21, 0.25, 0.40 }, { 0.27, 0.27, 0.32, 0.36 } },
	float = { { 0.11, 0.11, 0.14, 0.985 }, { 0.19, 0.19, 0.235, 0.975 } }, -- (solid enough that text behind doesn't show)
	hud = { { 0.05, 0.05, 0.065, 0.42 }, { 0.09, 0.09, 0.11, 0.36 } },
	field = { { 0.035, 0.035, 0.05, 0.86 }, { 0.07, 0.07, 0.09, 0.82 } },
	lift = { { 0.16, 0.16, 0.20, 0.62 }, { 0.22, 0.22, 0.27, 0.56 } },
}
function TW.glassColour(tier, top)
	local k = 1
	if type(tier) == "number" then k, tier = tier, "panel" end
	local c = (GLASS[tier] or GLASS.panel)[top and 2 or 1]
	return { c[1], c[2], c[3], math.min(0.99, c[4] * k) }
end
-- Frosted glass: on screens with a picture behind them (main menu, song select, results) the
-- panels show that picture blurred through a grey tint, like frosted glass, instead of a flat grey.
-- TW.frostSource (in the screen's underlay) renders the background small through a few
-- ActorFrameTextures (each pass averages nine shifted copies, so the picture comes out soft rather
-- than blocky) and every glass part is drawn with that texture, cut to where it sits on the screen.
-- The tint per layer multiplies the blurred picture: bottom, top, alpha. (Solid or nearly: the blur is
-- what makes it look see-through; even a little alpha lets text behind a dark panel show through.)
local FROST = {
	back = { 0.78, 0.86, 0.90 },
	bar = { 0.62, 0.70, 1 },
	panel = { 0.56, 0.64, 1 },
	float = { 0.44, 0.52, 1 },
	shade = { 0.62, 0.62, 0.80 },
	lift = { 0.92, 1.00, 0.95 },
}
TW.frostQuads = TW.frostQuads or setmetatable({}, { __mode = "k" })
local function frostTint(self, key, a)
	local f = FROST[key]
	local k = a or 1
	self:diffuse({ f[1], f[1], f[1] * 1.04, math.min(1, f[3] * k) })
		:diffusetopedge({ f[2], f[2], f[2] * 1.04, math.min(1, f[3] * k) })
	self.twFrostTinted = true
end
-- puts the blurred picture on a glass part (once) and cuts it to where the part is now
local function frostFit(q, key, tex, rect)
	if q.twFrostTex ~= tex then
		local w, h = q:GetZoomedWidth(), q:GetZoomedHeight()
		q:SetTexture(tex)
		q:zoomto(w, h)
		q.twFrostTex = tex
		-- (a part made before this screen's picture was known still has the plain grey: its own
		-- shading, like a fade to the right, is kept on parts that had the frost colours already)
		if not q.twFrostTinted then frostTint(q, key, q.twFrostAlpha) end
	end
	if not q:GetVisible() then return end
	local par = q:GetParent()
	local zx, zy = par and par:GetTrueZoomX() or 1, par and par:GetTrueZoomY() or 1
	local w, h = q:GetZoomedWidth() * zx, q:GetZoomedHeight() * zy
	local x0 = q:GetTrueX() - q:GetHAlign() * w
	local y0 = q:GetTrueY() - q:GetVAlign() * h
	local l, t, r, b = rect[1], rect[2], rect[3], rect[4]
	local u0, u1 = l + (r - l) * x0 / SCREEN_WIDTH, l + (r - l) * (x0 + w) / SCREEN_WIDTH
	local v0, v1 = t + (b - t) * y0 / SCREEN_HEIGHT, t + (b - t) * (y0 + h) / SCREEN_HEIGHT
	q:customtexturerect(u0, v0, u1, v1)
end
local function frostKey(tier)
	if type(tier) == "number" then return "panel" end
	return FROST[tier] and tier or nil
end
function TW.glassify(self, tier, old)
	if TW.isQuaver and old then self:diffuse(old) return self end
	local key = frostKey(tier)
	local a = type(tier) == "number" and tier or nil
	if key and TW.frostTex and self.twFrostTex == TW.frostTex then
		-- already frosted (a part that sets its look again, e.g. a song panel scrolling by)
		self.twFrostAlpha = a
		frostTint(self, key, a)
		TW.frostQuads[self] = key
		return self
	end
	if key and not TW.isQuaver and TW.frostExpected then
		-- this screen has a picture behind it: the frost colours now (the caller may shade them
		-- further, e.g. fade them out to the right), the blurred picture as soon as it is ready
		self.twFrostAlpha = a
		frostTint(self, key, a)
		TW.frostQuads[self] = key
		if TW.frostTex and TW.frostRect then pcall(frostFit, self, key, TW.frostTex, TW.frostRect) end
		return self
	end
	self:diffuse(TW.glassColour(tier)):diffusetopedge(TW.glassColour(tier, true))
	return self
end
-- the background picture the screen shows, blurred, for the frosted parts. TW.frostTarget is the
-- actor that draws that background (set by the underlay).
-- Only with OpenGL: Etterna's Direct3D drawing into textures holds on to the screen each frame, so
-- the next time Direct3D sets the screen up again (changing the look or the display settings,
-- Alt+Tab out of fullscreen) the game stops with "D3DERR_INVALIDCALL". With Direct3D the glass is a
-- plain grey; the Renderer option (VIDEO) switches to OpenGL.
function TW.canFrost()
	local ok, v = pcall(function() return DISPLAY:SupportsRenderToTexture() end)
	return ok and v == true
end
function TW.frostSource()
	if not TW.canFrost() then
		return Def.ActorFrame { Name = "TWFrost", InitCommand = function(self)
			TW.frostQuads = setmetatable({}, { __mode = "k" })
			TW.frostTex, TW.frostRect, TW.frostExpected = nil, nil, false
		end }
	end
	local W, H = SCREEN_WIDTH, SCREEN_HEIGHT
	local sizes = { { math.floor(W / 3), math.floor(H / 3) }, { math.floor(W / 7), math.floor(H / 7) },
		{ math.floor(W / 14), math.floor(H / 14) } }
	local function pass(i)
		local w, h = sizes[i][1], sizes[i][2]
		local f = Def.ActorFrameTexture {
			Name = "P" .. i,
			InitCommand = function(self) self:SetWidth(w):SetHeight(h):EnableAlphaBuffer(false):Create() end,
		}
		if i == 1 then
			-- the screen's background, small
			f[#f + 1] = Def.ActorProxy { Name = "Proxy", InitCommand = function(self) self:zoom(w / W) end }
		else
			-- nine shifted copies of the previous pass, averaged
			local n = 0
			for dy = -1, 1 do
				for dx = -1, 1 do
					n = n + 1
					local k = n
					f[#f + 1] = Def.Sprite {
						Name = "S" .. k,
						InitCommand = function(self) self:align(0, 0):xy(dx * 0.85, dy * 0.85):diffusealpha(1 / k) end,
					}
				end
			end
			-- a grey lift, so the glass reads as grey with the picture soft in it
			if i == #sizes then
				f[#f + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(w, h):diffuse({ 0.16, 0.16, 0.19, 0.42 }) end }
			end
		end
		-- (the averaging leaves the texture part see-through, and the glass with it: adding black at
		-- full alpha makes it solid again without changing a colour)
		f[#f + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(w, h):diffuse({ 0, 0, 0, 1 }):blend("BlendMode_Add") end }
		return f
	end
	local t = Def.ActorFrame {
		Name = "TWFrost",
		InitCommand = function(self)
			-- (the old screen's parts are gone or going: start over)
			TW.frostQuads = setmetatable({}, { __mode = "k" })
			TW.frostTex, TW.frostRect = nil, nil
			TW.frostExpected = not TW.isQuaver
		end,
		OnCommand = function(self)
			if TW.isQuaver then self:visible(false) return end
			local p1 = self:GetChild("P1")
			local proxy = p1 and p1:GetChild("Proxy")
			if not (proxy and TW.frostTarget) then self:visible(false) return end
			proxy:SetTarget(TW.frostTarget)
			for i = 2, #sizes do
				local src = self:GetChild("P" .. (i - 1)):GetTexture()
				local pi = self:GetChild("P" .. i)
				if not src then self:visible(false) return end
				local l, tt, r, b = src:GetTextureCoordRect(0)
				for k = 1, 9 do
					local sp = pi:GetChild("S" .. k)
					sp:SetTexture(src)
					sp:customtexturerect(l, tt, r, b):zoomto(sizes[i][1], sizes[i][2])
				end
			end
			local last = self:GetChild("P" .. #sizes):GetTexture()
			if not last then self:visible(false) return end
			TW.frostTex = last
			TW.frostRect = { last:GetTextureCoordRect(0) }
			TW.everyFrame(self)
			self:SetUpdateFunction(function()
				local tex, rect = TW.frostTex, TW.frostRect
				if not tex then return end
				for q, key in pairs(TW.frostQuads) do
					if not pcall(frostFit, q, key, tex, rect) then TW.frostQuads[q] = nil end
				end
			end)
		end,
		-- leaving the screen: the next one has no picture behind it until its own source says so
		OffCommand = function(self) self:SetUpdateFunction(nil); TW.frostTex, TW.frostRect = nil, nil; TW.frostExpected = false end,
	}
	for i = 1, #sizes do t[#t + 1] = pass(i) end
	return t
end
-- a full-screen shade behind a panel or dialog: grey in the osu! look, frosted where it can be
function TW.shade(self, a, old)
	if TW.isQuaver then self:diffuse(old or { 0, 0, 0, a or 0.6 }) return self end
	if not TW.frostExpected then self:diffuse({ 0.05, 0.05, 0.065, a or 0.6 }) return self end
	self.twFrostAlpha = (a or 0.6) / 0.6
	frostTint(self, "shade", self.twFrostAlpha)
	TW.frostQuads[self] = "shade"
	if TW.frostTex and TW.frostRect then pcall(frostFit, self, "shade", TW.frostTex, TW.frostRect) end
	return self
end
-- a faint light line along the top of a panel (where light would catch it)
function TW.glassEdge(x, y, w)
	return Def.Quad { InitCommand = function(self)
		self:align(0, 0):xy(x, y):zoomto(w, 1):diffuse({ 1, 1, 1, 0.14 }):visible(not TW.isQuaver)
	end }
end
-- a 1-pixel frame round x, y, w, h (a glass panel can't have a solid one behind it: it shows through)
function TW.outline(x, y, w, h, col)
	local function line(lx, ly, lw, lh)
		return Def.Quad { InitCommand = function(self) self:align(0, 0):xy(lx, ly):zoomto(lw, lh):diffuse(col) end }
	end
	return Def.ActorFrame { line(x - 1, y - 1, w + 2, 1), line(x - 1, y + h, w + 2, 1), line(x - 1, y, 1, h), line(x + w, y, 1, h) }
end

-- Fonts: osu! stable writes everything in Aller (regular, light, bold); Aller can't be shipped, so
-- the look uses Ubuntu, from the same type foundry and very close to it (Ubuntu Font Licence)
-- (redrawn at twice the resolution, and
-- again at four times for big text, so text stays sharp on a 1080p or larger screen)
TW.font = "_vh sans"
TW.bold = "_vh bold"
TW.fontBig = { [TW.font] = "_vhx sans", [TW.bold] = "_vhx bold", ["_vh light"] = "_vhx light" }
TW.light = "_vh light"
-- the font and zoom for text px tall (cap height): big text takes the sharper copy, drawn at
-- half the zoom (it is twice the size)
function TW.fontFor(px, bold)
	local f = bold and TW.bold or TW.font
	-- The copy whose letters are closest to the size they are drawn at on screen: the normal one
	-- (letters 34 screen pixels tall at full size) up to about that, then the big one (68). Drawn much
	-- smaller than its letters a font gets jagged; much larger, blurry.
	return TW.pickFont(f, px)
end
-- the look's copies of each font: small (letters 17 screen pixels tall at full size), normal (34),
-- big (68), huge (136, digits and capitals only); the one whose letters are just bigger than they
-- will be drawn is used
TW.fontSmall = { ["_vh sans"] = "_vhs sans", ["_vh bold"] = "_vhs bold", ["_vh light"] = "_vhs light" }
function TW.pickFont(f, px, huge)
	local d = px * DISPLAY:GetDisplayHeight() / SCREEN_HEIGHT * 0.85
	if d <= 17 and TW.fontSmall and TW.fontSmall[f] then return TW.fontSmall[f], px / 8.5 end
	if d <= 34 or not TW.fontBig[f] then return f, px / 17 end
	if d > 68 and huge and TW.fontHuge and TW.fontHuge[f] then return TW.fontHuge[f], px / 68 end
	return TW.fontBig[f], px / 34
end
-- Big numbers and capitals (scores, grades, ratings): a third, much larger copy of the look's font when
-- it has one (TW.fontHuge: only digits, capitals and . , % x - + : /), so they stay sharp very large.
TW.fontHuge = TW.fontHuge or {}
function TW.bigText(px, weight, init)
	local f, z = TW.pickFont(weight == "bold" and TW.bold or (weight == "light" and (TW.light or TW.font) or TW.font), px, true)
	return LoadFont(f) .. {
		InitCommand = function(self)
			self:zoom(z):halign(0):shadowlength(0)
			if init then init(self) end
		end
	}
end
-- Text whose cap height is about px Etterna pixels.
function TW.text(px, bold, init)
	local f, z = TW.fontFor(px, bold)
	return LoadFont(f) .. {
		InitCommand = function(self)
			self:zoom(z):halign(0):shadowlength(1) -- readable on light skins too
			if init then init(self) end
		end
	}
end

TW.GradeToRank = {
	Grade_Tier01 = "X", Grade_Tier02 = "X", Grade_Tier03 = "X", Grade_Tier04 = "X",
	Grade_Tier05 = "S", Grade_Tier06 = "S", Grade_Tier07 = "S",
	Grade_Tier08 = "A", Grade_Tier09 = "A", Grade_Tier10 = "A",
	Grade_Tier11 = "B", Grade_Tier12 = "B", Grade_Tier13 = "B",
	Grade_Tier14 = "C", Grade_Tier15 = "D", Grade_Tier16 = "D", Grade_Failed = "D"
}
TW.RankLetter = { X = "SS", S = "S", A = "A", B = "B", C = "C", D = "D", F = "F" }
TW.RankColour = {
	X = TW.rgb(255, 211, 0), S = TW.rgb(255, 211, 0), A = TW.rgb(136, 218, 32),
	B = TW.rgb(58, 160, 255), C = TW.rgb(191, 90, 241), D = TW.rgb(255, 80, 80),
	F = TW.rgb(150, 150, 160)
}

function TW.msd(steps, skill)
	if not steps then return 0 end
	local ok, v = pcall(function() return steps:GetMSD(getCurRateValue(), skill or 1) end)
	return ok and v or 0
end
-- a chart's key count, from its type (steps:GetNumColumns unpacks the whole chart's notes to count
-- them: called for every panel as the song list moves, that made fast scrolling stutter)
local KEYS = {
	StepsType_Dance_Single = 4, StepsType_Dance_Double = 8, StepsType_Dance_Solo = 6, StepsType_Dance_Threepanel = 3,
	StepsType_Kb7_Single = 7, StepsType_Pump_Single = 5, StepsType_Pump_Halfdouble = 6, StepsType_Pump_Double = 10,
	StepsType_Pnm_Five = 5, StepsType_Pnm_Nine = 9, StepsType_Bm_Single5 = 6, StepsType_Bm_Double5 = 12,
	StepsType_Bm_Single7 = 8, StepsType_Bm_Double7 = 16,
}
function TW.keys(steps)
	if not steps then return 0 end
	local ok, st = pcall(function() return steps:GetStepsType() end)
	local n = ok and KEYS[st]
	if n then return n end
	ok, n = pcall(function() return steps:GetNumColumns() end)
	return ok and n or 0
end
-- The charts VSRG Hub plays: 4K (Etterna's "dance-single") and 7K ("kb7-single"). Etterna's "dance"
-- game also holds 8K doubles, 6K solo and 3K charts; VSRG Hub has no notes, skins or layouts for
-- those, so they are left out wherever charts are listed (and songs with only those, from the song
-- list: metrics.ini's StepsTypesToHide).
function TW.isPlayable(steps)
	local k = TW.keys(steps)
	return k == 4 or k == 7
end
function TW.onlyPlayable(list)
	local out = {}
	for _, st in ipairs(list or {}) do
		if TW.isPlayable(st) then out[#out + 1] = st end
	end
	return out
end
-- a song's charts of the key mode being played (4K or 7K)
function TW.playable(song)
	if not song then return {} end
	local ok, list = pcall(function() return song:GetChartsOfCurrentGameMode() end)
	return TW.onlyPlayable(ok and list or {})
end
function TW.diffName(steps)
	if not steps then return "" end
	local d = ""
	pcall(function() d = steps:GetChartName() end)
	if d == nil or d == "" then pcall(function() d = steps:GetDescription() end) end
	if d == nil or d == "" then d = getDifficulty(steps:GetDifficulty()) end
	return d
end
function TW.author(song)
	local by = ""
	pcall(function() by = song:GetOrTryAtLeastToGetSimfileAuthor() end)
	if by == "Author Unknown" then by = "" end
	return by or ""
end

-- Skin number fonts (score-0 ... score-9, score-dot, score-percent, score-comma, score-x) drawn
-- the way osu! draws them: each glyph image left to right, overlapping by ScoreOverlap/ComboOverlap.
local glyph = { ["."] = "dot", ["%"] = "percent", [","] = "comma", ["x"] = "x" }
local glyphIds = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "dot", "percent", "comma", "x" }
-- The skin's number font: one sprite per character place, plus a hidden sprite holding each glyph's
-- image. Changing a digit hands the place the glyph's texture (SetTexture) instead of loading the
-- file: Etterna frees an image as soon as nothing shows it, so loading digits by file name read and
-- decoded PNGs from disk on every hit, which made gameplay stutter.
-- Hands a sprite another image's texture. Etterna keeps the sprite's first texture coordinates,
-- which cover only the image part of its padded (power-of-two) texture: a wider image handed over
-- later (score-percent after score-0) would be cut off on the right, so they are set from the new one.
function TW.setTexture(spr, tex)
	spr:SetTexture(tex)
	local l, t, r, b = tex:GetTextureCoordRect(0)
	spr:customtexturerect(l, t, r, b)
	return TW.inset(spr)
end
-- Etterna puts a picture whose size isn't a power of two into a bigger texture and leaves the
-- rest of it as it was in memory: drawn up to its very edge, the picture picks up a line of that
-- leftover (random coloured dots, or a faint frame) along its sides. The texture's picture area,
-- half a texel in from each side (the middle of its edge texels), keeps it out (skins leave their pictures' edges see-through anyway).
-- Not for animations (their frames' areas are set by Etterna) or anything cut to a rect afterwards.
function TW.inset(spr)
	pcall(function()
		local tex = spr:GetTexture()
		if not tex or (tex:GetNumFrames() or 1) > 1 then return end
		local l, t, r, b = tex:GetTextureCoordRect(0)
		local tw, th = tex:GetTextureWidth(), tex:GetTextureHeight()
		if not (l and tw and th and tw > 0 and th > 0) then return end
		local dx, dy = math.min(0.5 / tw, (r - l) / 4), math.min(0.5 / th, (b - t) / 4)
		spr:customtexturerect(l + dx, t + dy, r - dx, b - dy)
	end)
	return spr
end
function TW.digits(prefix, maxChars, name)
	local t = Def.ActorFrame { Name = name }
	for i = 1, maxChars do
		-- (glyph: what the place shows now; handing a sprite the image it already has would keep an
		-- extra reference to it)
		t[#t + 1] = Def.Sprite { Name = "c" .. i, Texture = TW.img(prefix .. "_0"), InitCommand = function(self) self.glyph = "0"; self:visible(false):align(0, 0) end }
	end
	for _, g in ipairs(glyphIds) do
		local id = prefix .. "_" .. g
		if TW.has(id) then
			t[#t + 1] = Def.Sprite { Name = "g_" .. g, Texture = TW.img(id), InitCommand = function(self) self:visible(false) end }
		end
	end
	-- osu! number fonts have no minus: a dash for a negative accuracy (Etterna's Wife% can go below 0)
	t[#t + 1] = Def.Quad { Name = "minus", InitCommand = function(self) self:visible(false):align(0, 0.5) end }
	return t
end
-- align 0 = text starts at x, 1 = ends at x; zoom is relative to osu!'s own size.
-- Some skins pad each glyph image far to the left of the character and cancel the padding with a
-- huge ScoreOverlap (and a few make score-percent a long strip with the % at its far end); drawn
-- whole, the padding's edges show as faint broken lines across the HUD and the % lands far from the
-- digits. When the overlap is most of a digit's width, each glyph is cropped to its right end, the
-- part with the character, and the characters are set next to each other.
local function glyphWidth(c, id) return c:GetWidth() * (TW.hd(id) and 0.5 or 1) end
-- (padded: whether the skin's glyphs are padded that way; vis: a character's width, osu! pixels)
function TW.digitsPadded(frame, prefix)
	local overlap = TW_SKIN and (prefix == "combo" and TW_SKIN.comboOverlap or TW_SKIN.scoreOverlap) or 0
	local zero = frame.GetChild and frame:GetChild("g_0")
	local w0 = zero and glyphWidth(zero, prefix .. "_0") or 0
	-- (the launcher measures where a digit's ink starts: small digits that just overlap a lot, with
	-- their ink from the left edge, aren't padded and are drawn whole)
	local inkL = TW_SKIN and (prefix == "combo" and TW_SKIN.comboInkL or TW_SKIN.scoreInkL)
	local padded = w0 > 0 and overlap > 0.4 * w0 and (inkL == nil or inkL > 0.3)
	return padded, math.max(1, w0 - overlap), overlap, w0
end
function TW.setDigits(frame, prefix, text, maxChars, zoom, align)
	local padded, _, overlap, w0 = TW.digitsPadded(frame, prefix)
	local xs, x = {}, 0
	local shown = {}
	local minus = frame:GetChild("minus")
	local minusAt = nil
	if minus then minus:visible(false) end
	for i = 1, maxChars do
		local c = frame:GetChild("c" .. i)
		local ch = text:sub(i, i)
		if ch == "-" and minus and not TW.has(prefix .. "_minus") then
			-- as wide as most of a character, a little thicker than a stroke
			local vis = padded and math.max(1, w0 - overlap) or math.max(1, w0 - overlap)
			minusAt = { x = x, w = vis * 0.8 * zoom * TW.U }
			x = x + vis * zoom * TW.U
			ch = ""
		end
		local g = ch ~= "" and (glyph[ch] or ch) or nil
		local id = g and (prefix .. "_" .. g) or nil
		local holder = g and frame:GetChild("g_" .. g)
		if id and holder and TW.has(id) then
			if c.glyph ~= g then
				TW.setTexture(c, holder:GetTexture())
				c.glyph = g
			end
			local z = zoom * TW.scale(id)
			c:zoom(z):visible(true)
			local w1 = glyphWidth(c, id) -- width in osu! pixels
			if padded then
				-- what shows: a digit's width less the overlap (a wide strip such as the % gets a
				-- little more), from the image's right end
				local keep = math.min(w1, math.max(1, w0 - overlap) * (w1 > 2 * w0 and 1.6 or 1.15))
				c:cropleft(1 - keep / w1):cropright(0)
				xs[i] = x - (w1 - keep) * zoom * TW.U
				x = x + keep * zoom * TW.U
			else
				c:cropleft(0):cropright(0)
				xs[i] = x
				x = x + (w1 - overlap) * zoom * TW.U
			end
			shown[#shown + 1] = i
		else
			c:visible(false)
		end
	end
	-- like osu!, the text's width is the sum of the glyph widths minus the overlap between each pair
	-- (not after the last glyph: counting that one too would push the last glyph, e.g. the accuracy's
	-- %, past the right edge in skins with a large ScoreOverlap)
	local total = x
	if #shown > 0 and not padded then total = total + overlap * zoom * TW.U end
	local off = -total * (align or 0)
	for _, i in ipairs(shown) do frame:GetChild("c" .. i):x(off + xs[i]) end
	if minusAt and #shown > 0 then
		-- at the middle of the digits' height, in their colour (the skin's digits are mostly white)
		local c1 = frame:GetChild("c" .. shown[1])
		local h = c1:GetZoomedHeight()
		-- (where the ink is up and down the glyph: padded skins draw small digits at the top of a
		-- big image)
		local key = prefix == "combo" and "combo" or "score"
		local t, b = TW_SKIN and TW_SKIN[key .. "InkT"], TW_SKIN and TW_SKIN[key .. "InkB"]
		if not (t and b and b > t) then t, b = 0, 1 end
		local ink = h * (b - t)
		minus:visible(true):xy(off + minusAt.x + minusAt.w * 0.1, h * (t + b) / 2):zoomto(minusAt.w, math.max(2, ink * 0.11))
	end
end

-- Notes from a Quaver skin: its own gameplay art (judgement pictures, combo and score digits, and
-- their scales from its skin.ini), as the Quaver look uses it; nil for any other noteskin.
function TW.quaverHud()
	local ok, ns = pcall(function()
		return GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin()
	end)
	local info = ok and ns and TW.noteskinInfo(ns)
	return info and info.qv
end
-- a Quaver skin size (a percent of the picture, or pixels at Quaver's 1366x768) in Etterna pixels
function TW.qvSize(v) return v * SCREEN_HEIGHT / 768.43 end
-- A row of a Quaver skin's digit pictures, aligned at x = 0 (halign 0 left, 0.5 centre, 1 right).
-- playcommand("Set", { text = "100.00%" }) shows a number; '.' and ',' use the decimal picture.
function TW.qvDigits(pics, scale, halign, extra)
	local z = TW.qvSize(scale) / 100
	local t = Def.ActorFrame {}
	local N = 12
	for i = 1, N do
		t[#t + 1] = Def.Sprite { Name = "D" .. i, Texture = pics[0], InitCommand = function(self) TW.inset(self); self:zoom(z):visible(false) end }
	end
	-- (Quaver skins have no minus either: a dash for a negative accuracy)
	t[#t + 1] = Def.Quad { Name = "Minus", InitCommand = function(self) self:visible(false):align(0, 0.5) end }
	local shown = {}
	t.SetCommand = function(self, p)
		local text, w, sprites = tostring(p.text or ""), 0, {}
		local minus = self:GetChild("Minus")
		local dashW = nil
		for i = 1, N do
			local ch = text:sub(i, i)
			local sp = self:GetChild("D" .. i)
			local pic = (ch:match("%d") and pics[tonumber(ch)]) or ((ch == "." or ch == ",") and extra and extra.decimal)
				or (ch == "%" and extra and extra.percent) or nil
			if ch == "-" and i == 1 then
				local d0 = self:GetChild("D1")
				dashW = (d0 and d0:GetZoomedWidth() or 10) * 0.9
				sprites[#sprites + 1] = "dash"
				w = w + dashW
				sp:visible(false)
			elseif pic then
				if shown[i] ~= pic then sp:Load(pic); TW.inset(sp); sp:zoom(z); shown[i] = pic end
				sp:visible(true)
				sprites[#sprites + 1] = sp
				w = w + sp:GetZoomedWidth()
			else
				sp:visible(false)
			end
		end
		local x = -w * (halign or 0)
		minus:visible(false)
		local h = 0
		for _, sp in ipairs(sprites) do if sp ~= "dash" then h = math.max(h, sp:GetZoomedHeight()) end end
		for _, sp in ipairs(sprites) do
			if sp == "dash" then
				minus:visible(true):xy(x + dashW * 0.1, 0):zoomto(dashW * 0.8, math.max(2, h * 0.11))
				x = x + dashW
			else
				sp:halign(0):x(x)
				x = x + sp:GetZoomedWidth()
			end
		end
	end
	return t
end

-- Text drawn with the skin's number font when it has one, otherwise with a plain font.
-- Draws nothing when the skin blanks its numbers.
function TW.number(prefix, maxChars, name, zoom, align, init)
	if TW.has(prefix .. "_0") then
		local t = TW.digits(prefix, maxChars, name)
		t.InitCommand = init
		t.SetTextCommand = function(self, p) TW.setDigits(self, prefix, p.text, maxChars, zoom, align) end
		return t
	end
	if TW.blank(prefix .. "_0") then return Def.Actor { Name = name } end
	return LoadFont(TW.font) .. { Name = name,
		InitCommand = function(self) self:zoom(zoom * 1.1):align(align, 0); if init then init(self) end end,
		SetTextCommand = function(self, p) self:settext(p.text) end }
end

-- A clickable area (Til Death's mouse layer must be loaded on the screen).
function TW.button(w, h, onClick, onOver, onRight)
	return UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self) self:zoomto(w, h):diffusealpha(0) end,
		MouseOverCommand = function(self) if onOver then onOver(self, true) end end,
		MouseOutCommand = function(self) if onOver then onOver(self, false) end end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then onClick(self)
			elseif onRight and params.event == "DeviceButton_right mouse button" then onRight(self) end
		end
	}
end

-- A filled circle with a smooth edge (one actor: its diffuse tints it).
function TW.circle(r, col)
	return Def.ActorMultiVertex {
		InitCommand = function(self)
			self:SetDrawState { Mode = "DrawMode_Triangles" }:SetVertices(TW.boxVerts { w = r * 2, h = r * 2, r = r, ax = 0.5, ay = 0.5, col = col })
		end
	}
end

-- The osu! cookie: white rim, pink face with paler triangles, a word in the middle.
function TW.cookie(r, word)
	local t = Def.ActorFrame {
		TW.circle(r, color("#FFFFFF")),
		TW.circle(r * 0.89, TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.12)), -- osu!'s pink, or the interface colour
	}
	-- a few soft triangles, like the osu! cookie's pattern
	local tris = { { -0.45, -0.55, 0.22 }, { 0.2, -0.62, 0.16 }, { 0.5, -0.2, 0.2 }, { -0.62, 0.15, 0.18 },
		{ 0.35, 0.45, 0.24 }, { -0.2, 0.55, 0.2 }, { 0.05, -0.15, 0.12 }, { -0.35, -0.05, 0.1 } }
	for _, tr in ipairs(tris) do
		local x, y, s = tr[1] * r, tr[2] * r, tr[3] * r
		local c = TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.35); c[4] = 0.55
		t[#t + 1] = Def.ActorMultiVertex {
			InitCommand = function(self)
				self:xy(x, y):SetDrawState { Mode = "DrawMode_Triangles" }:SetVertices {
					{ { 0, -s, 0 }, c }, { { -s * 0.95, s * 0.6, 0 }, c }, { { s * 0.95, s * 0.6, 0 }, c } }
			end
		}
	end
	t[#t + 1] = LoadFont("Common Large") .. { Text = word, InitCommand = function(self)
		self:zoom(r * 1.3 / math.max(1, self:GetWidth())):diffuse(color("#FFFFFF"))
	end }
	return t
end

-- The player's card, as osu! shows it: avatar, name, rating (Etterna's MSD-based rating in place of
-- osu!'s pp), accuracy and play count with a level-style bar.
-- the player's profile, also on the title screen (where Etterna hasn't loaded it yet)
function TW.profile()
	local p = PROFILEMAN:GetProfile(PLAYER_1)
	if p and p:GetDisplayName() ~= "" then return p, getAvatarPath(PLAYER_1) end
	local ok, id = pcall(function() return PREFSMAN:GetPreference("DefaultLocalProfileIDP1") end)
	if ok and id and id ~= "" then
		local lp = PROFILEMAN:GetLocalProfile(id)
		if lp then return lp, getAvatarPath(PLAYER_1) end
	end
	return p, getAvatarPath(PLAYER_1)
end

-- Play time as Etterna counts it (the length of every play that was saved, the part you survived of a
-- failed one), split into 4K and 7K by each score's chart: { k4, k7, total } in seconds. Worked out
-- again only when there are new scores.
local playCache = { n = -1 }
function TW.playTimes()
	local n = 0
	pcall(function() n = SCOREMAN:GetTotalNumberOfScores() end)
	local p = TW.profile()
	if playCache.n == n and playCache.p == p then return playCache.v end
	local k4, k7, sum = 0, 0, 0
	pcall(function()
		SCOREMAN:SortRecentScores()
		local kinds = {}
		local i = 1
		while true do
			local hs = SCOREMAN:GetRecentScore(i)
			if not hs then break end
			local sec = hs:GetPlayedSeconds() or 0
			local ck = hs:GetChartKey()
			local kind = kinds[ck]
			if kind == nil then
				kind = ""
				local st = SONGMAN:GetStepsByChartKey(ck)
				if st then
					local t = tostring(st:GetStepsType())
					kind = t == "StepsType_Dance_Single" and "4" or (t == "StepsType_Kb7_Single" and "7" or "")
				end
				kinds[ck] = kind
			end
			if kind == "4" then k4 = k4 + sec elseif kind == "7" then k7 = k7 + sec end
			sum = sum + sec
			i = i + 1
		end
	end)
	local total = sum
	pcall(function() total = math.max(sum, p:GetTotalGameplaySeconds()) end)
	playCache = { n = n, p = p, v = { k4 = k4, k7 = k7, total = total } }
	return playCache.v
end
function TW.fmtPlayTime(sec)
	sec = math.floor(sec or 0)
	return string.format("%dh %02dm", math.floor(sec / 3600), math.floor(sec / 60) % 60)
end

-- The profile's numbers, for the profile panels (Quaver's PROFILE, osu!'s user card): { label, fn(profile) }
function TW.profileRows()
	local rows = {
		{ "Overall Rating", function(p) return string.format("%.2f", p:GetPlayerRating()) end },
		{ "Highest Rated Score", function(p)
			local v = 0
			pcall(function() SCOREMAN:SortSSRsForGame("Overall"); local hs = SCOREMAN:GetTopSSRHighScoreForGame(1, "Overall"); v = hs and hs:GetSkillsetSSR("Overall") or 0 end)
			return string.format("%.2f", v)
		end },
	}
	for _, sk in ipairs({ "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical" }) do
		rows[#rows + 1] = { sk == "JackSpeed" and "Jackspeed" or sk, function(p) local v = 0; pcall(function() v = p:GetPlayerSkillsetRating(sk) end); return string.format("%.2f", v) end }
	end
	rows[#rows + 1] = { "Play Count", function(p) return tostring(p:GetNumTotalSongsPlayed()) end }
	rows[#rows + 1] = { "Total Hits", function(p) local n = 0; pcall(function() n = p:GetTotalTapsAndHolds() end); local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse(); return (s:gsub("^,", "")) end }
	rows[#rows + 1] = { "Play Time (4K)", function() return TW.fmtPlayTime(TW.playTimes().k4) end }
	rows[#rows + 1] = { "Play Time (7K)", function() return TW.fmtPlayTime(TW.playTimes().k7) end }
	rows[#rows + 1] = { "Play Time (total)", function() return TW.fmtPlayTime(TW.playTimes().total) end }
	return rows
end

-- Sets the music rate back to 1.0x (resetting mods does, as in osu! and Quaver)
function TW.resetRate()
	for _, l in ipairs({ "ModsLevel_Preferred", "ModsLevel_Song", "ModsLevel_Current" }) do
		pcall(function() GAMESTATE:GetSongOptionsObject(l):MusicRate(1) end)
	end
	MESSAGEMAN:Broadcast("CurrentRateChanged")
end

-- Names a new Etterna playlist (the same lists the Quaver look's Create Playlist and Group by >
-- Playlists use) and puts the selected chart in it.
function TW.createPlaylist(name)
	name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then SCREENMAN:SystemMessage("Type a name for the playlist first") return false end
	local ok = SONGMAN:NewPlaylistNoDialog(name)
	if not ok then SCREENMAN:SystemMessage("There is already a playlist called " .. name) return false end
	local steps = GAMESTATE:GetCurrentSteps()
	local pl = SONGMAN:GetActivePlaylist()
	if steps and pl then pl:AddChart(steps:GetChartKey()) end
	SCREENMAN:SystemMessage("Playlist \"" .. name .. "\" made with the selected chart in it")
	MESSAGEMAN:Broadcast("TWPlaylistsChanged")
	return true
end

-- osu!'s user panel: a dark see-through card with the avatar, the name, the rating (Etterna's in
-- place of osu!'s pp), the play count and a level bar, the rating also large and faint behind.
-- (bare: no box behind it, as osu! stable's song select shows it over the skin's bottom bar)
-- The player's accuracy as osu! shows it on the user card: the accuracies of the best scores, each
-- weighted 0.95 times the one before (here Etterna's top scores by rating, Wife%)
local accCache = nil
function TW.profileAccuracy()
	local p = TW.profile()
	if not p then return 0 end
	local n = 0
	pcall(function() n = p:GetNumTotalSongsPlayed() end)
	if accCache and accCache.p == p and accCache.n == n then return accCache.v end
	local sum, wsum, w = 0, 0, 1
	pcall(function()
		SCOREMAN:SortSSRsForGame("Overall")
		for i = 1, 100 do
			local hs = SCOREMAN:GetTopSSRHighScoreForGame(i, "Overall")
			if not hs then break end
			sum = sum + hs:GetWifeScore() * 100 * w
			wsum = wsum + w
			w = w * 0.95
		end
	end)
	local v = wsum > 0 and sum / wsum or 0
	accCache = { p = p, n = n, v = v }
	return v
end

function TW.userCard(x, y, h, bare)
	local s = h / 80
	local W = 330 * s
	local function level(p)
		local secs = p and p:GetTotalGameplaySeconds() or 0
		return math.sqrt(secs / 60) + 1
	end
	if bare then
		-- osu! stable's user card, line for line (skins frame it with their art, and often cover osu!'s
		-- "Performance:" / "Accuracy:" / "Lv" with words of their own, leaving holes for the numbers,
		-- so the text has to sit exactly where osu! writes it): the avatar, the name, then
		-- Performance (Etterna's rating), Accuracy and level, with the level's bar along the bottom
		local TX = 88.5 * s
		local function line(px, cy, bold) return function(self) self:align(0, 0.5):xy(TX, cy * s):shadowlength(0) end end
		return Def.ActorFrame {
			InitCommand = function(self) self:xy(x, y) end,
			BeginCommand = function(self) self:playcommand("Set") end,
			PlayerRatingUpdatedMessageCommand = function(self) self:playcommand("Set") end,
			Def.Sprite {
				Name = "Avatar",
				SetCommand = function(self)
					local _, av = TW.profile()
					self:Load(av):align(0, 0):xy(3 * s, 0):zoomto(76 * s, 76 * s)
				end
			},
			TW.text(12.5 * s, false, line(12.5, 9.25)) .. {
				InitCommand = function(self) self:maxwidth((W - TX - 8 * s) / self:GetZoom()) end,
				SetCommand = function(self)
					local p = TW.profile()
					local n = p and p:GetDisplayName() or ""
					self:settext(n ~= "" and n or "Guest")
				end
			},
			-- (signed in to VSRG Hub: its rating for the key count you play, and your place, as osu!'s
			-- pp and rank; else Etterna's rating)
			TW.text(9.1 * s, false, line(9.1, 29.2)) .. {
				SetCommand = function(self)
					local me = TW.hubMe and TW.hubMe()
					if me then
						local seven = TW.gameName and TW.gameName() == "kb7"
						self:settextf("Performance:%.2f", seven and me.r7 or me.r4)
						return
					end
					local p = TW.profile()
					self:settextf("Performance:%.2f", p and p:GetPlayerRating() or 0)
				end
			},
			TW.text(30 * s, false, function(self) self:align(1, 0.5):xy(W - 6 * s, 52 * s):diffusealpha(0.18):shadowlength(0) end) .. {
				SetCommand = function(self)
					local me = TW.hubMe and TW.hubMe()
					local seven = TW.gameName and TW.gameName() == "kb7"
					local place = me and (seven and me.p7 or me.p4) or 0
					self:settext(place > 0 and ("#" .. place) or "")
				end
			},
			-- (VSRG Hub writes your ratings a moment after the game starts, and after each play)
			Def.Actor { OnCommand = function(self) self:sleep(3):queuecommand("Again") end,
				AgainCommand = function(self) self:GetParent():playcommand("Set"); self:sleep(10):queuecommand("Again") end },
			TW.text(9.1 * s, false, line(9.1, 45.9)) .. {
				SetCommand = function(self) self:settextf("Accuracy:%.2f%%", TW.profileAccuracy()) end
			},
			TW.text(9.1 * s, false, line(9.1, 62.6)) .. {
				SetCommand = function(self) self:settextf("Lv%d", math.floor(level(TW.profile()))) end
			},
			TW.box { w = 140 * s, h = 3 * s, r = 1.5 * s, col = { 1, 1, 1, 0.16 }, init = function(self) self:xy(TX + 47 * s, 68.5 * s) end },
			TW.box { w = 0, h = 3 * s, r = 1.5 * s, col = TW.yellow, init = function(self) self:xy(TX + 47 * s, 68.5 * s) end } .. {
				SetCommand = function(self)
					local lv = level(TW.profile())
					TW.setBox(self, { w = 140 * s * (lv - math.floor(lv)) })
				end
			},
		}
	end
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(x, y) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		PlayerRatingUpdatedMessageCommand = function(self) self:playcommand("Set") end,
		TW.shadow { w = W, h = h, spread = 10 * s, alpha = 0.35 },
		TW.box { w = W, h = h, r = 6 * s, col = { 0.04, 0.04, 0.06, 0.62 }, col2 = { 0.08, 0.08, 0.11, 0.55 } },
		-- the rating, large and faint on the right (osu!'s rank number)
		TW.text(34 * s, true, function(self) self:align(1, 0.5):xy(W - 8 * s, h / 2 + 2 * s):diffusealpha(0.10) end) .. {
			SetCommand = function(self) local p = TW.profile(); self:settextf("%.2f", p and p:GetPlayerRating() or 0) end
		},
		Def.Sprite {
			Name = "Avatar",
			SetCommand = function(self)
				local _, av = TW.profile()
				self:Load(av):align(0, 0):xy(5 * s, 5 * s):zoomto(h - 10 * s, h - 10 * s)
			end
		},
		TW.text(15 * s, true, function(self) self:align(0, 0):xy(h + 4 * s, 6 * s):maxwidth((W - h - 12 * s) / self:GetZoom()) end) .. {
			SetCommand = function(self)
				local p = TW.profile()
				local n = p and p:GetDisplayName() or ""
				self:settext(n ~= "" and n or "Guest")
			end
		},
		TW.text(10 * s, false, function(self) self:align(0, 0):xy(h + 4 * s, 28 * s):diffusealpha(0.9) end) .. {
			SetCommand = function(self)
				local p = TW.profile()
				local n = 0
				pcall(function() n = p:GetNumTotalSongsPlayed() end)
				self:settextf("Rating: %.2f", p and p:GetPlayerRating() or 0)
				self:GetParent():GetChild("Plays"):settextf("Plays: %d", n)
			end
		},
		TW.text(10 * s, false, function(self) self:align(0, 0):xy(h + 4 * s, 43 * s):diffusealpha(0.9) end) .. { Name = "Plays" },
		TW.text(9.5 * s, false, function(self) self:align(0, 0):xy(h + 4 * s, 57 * s):diffusealpha(0.85) end) .. {
			SetCommand = function(self)
				local p = TW.profile()
				-- with the play time in the mode you're in, like osu!'s user card
				local pt = TW.playTimes()
				local seven = TW.gameName and TW.gameName() == "kb7"
				local lv = math.floor(level(p))
				-- (on the main menu Etterna hasn't read the scores yet: just the level there)
				if pt.k4 + pt.k7 <= 0 then self:settextf("Lv%d", lv) return end
				self:settextf("Lv%d   %s: %s", lv, seven and "7K" or "4K", TW.fmtPlayTime(seven and pt.k7 or pt.k4))
			end
		},
		TW.box { w = W - h - 12 * s, h = 4 * s, r = 2 * s, col = { 1, 1, 1, 0.16 }, init = function(self) self:xy(h + 4 * s, h - 9 * s) end },
		TW.box { w = 0, h = 4 * s, r = 2 * s, col = TW.yellow, init = function(self) self:xy(h + 4 * s, h - 9 * s) end } .. {
			SetCommand = function(self)
				local lv = level(TW.profile())
				TW.setBox(self, { w = (W - h - 12 * s) * (lv - math.floor(lv)) })
			end
		},
	}
end

-- Song select: the song pictures the wheel showed last stay loaded in hidden sprites, so a panel
-- showing a song its neighbour showed a moment ago (every wheel step shifts them all by one) finds
-- the image ready instead of reading and decoding it from disk again. Only new songs are loaded.
local KEEP = 18
function TW.textureKeeper()
	local f = Def.ActorFrame {
		Name = "TWTextureKeeper",
		InitCommand = function(self) TW.texHold = self; TW.texSlots = {}; TW.texNext = 1 end,
		OffCommand = function() TW.texHold = nil end,
	}
	for i = 1, KEEP do f[#f + 1] = Def.Sprite { Name = "K" .. i, InitCommand = function(self) self:visible(false) end } end
	return f
end
function TW.keepTexture(spr)
	local h = TW.texHold
	if not h then return end
	pcall(function()
		local tex = spr:GetTexture()
		if not tex then return end
		local path = tex:GetPath()
		if TW.texSlots[path] then return end
		local i = TW.texNext
		for p, j in pairs(TW.texSlots) do if j == i then TW.texSlots[p] = nil break end end
		h:GetChild("K" .. i):SetTexture(tex)
		TW.texSlots[path] = i
		TW.texNext = i % KEEP + 1
	end)
end
-- how long a wheel panel waits before loading its picture: once the wheel stops, from the middle
-- out, a few frames apart (all at once made a long hitch every time the wheel stopped)
function TW.pictureDelay(drawIndex, middle)
	local d = math.abs((drawIndex or middle) - middle)
	return 0.12 + d * 0.04
end

-- Animations inside the song wheel's panels, without tweens. Etterna's wheel only places its panels
-- while nothing inside it is tweening (WheelBase::Update asks the whole wheel's GetTweenTimeLeft),
-- so a panel's fade, hover or a picture waiting to load froze the wheel's scrolling until it ended,
-- and the panels jumped instead of gliding. These are stepped by the panel's own update function
-- (TW.wheelStep) instead: owner is the panel's frame, actor the one that moves.
local function iaGet(a, prop)
	if prop == "x" then return a:GetX() elseif prop == "zoom" then return a:GetZoom() end
	return a.twOwnAlpha or a:GetDiffuseAlpha()
end
local function iaSet(a, prop, v)
	if prop == "x" then a:x(v) elseif prop == "zoom" then a:zoom(v) else a.twOwnAlpha = v; a:diffusealpha(v * (a.twFade or 1)) end
end
-- moves actor's prop ("x", "zoom" or "alpha") to `to` in dur seconds (ease "dec" or "lin"), after
-- delay, from `from` (or where it is now)
function TW.ianim(owner, actor, prop, to, dur, ease, delay, from)
	owner._ia = owner._ia or {}
	if from ~= nil then iaSet(actor, prop, from) end
	local key = tostring(actor) .. prop
	owner._ia[key] = { a = actor, prop = prop, from = from or iaGet(actor, prop), to = to,
		t0 = GetTimeSinceStart() + (delay or 0), dur = math.max(dur or 0, 0.0001), ease = ease }
end
-- runs fn after delay seconds (one per name: a new one replaces the waiting one; fn nil cancels)
function TW.ilater(owner, name, delay, fn)
	owner._il = owner._il or {}
	owner._il[name] = fn and { t = GetTimeSinceStart() + delay, fn = fn } or nil
end
function TW.wheelStep(owner)
	local now = GetTimeSinceStart()
	if owner._ia then
		for key, s in pairs(owner._ia) do
			if now >= s.t0 then
				local k = math.min(1, (now - s.t0) / s.dur)
				local e = s.ease == "lin" and k or (1 - (1 - k) * (1 - k))
				iaSet(s.a, s.prop, s.from + (s.to - s.from) * e)
				if k >= 1 then owner._ia[key] = nil end
			end
		end
	end
	if owner._il then
		for name, l in pairs(owner._il) do
			if now >= l.t then owner._il[name] = nil; l.fn() end
		end
	end
end

-- How many songs a pack on the wheel holds right now: what the search and filters left in it
-- (Etterna's own filtered list), or the whole pack when the wheel isn't there.
-- Counted once per pack and kept until the wheel's list changes (Etterna sends FilterResults then;
-- the wheel items clear TW.groupCache): asking Etterna for a 9000-song pack's list on every wheel
-- step made scrolling stutter.
function TW.groupCount(name)
	local so = tostring(GAMESTATE:GetSortOrder())
	TW.groupCache = TW.groupCache or {}
	local c = TW.groupCache[so]
	if not c then c = {}; TW.groupCache[so] = c end
	if c[name] then return c[name] end
	local n
	pcall(function()
		local top = SCREENMAN:GetTopScreen()
		local w = top and top.GetMusicWheel and top:GetMusicWheel()
		local songs = w and w:GetSongsInGroup(name)
		if songs and #songs > 0 then n = #songs end
	end)
	if n == nil then
		local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(name) end)
		n = ok and songs and #songs or 0
	end
	c[name] = n
	return n
end

-- Volume with Alt + mouse wheel, as in osu! and Quaver, on every screen ------------------------
function TW.volume() return PREFSMAN:GetPreference("SoundVolumeMaster") or 1 end
-- Alt is tracked from its own key events too (IsBeingPressed misses it on some keyboards/setups)
TW.altDown = false
-- (asks Etterna whether Alt is down right now; the Alt key events alone can't be trusted: the
-- release is lost when it happens during a screen change or while playing, and the wheel then kept
-- changing the volume without Alt)
function TW.altHeld()
	local ok, held = pcall(function()
		return INPUTFILTER:IsBeingPressed("left alt") or INPUTFILTER:IsBeingPressed("right alt")
	end)
	if ok then return held == true end
	return TW.altDown == true
end
function TW.volumeInput(event)
	local b = event.DeviceInput.button
	if b == "DeviceButton_left alt" or b == "DeviceButton_right alt" then
		TW.altDown = event.type ~= "InputEventType_Release"
		return false
	end
	-- a wheel that keeps turning stays "pressed" and sends repeats: each one is a step, so the volume
	-- follows the wheel while it turns (not only once per turn)
	local step = event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat"
	-- the song select screens call this first and the system layer calls it again: act once
	if (b == "DeviceButton_mousewheel up" or b == "DeviceButton_mousewheel down") and step then
		local now = GetTimeSinceStart()
		if TW._volT and math.abs(now - TW._volT) < 0.005 and TW._volB == b and TW.altHeld() then return true end
		TW._volT, TW._volB = now, b
	end
	if (b ~= "DeviceButton_mousewheel up" and b ~= "DeviceButton_mousewheel down") or not TW.altHeld() then return false end
	if step then
		local v = TW.volume() + (b == "DeviceButton_mousewheel up" and 0.05 or -0.05)
		v = math.max(0, math.min(1, math.floor(v * 20 + 0.5) / 20))
		SOUND:SetVolume(v)
		MESSAGEMAN:Broadcast("TWVolume", { volume = v })
	end
	return true
end
-- Hooks TW.volumeInput into whatever screen is on top (put it in a system layer, which every screen
-- shares), so it also works in gameplay, results and Etterna's own option screens.
function TW.volumeHook()
	local hooked = nil
	return Def.ActorFrame { -- (an ActorFrame: a plain Actor has no update function)
		InitCommand = function(self)
			self:SetUpdateFunction(function()
				local top = SCREENMAN:GetTopScreen()
				if top and top ~= hooked then
					hooked = top
					pcall(function() top:AddInputCallback(TW.volumeInput) end)
				end
			end)
		end
	}
end
-- osu!'s volume meter in the bottom right corner while you change it
function TW.volumeDisplay(col)
	local M = TW.M
	col = col or TW.pink
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(SCREEN_WIDTH - M(110), SCREEN_HEIGHT - M(110)):draworder(9000):diffusealpha(0) end,
		TWVolumeMessageCommand = function(self, p)
			self:stoptweening():linear(0.1):diffusealpha(1):sleep(1.2):linear(0.3):diffusealpha(0)
			self:GetChild("Text"):settext(string.format("%d%%", math.floor(p.volume * 100 + 0.5)))
			self:GetChild("Bar"):zoomto(M(150) * p.volume, M(8))
		end,
		Def.Quad { InitCommand = function(self) TW.glassify(self:zoomto(M(180), M(90)), "float", { 0, 0, 0, 0.75 }) end },
		TW.text(M(13), true, function(self) self:align(0.5, 0.5):y(-M(28)):settext("VOLUME") end),
		TW.text(M(26), true, function(self) self:align(0.5, 0.5):y(-M(2)) end) .. { Name = "Text" },
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(-M(75), M(28)):zoomto(M(150), M(8)):diffuse(color("#FFFFFF33")) end },
		Def.Quad { Name = "Bar", InitCommand = function(self) self:align(0, 0.5):xy(-M(75), M(28)):zoomto(0, M(8)):diffuse(col) end },
	}
end
-- Right click on an empty part of song select pauses or resumes the song's preview, as in Etterna.
function TW.pauseCatcher()
	return UIElements.QuadButton(-1000, 1) .. {
		InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffusealpha(0); TW.previewPaused = false end,
		CurrentSongChangedMessageCommand = function() TW.previewPaused = false end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_right mouse button" then
				local top = SCREENMAN:GetTopScreen()
				if top and top.PauseSampleMusic then
					top:PauseSampleMusic()
					TW.previewPaused = not TW.previewPaused
					SCREENMAN:SystemMessage(TW.previewPaused and "Preview paused (right click to resume)" or "Preview playing")
					MESSAGEMAN:Broadcast("MusicPauseToggled")
				end
			end
		end
	}
end

-- Tab on song select (View Map in the Quaver look) plays the chart in Etterna's practice mode from
-- where the preview is: song select stores the time, gameplay jumps there once it starts.
function TW.playFromPreview()
	local top = SCREENMAN:GetTopScreen()
	if not (top and top.GetSampleMusicPosition and top.SelectCurrent and GAMESTATE:GetCurrentSteps()) then return end
	TW.practiceStart = top:GetSampleMusicPosition()
	TW.practiceByTab = true
	GAMESTATE:SetPracticeMode(true)
	top:SelectCurrent()
end
function TW.practiceSeek()
	return Def.Actor {
		OnCommand = function(self) if TW.practiceStart then self:sleep(0.3):queuecommand("Seek") end end,
		SeekCommand = function(self)
			local t = TW.practiceStart
			TW.practiceStart = nil
			local top = SCREENMAN:GetTopScreen()
			if t and top and top.SetSongPositionAndUnpause then
				pcall(function() top:SetSongPositionAndUnpause(math.max(0, t - 2), 1, true) end)
			end
		end
	}
end
-- back on song select after a Tab play, practice mode goes off again
function TW.endTabPractice()
	TW.customize = false
	if TW.practiceByTab then
		TW.practiceByTab = false
		GAMESTATE:SetPracticeMode(false)
	end
	-- (the Practice mod keeps it on)
	if TW.keepPractice then TW.keepPractice() end
end
