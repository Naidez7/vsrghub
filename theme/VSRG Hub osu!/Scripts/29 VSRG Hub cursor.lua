-- The pointer, picked in the options (Cursor): the look's own (the interface skin's in the osu!
-- look, Quaver's in the Quaver look), Etterna's, Quaver's or any osu! skin's cursor.png. It is drawn
-- the way its game draws it: an osu! cursor at osu!'s size (its @2x art at half), turning and
-- growing on a click when the skin asks for it, with the skin's cursortrail and cursormiddle;
-- Quaver's as a 40-unit square with its tip on the mouse, growing a little on a click; Etterna's as
-- its small white diamond. "Cursor size" scales any of them, like osu!'s cursor size.
--
-- settings.ini: cursor = "" (the look's own), "etterna", "quaver" or "osu:<osu! skin folder>";
-- cursorSize = 0.5 ... 2. The picked pointer is also written out (cursorKind, cursorFile, ...) so
-- Til' Death and Rebirth, which don't run this file, draw it too (VSRG Hub's theme-switch.lua).

TW.QUAVER_CURSOR = "/Themes/VSRG Hub Quaver/Graphics/_quaver cursor.png"
local QUAVER_SIZE = 40 -- Quaver's pointer, in its 768-tall units

function TW.cursorSize()
	local v = tonumber(TW.settings and TW.settings.cursorSize or "") or 1
	return math.max(0.5, math.min(2, v))
end

-- What a choice draws: { kind = "osu" | "quaver" | "etterna" | "plain", ... }
function TW.cursorSpec(choice)
	if choice == nil then choice = TW.settings and TW.settings.cursor or "" end
	if choice == "" then
		local own = TW.settings and TW.settings.interfaceSkin
		if own == "" then own = nil end
		own = own or TW_OSU_SKIN
		if TW.isQuaver then choice = "quaver"
		elseif TW_SKIN and TW_SKIN.folder then choice = "osu:" .. TW_SKIN.folder
		-- (osu!lazer's look draws no skin, but its pointer is still your osu! skin's, as in lazer)
		elseif own and own ~= "" and TW_SKINS and TW_SKINS[own] then choice = "osu:" .. own
		else choice = "plain" end
	end
	if choice == "etterna" then return { kind = "etterna" } end
	if choice == "quaver" then return { kind = "quaver", file = TW.QUAVER_CURSOR } end
	local folder = choice:match("^osu:(.*)$")
	local s = folder and TW_SKINS and TW_SKINS[folder]
	if s and s.files and s.files.cursor then
		local function file(id) return s.files[id] and (s.dir .. s.files[id]) or nil end
		local function hd(id) return s.hd ~= nil and s.hd[id] == true end
		return { kind = "osu", file = file("cursor"), hd = hd("cursor"),
			middle = file("cursor_middle"), middleHd = hd("cursor_middle"),
			trail = file("cursor_trail"), trailHd = hd("cursor_trail"),
			centre = s.cursorCentre ~= false, rotate = s.cursorRotate ~= false, expand = s.cursorExpand ~= false,
			name = s.name or folder }
	end
	return { kind = "plain" }
end

-- The list the Cursor option opens: the three built-in pointers, then every osu! skin with one.
function TW.cursorItems()
	local items = {
		{ label = "The look's own", value = "", sub = "interface skin's / Quaver's" },
		{ label = "Etterna", value = "etterna", sub = "Etterna's pointer" },
		{ label = "Quaver", value = "quaver", sub = "Quaver's pointer" },
	}
	local folders = {}
	for folder, s in pairs(TW_SKINS or {}) do
		if s.files and s.files.cursor then folders[#folders + 1] = folder end
	end
	table.sort(folders, function(a, b)
		local na, nb = (TW_SKINS[a].name or a):lower(), (TW_SKINS[b].name or b):lower()
		if na == nb then return a < b end
		return na < nb
	end)
	local seen = {}
	for _, folder in ipairs(folders) do
		local n = (TW_SKINS[folder].name or folder):lower()
		seen[n] = (seen[n] or 0) + 1
	end
	for _, folder in ipairs(folders) do
		local s = TW_SKINS[folder]
		local name = s.name or folder
		-- (two skins with the same name are told apart by their folder)
		local sub = seen[name:lower()] > 1 and folder or "osu! skin"
		if s.hd and s.hd.cursor then sub = sub .. ", @2x" end
		items[#items + 1] = { label = name, value = "osu:" .. folder, sub = sub }
	end
	return items
end
function TW.cursorLabel()
	local c = TW.settings and TW.settings.cursor or ""
	for _, it in ipairs(TW.cursorItems()) do if it.value == c then return it.label end end
	return "The look's own"
end

-- Keeps the choice and writes out what Til' Death and Rebirth need to draw it.
function TW.setCursor(choice)
	TW.saveSetting("cursor", choice or "")
	-- (with the look's own picked, Etterna's own themes keep their pointer)
	local spec = (choice or "") == "" and { kind = "etterna" } or TW.cursorSpec(choice)
	TW.saveSetting("cursorKind", spec.kind)
	TW.saveSetting("cursorFile", spec.file or "")
	TW.saveSetting("cursorHd", spec.hd and "1" or "0")
	TW.saveSetting("cursorCentre", spec.centre and "1" or "0")
	TW.saveSetting("cursorRotate", spec.rotate and "1" or "0")
	MESSAGEMAN:Broadcast("TWCursorChanged")
end
function TW.setCursorSize(v)
	TW.saveSetting("cursorSize", string.format("%.2f", math.max(0.5, math.min(2, v))))
	MESSAGEMAN:Broadcast("TWCursorChanged")
end

-- The pointer's art for a spec. preview: drawn still (no turning) and centred, for the picker.
-- SetCursorCommand { spec = ..., size = ... } loads it; the frame's Grow child grows on clicks.
local TRAIL_N = 10
function TW.cursorArt(preview)
	local spec = { kind = "plain" }
	local function apply(self, p)
		spec = p.spec or TW.cursorSpec()
		local size = p.size or TW.cursorSize()
		local grow = self:GetChild("Grow")
		local spin = grow:GetChild("Spin")
		local img, mid = spin:GetChild("Img"), grow:GetChild("Mid")
		grow:stoptweening():zoom(1)
		spin:stopeffect():rotationz(0)
		img:visible(false); mid:visible(false)
		grow:GetChild("Diamond"):visible(spec.kind == "etterna"):zoom(size)
		grow:GetChild("Plain"):visible(spec.kind == "plain"):zoom(size)
		if spec.kind == "osu" then
			local a = (spec.centre or preview) and 0.5 or 0
			TW.inset(img:Load(spec.file)):align(a, a):zoom(TW.U * (spec.hd and 0.5 or 1) * size):visible(true)
			if spec.middle then
				TW.inset(mid:Load(spec.middle)):align(a, a):zoom(TW.U * (spec.middleHd and 0.5 or 1) * size):visible(true)
			end
			if spec.rotate and not preview then spin:spin():effectmagnitude(0, 0, 36) end
		elseif spec.kind == "quaver" then
			local s = QUAVER_SIZE * TW.U * size
			TW.inset(img:Load(spec.file)):align(preview and 0.5 or 0, preview and 0.5 or 0):zoomto(s, s):visible(true)
		end
	end
	local function grow(self, on)
		local g = self:GetChild("Grow")
		local z = 1
		if on and spec.kind == "osu" and spec.expand then z = 1.3 end
		if on and spec.kind == "quaver" then z = 1.2 end
		g:stoptweening():linear(0.1):zoom(z)
	end
	local s = 5 * SCREEN_HEIGHT / 480 -- Etterna's pointer
	return Def.ActorFrame {
		SetCursorCommand = apply,
		MouseClickPressMessageCommand = function(self) if not preview then grow(self, true) end end,
		MouseClickReleaseMessageCommand = function(self) if not preview then grow(self, false) end end,
		Def.ActorFrame {
			Name = "Grow",
			Def.ActorFrame { Name = "Spin", Def.Sprite { Name = "Img" } },
			Def.Sprite { Name = "Mid" },
			Def.ActorFrame {
				Name = "Diamond",
				InitCommand = function(self) self:visible(false) end,
				Def.Quad { InitCommand = function(self) self:rotationz(45):zoomto(s + 2, s + 2):diffuse(color("#000000")):diffusealpha(0.6) end },
				Def.Quad { InitCommand = function(self) self:rotationz(45):zoomto(s, s):diffuse(color("#FFFFFF")) end },
			},
			-- osu!'s look without a skin pointer: a light diamond with the interface colour inside
			Def.ActorFrame {
				Name = "Plain",
				InitCommand = function(self) self:visible(false) end,
				Def.Quad { InitCommand = function(self) self:zoomto(TW.M(22), TW.M(22)):rotationz(45):diffuse(color("#FFFFFF")):diffusealpha(0.9) end },
				Def.Quad { InitCommand = function(self) self:zoomto(TW.M(16), TW.M(16)):rotationz(45):diffuse(TW.pink) end },
			},
		},
	}
end

-- The game's pointer, with the picked art (and the osu! skin's trail behind it).
function TW.choosablePointer()
	local spec = nil
	local function load(self)
		spec = TW.cursorSpec()
		local size = TW.cursorSize()
		local arrow = self:GetChild("Arrow")
		local art = arrow and arrow:GetChild("Art")
		if art then art:playcommand("SetCursor", { spec = spec, size = size }) end
		local trail = self:GetChild("Trail")
		if trail then
			for i = 1, TRAIL_N do
				local t = trail:GetChild("T" .. i)
				t:visible(false)
				if spec.kind == "osu" and spec.trail then
					local a = spec.centre and 0.5 or 0
					TW.inset(t:Load(spec.trail)):align(a, a):zoom(TW.U * (spec.trailHd and 0.5 or 1) * size)
				end
			end
		end
	end
	local acc, idx, step = 0, 0, 1 / 90
	local trail = Def.ActorFrame { Name = "Trail" }
	for i = 1, TRAIL_N do trail[#trail + 1] = Def.Sprite { Name = "T" .. i, InitCommand = function(self) self:visible(false) end } end
	trail.PointerCommand = function(self, p)
		if not (spec and spec.kind == "osu" and spec.trail) then return end
		if not p.show then for i = 1, TRAIL_N do self:GetChild("T" .. i):visible(false) end return end
		acc = acc + p.dt
		if acc < step then return end
		acc = 0
		idx = idx % TRAIL_N + 1
		self:GetChild("T" .. idx):visible(true):stoptweening():xy(p.x, p.y):diffusealpha(1):linear(0.15):diffusealpha(0)
	end
	local f = TW.pointer(TW.cursorArt(false) .. { Name = "Art" }, trail)
	f.TWCursorChangedMessageCommand = function(self) load(self) end
	-- (the system layer's actors get no On command, and a command queued at Init can be cleared by
	-- the pointer's own stoptweening on the first screen change: the art is loaded on the first
	-- screen change, and again whenever the choice changes)
	local loaded = false
	local init = f.InitCommand
	f.InitCommand = function(self)
		if init then init(self) end
		self:queuecommand("LoadCursor")
	end
	f.LoadCursorCommand = function(self) if not loaded then loaded = true; load(self) end end
	local changed = f.ScreenChangedMessageCommand
	f.ScreenChangedMessageCommand = function(self, p)
		if not loaded then loaded = true; load(self) end
		if changed then changed(self, p) end
	end
	return f
end

-- The first start: the pointer and the combo digits come from the skin you use in osu! (the
-- interface already does, until you pick another).
if TW.settings and TW_OSU_SKIN and TW_OSU_SKIN ~= "" and TW_SKINS and TW_SKINS[TW_OSU_SKIN] then
	local e = TW_SKINS[TW_OSU_SKIN]
	if TW.settings.cursor == nil and e.files and e.files.cursor then TW.setCursor("osu:" .. TW_OSU_SKIN) end
	if TW.settings.combo_skin == nil and e.files and e.files.combo_0 then TW.setComboSkin("osu:" .. TW_OSU_SKIN) end
end
