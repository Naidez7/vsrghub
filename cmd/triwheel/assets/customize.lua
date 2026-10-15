-- Written by VSRG Hub next to its theme picker in Etterna's own themes (Til Death, Rebirth) and loaded
-- by the picker's file. It brings over what the osu! and Quaver looks' Customize gameplay has:
--
-- 1. TWL: the settings VSRG Hub's noteskins read (note size, note spacing, receptor offset and size,
--    stage hint, LN tail), from the same Save/VSRGHub/layout.ini the osu! and Quaver looks use, kept
--    per noteskin, so a noteskin set up in one look plays the same in the others; and the stage those
--    noteskins need in play (where each receptor is, so the stage hint is one line across the stage).
-- 2. Customize Gameplay's panel, drawn the way the theme draws its own panels: Til Death's notefield
--    (position, hit position, size, column spacing) and every part it lets you move, picked with the
--    mouse instead of its letter keys; and in both themes the noteskin rows above. Rebirth keeps its
--    own menu for its parts and notefield; this panel sits on the other side and adds the rest.

local FILE = "Save/VSRGHub/layout.ini"
local function theme() return THEME:GetCurThemeName() end
local function isRebirth() return theme() == "Rebirth" end
local function isTD() return theme() == "Til Death" end
local function ownLook() return theme():find("^VSRG Hub") ~= nil end

-- the layout file, as the osu! and Quaver looks keep it ----------------------------------------
TWL = TWL or {}
local data = {}
local function loadData()
	data = {}
	local ok, txt = pcall(function() return File.Read(FILE) end)
	if ok and type(txt) == "string" then
		for k, v in txt:gmatch("([%w_]+)=([^\r\n]*)") do data[k] = tonumber(v) or v end
	end
end
local function saveData()
	local out = {}
	for k, v in pairs(data) do out[#out + 1] = k .. "=" .. tostring(v) end
	table.sort(out)
	pcall(function() File.Write(FILE, table.concat(out, "\n") .. "\n") end)
end
loadData()
local SKIN_ITEMS = { field = true, columns = true, receptors = true, lanecover = true, lntail = true, notes = true, hint = true,
	lighting = true, holdlight = true, collight = true }
local function gameKey()
	local g = GAMESTATE:GetCurrentGame()
	return g and g:GetName() or "dance"
end
local function safe(ns) return ((ns or ""):lower():gsub("[^%w]", "_")) end
local function noteskin()
	local ns = ""
	pcall(function() ns = GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin() or "" end)
	return ns
end
local function key(item, field)
	if SKIN_ITEMS[item] then return gameKey() .. "_" .. safe(noteskin()) .. "__" .. item .. "_" .. field end
	return gameKey() .. "_" .. item .. "_" .. field
end
local defaults = { x = 0, y = 0, z = 1, on = 1, w = 1, h = 1, a = 1 }
function TWL.lv(item, field)
	local v = data[key(item, field)]
	if v == nil then v = defaults[field] or 0 end
	return tonumber(v) or 0
end
function TWL.setLv(item, field, v)
	data[key(item, field)] = v
	saveData()
	MESSAGEMAN:Broadcast("TWLayoutChanged", { item = item })
end
function TWL.resetLv(item, field)
	data[key(item, field)] = nil
	saveData()
	MESSAGEMAN:Broadcast("TWLayoutChanged", { item = item })
end
function TWL.receptorLayout() return TWL.lv("receptors", "y"), TWL.lv("receptors", "z"), TWL.lv("receptors", "w"), TWL.lv("receptors", "h") end
function TWL.receptorsOrder() return TWL.lv("receptors", "o") end
function TWL.lightLayout(kind)
	return TWL.lv(kind, "on"), TWL.lv(kind, "x"), TWL.lv(kind, "y"), TWL.lv(kind, "z"), TWL.lv(kind, "w"), TWL.lv(kind, "h")
end
function TWL.tailLayout() return TWL.lv("lntail", "h"), TWL.lv("lntail", "y") end
function TWL.noteScale() return TWL.lv("notes", "z") end
function TWL.noteDims() return TWL.lv("notes", "w"), TWL.lv("notes", "h") end
function TWL.hintLayout() return TWL.lv("hint", "y"), TWL.lv("hint", "h") end
function TWL.noteSpacingExtra() return TWL.lv("columns", "n") end
TWL.stage = nil

-- the stage in play -----------------------------------------------------------------------------
-- Both themes space the columns themselves ((i - floor(n/2) - 1) * spacing, Til Death's and
-- Rebirth's own formula) and size them with zoomtowidth. Note spacing moves each column further
-- (its notes and holds); the noteskin moves the receptor back (noteShift, in the column's own,
-- zoomed, units). recX is each receptor's place in the notefield; the hint is drawn across from the
-- first receptor's frame.
local cols, applied, lastKey = nil, false, nil
local function mv(a, b)
	if not MovableValues then return nil end
	return tonumber(MovableValues[a]) or tonumber(MovableValues[b])
end
local function updateStage(force)
	if not cols or #cols == 0 then return end
	local n = #cols
	local inc = mv("NotefieldSpacing", "NoteFieldSpacing") or 0
	local zw = mv("NotefieldWidth", "NoteFieldWidth") or 1
	if zw == 0 then zw = 1 end
	local nd = TWL.noteSpacingExtra()
	if nd ~= 0 or applied then
		applied = true
		local hC = math.floor(n / 2)
		for i, col in ipairs(cols) do
			local want = (i - hC - 1) * inc + (i - (n + 1) / 2) * nd
			if math.abs(col:GetX() - want) > 0.001 then col:x(want) end
		end
	end
	local k = table.concat({ n, inc, zw, nd }, "|")
	if k == lastKey and not force then return end
	lastKey = k
	local hC = math.floor(n / 2)
	local recX, shift = {}, {}
	for i = 1, n do
		local off = i - (n + 1) / 2
		recX[i] = (i - hC - 1) * inc + off * 64 * zw
		shift[i] = -off * nd / zw
	end
	local left, right = recX[1] - 32 * zw, recX[n] + 32 * zw
	TWL.stage = { recX = recX, noteShift = shift, colZoom = zw, hintCX = (left + right) / 2, stageW = right - left }
	MESSAGEMAN:Broadcast("TWStage")
end
local function inPlay(top)
	local name = top and top:GetName() or ""
	return name:find("^ScreenGameplay") ~= nil and name ~= "ScreenGameplaySyncMachine"
end
local function customizing()
	local ok, on = pcall(function() return playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay end)
	if not ok then ok, on = pcall(function() return playerConfig:get_data().CustomizeGameplay end) end
	return ok and on == true
end

-- the panel -------------------------------------------------------------------------------------
-- colours and measures: the theme's own (as VSRG Hub's Ctrl+O menu in these themes)
local function C(k)
	if isRebirth() then
		local map = { body = "PrimaryBackground", lip = "SecondaryBackground", text = "PrimaryText", sub = "SecondaryText", line = "SeparationDivider", accent = "SeparationDivider" }
		local ok, c = pcall(function() return COLORS:getMainColor(map[k] or "PrimaryText") end)
		return ok and c or color((k == "body" or k == "lip") and "#111111" or "#FFFFFF")
	end
	local map = { body = "tabs", lip = "frames", text = "positive", accent = "highlight", line = "highlight" }
	local ok, c = pcall(function() return getMainColor(map[k] or "positive") end)
	local fallback = { body = "#2E2E2E", lip = "#000111", text = "#9654FD", accent = "#614080", line = "#614080" }
	return ok and c or color(fallback[k] or "#FFFFFF")
end
local function A(c, a) return { c[1], c[2], c[3], a } end
local function L()
	if isRebirth() then
		local u = SCREEN_HEIGHT / 720
		return { u = u, W = 330 * u, RH = 16 * u, lip = 22 * u, pad = 6 * u, z = 0.46, zs = 0.38, zt = 0.56, btn = 20 * u }
	end
	local u = SCREEN_HEIGHT / 480
	return { u = u, W = 214 * u, RH = 10.6 * u, lip = 15 * u, pad = 5 * u, z = 0.3, zs = 0.25, zt = 0.38, btn = 14 * u }
end
local MAXROWS = 46

-- Til Death's parts: its Movable table, picked as its letter keys pick them
local PART_NAMES = {
	Judge = "Judgment", Combo = "Combo", ErrorBar = "Error bar", TargetTracker = "Goal tracker",
	FullProgressBar = "Full progress bar", MiniProgressBar = "Mini progress bar", DisplayPercent = "Current percent",
	DisplayMean = "Current mean", NPSDisplay = "NPS display", NPSGraph = "NPS graph", JudgeCounter = "Judge counter",
	Leaderboard = "Leaderboard", ReplayButtons = "Replay buttons", LifeP1 = "Life bar", BPMText = "BPM",
	MusicRate = "Rate", PracticeCDGraph = "Density graph",
}
local PART_ORDER = { "Judge", "Combo", "ErrorBar", "TargetTracker", "DisplayPercent", "DisplayMean", "JudgeCounter",
	"FullProgressBar", "MiniProgressBar", "LifeP1", "NPSDisplay", "NPSGraph", "Leaderboard", "BPMText", "MusicRate",
	"ReplayButtons", "PracticeCDGraph" }
local function tdOK() return isTD() and Movable ~= nil and MovableInput ~= nil and MovableValues ~= nil end
-- While the mouse is over the panel, Til Death's "current" part is a stand-in (TWPanel, which has
-- nothing to move): Til Death moves the picked part to the mouse while its button is held, and
-- whatever is under a held button when nothing is picked. The real one is kept in "saved".
local blocking, saved = false, "None"
local function curPick() if blocking then return saved end return Movable and Movable.current end
local function block(on)
	if not tdOK() then return end
	Movable.TWPanel = Movable.TWPanel or {}
	-- (a right click let go of the part meanwhile)
	if blocking and Movable.current ~= "TWPanel" then blocking = false end
	if on and not blocking then
		saved, blocking = Movable.current, true
		Movable.current = "TWPanel"
	elseif not on and blocking then
		blocking = false
		if Movable.current == "TWPanel" then Movable.current = saved end
	end
end
-- Til Death's input as its keys would give it (with the real picked part in place)
local function tdFake(button)
	local was = blocking
	block(false)
	pcall(MovableInput, { DeviceInput = { button = button, is_mouse = false }, type = "InputEventType_FirstPress" })
	if was then block(true) end
end
-- one step of a Til Death setting, as its key and an arrow would do it (the picked part stays picked)
local function tdStep(sel, dir)
	if not (tdOK() and Movable[sel] and Movable[sel].condition) then return end
	local was = blocking
	block(false)
	local pc, pp = Movable.current, Movable.pressed
	Movable.current, Movable.pressed = sel, true
	pcall(MovableInput, { DeviceInput = { button = dir, is_mouse = false }, type = "InputEventType_FirstPress" })
	Movable.current, Movable.pressed = pc, pp
	if was then block(true) end
end
local function reverse()
	local ok, r = pcall(function() return GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():UsingReverse() end)
	return ok and r
end
local function tdVal(name) return MovableValues and tonumber(MovableValues[name]) or 0 end

local rows = {}  -- {kind, label, get, dec, inc, fmt} / {kind="head", label} / {kind="part", name, keys}
local buttons = {} -- {x0, y0, x1, y1, fn}
local frame, shown, collapsed = nil, false, false
local pos = nil -- the panel's top left (dragged with its title bar)
local drag = nil
local fpsText, fpsBox, fpsDrag = nil, { 0, 0, 0, 0 }, nil -- the FPS counter (dragged too, while customizing)
local partsFirst, partsRows = 1, 0

local function fix(field, v)
	v = math.floor(v * 100 + 0.5) / 100
	if field == "z" or field == "w" or field == "h" then v = math.max(0.2, math.min(4, v)) end
	return v
end
local function noteRows(list)
	local function nr(label, item, field, fmt, step)
		list[#list + 1] = { kind = "value", label = label, fmt = fmt,
			get = function() return TWL.lv(item, field) end,
			dec = function() TWL.setLv(item, field, fix(field, TWL.lv(item, field) - step)) end,
			inc = function() TWL.setLv(item, field, fix(field, TWL.lv(item, field) + step)) end }
	end
	if tdOK() then list[#list + 1] = { kind = "head", label = "Notes (VSRG Hub noteskins, kept per noteskin)" } end
	nr("Note spacing", "columns", "n", "%+dpx", 1)
	nr("Note size", "notes", "z", "%.2fx", 0.05)
	nr("Note width", "notes", "w", "%.2fx", 0.05)
	nr("Note height", "notes", "h", "%.2fx", 0.05)
	nr("Receptor offset", "receptors", "y", "%+dpx", 2)
	nr("Receptor size", "receptors", "z", "%.2fx", 0.05)
	nr("Receptor width", "receptors", "w", "%.2fx", 0.05)
	nr("Receptor height", "receptors", "h", "%.2fx", 0.05)
	nr("Stage hint offset", "hint", "y", "%+dpx", 2)
	nr("Stage hint height", "hint", "h", "%.2fx", 0.05)
	nr("LN tail height", "lntail", "h", "%.2fx", 0.05)
	nr("LN tail offset", "lntail", "y", "%+dpx", 2)
	-- the receptors over the notes or under them (as the skin has them, by default)
	local ORDER = { [0] = "As the skin", [1] = "Under the notes", [2] = "Over the notes" }
	local function order() return math.floor(TWL.lv("receptors", "o") + 0.5) % 3 end
	list[#list + 1] = { kind = "value", label = "Receptors", text = function() return ORDER[order()] end,
		dec = function() TWL.setLv("receptors", "o", (order() + 2) % 3) end,
		inc = function() TWL.setLv("receptors", "o", (order() + 1) % 3) end }
end
-- the skin's lighting (as in the osu! and Quaver looks): hit lighting (osu!'s LightingN), hold
-- lighting (LightingL) and column lighting, each on or off, moved and sized (and its width and height)
local LIGHTS = {
	{ "lighting", "Hit lighting (LightingN)" }, { "holdlight", "Hold lighting (LightingL)" }, { "collight", "Column lighting" },
}
local function lightRows(list)
	for _, l in ipairs(LIGHTS) do
		local item = l[1]
		list[#list + 1] = { kind = "head", label = l[2] }
		list[#list + 1] = { kind = "value", label = "Show", text = function() return TWL.lv(item, "on") ~= 0 and "On" or "Off" end,
			dec = function() TWL.setLv(item, "on", TWL.lv(item, "on") ~= 0 and 0 or 1) end,
			inc = function() TWL.setLv(item, "on", TWL.lv(item, "on") ~= 0 and 0 or 1) end }
		local function nr(label, field, fmt, step)
			list[#list + 1] = { kind = "value", label = label, fmt = fmt,
				get = function() return TWL.lv(item, field) end,
				dec = function() TWL.setLv(item, field, fix(field, TWL.lv(item, field) - step)) end,
				inc = function() TWL.setLv(item, field, fix(field, TWL.lv(item, field) + step)) end }
		end
		nr("Offset X", "x", "%+dpx", 2)
		nr("Offset Y", "y", "%+dpx", 2)
		nr("Size", "z", "%.2fx", 0.05)
		nr("Width", "w", "%.2fx", 0.05)
		nr("Height", "h", "%.2fx", 0.05)
	end
end
-- VSRG Hub's lane cover in these themes (as the osu! and Quaver looks have one): per key mode,
-- off / sudden (the far end of the lanes) / hidden (the end by the receptors), its height, opacity
-- and colour. While it is on, the theme's own lane cover is hidden.
local COVER_COLOURS = {
	{ "Black", "#000000" }, { "Dark grey", "#1E1E1E" }, { "Grey", "#555555" }, { "White", "#FFFFFF" },
	{ "Purple", "#6A3FB5" }, { "Blue", "#2F5BD3" }, { "Cyan", "#2BB5D1" }, { "Green", "#3DBE5A" },
	{ "Yellow", "#E7C83B" }, { "Orange", "#E8832E" }, { "Red", "#D63B3B" }, { "Pink", "#E05FA8" },
}
local COVER_MODES = { [0] = "Off", [1] = "Sudden (far end)", [2] = "Hidden (by receptors)" }
local function cv(field, default)
	local v = data[key("tdcover", field)]
	if v == nil then return default end
	return tonumber(v) or default
end
local function setCv(field, v)
	data[key("tdcover", field)] = v
	saveData()
end
local function coverMode() return math.floor(cv("m", 0)) % 3 end
local function coverHeight() return math.max(0, math.min(SCREEN_HEIGHT, cv("h", 120))) end
local function coverAlpha() return math.max(0, math.min(1, cv("a", 1))) end
local function coverColour()
	local i = math.floor(cv("c", 1))
	if i < 1 or i > #COVER_COLOURS then i = 1 end
	return i
end
local BORDERS = { [0] = "None", [1] = "Line", [2] = "Fade", [3] = "Glow" }
local function coverBorder() return math.floor(cv("b", 0)) % 4 end
local function borderHeight() return math.max(1, math.min(24, cv("bh", 2))) end
local function borderColour()
	local i = math.floor(cv("bc", 1))
	if i < 1 or i > #COVER_COLOURS then i = 1 end
	return i
end
local function coverRows(list, head)
	if head then list[#list + 1] = { kind = "head", label = "Lane cover (VSRG Hub's, per key mode)" } end
	list[#list + 1] = { kind = "value", label = "Lane cover", text = function() return COVER_MODES[coverMode()] end,
		dec = function() setCv("m", (coverMode() + 2) % 3) end, inc = function() setCv("m", (coverMode() + 1) % 3) end }
	list[#list + 1] = { kind = "value", label = "Lane cover height", fmt = "%dpx", get = coverHeight,
		dec = function() setCv("h", math.max(0, coverHeight() - 5)) end,
		inc = function() setCv("h", math.min(SCREEN_HEIGHT, coverHeight() + 5)) end }
	list[#list + 1] = { kind = "value", label = "Lane cover opacity", fmt = "%.2f", get = coverAlpha,
		dec = function() setCv("a", math.floor(math.max(0, coverAlpha() - 0.05) * 100 + 0.5) / 100) end,
		inc = function() setCv("a", math.floor(math.min(1, coverAlpha() + 0.05) * 100 + 0.5) / 100) end }
	list[#list + 1] = { kind = "value", label = "Lane cover colour", text = function() return COVER_COLOURS[coverColour()][1] end,
		swatch = function() return COVER_COLOURS[coverColour()][2] end,
		dec = function() setCv("c", (coverColour() - 2) % #COVER_COLOURS + 1) end,
		inc = function() setCv("c", coverColour() % #COVER_COLOURS + 1) end }
	-- its border, on the edge the notes cross: none, a line, a fade (soft into the lanes) or a glow
	list[#list + 1] = { kind = "value", label = "Border", text = function() return BORDERS[coverBorder()] end,
		dec = function() setCv("b", (coverBorder() + 3) % 4) end, inc = function() setCv("b", (coverBorder() + 1) % 4) end }
	do
		list[#list + 1] = { kind = "value", label = "Border height", fmt = "%dpx", get = borderHeight,
			dec = function() setCv("bh", math.max(1, borderHeight() - 1)) end,
			inc = function() setCv("bh", math.min(24, borderHeight() + 1)) end }
		list[#list + 1] = { kind = "value", label = "Border colour", text = function() return COVER_COLOURS[borderColour()][1] end,
			swatch = function() return COVER_COLOURS[borderColour()][2] end,
			dec = function() setCv("bc", (borderColour() - 2) % #COVER_COLOURS + 1) end,
			inc = function() setCv("bc", borderColour() % #COVER_COLOURS + 1) end }
	end
end
-- the panel shows one page at a time: the notes, the skin's lighting, the lane cover, the HUD
local page = "notes"
local PAGES = { { "notes", "Noteskin" }, { "light", "Lighting" }, { "cover", "Lane cover" }, { "hud", "HUD" } }

-- the FPS counter in play (when Etterna's Show stats option is on): VSRG Hub's, moved, sized or
-- switched off here, with its lines picked (FPS, average FPS, vertices per frame, renderer), while
-- Etterna's own in the corner steps aside. Kept per key mode.
local FPS_LINES = { { "f1", "FPS" }, { "f2", "Average FPS" }, { "f3", "Vertices per frame" }, { "f4", "Renderer" } }
local FPS_DEFAULTS = { on = 1, x = 0, y = 0, z = 1, f1 = 1, f2 = 1, f3 = 1, f4 = 1 }
local function fpsv(field)
	local v = data[key("fps", field)]
	if v == nil then return FPS_DEFAULTS[field] or 0 end
	return tonumber(v) or 0
end
local function setFps(field, v)
	data[key("fps", field)] = v
	saveData()
end
local function statsOn()
	local ok, v = pcall(function() return PREFSMAN:GetPreference("ShowStats") end)
	return ok and v == true
end
local function fpsRows(list)
	list[#list + 1] = { kind = "head", label = statsOn() and "FPS counter" or "FPS counter (shown when Options > Show stats is on)" }
	local function toggle(label, field, onText, offText)
		list[#list + 1] = { kind = "value", label = label, text = function() return fpsv(field) ~= 0 and onText or offText end,
			dec = function() setFps(field, fpsv(field) ~= 0 and 0 or 1) end,
			inc = function() setFps(field, fpsv(field) ~= 0 and 0 or 1) end }
	end
	toggle("FPS counter", "on", "VSRG Hub's", "Etterna's")
	local function nr(label, field, fmt, step, lo, hi)
		list[#list + 1] = { kind = "value", label = label, fmt = fmt, get = function() return fpsv(field) end,
			dec = function() setFps(field, math.max(lo, math.floor((fpsv(field) - step) * 100 + 0.5) / 100)) end,
			inc = function() setFps(field, math.min(hi, math.floor((fpsv(field) + step) * 100 + 0.5) / 100)) end }
	end
	nr("Offset X", "x", "%+dpx", 4, -SCREEN_WIDTH, SCREEN_WIDTH)
	nr("Offset Y", "y", "%+dpx", 4, -SCREEN_HEIGHT, SCREEN_HEIGHT)
	nr("Size", "z", "%.2fx", 0.05, 0.3, 4)
	for _, l in ipairs(FPS_LINES) do toggle(l[2], l[1], "Shown", "Hidden") end
end

local function buildRows()
	rows = {}
	rows[#rows + 1] = { kind = "tabs" }
	if page == "light" then lightRows(rows) return end
	if page == "cover" then coverRows(rows, false) return end
	if page == "hud" then
		fpsRows(rows)
		if isRebirth() then return end
	end
	if isRebirth() then noteRows(rows) return end
	if tdOK() and page == "notes" then
		rows[#rows + 1] = { kind = "head", label = "Notefield" }
		local function tr(label, sel, valName, fmt, minusKey, plusKey)
			rows[#rows + 1] = { kind = "value", label = label, fmt = fmt, get = function() return tdVal(valName) end,
				dec = function() tdStep(sel, type(minusKey) == "function" and minusKey() or minusKey) end,
				inc = function() tdStep(sel, type(plusKey) == "function" and plusKey() or plusKey) end }
		end
		tr("Notefield X", "DeviceButton_r", "NotefieldX", "%dpx", "DeviceButton_left", "DeviceButton_right")
		-- (Til Death's notefield Y grows upwards in upscroll and downwards in reverse)
		tr("Hit position", "DeviceButton_r", "NotefieldY", "%dpx",
			function() return reverse() and "DeviceButton_up" or "DeviceButton_down" end,
			function() return reverse() and "DeviceButton_down" or "DeviceButton_up" end)
		tr("Notefield width", "DeviceButton_t", "NotefieldWidth", "%.2fx", "DeviceButton_left", "DeviceButton_right")
		tr("Notefield height", "DeviceButton_t", "NotefieldHeight", "%.2fx", "DeviceButton_down", "DeviceButton_up")
		tr("Column spacing", "DeviceButton_n", "NotefieldSpacing", "%+dpx", "DeviceButton_down", "DeviceButton_up")
	end
	if page == "notes" then noteRows(rows) return end
	if tdOK() then
		rows[#rows + 1] = { kind = "head", label = "Parts (click one, then drag it or use the arrows)" }
		local groups = {}
		for k, v in pairs(Movable) do
			if type(k) == "string" and k:find("^DeviceButton_") and type(v) == "table" and v.name and v.properties
				and v.condition and v.name ~= "Notefield" and v.external == nil then
				groups[v.name] = groups[v.name] or {}
				local p = v.properties[1]
				local kind = (p == "X" or p == "Y") and "Move" or (p == "Rotation" and "Turn") or (p == "Spacing" and "Spacing") or "Size"
				table.insert(groups[v.name], { key = k, kind = kind })
			end
		end
		local order = {}
		for _, n in ipairs(PART_ORDER) do if groups[n] then order[#order + 1] = n end end
		for n in pairs(groups) do
			local known = false
			for _, m in ipairs(order) do if m == n then known = true end end
			if not known then order[#order + 1] = n end
		end
		local rank = { Move = 1, Size = 2, Spacing = 3, Turn = 4 }
		for _, n in ipairs(order) do
			table.sort(groups[n], function(a, b) return rank[a.kind] < rank[b.kind] end)
			rows[#rows + 1] = { kind = "part", name = n, label = PART_NAMES[n] or n, keys = groups[n] }
		end
	end
end

local function pickedText()
	local cur = curPick()
	if not tdOK() or not Movable.pressed or not cur or not Movable[cur] or not Movable[cur].name then return "Nothing picked" end
	local m = Movable[cur]
	local out = {}
	for _, p in ipairs(m.properties or {}) do
		local v = tonumber(MovableValues[m.name .. p])
		if v then out[#out + 1] = string.format(v % 1 == 0 and "%s %d" or "%s %.2f", p, v) end
	end
	return (PART_NAMES[m.name] or m.name) .. ": " .. table.concat(out, "  ")
end

local function refresh() if frame and shown then frame:playcommand("Draw") end end

local function geometry()
	local l = L()
	if not pos then
		-- (below Etterna's frame rate display, when it is on: it sits in the top right corner)
		local stats = false
		pcall(function() stats = PREFSMAN:GetPreference("ShowStats") == true end)
		-- (Rebirth: in the free space at the top left, under the life bar and above its judge counter)
		if isRebirth() then pos = { 8 * l.u, 26 * l.u }
		else pos = { SCREEN_WIDTH - l.W - 2 * l.pad - 4 * l.u, (stats and 72 or 4) * l.u } end
	end
	return l, pos[1], pos[2]
end

local function inside(x, y, b) return x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] end
local panelBox = { 0, 0, 0, 0 }
local titleBox = { 0, 0, 0, 0 }

local function onMouse(button, kind)
	local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
	if button == "DeviceButton_left mouse button" then
		if kind == "InputEventType_FirstPress" then
			if inside(mx, my, titleBox) then drag = { mx, my, pos[1], pos[2], moved = false } return true end
			for _, b in ipairs(buttons) do
				if inside(mx, my, b) then b[5](); refresh() return true end
			end
			if inside(mx, my, panelBox) then return true end
			if fpsText and fpsText:GetVisible() and inside(mx, my, fpsBox) then
				fpsDrag = { mx, my, fpsv("x"), fpsv("y") }
				return true
			end
			return false
		elseif kind == "InputEventType_Release" and fpsDrag then
			fpsDrag = nil
			saveData()
			return true
		elseif kind == "InputEventType_Release" and drag then
			if not drag.moved then collapsed = not collapsed; refresh() end
			drag = nil
			return true
		end
	elseif (button == "DeviceButton_mousewheel up" or button == "DeviceButton_mousewheel down") and inside(mx, my, panelBox) then
		-- over a value: change it; over the parts: scroll them
		local up = button == "DeviceButton_mousewheel up"
		for _, b in ipairs(buttons) do
			if b.row and my >= b[2] and my <= b[4] and mx >= panelBox[1] and mx <= panelBox[3] then
				if b.row.kind == "value" then (up and b.row.inc or b.row.dec)(); refresh() return true end
			end
		end
		partsFirst = math.max(1, partsFirst + (up and -1 or 1))
		refresh()
		return true
	end
	return false
end

-- the lane cover on the screen: across the stage, from the top or the bottom of the screen
local coverQuad, playerActor, nfActor = nil, nil, nil
local coverEdge, coverGlow = nil, nil
local themeCover = nil -- the theme's own lane cover parts (hidden while VSRG Hub's is on)
local function findAll(actor, names, out, depth)
	if not actor or depth > 7 then return end
	local ok, kids = pcall(function() return actor:GetChildren() end)
	if not ok or type(kids) ~= "table" then return end
	for name, kid in pairs(kids) do
		if names[name] then out[#out + 1] = kid end
		if type(kid) == "table" and kid.GetChildren == nil then
			for _, k in ipairs(kid) do findAll(k, names, out, depth + 1) end
		else
			findAll(kid, names, out, depth + 1)
		end
	end
end
local function themeCoverParts(top)
	if themeCover then return themeCover end
	themeCover = {}
	if isRebirth() then
		local c = nfActor and nfActor:GetChild("Cover")
		if c then themeCover[1] = c end
	else
		findAll(top, { CoverP1 = true, CoverTextP1White = true, CoverTextP1Green = true }, themeCover, 0)
	end
	return themeCover
end
local function updateCover(top)
	if not coverQuad then return end
	local m = coverMode()
	local on = m ~= 0 and nfActor ~= nil and playerActor ~= nil
	for _, a in ipairs(themeCoverParts(top)) do pcall(function() a:visible(not on) end) end
	if not on then
		coverQuad:visible(false)
		if coverEdge then coverEdge:visible(false); coverGlow:visible(false) end
		return
	end
	local st = TWL.stage
	local mini = 0
	pcall(function() mini = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():Mini() end)
	-- (Rebirth zooms the whole player by SCREEN_HEIGHT/480)
	local zoom = (1 - mini * 0.5) * (nfActor:GetZoomX() or 1) * (playerActor:GetZoomX() or 1)
	local cx = playerActor:GetX() + (nfActor:GetX() + (st and st.hintCX or 0)) * zoom
	local w = ((st and st.stageW) or 64 * (cols and #cols or 4)) * zoom + 8
	local fromTop = (m == 1) == (reverse() and true or false)
	coverQuad:visible(true):x(cx):zoomto(w, coverHeight())
		:diffuse(color(COVER_COLOURS[coverColour()][2])):diffusealpha(coverAlpha())
	if fromTop then coverQuad:valign(0):y(0) else coverQuad:valign(1):y(SCREEN_HEIGHT) end
	-- the border on the edge the notes cross
	if not coverEdge then return end
	local h = coverHeight()
	local b = coverBorder()
	local col = color(COVER_COLOURS[borderColour()][2])
	local bh = borderHeight()
	local clear = { col[1], col[2], col[3], 0 }
	local edgeY = fromTop and h or SCREEN_HEIGHT - h
	local a = coverAlpha()
	coverEdge:visible(h > 0 and b > 0):x(cx):zoomx(w):diffuse(col):diffusealpha(a)
	coverGlow:visible(h > 0 and b == 3)
	if b == 1 then
		coverEdge:valign(0.5):y(edgeY):zoomy(bh)
	elseif b == 2 then
		coverEdge:valign(fromTop and 0 or 1):y(edgeY):zoomy(bh * 4)
		if fromTop then coverEdge:diffusebottomedge(clear) else coverEdge:diffusetopedge(clear) end
	elseif b == 3 then
		coverEdge:valign(fromTop and 0 or 1):y(edgeY):zoomy(bh * 3)
		if fromTop then coverEdge:diffusebottomedge(clear) else coverEdge:diffusetopedge(clear) end
		coverGlow:x(cx):zoomx(w):valign(fromTop and 1 or 0):y(edgeY):zoomy(bh * 3):diffuse(col):diffusealpha(a)
		if fromTop then coverGlow:diffusetopedge(clear) else coverGlow:diffusebottomedge(clear) end
	end
end

-- the FPS counter's actor (in play) and Etterna's own, which steps aside while it is there
local function statsOverlay()
	local found = nil
	pcall(function()
		for _, sc in ipairs(SCREENMAN:GetOverlayScreens()) do
			if sc:GetName() == "ScreenStatsOverlay" then found = sc end
		end
	end)
	return found
end
local etternaHidden = false
local function etternaStats(show)
	if show == not etternaHidden then return end
	local sc = statsOverlay()
	if sc then pcall(function() sc:zoom(show and 1 or 0) end) end
	etternaHidden = not show
end
local function fpsRenderer()
	local r = ""
	pcall(function() r = statsOverlay():GetChild("Stats"):GetText() or "" end)
	local last = r:match("([^\n]+)$") or ""
	if last ~= "" and not last:find("%d") then return last end
	local pref = ""
	pcall(function() pref = PREFSMAN:GetPreference("VideoRenderers") or "" end)
	return ((pref:match("^%s*([^,]+)") or ""):lower():find("opengl")) and "OGL" or "D3D"
end
local function fpsActor()
	return Def.ActorFrame {
		InitCommand = function(self)
			self:SetUpdateFunction(function(frame)
				local s = fpsText
				if not s then return end
				local on = not ownLook() and inPlay(SCREENMAN:GetTopScreen()) and statsOn() and fpsv("on") ~= 0
				s:visible(on)
				etternaStats(not on)
				if not on then return end
				local vals = {
					f1 = function() return string.format("%d FPS", DISPLAY:GetFPS()) end,
					f2 = function() return string.format("%d av FPS", DISPLAY:GetCumFPS()) end,
					f3 = function() return string.format("%d VPF", DISPLAY:GetVPF()) end,
					f4 = fpsRenderer,
				}
				local lines = {}
				for _, l in ipairs(FPS_LINES) do
					if fpsv(l[1]) ~= 0 then
						local ok, v = pcall(vals[l[1]])
						if ok then lines[#lines + 1] = v end
					end
				end
				-- (where Etterna has its own: the top right corner)
				local z = 0.5 * math.max(0.3, fpsv("z"))
				s:xy(SCREEN_WIDTH - 8 + fpsv("x"), 10 + fpsv("y")):zoom(z):settext(table.concat(lines, "\n"))
				local w, h = s:GetZoomedWidth(), s:GetZoomedHeight()
				fpsBox = { s:GetX() - w - 4, s:GetY() - 4, s:GetX() + 4, s:GetY() + h + 4 }
			end)
			self:SetUpdateFunctionInterval(0.1)
		end,
		LoadFont("Common Normal") .. {
			Name = "TWFps",
			InitCommand = function(self)
				fpsText = self
				self:visible(false):align(1, 0):shadowlength(1)
			end,
		},
	}
end

-- The combo in any skin's digits (VSRG Hub's menu > Combo skin, as the osu! and Quaver looks have
-- it): the theme's own combo steps aside and the digits are drawn where its number is, as big, with
-- its number (so Til Death's and Rebirth's own settings, place and size still apply).
-- TWCombo also gives the menu its choices and preview pictures.
TWCombo = TWCombo or {}
local SETTINGS = "Save/VSRGHub/settings.ini"
local function setting(k)
	local ok, txt = pcall(function() return File.Read(SETTINGS) end)
	txt = ok and type(txt) == "string" and txt or ""
	return txt:match("\n" .. k .. "=([^\r\n]*)") or txt:match("^" .. k .. "=([^\r\n]*)") or ""
end
local function skinData()
	if not TW_SKINS then pcall(dofile, "/Themes/VSRG Hub osu!/Scripts/00 VSRG Hub skin.lua") end
end
local function pretty(n)
	if n:find("^quaver_") then return "Quaver " .. n:sub(8):gsub("_", " ") end
	return n
end
local function qvInfo(n)
	n = n:lower()
	local info = TW_NOTESKINS and TW_NOTESKINS[n]
	if not (info and info.qv) and TW_NOTESKINS_GAME then
		for _, g in pairs(TW_NOTESKINS_GAME) do if g[n] and g[n].qv then info = g[n] end end
	end
	return info
end
function TWCombo.items()
	skinData()
	local items = { { label = "The theme's own", value = "", sub = "Til Death's or Rebirth's combo, as before" } }
	local folders = {}
	for f, e in pairs(TW_SKINS or {}) do if e.files and e.files.combo_0 then folders[#folders + 1] = f end end
	table.sort(folders, function(a, b) return (TW_SKINS[a].name or a):lower() < (TW_SKINS[b].name or b):lower() end)
	for _, f in ipairs(folders) do items[#items + 1] = { label = TW_SKINS[f].name or f, value = "osu:" .. f, sub = "osu! skin" } end
	local seen, qv = {}, {}
	local function add(name, info) if info and info.qv and info.qv.combo and not seen[name] then seen[name] = true; qv[#qv + 1] = name end end
	for name, info in pairs(TW_NOTESKINS or {}) do add(name, info) end
	for _, g in pairs(TW_NOTESKINS_GAME or {}) do for name, info in pairs(g) do add(name, info) end end
	table.sort(qv)
	for _, n in ipairs(qv) do items[#items + 1] = { label = pretty(n), value = "qv:" .. n, sub = "Quaver skin" } end
	return items
end
function TWCombo.current() return setting("combo_skin") end
function TWCombo.label()
	local v = TWCombo.current()
	for _, it in ipairs(TWCombo.items()) do if it.value == v then return it.label end end
	return "The theme's own"
end
-- a choice's digits: { [0..9] = path, zoom (to osu!'s size), overlap } or nil (the theme's own)
function TWCombo.pics(v)
	skinData()
	local out = {}
	local f = v:match("^osu:(.*)$")
	if f then
		local e = TW_SKINS and TW_SKINS[f]
		if not (e and e.files and e.files.combo_0) then return nil end
		for i = 0, 9 do out[i] = e.files["combo_" .. i] and (e.dir .. e.files["combo_" .. i]) or nil end
		out.zoom = (e.hd and e.hd.combo_0) and 0.5 or 1
		out.overlap = e.comboOverlap or 0
		return out
	end
	local n = v:match("^qv:(.*)$")
	local info = n and qvInfo(n)
	if not (info and info.qv and info.qv.combo) then return nil end
	for i = 0, 9 do out[i] = info.qv.combo[i] end
	out.zoom, out.overlap = 1, 0
	return out
end

local comboFrame, comboPics, themeCombo, themeNumber = nil, nil, nil, nil
local COMBO_MAX = 7
local function comboSetup(top)
	comboPics, themeCombo, themeNumber = nil, nil, nil
	if not comboFrame then return end
	comboFrame:visible(false)
	-- (the combo skin is the osu! and Quaver looks' only: Til' Death and Rebirth keep their own combo)
	if true then return end
	comboPics = TWCombo.pics(TWCombo.current())
	if not comboPics then return end
	pcall(function()
		themeCombo = top:GetChild("PlayerP1"):GetChild("Combo")
		themeNumber = themeCombo and themeCombo:GetChild("Number")
	end)
	if not themeNumber then comboPics = nil return end
	-- the theme's combo draws only the border Til' Death puts round it while customizing, never its
	-- number or label (hiding them instead would let them flash on each note, as the theme shows
	-- them again with every combo)
	pcall(function()
		themeCombo:SetDrawFunction(function(f)
			local b = f:GetChild("Border")
			if b then b:Draw() end
		end)
	end)
	local c = comboFrame:GetChildren()
	for i = 0, 9 do
		local h = c["H" .. i]
		if comboPics[i] then pcall(function() h:Load(comboPics[i]) end) end
	end
	comboFrame.last = nil
	local rc = c.Row:GetChildren()
	for i = 1, COMBO_MAX do rc["C" .. i].glyph = nil end
end
local function comboUpdate()
	if not comboPics or not themeNumber then return end
	-- (the theme's own number and label aren't drawn (comboSetup): the number still says where and
	-- how big)
	local editing = customizing()
	local combo, showAt = 0, 1
	pcall(function() combo = STATSMAN:GetCurStageStats():GetPlayerStageStats():GetCurrentCombo() end)
	pcall(function() showAt = tonumber(THEME:GetMetric("Combo", "ShowComboAt")) or 1 end)
	local text = combo >= math.max(1, showAt) and tostring(combo) or (editing and "1000" or "")
	local f = comboFrame
	if text == "" then f:visible(false) return end
	f:visible(true)
	local c = f:GetChildren()
	local row = c.Row
	local rc = row:GetChildren()
	if text ~= f.last then
		local x, h = 0, 1
		for i = 1, COMBO_MAX do
			local s = rc["C" .. i]
			local d = tonumber(text:sub(i, i))
			if d and comboPics[d] then
				-- (loaded by path: the textures are kept loaded by the holders, so this is quick)
				if s.glyph ~= d then pcall(function() s:Load(comboPics[d]) end); s.glyph = d end
				local tw, th = 1, 1
				pcall(function() tw, th = s:GetTexture():GetSourceWidth(), s:GetTexture():GetSourceHeight() end)
				s:visible(true):zoomto(tw * comboPics.zoom, th * comboPics.zoom):x(x)
				x = x + tw * comboPics.zoom - comboPics.overlap
				h = math.max(h, th * comboPics.zoom)
			else
				s:visible(false)
			end
		end
		row.w, row.h = math.max(1, x + comboPics.overlap), h
		local grew = f.last and tonumber(text) and tonumber(f.last) and tonumber(text) > tonumber(f.last)
		f.last = text
		if grew then row:stoptweening():zoomy(1.12):linear(0.05):zoomy(1) end
	end
	-- as tall as the theme's number, where it is, aligned as it is
	local tz = 1
	pcall(function()
		local a = themeNumber
		tz = 1
		while a do tz = tz * a:GetZoomY(); a = a:GetParent() end
	end)
	local nh = 0
	pcall(function() nh = themeNumber:GetHeight() * tz end)
	if nh <= 0 then nh = 30 * SCREEN_HEIGHT / 480 end
	local z = nh * 1.15 / row.h
	local ha, va = 1, 1
	pcall(function() ha = themeNumber:GetHAlign() end)
	pcall(function() va = themeNumber:GetVAlign() end)
	f:xy(themeNumber:GetTrueX(), themeNumber:GetTrueY()):zoom(z)
	row:x(-row.w * ha):y(-row.h * (va - 0.5))
end
local function comboActor()
	local row = Def.ActorFrame { Name = "Row" }
	for i = 1, COMBO_MAX do row[#row + 1] = Def.Sprite { Name = "C" .. i, InitCommand = function(self) self:align(0, 0.5):visible(false) end } end
	local f = Def.ActorFrame {
		Name = "TWCombo",
		InitCommand = function(self) comboFrame = self; self:visible(false) end,
		row,
	}
	for i = 0, 9 do f[#f + 1] = Def.Sprite { Name = "H" .. i, InitCommand = function(self) self:visible(false) end } end
	return f
end

local hooked = nil
local function input(event)
	if not shown then return false end
	local b = event.DeviceInput and event.DeviceInput.button or ""
	if b:find("mouse") then return onMouse(b, event.type) end
	return false
end

-- one row's actors (drawn by Draw)
local function rowActor(i)
	return Def.ActorFrame {
		Name = "R" .. i,
		Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0) end },
		LoadFont("Common Normal") .. { Name = "Label", InitCommand = function(self) self:align(0, 0.5) end },
		LoadFont("Common Normal") .. { Name = "Value", InitCommand = function(self) self:align(1, 0.5) end },
		Def.Quad { Name = "B1", InitCommand = function(self) self:align(0, 0) end },
		Def.Quad { Name = "B2", InitCommand = function(self) self:align(0, 0) end },
		Def.Quad { Name = "B3", InitCommand = function(self) self:align(0, 0) end },
		Def.Quad { Name = "B4", InitCommand = function(self) self:align(0, 0) end },
		LoadFont("Common Normal") .. { Name = "T1", InitCommand = function(self) self:align(0.5, 0.5) end },
		LoadFont("Common Normal") .. { Name = "T2", InitCommand = function(self) self:align(0.5, 0.5) end },
		LoadFont("Common Normal") .. { Name = "T3", InitCommand = function(self) self:align(0.5, 0.5) end },
		LoadFont("Common Normal") .. { Name = "T4", InitCommand = function(self) self:align(0.5, 0.5) end },
	}
end

local t = Def.ActorFrame {
	InitCommand = function(self) frame = self; self:visible(false) end,
	ScreenChangedMessageCommand = function(self)
		local top = SCREENMAN:GetTopScreen()
		cols, applied, lastKey, TWL.stage = nil, false, nil, nil
		playerActor, nfActor, themeCover = nil, nil, nil
		if coverQuad then coverQuad:visible(false) end
		if coverEdge then coverEdge:visible(false); coverGlow:visible(false) end
		if comboFrame then comboFrame:visible(false) end
		comboPics = nil
		shown, drag, fpsDrag = false, nil, nil
		if blocking and Movable and Movable.current == "TWPanel" then Movable.current = "None" end
		blocking, saved = false, "None"
		self:visible(false)
		if ownLook() or not inPlay(top) then self:SetUpdateFunction(nil) return end
		loadData()
		pcall(function()
			playerActor = top:GetChild("PlayerP1")
			nfActor = top:GetDescendant("PlayerP1", "NoteField")
			cols = nfActor:get_column_actors()
		end)
		updateStage(true)
		comboSetup(top)
		local want = customizing()
		self:SetUpdateFunction(function(s)
			updateStage(false)
			updateCover(SCREENMAN:GetTopScreen())
			comboUpdate()
			if shown then s:playcommand("Tick") end
		end)
		if want then
			if hooked ~= top then pcall(function() top:AddInputCallback(input) end); hooked = top end
			-- (Til Death fills its parts in when the play starts)
			self:sleep(0.4):queuecommand("Open")
		end
	end,
	TWLayoutChangedMessageCommand = function(self) updateStage(true); refresh() end,
	OpenCommand = function(self)
		if not inPlay(SCREENMAN:GetTopScreen()) then return end
		buildRows()
		partsFirst = 1
		shown = true
		self:visible(true)
		-- Til Death's own key list and its picked-part text are replaced by this panel
		if tdOK() and Movable.message then
			pcall(function()
				local p = Movable.message:GetParent()
				local ins = p and p:GetChild("Instructions")
				if ins then ins:visible(false) end
			end)
		end
		refresh()
	end,
	TickCommand = function(self)
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
		if fpsDrag then
			data[key("fps", "x")] = math.floor(fpsDrag[3] + mx - fpsDrag[1] + 0.5)
			data[key("fps", "y")] = math.floor(fpsDrag[4] + my - fpsDrag[2] + 0.5)
		end
		if drag then
			local dx, dy = mx - drag[1], my - drag[2]
			if math.abs(dx) + math.abs(dy) > 3 then drag.moved = true end
			if drag.moved then
				local l = L()
				pos[1] = math.max(0, math.min(SCREEN_WIDTH - 40 * l.u, drag[3] + dx))
				pos[2] = math.max(0, math.min(SCREEN_HEIGHT - 20 * l.u, drag[4] + dy))
				refresh()
			end
		end
		if tdOK() then
			if Movable.message then Movable.message:visible(false) end
			-- the mouse over the panel mustn't grab the part under it (Til Death moves whatever is under
			-- a held mouse button when nothing is picked)
			block((inside(mx, my, panelBox) and not drag) or fpsDrag ~= nil)
		end
		self.tick = (self.tick or 0) + 1
		-- (Til Death turns its parts on as they load: the list follows)
		if self.tick % 60 == 0 then buildRows() end
		if self.tick % 6 == 0 then refresh() end
	end,
	DrawCommand = function(self)
		local l, x0, y0 = geometry()
		local rb = isRebirth()
		local c = self:GetChildren()
		local W, RH, pad = l.W, l.RH, l.pad
		buttons = {}
		local textCol = rb and C("text") or color("#FFFFFF")
		-- what fits: the parts list scrolls when the screen is short of room
		local fixed, parts = {}, {}
		for _, r in ipairs(rows) do if r.kind == "part" then parts[#parts + 1] = r else fixed[#fixed + 1] = r end end
		local helpLines = 2
		local room = math.floor((SCREEN_HEIGHT - y0 - l.lip - pad * 3 - (helpLines + 2.3) * RH) / RH) - #fixed
		partsRows = math.max(0, math.min(#parts, room))
		partsFirst = math.max(1, math.min(partsFirst, math.max(1, #parts - partsRows + 1)))
		local list = {}
		for _, r in ipairs(fixed) do list[#list + 1] = r end
		for i = partsFirst, partsFirst + partsRows - 1 do if parts[i] then list[#list + 1] = parts[i] end end
		if collapsed then list = {} end
		local top = y0
		titleBox = { x0, top, x0 + W + 2 * pad, top + l.lip }
		c.Lip:xy(x0, top):zoomto(W + 2 * pad, l.lip):diffuse(A(C("lip"), rb and 0.95 or 0.85))
		c.Edge:visible(not rb):xy(x0, top + l.lip):zoomto(W + 2 * pad, 2 * l.u):diffuse(A(C("accent"), 0.6))
		local keys = gameKey() == "kb7" and "7K" or "4K"
		c.Title:xy(x0 + pad, top + l.lip / 2):zoom(l.zt):maxwidth((W * 0.6) / l.zt):diffuse(textCol)
			:settext(tdOK() and ("Customize Gameplay (" .. keys .. ")") or ("VSRG Hub settings (" .. keys .. ")"))
		c.Fold:xy(x0 + W + pad, top + l.lip / 2):zoom(l.zs):diffuse(textCol):diffusealpha(0.6)
			:settext(collapsed and "click: open   drag: move" or "click: fold   drag: move")
		local y = top + l.lip + pad * 0.6
		for i = 1, MAXROWS do
			local a = c["R" .. i]
			local r = list[i]
			a:visible(r ~= nil)
			if r then
				a:xy(x0 + pad, y)
				local ac = a:GetChildren()
				for _, n in ipairs({ "B1", "B2", "B3", "B4", "T1", "T2", "T3", "T4" }) do ac[n]:visible(false) end
				ac.Value:visible(false)
				if r.kind == "head" then
					ac.Bg:zoomto(W, RH - l.u):diffuse(rb and A(C("line"), 0.35) or A(C("accent"), 0.55))
					ac.Label:xy(4 * l.u, RH / 2):zoom(l.zs * 1.08):maxwidth((W - 8 * l.u) / (l.zs * 1.08)):diffuse(textCol):settext(r.label)
				else
					ac.Bg:zoomto(W, RH - l.u):diffuse(rb and color("1,1,1,0.03") or A(C("lip"), 0.45))
					ac.Label:xy(4 * l.u, RH / 2):zoom(l.z):maxwidth((W * 0.5) / l.z):diffuse(textCol):settext(r.label or "")
					local bw, bh = (r.kind == "part" and 30 or 15) * l.u * (rb and 1.3 or 1), RH - 2.5 * l.u
					local function btn(n, bx, label, fn, on)
						local q, tx = ac["B" .. n], ac["T" .. n]
						q:visible(true):xy(bx, l.u):zoomto(bw, bh)
							:diffuse(on and (rb and A(C("line"), 0.9) or A(C("accent"), 0.95)) or color("1,1,1,0.12"))
						tx:visible(true):xy(bx + bw / 2, RH / 2):zoom(l.zs):maxwidth((bw - 2 * l.u) / l.zs):diffuse(textCol):settext(label)
						buttons[#buttons + 1] = { x0 + pad + bx, y + l.u, x0 + pad + bx + bw, y + l.u + bh, fn, row = r }
					end
					if r.kind == "value" then
						local txt
						if r.text then txt = r.text()
						else
							local v = r.get()
							txt = string.format(r.fmt, r.fmt:find("d") and math.floor(v + 0.5) or v)
						end
						ac.Value:visible(true):xy(W - 2 * bw - 8 * l.u, RH / 2):zoom(l.z):maxwidth((W * 0.42) / l.z):diffuse(textCol):settext(txt)
						btn(1, W - 2 * bw - 3 * l.u, "-", function() r.dec() end)
						btn(2, W - bw, "+", function() r.inc() end)
						if r.swatch then
							-- (the colour itself, left of its name)
							local sw = RH - 4 * l.u
							ac.B3:visible(true):xy(W - 2 * bw - 12 * l.u - ac.Value:GetZoomedWidth() - sw, 2 * l.u):zoomto(sw, sw)
								:diffuse(color(r.swatch()))
						end
					elseif r.kind == "tabs" then
						ac.Label:settext("")
						ac.Bg:diffuse(color("0,0,0,0"))
						local tw = (W - (#PAGES - 1) * 3 * l.u) / #PAGES
						local function tab(n, bx, label, name)
							local q, tx = ac["B" .. n], ac["T" .. n]
							q:visible(true):xy(bx, l.u):zoomto(tw, RH - 2.5 * l.u)
								:diffuse(page == name and (rb and A(C("line"), 0.9) or A(C("accent"), 0.95)) or color("1,1,1,0.1"))
							tx:visible(true):xy(bx + tw / 2, RH / 2):zoom(l.z):maxwidth((tw - 4 * l.u) / l.z)
								:diffuse((rb and page == name) and color("0.08,0.08,0.1,1") or textCol):settext(label)
							buttons[#buttons + 1] = { x0 + pad + bx, y + l.u, x0 + pad + bx + tw, y + RH - 1.5 * l.u,
								function() page = name; partsFirst = 1; buildRows() end }
						end
						for n, pg in ipairs(PAGES) do tab(n, (n - 1) * (tw + 3 * l.u), pg[2], pg[1]) end
					elseif r.kind == "part" then
						for n, k in ipairs(r.keys) do
							if n <= 3 then
								local bx = W - (#r.keys - n + 1) * (bw + 3 * l.u) + 3 * l.u
								btn(n, bx, k.kind, function() tdFake(k.key) end, Movable.pressed and curPick() == k.key)
							end
						end
					end
				end
				y = y + RH
			end
		end
		for i = #list + 1, MAXROWS do c["R" .. i]:visible(false) end
		-- the picked part, the reset buttons and how it works
		local show = not collapsed
		c.Picked:visible(show and tdOK()):xy(x0 + pad, y + RH * 0.55):zoom(l.zs):maxwidth(W / l.zs):diffuse(textCol):settext(pickedText())
		if show and tdOK() then y = y + RH end
		local bw = tdOK() and (W / 2 - 2 * l.u) or W
		local function wide(name, txtName, bx, label, fn)
			if not tdOK() and name == "W2" then c[name]:visible(false); c[txtName]:visible(false) return end
			c[name]:visible(show):xy(x0 + pad + bx, y + l.u):zoomto(bw, RH * 1.15):diffuse(rb and color("1,1,1,0.1") or A(C("accent"), 0.7))
			c[txtName]:visible(show):xy(x0 + pad + bx + bw / 2, y + l.u + RH * 0.58):zoom(l.zs):maxwidth((bw - 4 * l.u) / l.zs):diffuse(textCol):settext(label)
			if show then buttons[#buttons + 1] = { x0 + pad + bx, y + l.u, x0 + pad + bx + bw, y + l.u + RH * 1.15, fn } end
		end
		wide("W1", "WT1", 0, (tdOK() and Movable.pressed and Movable[curPick() or ""]) and "Reset picked part" or "Reset this page", function()
			if tdOK() and Movable.pressed and Movable[curPick() or ""] then tdFake("DeviceButton_backspace")
			elseif page == "cover" then
				for _, f in ipairs({ "m", "h", "a", "c", "b", "bh", "bc" }) do data[key("tdcover", f)] = nil end
				saveData()
			elseif page == "hud" then
				for f in pairs(FPS_DEFAULTS) do data[key("fps", f)] = nil end
				saveData()
			elseif page == "light" then
				for _, l in ipairs(LIGHTS) do
					for _, f in ipairs({ "on", "x", "y", "z", "w", "h" }) do data[key(l[1], f)] = nil end
				end
				saveData()
				MESSAGEMAN:Broadcast("TWLayoutChanged", {})
			else
				for _, it in ipairs({ { "columns", "n" }, { "notes", "z" }, { "notes", "w" }, { "notes", "h" }, { "receptors", "y" }, { "receptors", "z" }, { "receptors", "w" },
					{ "receptors", "h" }, { "receptors", "o" }, { "hint", "y" }, { "hint", "h" }, { "lntail", "h" }, { "lntail", "y" } }) do
					data[key(it[1], it[2])] = nil
				end
				saveData()
				MESSAGEMAN:Broadcast("TWLayoutChanged", {})
			end
		end)
		wide("W2", "WT2", bw + 4 * l.u, "Let go (right click)", function()
			if tdOK() then
				block(false)
				Movable.current = "None"; Movable.pressed = false
			end
		end)
		y = y + RH * 1.5
		local help = rb and "Rebirth's own menu moves the parts and the notefield. The mouse wheel over a row changes it."
			or "Click Move / Size / Spacing / Turn on a part, then drag it or use the arrow keys (Backspace resets it). The mouse wheel over a row changes it. Esc when done."
		c.Help:visible(show):xy(x0 + pad, y):zoom(l.zs):wrapwidthpixels(W / l.zs):diffuse(textCol):diffusealpha(0.75):settext(help)
		-- the panel's body ends under the last thing in it
		local bottom = collapsed and (top + l.lip) or (y + c.Help:GetZoomedHeight() + pad)
		panelBox = { x0, top, x0 + W + 2 * pad, bottom }
		c.Body:xy(x0, top):zoomto(W + 2 * pad, bottom - top):diffuse(A(C("body"), 0.97))
	end,
	Def.Quad { Name = "Body", InitCommand = function(self) self:align(0, 0) end },
	Def.Quad { Name = "Lip", InitCommand = function(self) self:align(0, 0) end },
	Def.Quad { Name = "Edge", InitCommand = function(self) self:align(0, 0) end },
	LoadFont("Common Normal") .. { Name = "Title", InitCommand = function(self) self:align(0, 0.5) end },
	LoadFont("Common Normal") .. { Name = "Fold", InitCommand = function(self) self:align(1, 0.5) end },
	LoadFont("Common Normal") .. { Name = "Picked", InitCommand = function(self) self:align(0, 0.5) end },
	Def.Quad { Name = "W1", InitCommand = function(self) self:align(0, 0) end },
	Def.Quad { Name = "W2", InitCommand = function(self) self:align(0, 0) end },
	LoadFont("Common Normal") .. { Name = "WT1", InitCommand = function(self) self:align(0.5, 0.5) end },
	LoadFont("Common Normal") .. { Name = "WT2", InitCommand = function(self) self:align(0.5, 0.5) end },
	LoadFont("Common Normal") .. { Name = "Help", InitCommand = function(self) self:align(0, 0) end },
}
for i = 1, MAXROWS do t[#t + 1] = rowActor(i) end
return Def.ActorFrame {
	-- (under the panel)
	Def.Quad { Name = "TWLaneCover", InitCommand = function(self) coverQuad = self; self:visible(false):halign(0.5) end },
	Def.Quad { Name = "TWLaneCoverEdge", InitCommand = function(self) coverEdge = self; self:visible(false):halign(0.5) end },
	Def.Quad { Name = "TWLaneCoverGlow", InitCommand = function(self) coverGlow = self; self:visible(false):halign(0.5) end },
	fpsActor(),
	comboActor(),
	t,
}
