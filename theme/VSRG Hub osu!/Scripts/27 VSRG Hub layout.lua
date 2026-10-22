-- Customize gameplay, as in Etterna: every part of the gameplay screen can be moved and resized,
-- for 4K and 7K separately, and the notefield gets osu!/Quaver-style settings on top (hit position,
-- column and note spacing, notefield size, receptor offset and size, judgment and combo height).
-- Turn it on from the options (Ctrl+O, "Customize gameplay") or Etterna's own Customize Gameplay
-- player option: the song then plays on autoplay in practice mode with an editor over it.
-- Saved in Save/VSRGHub/layout.ini. The notefield's own settings (hit position, notefield place and
-- size, column and note spacing, receptors, lane cover) are kept per noteskin, since each skin needs its own;
-- the HUD parts are shared by every skin.

TW.layoutFile = "Save/VSRGHub/layout.ini"
local function gameKey()
	local g = GAMESTATE:GetCurrentGame()
	return g and g:GetName() or "dance"
end

local data = {}
local function save()
	local out = {}
	for k, v in pairs(data) do out[#out + 1] = k .. "=" .. tostring(v) end
	table.sort(out)
	pcall(function() File.Write(TW.layoutFile, table.concat(out, "\n") .. "\n") end)
end
-- the parts that belong to the notes, kept per noteskin: "<game>_<noteskin>__<item>_<field>"
local SKIN_ITEMS = { field = true, columns = true, receptors = true, lanecover = true, lntail = true, notes = true, hint = true,
	lighting = true, holdlight = true, collight = true }
local function safe(ns) return ((ns or ""):lower():gsub("[^%w]", "_")) end
local function skinKey()
	local ns = ""
	pcall(function() ns = GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin() or "" end)
	return safe(ns)
end
local function key(item, field)
	if SKIN_ITEMS[item] then return gameKey() .. "_" .. skinKey() .. "__" .. item .. "_" .. field end
	return gameKey() .. "_" .. item .. "_" .. field
end
do
	local ok, txt = pcall(function() return File.Read(TW.layoutFile) end)
	if ok and type(txt) == "string" then
		for k, v in txt:gmatch("([%w_]+)=([^\r\n]*)") do data[k] = tonumber(v) or v end
	end
	-- (from before the notefield's settings were per noteskin: they go to the noteskin picked for
	-- that key mode, the one they were set for)
	local moved = false
	for _, g in ipairs({ "dance", "kb7" }) do
		local ns = TW.settings and TW.settings["notes_" .. g]
		if ns and ns ~= "" then
			for item in pairs(SKIN_ITEMS) do
				for _, f in ipairs({ "x", "y", "z", "w", "h", "on", "a" }) do
					local old = g .. "_" .. item .. "_" .. f
					if data[old] ~= nil then
						local new = g .. "_" .. safe(ns) .. "__" .. item .. "_" .. f
						if data[new] == nil then data[new] = data[old] end
						data[old] = nil
						moved = true
					end
				end
			end
		end
	end
	if moved then save() end
end

-- numbers: TW.lv("judge", "y") is the current game's value (0 / 1 for zoom / 1 for on)
-- (w and h stretch a part across and down, on top of its size z; a is the lane cover's opacity)
local defaults = { x = 0, y = 0, z = 1, on = 1, w = 1, h = 1, a = 1 }
function TW.lv(item, field)
	local v = data[key(item, field)]
	if v == nil then
		local d = TW.layoutItems[item] and TW.layoutItems[item].defaults
		v = d and d[field]
		if v == nil then v = defaults[field] or 0 end
	end
	return v
end
function TW.setLv(item, field, v, noSave)
	data[key(item, field)] = v
	if not noSave then save() end
	MESSAGEMAN:Broadcast("TWLayoutChanged", { item = item })
end
function TW.resetItem(item)
	local pre = key(item, "")
	for k in pairs(data) do if k:sub(1, #pre) == pre then data[k] = nil end end
	save()
	MESSAGEMAN:Broadcast("TWLayoutChanged", { item = item })
end
function TW.resetLayout()
	-- (this noteskin's notefield settings and the shared HUD parts; other noteskins keep theirs)
	local pre, skinPre = gameKey() .. "_", gameKey() .. "_" .. skinKey() .. "__"
	for k in pairs(data) do
		if k:sub(1, #skinPre) == skinPre or (k:sub(1, #pre) == pre and not k:find("__", 1, true)) then data[k] = nil end
	end
	save()
	MESSAGEMAN:Broadcast("TWLayoutChanged", {})
end
-- Sharing a noteskin's settings: everything kept per noteskin for the current key mode (notefield,
-- columns, notes, receptors, lane cover, LN tail, stage hint, lighting) goes to a small text file in
-- Save/VSRGHub/skins/, "<noteskin> (4K).vhskin", to send to someone; TW.importSkinLayout reads one
-- back onto the noteskin and key mode in use. The game's own options (judge, scroll speed) and the
-- HUD parts (shared by every skin) aren't part of it.
TW.skinFilesDir = "Save/VSRGHub/skins/"
local function skinLayoutKeys()
	local pre = gameKey() .. "_" .. skinKey() .. "__"
	local out = {}
	for k, v in pairs(data) do
		if k:sub(1, #pre) == pre then out[k:sub(#pre + 1)] = v end
	end
	return out, pre
end
local function keysLabel() return gameKey() == "kb7" and "7K" or "4K" end
function TW.exportSkinLayout()
	local ns = ""
	pcall(function() ns = GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin() or "" end)
	if ns == "" then return nil, "No noteskin is in use (pick a song first)" end
	local vals = skinLayoutKeys()
	local lines = { "# VSRG Hub skin settings", "skin=" .. ns, "keys=" .. keysLabel() }
	local names = {}
	for k in pairs(vals) do names[#names + 1] = k end
	table.sort(names)
	for _, k in ipairs(names) do if k ~= "auto" then lines[#lines + 1] = k .. "=" .. tostring(vals[k]) end end
	local pretty = TW.prettyNoteskin and TW.prettyNoteskin(ns) or ns
	local file = TW.skinFilesDir .. (pretty:gsub("[\\/:*?\"<>|]", "_")) .. " (" .. keysLabel() .. ").vhskin"
	local ok = pcall(function() File.Write(file, table.concat(lines, "\n") .. "\n") end)
	if not ok then return nil, "The file couldn't be written" end
	return file, #names
end
-- the files there, newest name last: { { label, value = path, sub }, ... }
function TW.skinLayoutFiles()
	local files = {}
	pcall(function() files = FILEMAN:GetDirListing(TW.skinFilesDir) or {} end)
	table.sort(files, function(a, b) return a:lower() < b:lower() end)
	local items = {}
	for _, f in ipairs(files) do
		if f:lower():match("%.vhskin$") then
			local sub = ""
			pcall(function()
				local txt = File.Read(TW.skinFilesDir .. f) or ""
				local skin, keys = txt:match("\nskin=([^\r\n]*)"), txt:match("\nkeys=([^\r\n]*)")
				sub = (skin and ("for " .. (TW.prettyNoteskin and TW.prettyNoteskin(skin) or skin)) or "") .. (keys and ("  ·  " .. keys) or "")
			end)
			items[#items + 1] = { label = (f:gsub("%.vhskin$", "")), value = f, sub = sub }
		end
	end
	return items
end
-- A skin that brings its own settings (vsrghub-4k.vhskin in the skin's folder: the launcher copies
-- it to skins/auto/<noteskin>.vhskin) sets the notefield up the first time it is used, or again
-- after "Reset" in Customize gameplay. Called when a noteskin is put in use.
function TW.autoSkinLayout()
	local ns = ""
	pcall(function() ns = GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin() or "" end)
	if ns == "" then return end
	local vals, pre = skinLayoutKeys()
	if next(vals) ~= nil then return end -- (set up already, by hand or by the skin's file)
	local n = TW.importSkinLayout("auto/" .. ns:lower() .. ".vhskin", true)
	if n then
		data[pre .. "auto"] = 1
		save()
		SCREENMAN:SystemMessage((TW.prettyNoteskin and TW.prettyNoteskin(ns) or ns) .. " came with its own settings: applied")
	end
end
function TW.importSkinLayout(f, quiet)
	if skinKey() == "" then return nil, "No noteskin is in use (pick a song first)" end
	local ok, txt = pcall(function() return File.Read(TW.skinFilesDir .. f) end)
	if not ok or type(txt) ~= "string" or not txt:find("VSRG Hub skin settings", 1, true) then return nil, "That isn't a VSRG Hub skin settings file" end
	local _, pre = skinLayoutKeys()
	for k in pairs(data) do if k:sub(1, #pre) == pre then data[k] = nil end end
	local n = 0
	for k, v in txt:gmatch("\n([%w_]+)=([^\r\n]*)") do
		if k ~= "skin" and k ~= "keys" then
			local item = k:match("^(%w+)_")
			if item and SKIN_ITEMS[item] then data[pre .. k] = tonumber(v) or v; n = n + 1 end
		end
	end
	save()
	MESSAGEMAN:Broadcast("TWLayoutChanged", {})
	local keys = txt:match("\nkeys=([^\r\n]*)")
	return n, (keys and keys ~= keysLabel()) and ("(the file was made for " .. keys .. ", you're on " .. keysLabel() .. ")") or nil
end

function TW.layoutOn(item)
	if item == "lanecover" and TW.coverMode then return TW.coverMode() ~= 0 end
	return TW.lv(item, "on") ~= 0
end

-- the receptor art (read by the VSRG Hub noteskins): offset toward the screen edge, size, and the
-- stretch across and down (for skins whose receptors come out too flat or too tall)
function TW.receptorLayout() return TW.lv("receptors", "y"), TW.lv("receptors", "z"), TW.lv("receptors", "w"), TW.lv("receptors", "h") end
-- receptors under or over the notes: 0 as the skin draws them, 1 under, 2 over
function TW.receptorsOrder() return TW.lv("receptors", "o") end
-- the skin's lighting ("lighting": osu!'s LightingN / Quaver's hit lighting, "holdlight": LightingL /
-- Quaver's hold lighting, "collight": Quaver's column lighting): on, x, y, size, width, height
function TW.lightLayout(kind)
	return TW.lv(kind, "on"), TW.lv(kind, "x"), TW.lv(kind, "y"), TW.lv(kind, "z"), TW.lv(kind, "w"), TW.lv(kind, "h")
end
-- the long notes' end image (read by the VSRG Hub noteskins): its height and how far its far edge
-- moves away from the head (it never covers the body or goes past the head)
function TW.tailLayout() return TW.lv("lntail", "h"), TW.lv("lntail", "y") end
-- Note size: notes, hold heads, bodies and ends drawn bigger or smaller than their column
function TW.noteScale() return TW.lv("notes", "z") end
-- Note width / height: notes and hold heads stretched across or along their column (bodies follow
-- the width)
function TW.noteDims() return TW.lv("notes", "w"), TW.lv("notes", "h") end
-- the stage hint (and osu!'s judgement line): how far it moves from the hit position (+ towards
-- the receptors' edge of the screen, as Receptor offset) and how tall it is drawn
function TW.hintLayout() return TW.lv("hint", "y"), TW.lv("hint", "h") end

-- items: name -> { label, box = function() return cx, cy, w, h end (default place, unscaled),
-- kind = "hud" (moved and sized by its frame) / "field" (the notefield) / "receptors" }
TW.layoutItems = {}
TW.layoutOrder = {}
function TW.stageCX() return TW.stage and TW.stage.cx or SCREEN_CENTER_X end
local function register(name, spec)
	if not TW.layoutItems[name] then TW.layoutOrder[#TW.layoutOrder + 1] = name end
	TW.layoutItems[name] = spec
end
function TW.registerLayout(name, label, box, opts)
	opts = opts or {}
	register(name, { label = label, box = box, kind = opts.kind or "hud", defaults = opts.defaults, optional = opts.optional })
end
TW.registerLayout("field", "Notefield", function()
	local s = TW.stage
	if not s then return SCREEN_CENTER_X, SCREEN_CENTER_Y, 256, SCREEN_HEIGHT end
	return s.cx, SCREEN_CENTER_Y, s.width, SCREEN_HEIGHT
end, { kind = "field" })
TW.registerLayout("receptors", "Receptors", function()
	local s = TW.stage
	if not s then return SCREEN_CENTER_X, SCREEN_HEIGHT - 80, 256, 60 end
	return s.cx, s.receptorY or (s.reverse and SCREEN_HEIGHT - 80 or 80), s.width, 60
end, { kind = "receptors" })

-- where an item is now: its box moved and scaled by the saved values
function TW.itemRect(name)
	local it = TW.layoutItems[name]
	if not it then return nil end
	local cx, cy, w, h = it.box()
	if it.kind == "cover" then return cx, cy, w, h end -- its box already follows the saved values
	if it.kind == "hud" then
		local z = TW.lv(name, "z")
		return cx + TW.lv(name, "x"), cy + TW.lv(name, "y"), w * z * TW.lv(name, "w"), h * z * TW.lv(name, "h")
	end
	if it.kind == "receptors" then
		local z = TW.lv(name, "z")
		return cx, cy, w * z * TW.lv(name, "w"), h * z * TW.lv(name, "h")
	end
	return cx, cy, w, h
end

-- a frame that puts a HUD part where the layout says: children are drawn at their normal place,
-- the frame scales them around the item's box centre and moves them by the saved offset
function TW.movable(name, label, box, children, opts)
	TW.registerLayout(name, label, box, opts)
	local f = Def.ActorFrame {
		Name = "TWMove_" .. name,
		InitCommand = function(self) self:playcommand("TWPlace") end,
		TWStageMessageCommand = function(self) self:playcommand("TWPlace") end,
		TWLayoutChangedMessageCommand = function(self) self:playcommand("TWPlace") end,
		TWPlaceCommand = function(self)
			local cx, cy = box()
			local z = TW.lv(name, "z")
			local zx, zy = z * TW.lv(name, "w"), z * TW.lv(name, "h")
			self:xy(cx * (1 - zx) + TW.lv(name, "x"), cy * (1 - zy) + TW.lv(name, "y")):zoomx(zx):zoomy(zy)
			-- (a hidden part is hidden in Customize gameplay too: its panel row shows it again)
			self:visible(TW.layoutOn(name))
		end,
	}
	for _, c in ipairs(children) do f[#f + 1] = c end
	return f
end

-- the notefield: x offset, hit position (toward the middle), size, column and note spacing.
-- Called by the gameplay underlay before it measures the stage.
TW.registerLayout("columns", "Column spacing", function() return 0, 0, 0, 0 end, { kind = "value" })
TW.registerLayout("lntail", "LN tail", function() return 0, 0, 0, 0 end, { kind = "value" })
TW.registerLayout("notes", "Note size", function() return 0, 0, 0, 0 end, { kind = "value" })
TW.registerLayout("hint", "Stage hint", function() return 0, 0, 0, 0 end, { kind = "value" })
-- judgment and combo are made with the player, possibly after the editor: list them up front
TW.registerLayout("judge", "Judgment", function() return TW.stageCX(), SCREEN_CENTER_Y, 200, 50 end)
TW.registerLayout("combo", "Combo", function() return TW.stageCX(), SCREEN_CENTER_Y + 60, 120, 40 end)
function TW.applyFieldLayout(pl, nf, reverse)
	if not (pl and nf) then return end
	TW.fieldBase = TW.fieldBase or {}
	local b = TW.fieldBase
	if b.pl ~= pl then b.pl, b.x, b.y = pl, nf:GetX(), nf:GetY() end
	local hit = TW.lv("field", "y")
	nf:x(b.x + TW.lv("field", "x"))
	nf:y(b.y + (reverse and -hit or hit))
	nf:zoom(TW.lv("field", "z"))
end
function TW.columnExtra() return TW.lv("columns", "x") end
-- how much further apart the notes are than the columns (0: the notes sit on their receptors; for
-- skins whose notes and receptors don't line up)
function TW.noteSpacingExtra() return TW.lv("columns", "n") end

-- judgment and combo live inside the player: place their frame at a screen point (the item's box
-- centre) plus the saved offset and size. Their box follows the stage.
function TW.placeInPlayer(self, name)
	local it = TW.layoutItems[name]
	if not it then return end
	local s = TW.stage
	local px, py = s and s.plX or SCREEN_CENTER_X, s and s.plY or SCREEN_CENTER_Y
	local cx, cy = it.box()
	local z = TW.lv(name, "z")
	self:xy(cx - px + TW.lv(name, "x"), cy - py + TW.lv(name, "y")):zoomx(z * TW.lv(name, "w")):zoomy(z * TW.lv(name, "h"))
	self:visible(TW.layoutOn(name))
end
function TW.playerItem(name, label, box, w, h)
	TW.registerLayout(name, label, function() local x, y = box(); return x, y, w, h end)
	return {
		TWStageMessageCommand = function(self) TW.placeInPlayer(self, name) end,
		TWLayoutChangedMessageCommand = function(self) TW.placeInPlayer(self, name) end,
	}
end

-- ---------------------------------------------------------------------------------------------
-- extra HUD parts from Etterna, off until you switch them on in Customize gameplay
-- ---------------------------------------------------------------------------------------------
local judgeOrder = { "TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3", "TapNoteScore_W4", "TapNoteScore_W5", "TapNoteScore_Miss" }
local judgeShort = { "Marvelous", "Perfect", "Great", "Good", "Bad", "Miss" }
local judgeCol = { color("#99CCFF"), color("#F2CB30"), color("#14CC8F"), color("#1AB2FF"), color("#FF1AB3"), color("#CC2929") }
local function stageX(dx) return (TW.stage and TW.stage.cx or SCREEN_CENTER_X) + (dx or 0) end
local function stageR() return TW.stage and TW.stage.right or SCREEN_CENTER_X + 128 end
local function stageL() return TW.stage and TW.stage.left or SCREEN_CENTER_X - 128 end

-- skip: parts the look already has its own of (Quaver's hit error bar and song time)
function TW.hudExtras(skip)
	skip = skip or {}
	local text = TW.hudText or TW.text
	local t = Def.ActorFrame {}
	-- error bar: every hit as a tick, early left, late right (Etterna's error bar)
	local EBW, EBH = 240, 14
	local ebBox = function() return stageX(), SCREEN_CENTER_Y + 40, EBW, EBH end
	local ticks = {}
	local ebar = Def.ActorFrame {
		InitCommand = function(self) self:playcommand("TWPlace2") end,
		TWStageMessageCommand = function(self) self:playcommand("TWPlace2") end,
		TWPlace2Command = function(self) local x, y = ebBox(); self:xy(x, y) end,
		-- (its background's opacity is set in Customize gameplay: "Error bar background")
		Def.Quad { InitCommand = function(self) self:zoomto(EBW, EBH):playcommand("Bg") end,
			TWLayoutChangedMessageCommand = function(self) self:playcommand("Bg") end,
			BgCommand = function(self)
				TW.glassify(self, "hud", { 0, 0, 0, 0.35 })
				local a = TW.lv("errorbar", "a")
				if a ~= 1 then self:diffusealpha(self:GetDiffuseAlpha() * math.max(0, a)) end
			end },
		Def.Quad { InitCommand = function(self) self:zoomto(2, EBH + 6):diffuse(color("1,1,1,0.9")) end },
	}
	for i = 1, 30 do
		ebar[#ebar + 1] = Def.Quad { Name = "T" .. i, InitCommand = function(self) self:zoomto(2, EBH):diffusealpha(0) end }
	end
	local nextTick = 1
	ebar.JudgmentMessageCommand = function(self, p)
		if p.HoldNoteScore or not p.TapNoteOffset or p.TapNoteScore == "TapNoteScore_Miss" then return end
		local scale = 1
		pcall(function() scale = GetTimingDifficulty and ms.JudgeScalers[GetTimingDifficulty()] or 1 end)
		local off = p.TapNoteOffset * 1000
		local x = math.max(-1, math.min(1, off / (180 * scale))) * EBW / 2
		local q = self:GetChild("T" .. nextTick)
		nextTick = nextTick % 30 + 1
		local j = 1
		for i, k in ipairs(judgeOrder) do if k == p.TapNoteScore then j = i end end
		q:finishtweening():x(x):diffuse(judgeCol[j]):diffusealpha(1):linear(1):diffusealpha(0)
	end
	if not skip.errorbar then
		t[#t + 1] = TW.movable("errorbar", "Error bar", ebBox, { ebar }, { defaults = { on = 0 }, optional = true })
	end

	-- full progress bar with the song time
	local PW, PH = 300, 8
	local pBox = function() return SCREEN_CENTER_X, SCREEN_HEIGHT - 14, PW, PH + 4 end
	if not skip.progress then t[#t + 1] = TW.movable("progress", "Progress bar", pBox, { Def.ActorFrame {
		InitCommand = function(self) local x, y = pBox(); self:xy(x, y) end,
		OnCommand = function(self)
			self:SetUpdateFunction(function()
				local song = GAMESTATE:GetCurrentSong()
				if not song then return end
				local len = song:GetLastSecond()
				local now = GAMESTATE:GetSongPosition():GetMusicSecondsVisible()
				local f = len > 0 and math.max(0, math.min(1, now / len)) or 0
				self:GetChild("Fill"):zoomx(f * PW)
				local rate = getCurRateValue and getCurRateValue() or 1
				local function clock(s) s = math.max(0, s / rate); return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60)) end
				self:GetChild("Time"):settext(clock(now) .. " / " .. clock(len))
			end)
		end,
		Def.Quad { InitCommand = function(self) TW.glassify(self:zoomto(PW, PH), "hud", { 0, 0, 0, 0.5 }) end },
		Def.Quad { Name = "Fill", InitCommand = function(self) self:halign(0):x(-PW / 2):zoomto(0, PH):diffuse(color("1,1,1,0.75")) end },
		text(10, true, function(self) self:align(0.5, 0.5):settext("") end) .. { Name = "Time" },
	} }, { defaults = { on = 0 }, optional = true }) end

	-- judgment counter
	local counts = { 0, 0, 0, 0, 0, 0 }
	local jBox = function() return stageL() - 70, SCREEN_CENTER_Y, 120, 6 * 18 end
	local jc = Def.ActorFrame {
		InitCommand = function(self) self:playcommand("TWP") end,
		TWStageMessageCommand = function(self) self:playcommand("TWP") end,
		TWPCommand = function(self) local x, y = jBox(); self:xy(x, y) end,
		Def.Quad { InitCommand = function(self) TW.glassify(self:zoomto(120, 6 * 18), "hud", { 0, 0, 0, 0.4 }) end },
		JudgmentMessageCommand = function(self, p)
			if p.HoldNoteScore or not p.TapNoteScore then return end
			for i, k in ipairs(judgeOrder) do
				if k == p.TapNoteScore then
					-- (a replay that jumps sends each count again, as Val)
					if p.FromReplay then counts[i] = tonumber(p.Val) or counts[i] else counts[i] = counts[i] + 1 end
					self:GetChild("N" .. i):settext(tostring(counts[i]))
				end
			end
		end,
	}
	for i = 1, 6 do
		local y = (i - 3.5) * 18
		jc[#jc + 1] = text(10, true, function(self) self:align(0, 0.5):xy(-54, y):settext(judgeShort[i]):diffuse(judgeCol[i]) end)
		jc[#jc + 1] = text(10, true, function(self) self:align(1, 0.5):xy(54, y):settext("0") end) .. { Name = "N" .. i }
	end
	t[#t + 1] = TW.movable("judgecounter", "Judgment counter", jBox, { jc }, { defaults = { on = 0 }, optional = true })

	-- mean offset, NPS, and the pace against your target (Etterna's target tracker)
	local function infoText(name, label, dy, update)
		local box = function() return stageR() + 70, SCREEN_CENTER_Y + dy, 120, 16 end
		return TW.movable(name, label, box, { text(11, true, function(self)
			self:align(0.5, 0.5); local x, y = box(); self:xy(x, y)
		end) .. {
			TWStageMessageCommand = function(self) local x, y = box(); self:xy(x, y) end,
			OnCommand = function(self) update(self, nil) end,
			JudgmentMessageCommand = function(self, p) update(self, p) end,
		} }, { defaults = { on = 0 }, optional = true })
	end
	local sum, n = 0, 0
	t[#t + 1] = infoText("mean", "Mean", -40, function(self, p)
		if p and not p.FromReplay and not p.HoldNoteScore and p.TapNoteOffset and p.TapNoteScore ~= "TapNoteScore_Miss" then
			sum = sum + p.TapNoteOffset * 1000; n = n + 1
		end
		self:settextf("Mean %.2fms", n > 0 and sum / n or 0)
	end)
	local times = {}
	local peak = 0
	t[#t + 1] = infoText("nps", "NPS", -20, function(self, p)
		local now = GetTimeSinceStart()
		if p and not p.FromReplay and not p.HoldNoteScore and p.TapNoteScore then times[#times + 1] = now end
		while #times > 0 and now - times[1] > 1 do table.remove(times, 1) end
		local nps = #times
		if nps > peak then peak = nps end
		self:settextf("NPS %d (peak %d)", nps, peak)
	end)
	t[#t + 1] = infoText("pace", "Pace (target)", 0, function(self, p)
		-- points ahead of (or behind) your target goal so far, as Etterna's target tracker shows them
		local target = 93
		pcall(function() target = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).TargetGoal or 93 end)
		local d = p and p.WifeDifferential or 0 -- what Til Death's target tracker shows
		-- (autoplay scores nothing: Etterna's number is meaningless then)
		local auto = false
		pcall(function()
			local pc = GAMESTATE:GetPlayerState():GetPlayerController()
			auto = pc == "PlayerController_Autoplay" or pc == "PlayerController_Cpu"
		end)
		if auto or d ~= d or math.abs(d) > 10000 then self:settextf("- (%g%%)", target):diffuse(color("#AAAAAA")) return end
		self:settextf("%+.2f (%g%%)", d, target):diffuse(d >= 0 and color("#66FF88") or color("#FF6666"))
	end)
	t[#t + 1] = TW.fpsCounter()
	return t
end

-- The FPS counter while playing (when Options > Show FPS is on): a HUD part like the others, moved,
-- sized or switched off in Customize gameplay, with its lines picked there (FPS, average FPS,
-- vertices per frame, renderer). Etterna's own counter in the corner steps aside meanwhile
-- (TWStatsText: caught by the metrics' StatsOnCommand).
TW.FPS_LINES = { { "f1", "FPS" }, { "f2", "Average FPS" }, { "f3", "Vertices per frame" }, { "f4", "Renderer" } }
function TW.fpsCounter()
	local text = TW.hudText or TW.text
	local function statsOn()
		local ok, v = pcall(function() return PREFSMAN:GetPreference("ShowStats") end)
		return ok and v == true
	end
	local function renderer()
		local r = ""
		pcall(function() r = TWStatsText and TWStatsText:GetText() or "" end)
		local last = r:match("([^\n]+)$") or ""
		if last ~= "" and not last:find("%d") then return last end
		local pref = ""
		pcall(function() pref = PREFSMAN:GetPreference("VideoRenderers") or "" end)
		local first = pref:match("^%s*([^,]+)") or ""
		return first:lower():find("opengl") and "OGL" or "D3D"
	end
	local box = function() return SCREEN_RIGHT - 60, SCREEN_TOP + 34, 110, 56 end
	local f = Def.ActorFrame {
		InitCommand = function(self)
			self:SetUpdateFunction(function(s)
				local on = statsOn()
				s:GetChild("T"):visible(on)
				if not on then return end
				local lines = {}
				local vals = {
					f1 = function() return string.format("%d FPS", DISPLAY:GetFPS()) end,
					f2 = function() return string.format("%d av FPS", DISPLAY:GetCumFPS()) end,
					f3 = function() return string.format("%d VPF", DISPLAY:GetVPF()) end,
					f4 = renderer,
				}
				for _, l in ipairs(TW.FPS_LINES) do
					if TW.lv("fps", l[1]) ~= 0 then
						local ok, v = pcall(vals[l[1]])
						if ok then lines[#lines + 1] = v end
					end
				end
				s:GetChild("T"):settext(table.concat(lines, "\n"))
			end)
			self:SetUpdateFunctionInterval(0.25)
		end,
		-- (Etterna's own counter steps aside while this one is there)
		OnCommand = function() if TWStatsText and statsOn() then TWStatsText:visible(false) end end,
		OffCommand = function() if TWStatsText then TWStatsText:visible(true) end end,
		text(11, true, function(self)
			local x, y = box()
			self:align(1, 0):xy(x + 55, y - 28):shadowlength(1)
		end) .. { Name = "T" },
	}
	return TW.movable("fps", "FPS counter", box, { f }, { defaults = { on = 1, f1 = 1, f2 = 1, f3 = 1, f4 = 1 }, optional = true })
end

-- ---------------------------------------------------------------------------------------------
-- the lane cover, as in Til' Death and Rebirth: off, sudden (over the far end of the lanes, where
-- the notes come in) or hidden (over the receptors), with its height, opacity and colour. A skin
-- with a mania-stage-bottom gets a fourth choice, "skin": that art drawn as osu! draws it, at the
-- bottom of the stage (the top when scrolling up), over the notes, at 1.6x osu!'s 480-pixel size,
-- not stretched to the stage's width (in the Quaver look too, when the notes are an osu! skin's).
-- Kept per noteskin and key mode, like the rest of the notefield.
-- ---------------------------------------------------------------------------------------------
TW.coverColours = {
	{ "Black", "#000000" }, { "Dark grey", "#1E1E1E" }, { "Grey", "#555555" }, { "White", "#FFFFFF" },
	{ "Purple", "#6A3FB5" }, { "Blue", "#2F5BD3" }, { "Cyan", "#2BB5D1" }, { "Green", "#3DBE5A" },
	{ "Yellow", "#E7C83B" }, { "Orange", "#E8832E" }, { "Red", "#D63B3B" }, { "Pink", "#E05FA8" },
}
TW.coverModes = { [0] = "Off", "Sudden", "Hidden", "Skin" }
TW.coverHasArt = false
-- 0 off, 1 sudden, 2 hidden, 3 the skin's art (from before the modes: shown meant the skin's art, or
-- the plain cover over the far end)
function TW.coverMode()
	local m = TW.lv("lanecover", "m")
	if m < 0 then m = (TW.lv("lanecover", "on") ~= 0) and (TW.coverHasArt and 3 or 1) or 0 end
	if m == 3 and not TW.coverHasArt then m = 1 end
	return m
end
function TW.setCoverMode(m)
	TW.setLv("lanecover", "on", m ~= 0 and 1 or 0, true)
	TW.setLv("lanecover", "m", m)
end
function TW.coverHeight()
	local p = TW.lv("lanecover", "p")
	if p < 0 then
		-- (from before the height: the plain cover was a quarter of the screen moved by its offset)
		local y = TW.lv("lanecover", "y")
		local rev = TW.stage == nil or TW.stage.reverse
		p = SCREEN_HEIGHT * 0.25 + (rev and y or -y)
	end
	return math.max(0, math.min(SCREEN_HEIGHT, math.floor(p + 0.5)))
end
function TW.coverColour()
	local c = math.floor(TW.lv("lanecover", "c") + 0.5)
	if c < 1 or c > #TW.coverColours then c = 1 end
	return c
end
function TW.laneCover()
	local art = TW.notesSkin and TW.has("stage_bottom") and TW.img("stage_bottom")
	TW.coverHasArt = art and true or false
	local hdScale = (art and TW.hd("stage_bottom")) and 0.5 or 1
	-- osu! draws it at 1.6x (its 480-high playfield units); here it follows the notefield, so it
	-- stays lined up with the columns when the notefield is smaller (Mini, notefield size)
	local artScale = (SCREEN_HEIGHT / 480) * hdScale
	local function fitStage()
		local s = TW.stage
		if s and s.fieldScale then artScale = (SCREEN_HEIGHT / 480) * s.fieldScale * hdScale end
	end
	local aw, ah = 0, 0
	local function rev() return TW.stage == nil or TW.stage.reverse end
	local function stageW() return TW.stage and TW.stage.width or 256 end
	local function box()
		fitStage()
		local m = TW.coverMode()
		local cx = TW.stageCX()
		if m == 3 then
			local y, z = TW.lv("lanecover", "y"), TW.lv("lanecover", "z")
			local w, h = aw * artScale * z, ah * artScale * z
			if rev() then return cx, SCREEN_HEIGHT - h / 2 + y, w, h end
			return cx, h / 2 + y, w, h
		end
		local h = TW.coverHeight()
		if TW.coverFromTop() then return cx, h / 2, stageW(), h end
		return cx, SCREEN_HEIGHT - h / 2, stageW(), h
	end
	-- sudden covers the end the notes come in from; hidden the receptors' end
	function TW.coverFromTop() return (TW.coverMode() == 1) == (rev() and true or false) end
	TW.registerLayout("lanecover", "Lane cover", box,
		{ kind = "cover", defaults = { on = art and 1 or 0, m = -1, p = -1, c = 1, b = 0, bh = 2, bc = 1 }, optional = true })
	local f = Def.ActorFrame {
		Name = "TWLaneCover",
		InitCommand = function(self) self:visible(false) end,
		TWStageMessageCommand = function(self) self:playcommand("Place") end,
		TWLayoutChangedMessageCommand = function(self) self:playcommand("Place") end,
		PlaceCommand = function(self)
			fitStage()
			local m = TW.coverMode()
			self:visible(m ~= 0):diffusealpha(math.max(0, math.min(1, TW.lv("lanecover", "a"))))
			if m == 0 then return end
			local cx, cy, w, h = box()
			local c = self:GetChildren()
			if c.Art then c.Art:visible(m == 3) end
			c.Cover:visible(m ~= 3)
			c.Edge:visible(m ~= 3)
			c.Glow:visible(false)
			if m == 3 then
				local z = artScale * TW.lv("lanecover", "z")
				c.Art:xy(cx, cy):zoomx(z):zoomy(rev() and z or -z)
				return
			end
			c.Cover:xy(cx, cy):zoomto(w, h):diffuse(color(TW.coverColours[TW.coverColour()][2]))
			-- the border on the edge the notes cross: none, a line, a fade (soft into the lanes) or a
			-- glow (both ways), its height and colour (Customize gameplay)
			local top = TW.coverFromTop()
			local b = math.floor(TW.lv("lanecover", "b") + 0.5)
			local bh = math.max(1, TW.lv("lanecover", "bh"))
			local bc = math.floor(TW.lv("lanecover", "bc") + 0.5)
			if bc < 1 or bc > #TW.coverColours then bc = 1 end
			local col = color(TW.coverColours[bc][2])
			local edgeY = top and h or SCREEN_HEIGHT - h
			local clear = { col[1], col[2], col[3], 0 }
			c.Edge:visible(h > 0 and b > 0):x(cx):zoomx(w):diffuse(col)
			if b == 1 then
				c.Edge:valign(0.5):y(edgeY):zoomy(bh)
			elseif b == 2 then
				-- (from the cover's colour at the edge to nothing, out over the lanes)
				c.Edge:valign(top and 0 or 1):y(edgeY):zoomy(bh * 4)
				if top then c.Edge:diffusebottomedge(clear) else c.Edge:diffusetopedge(clear) end
			elseif b == 3 then
				-- (out over the lanes and back into the cover, fading both ways from the edge)
				c.Edge:valign(top and 0 or 1):y(edgeY):zoomy(bh * 3)
				if top then c.Edge:diffusebottomedge(clear) else c.Edge:diffusetopedge(clear) end
				c.Glow:x(cx):zoomx(w):valign(top and 1 or 0):y(edgeY):zoomy(bh * 3):diffuse(col)
				if top then c.Glow:diffusetopedge(clear) else c.Glow:diffusebottomedge(clear) end
			end
			c.Glow:visible(h > 0 and b == 3)
		end,
	}
	f[#f + 1] = Def.Quad { Name = "Cover" }
	f[#f + 1] = Def.Quad { Name = "Edge" }
	f[#f + 1] = Def.Quad { Name = "Glow" }
	if art then
		f[#f + 1] = Def.Sprite { Name = "Art", Texture = art, InitCommand = function(self)
			aw, ah = self:GetWidth(), self:GetHeight()
		end }
	end
	return f
end

-- ---------------------------------------------------------------------------------------------
-- the editor drawn over gameplay while customizing
-- ---------------------------------------------------------------------------------------------
-- VSRG Hub's own "Customize gameplay" (options), or Etterna's (Til Death's "Customize Gameplay" in
-- the player options): that one stays on in the profile until it is turned off, which would open
-- the editor on every play, so here it opens the editor for the next play and turns itself off,
-- like VSRG Hub's own.
function TW.customizeActive()
	if TW.customize == true then return true end
	local on = false
	pcall(function() on = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay == true end)
	if not on then return false end
	TW.customize = true
	pcall(function()
		local slot = pn_to_profile_slot(PLAYER_1)
		playerConfig:get_data(slot).CustomizeGameplay = false
		playerConfig:set_dirty(slot)
		playerConfig:save(slot)
	end)
	return true
end
-- from the options: play the current chart on autoplay with the editor on
function TW.startCustomize()
	local top = SCREENMAN:GetTopScreen()
	if not (top and top.SelectCurrent and GAMESTATE:GetCurrentSteps()) then
		SCREENMAN:SystemMessage("Pick a song first")
		return
	end
	TW.customize = true -- song select turns it off again when you come back
	GAMESTATE:SetPracticeMode(false)
	top:SelectCurrent()
end

function TW.customizeEditor()
	TW.customizing = TW.customizeActive()
	if not TW.customizing then return Def.Actor {} end
	local text = TW.hudText or TW.text
	-- nothing is picked at first: click a part to pick it (then drag it, use the wheel or the keys),
	-- right click to let go of it
	local selected = nil
	local dragging = nil
	local hovered = nil
	local panelOn = true
	-- the panel (built further down): where it is, and what it does with the mouse
	local panel = { x = 0, w = 0, press = function() end, wheel = function() end, release = function() end, follow = function() end }
	local function step(field) return (field == "z") and 0.05 or 1 end
	local function nudge(item, field, d)
		local it = TW.layoutItems[item]
		if not it then return end
		local v = TW.lv(item, field) + d
		if field == "z" or field == "w" or field == "h" then v = math.max(0.2, math.min(4, math.floor(v * 100 + 0.5) / 100)) end
		if field == "a" then v = math.max(0, math.min(1, math.floor(v * 100 + 0.5) / 100)) end
		TW.setLv(item, field, v)
	end

	local function hitTest(mx, my)
		-- smallest box under the mouse wins, so small parts on top of the notefield can be picked
		local best, area = nil, math.huge
		for _, name in ipairs(TW.layoutOrder) do
			local it = TW.layoutItems[name]
			-- (hidden parts can't be picked on screen: their row in the panel shows them again)
			if it.kind ~= "value" and (TW.layoutOn(name) or it.kind == "field" or it.kind == "receptors") then
				local cx, cy, w, h = TW.itemRect(name)
				if cx and math.abs(mx - cx) <= w / 2 + 4 and math.abs(my - cy) <= h / 2 + 4 and w * h < area then
					best, area = name, w * h
				end
			end
		end
		return best
	end
	-- dragging changes x/y; for the notefield y is the hit position and for receptors their offset
	local function dragTo(name, dx, dy, base)
		local it = TW.layoutItems[name]
		local rev = TW.stage and TW.stage.reverse
		if it.kind == "field" then
			TW.setLv(name, "x", math.floor(base.x + dx + 0.5), true)
			TW.setLv(name, "y", math.floor(base.y + (rev and -dy or dy) + 0.5), true)
		elseif it.kind == "receptors" then
			TW.setLv(name, "y", math.floor(base.y + (rev and dy or -dy) + 0.5), true)
		elseif it.kind == "cover" then
			-- (the skin's art moves; a plain cover gets taller or shorter)
			if TW.coverMode() == 3 then TW.setLv(name, "y", math.floor(base.y + dy + 0.5), true)
			else TW.setLv(name, "p", math.max(0, math.min(SCREEN_HEIGHT, math.floor(base.p + (TW.coverFromTop() and dy or -dy) + 0.5))), true) end
		else
			TW.setLv(name, "x", math.floor(base.x + dx + 0.5), true)
			TW.setLv(name, "y", math.floor(base.y + dy + 0.5), true)
		end
		if name == "field" then MESSAGEMAN:Broadcast("TWRelayout") end
	end

	local function input(event)
		local b = event.DeviceInput.button
		if event.type == "InputEventType_Release" then
			if b == "DeviceButton_left mouse button" and dragging then dragging = nil; if selected then TW.setLv(selected, "x", TW.lv(selected, "x")) end end
			if b == "DeviceButton_left mouse button" then panel.release() end
			return false
		end
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
		if b == "DeviceButton_left mouse button" and event.type == "InputEventType_FirstPress" then
			if panelOn and mx >= panel.x and mx <= panel.x + panel.w then
				-- clicks on the panel are handled by its buttons, sliders and tabs
				panel.press(mx, my)
				return false
			end
			-- pressing anywhere on the picked part drags it, even where a smaller part lies over it
			local inSel = false
			if selected then
				local cx, cy, w, h = TW.itemRect(selected)
				inSel = cx and TW.layoutItems[selected].kind ~= "value" and math.abs(mx - cx) <= w / 2 + 4 and math.abs(my - cy) <= h / 2 + 4
			end
			local name = inSel and selected or hitTest(mx, my)
			if name and name == selected then
				-- pressing on the picked part drags it
				dragging = { mx = mx, my = my, base = { x = TW.lv(name, "x"), y = TW.lv(name, "y"), p = TW.coverHeight and TW.coverHeight() or 0 } }
			elseif name then
				selected = name
				panel.follow(name)
				MESSAGEMAN:Broadcast("TWLayoutSelected")
			end
			return false
		end
		if b == "DeviceButton_right mouse button" and event.type == "InputEventType_FirstPress" then
			selected, dragging = nil, nil
			MESSAGEMAN:Broadcast("TWLayoutSelected")
			return false
		end
		if b == "DeviceButton_mousewheel up" or b == "DeviceButton_mousewheel down" then
			-- over the panel: its row's value, or the list scrolls
			if panelOn and mx >= panel.x and mx <= panel.x + panel.w then
				panel.wheel(b == "DeviceButton_mousewheel up" and 1 or -1, mx, my)
				return false
			end
			-- the wheel only sizes the part you picked, wherever the mouse is; with Shift it stretches it
			-- across, with Ctrl down (not for the notefield, whose width is its column width)
			if not selected or TW.layoutItems[selected].kind == "value" then return false end
			local kind = TW.layoutItems[selected].kind
			local field = "z"
			if kind ~= "field" and INPUTFILTER:IsShiftPressed() then field = "w"
			elseif kind ~= "field" and INPUTFILTER:IsControlPressed() then field = "h" end
			nudge(selected, field, (b == "DeviceButton_mousewheel up" and 1 or -1) * 0.05)
			if selected == "field" then MESSAGEMAN:Broadcast("TWRelayout") end
			MESSAGEMAN:Broadcast("TWLayoutSelected")
			return false
		end
		if event.type ~= "InputEventType_FirstPress" and event.type ~= "InputEventType_Repeat" then return false end
		if b == "DeviceButton_h" then panelOn = not panelOn; MESSAGEMAN:Broadcast("TWPanelToggle") return false end
		if not selected then return false end
		local big = INPUTFILTER:IsShiftPressed() and 10 or 1
		local it = TW.layoutItems[selected]
		local rev = TW.stage and TW.stage.reverse
		local ctrl = INPUTFILTER:IsControlPressed()
		-- Ctrl + arrows stretch the picked part (left / right across, up / down down)
		if ctrl and it.kind ~= "field" and (b == "DeviceButton_left" or b == "DeviceButton_right") then
			nudge(selected, "w", (b == "DeviceButton_right" and 0.05 or -0.05) * (big > 1 and 4 or 1))
		elseif ctrl and it.kind ~= "field" and (b == "DeviceButton_up" or b == "DeviceButton_down") then
			nudge(selected, "h", (b == "DeviceButton_up" and 0.05 or -0.05) * (big > 1 and 4 or 1))
		-- the lane cover: up / down how much it covers, left / right its opacity
		elseif it.kind == "cover" and (b == "DeviceButton_left" or b == "DeviceButton_right") then
			nudge(selected, "a", b == "DeviceButton_right" and 0.05 or -0.05)
		elseif it.kind == "cover" and TW.coverMode() ~= 3 and (b == "DeviceButton_up" or b == "DeviceButton_down") then
			-- (up covers more of the lanes, down less)
			TW.setLv(selected, "p", math.max(0, math.min(SCREEN_HEIGHT, TW.coverHeight() + (b == "DeviceButton_up" and 5 or -5) * big)))
		elseif b == "DeviceButton_left" then nudge(selected, "x", -big)
		elseif b == "DeviceButton_right" then nudge(selected, "x", big)
		elseif b == "DeviceButton_up" then
			nudge(selected, "y", big * (((it.kind == "field") and (rev and 1 or -1)) or (it.kind == "receptors" and (rev and -1 or 1)) or -1))
		elseif b == "DeviceButton_down" then
			nudge(selected, "y", big * (((it.kind == "field") and (rev and -1 or 1)) or (it.kind == "receptors" and (rev and 1 or -1)) or 1))
		elseif b == "DeviceButton_=" or b == "DeviceButton_KP +" then nudge(selected, "z", 0.05)
		elseif b == "DeviceButton_-" or b == "DeviceButton_KP -" then nudge(selected, "z", -0.05)
		elseif b == "DeviceButton_r" then TW.resetItem(selected)
		elseif b == "DeviceButton_v" and it.kind == "cover" then TW.setCoverMode(TW.coverMode() == 0 and (TW.coverHasArt and 3 or 1) or 0)
		elseif b == "DeviceButton_v" then TW.setLv(selected, "on", TW.layoutOn(selected) and 0 or 1)
		else return false end
		if selected == "field" or selected == "columns" then MESSAGEMAN:Broadcast("TWRelayout") end
		MESSAGEMAN:Broadcast("TWLayoutSelected")
		return false
	end

	local f = Def.ActorFrame {
		OnCommand = function(self)
			GAMESTATE:SetAutoplay(true)
			SCREENMAN:GetTopScreen():AddInputCallback(input)
			self:SetUpdateFunction(function()
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				if dragging and selected then
					dragTo(selected, mx - dragging.mx, my - dragging.my, dragging.base)
				end
				if panel.held then panel.held(mx, my) end
				local overPanel = panelOn and mx >= panel.x and mx <= panel.x + panel.w
				hovered = (not dragging and not overPanel) and hitTest(mx, my) or nil
				self:GetChild("Sel"):playcommand("Draw")
				self:GetChild("Hover"):playcommand("Draw")
			end)
		end,
		OffCommand = function() TW.customizing = false end,
	}
	-- the selection box
	f[#f + 1] = Def.ActorFrame {
		Name = "Sel",
		DrawCommand = function(self)
			if not selected then self:visible(false) return end
			local cx, cy, w, h = TW.itemRect(selected)
			if not cx or TW.layoutItems[selected].kind == "value" then self:visible(false) return end
			self:visible(true):xy(cx, cy)
			self:GetChild("T"):zoomto(w + 4, 2):y(-h / 2 - 2)
			self:GetChild("B"):zoomto(w + 4, 2):y(h / 2 + 2)
			self:GetChild("L"):zoomto(2, h + 4):x(-w / 2 - 2)
			self:GetChild("R"):zoomto(2, h + 4):x(w / 2 + 2)
			self:GetChild("Name"):y(-h / 2 - 12):settext(TW.layoutItems[selected].label)
		end,
		Def.Quad { Name = "T", InitCommand = function(self) self:diffuse(color("#FFDD33")) end },
		Def.Quad { Name = "B", InitCommand = function(self) self:diffuse(color("#FFDD33")) end },
		Def.Quad { Name = "L", InitCommand = function(self) self:diffuse(color("#FFDD33")) end },
		Def.Quad { Name = "R", InitCommand = function(self) self:diffuse(color("#FFDD33")) end },
		text(11, true, function(self) self:align(0.5, 1):diffuse(color("#FFDD33")) end) .. { Name = "Name" },
	}
	-- a thin outline on the part under the mouse, so you can see what a click would pick
	f[#f + 1] = Def.ActorFrame {
		Name = "Hover",
		DrawCommand = function(self)
			if not hovered or hovered == selected then self:visible(false) return end
			local cx, cy, w, h = TW.itemRect(hovered)
			if not cx then self:visible(false) return end
			self:visible(true):xy(cx, cy)
			self:GetChild("T"):zoomto(w + 4, 1):y(-h / 2 - 2)
			self:GetChild("B"):zoomto(w + 4, 1):y(h / 2 + 2)
			self:GetChild("L"):zoomto(1, h + 4):x(-w / 2 - 2)
			self:GetChild("R"):zoomto(1, h + 4):x(w / 2 + 2)
			self:GetChild("Name"):y(-h / 2 - 10):settext(TW.layoutItems[hovered].label .. " (click to pick)")
		end,
		Def.Quad { Name = "T", InitCommand = function(self) self:diffuse(color("1,1,1,0.6")) end },
		Def.Quad { Name = "B", InitCommand = function(self) self:diffuse(color("1,1,1,0.6")) end },
		Def.Quad { Name = "L", InitCommand = function(self) self:diffuse(color("1,1,1,0.6")) end },
		Def.Quad { Name = "R", InitCommand = function(self) self:diffuse(color("1,1,1,0.6")) end },
		text(9, false, function(self) self:align(0.5, 1):diffuse(color("1,1,1,0.8")) end) .. { Name = "Name" },
	}

	-- ---------------------------------------------------------------------------------------------
	-- the panel, in the look's own style: osu!'s settings (lazer) in the osu! look, Quaver's options
	-- dialog in the Quaver look. Five tabs; every value has a slider (drag it or click on it) and - / +,
	-- the lane cover its modes and colours, and every HUD part its switch. The header drags the panel
	-- across the screen (out of a wide notefield's way).
	-- ---------------------------------------------------------------------------------------------
	local M = TW.M
	local Q = TW.isQuaver == true
	-- (osu!'s font draws bigger than Quaver's Lato at the same size)
	local FS = Q and 1 or 0.8
	local function T(px, bold, init)
		if Q then return QV.t(M(px), bold, init) end
		return TW.text(M(px * FS), bold, init)
	end
	local S
	if Q then
		S = {
			bg = TW.rgb(47, 47, 47, 0.97), head = TW.rgb(31, 31, 31), tabs = TW.rgb(36, 36, 36), tabOn = TW.rgb(36, 48, 48),
			card = TW.rgb(38, 38, 38), cardOn = TW.rgb(40, 52, 56), track = TW.rgb(25, 25, 25), seg = TW.rgb(25, 25, 25),
			accent = QV.lightCyan, onText = TW.rgb(16, 20, 24), text = color("#FFFFFF"), dim = QV.grey,
			btn = TW.rgb(25, 25, 25), btnText = QV.lightCyan, danger = TW.rgb(170, 34, 60), rule = TW.rgb(12, 183, 231, 0.5),
		}
	else
		S = {
			bg = TW.rgb(31, 29, 40, 0.96), head = TW.rgb(23, 22, 30), tabs = TW.rgb(23, 22, 30), tabOn = TW.rgb(23, 22, 30),
			card = TW.rgb(255, 255, 255, 0), cardOn = TW.rgb(255, 255, 255, 0.07), track = TW.rgb(255, 255, 255, 0.16),
			seg = TW.rgb(0, 0, 0, 0.32), accent = TW.pink, onText = color("#FFFFFF"), text = color("#FFFFFF"),
			dim = TW.rgb(165, 160, 182), btn = TW.rgb(255, 255, 255, 0.11), btnText = color("#FFFFFF"),
			danger = TW.rgb(204, 51, 85), rule = TW.rgb(255, 255, 255, 0.14),
		}
	end
	local PW, PAD = M(410), M(18)
	local CW = PW - 2 * PAD
	local HH, TH, FOOT = M(66), M(38), M(126)
	local CY0, CYMAX = HH + TH + M(8), SCREEN_HEIGHT - FOOT
	panel.w = PW
	local function placePanel() panel.x = math.max(0, math.min(SCREEN_WIDTH - PW, TW.lv("editorpanel", "x"))) end
	placePanel()

	-- the rows of each tab
	local TABS = { { "field", "Notefield" }, { "notes", "Notes" }, { "receptors", "Receptors" }, { "cover", "Lane cover" }, { "light", "Lighting" }, { "hud", "HUD" } }
	local tab, first = "field", 1
	local function itemOf(r) if type(r.item) == "function" then return r.item() end return r.item end
	local function V(label, item, field, fmt, lo, hi, st) return { kind = "slider", label = label, item = item, field = field, fmt = fmt, lo = lo, hi = hi, step = st } end
	local function H(text) return { kind = "head", text = text } end
	local function pickedOk() return selected and TW.layoutItems[selected] and TW.layoutItems[selected].kind == "hud" end
	local function picked() return selected end
	local listItems = {}
	for _, name in ipairs(TW.layoutOrder) do
		if TW.layoutItems[name].kind == "hud" then listItems[#listItems + 1] = name end
	end
	local SH, SW = SCREEN_HEIGHT, SCREEN_WIDTH
	local function rowsFor(t)
		if t == "field" then
			return {
				H("Position"),
				V("Notefield X", "field", "x", "%+dpx", -SW / 2, SW / 2, 1),
				V("Hit position", "field", "y", "%+dpx", -SH / 4, SH / 2, 1),
				H("Size and spacing"),
				V("Notefield size", "field", "z", "%.2fx", 0.5, 1.5, 0.05),
				V("Column spacing", "columns", "x", "%+dpx", -32, 96, 1),
				V("Note spacing", "columns", "n", "%+dpx", -32, 96, 1),
				{ kind = "info", text = "Note spacing moves the notes apart from their columns (0 keeps them on their receptors), for skins whose notes and receptors don't line up." },
			}
		elseif t == "notes" then
			return {
				H("Notes"),
				V("Note size", "notes", "z", "%.2fx", 0.5, 1.5, 0.05),
				V("Note width", "notes", "w", "%.2fx", 0.3, 2, 0.05),
				V("Note height", "notes", "h", "%.2fx", 0.3, 3, 0.05),
				{ kind = "info", text = "Width and height stretch the notes and hold heads across or along their column, on top of their size (VSRG Hub noteskins)." },
				H("Long notes"),
				V("LN tail height", "lntail", "h", "%.2fx", 0.2, 2, 0.05),
				V("LN tail offset", "lntail", "y", "%+dpx", -64, 64, 1),
				H("Stage hint"),
				V("Stage hint offset", "hint", "y", "%+dpx", -80, 80, 1),
				V("Stage hint height", "hint", "h", "%.2fx", 0.2, 3, 0.05),
			}
		elseif t == "receptors" then
			return {
				H("Receptors"),
				V("Receptor offset", "receptors", "y", "%+dpx", -SH / 4, SH / 4, 1),
				V("Receptor size", "receptors", "z", "%.2fx", 0.5, 2, 0.05),
				V("Receptor width", "receptors", "w", "%.2fx", 0.5, 2, 0.05),
				V("Receptor height", "receptors", "h", "%.2fx", 0.5, 2, 0.05),
				{ kind = "info", text = "Width and height stretch receptors that come out too flat or too tall in a skin." },
				H("Drawing order"),
				{ kind = "seg", label = "Receptors", opts = { "As the skin", "Under notes", "Over notes" },
				  get = function() return math.floor(TW.lv("receptors", "o") + 0.5) end,
				  set = function(k) TW.setLv("receptors", "o", k) end },
			}
		elseif t == "light" then
			local function L(title, kind, note)
				local out = {
					H(title),
					{ kind = "seg", label = "Show", opts = { "Off", "On" },
					  get = function() return TW.lv(kind, "on") ~= 0 and 1 or 0 end,
					  set = function(k) TW.setLv(kind, "on", k) end },
					V("Offset X", kind, "x", "%+dpx", -64, 64, 1),
					V("Offset Y", kind, "y", "%+dpx", -128, 128, 1),
					V("Size", kind, "z", "%.2fx", 0.25, 3, 0.05),
					V("Width", kind, "w", "%.2fx", 0.25, 3, 0.05),
					V("Height", kind, "h", "%.2fx", 0.25, 3, 0.05),
				}
				if note then out[#out + 1] = { kind = "info", text = note } end
				return out
			end
			local rows = {}
			for _, part in ipairs({
				L("Hit lighting", "lighting", "osu!'s LightingN, Quaver's hit lighting: the flash when a note is hit."),
				L("Hold lighting", "holdlight", "osu!'s LightingL, Quaver's hold lighting: while a long note is held."),
				L("Column lighting", "collight", "Quaver's column lighting: the lane lit up while its key is down."),
			}) do for _, r in ipairs(part) do rows[#rows + 1] = r end end
			return rows
		elseif t == "cover" then
			local m = TW.coverMode()
			local rows = { H("Lane cover"), { kind = "mode", label = "Covers" } }
			if m == 1 or m == 2 then
				local hr = V("Height", "lanecover", "p", "%dpx", 0, SH, 5)
				hr.get = TW.coverHeight
				rows[#rows + 1] = hr
				rows[#rows + 1] = V("Opacity", "lanecover", "a", "%.2f", 0, 1, 0.05)
				rows[#rows + 1] = { kind = "colours", label = "Colour" }
				rows[#rows + 1] = H("Border")
				rows[#rows + 1] = { kind = "seg", label = "Border", opts = { "None", "Line", "Fade", "Glow" },
					get = function() return math.floor(TW.lv("lanecover", "b") + 0.5) end,
					set = function(k) TW.setLv("lanecover", "b", k) end }
				if TW.lv("lanecover", "b") > 0 then
					rows[#rows + 1] = V("Border height", "lanecover", "bh", "%dpx", 1, 24, 1)
					rows[#rows + 1] = { kind = "colours", label = "Border colour",
						get = function() local c = math.floor(TW.lv("lanecover", "bc") + 0.5); return (c >= 1 and c <= #TW.coverColours) and c or 1 end,
						set = function(k) TW.setLv("lanecover", "bc", k) end }
				end
			elseif m == 3 then
				rows[#rows + 1] = V("Position", "lanecover", "y", "%+dpx", -SH / 2, SH / 2, 1)
				rows[#rows + 1] = V("Size", "lanecover", "z", "%.2fx", 0.5, 2, 0.05)
				rows[#rows + 1] = V("Opacity", "lanecover", "a", "%.2f", 0, 1, 0.05)
			end
			rows[#rows + 1] = { kind = "info", text = (m == 0 and "Sudden covers the end of the lanes the notes come in from, Hidden the receptors' end. " or "")
				.. (TW.coverHasArt and "Skin draws this skin's own lane cover art. " or "")
				.. "Kept per noteskin and key mode; on the screen, drag it or use Up / Down (height) and Left / Right (opacity)." }
			return rows
		end
		-- HUD: the picked part's size, then every part with its switch
		local rows = {}
		if pickedOk() then
			rows[#rows + 1] = H("Picked: " .. TW.layoutItems[selected].label)
			rows[#rows + 1] = V("Size", picked, "z", "%.2fx", 0.25, 3, 0.05)
			rows[#rows + 1] = V("Width", picked, "w", "%.2fx", 0.25, 3, 0.05)
			rows[#rows + 1] = V("Height", picked, "h", "%.2fx", 0.25, 3, 0.05)
			if selected == "errorbar" then rows[#rows + 1] = V("Background opacity", "errorbar", "a", "%.2f", 0, 1, 0.05) end
			if selected == "fps" then
				rows[#rows + 1] = { kind = "info", text = "Shown while playing when Options > Show FPS is on." }
				for _, l in ipairs(TW.FPS_LINES) do
					local fld = l[1]
					rows[#rows + 1] = { kind = "seg", label = l[2], opts = { "Hide", "Show" },
						get = function() return TW.lv("fps", fld) ~= 0 and 1 or 0 end,
						set = function(k) TW.setLv("fps", fld, k) end }
				end
			end
		else
			rows[#rows + 1] = H("Picked part")
			rows[#rows + 1] = { kind = "info", text = "Click a part on the screen or in the list below to pick it, then drag it or nudge it with the arrow keys." }
		end
		rows[#rows + 1] = H("Parts")
		for _, name in ipairs(listItems) do rows[#rows + 1] = { kind = "part", name = name } end
		return rows
	end
	local HEIGHT = { head = M(36), slider = M(58), mode = M(60), seg = M(60), colours = M(62), part = M(32), info = M(40) }

	-- values
	local function relayout(item)
		if item == "field" or item == "columns" then MESSAGEMAN:Broadcast("TWRelayout") end
		MESSAGEMAN:Broadcast("TWLayoutSelected")
	end
	local function setValue(r, v, noSave)
		local item = itemOf(r)
		if not item then return end
		v = math.floor(v / r.step + 0.5) * r.step
		if r.step < 1 then v = math.floor(v * 100 + 0.5) / 100 end
		if r.field == "z" or r.field == "w" or r.field == "h" then v = math.max(0.2, math.min(4, v)) end
		if r.field == "a" then v = math.max(0, math.min(1, v)) end
		if item == "lanecover" and r.field == "p" then v = math.max(0, math.min(SH, v)) end
		TW.setLv(item, r.field, v, noSave)
		relayout(item)
	end
	local function touch(r)
		-- (the notefield, receptors and lane cover are picked on the screen too)
		local item = itemOf(r)
		if item == "field" or item == "receptors" or item == "lanecover" then selected = item end
	end

	-- the actors
	local MAXR = 22
	local regions = {}
	local held = nil
	local p = Def.ActorFrame {
		InitCommand = function(self) self:x(panel.x) end,
		OnCommand = function(self) self:playcommand("Render") end,
		TWPanelToggleMessageCommand = function(self) self:visible(panelOn) end,
		TWLayoutSelectedMessageCommand = function(self) self:playcommand("Render") end,
		TWLayoutChangedMessageCommand = function(self) self:playcommand("Render") end,
		TWNoteskinChangedMessageCommand = function(self) self:playcommand("Render") end,
		Def.Quad { Name = "PanelBg", InitCommand = function(self) self:align(0, 0):zoomto(PW, SH):diffuse(S.bg) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(PW, HH):diffuse(S.head) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):y(HH):zoomto(PW, TH):diffuse(S.tabs) end },
		-- (osu!'s settings: a thin line down the panel's edge; Quaver: the dialog's light rim)
		Def.Quad { InitCommand = function(self) self:align(1, 0):x(PW):zoomto(1, SH):diffuse(Q and TW.rgb(68, 211, 255, 0.35) or TW.rgb(255, 255, 255, 0.12)) end },
		T(Q and 16 or 22, Q, function(self)
			self:align(0, 0.5):xy(PAD, Q and M(25) or M(24)):settext(Q and "CUSTOMIZE GAMEPLAY" or "Customize gameplay")
		end),
		T(Q and 11.5 or 12.5, false, function(self) self:align(0, 0.5):xy(PAD, Q and M(46) or M(49)):diffuse(Q and S.dim or S.accent) end) .. {
			RenderCommand = function(self)
				local ns = ""
				pcall(function() ns = GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin() or "" end)
				self:settext((gameKey() == "kb7" and "7K" or "4K") .. "   " .. ns:gsub("_", " ")):maxwidth((PW - PAD * 2 - M(150)) / self:GetZoom())
			end,
		},
		T(10.5, false, function(self) self:align(1, 0.5):xy(PW - PAD, Q and M(46) or M(49)):settext("drag to move  ·  H hides"):diffuse(S.dim) end),
	}
	-- tabs
	local TW_ = PW / #TABS
	for i, tb in ipairs(TABS) do
		p[#p + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy((i - 1) * TW_, HH) end,
			RenderCommand = function(self)
				local on = tab == tb[1]
				local c = self:GetChildren()
				c.Bg:visible(on and Q)
				c.Bar:visible(on)
				c.Label:diffuse(on and (Q and S.accent or S.text) or S.dim)
			end,
			Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0):zoomto(TW_, TH):diffuse(S.tabOn) end },
			Def.Quad { Name = "Bar", InitCommand = function(self)
				if Q then self:align(0, 1):xy(0, TH):zoomto(TW_, M(3)) else self:align(0.5, 1):xy(TW_ / 2, TH):zoomto(TW_ - M(22), M(3)) end
				self:diffuse(S.accent)
			end },
			T(13, true, function(self) self:align(0.5, 0.5):xy(TW_ / 2, TH / 2):settext(tb[2]):maxwidth((TW_ - M(8)) / self:GetZoom()) end) .. { Name = "Label" },
		}
	end
	-- a row: every kind's actors, the ones its kind uses shown
	local function rowActor(i)
		local r = Def.ActorFrame {
			Name = "R" .. i,
			Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0) end },
			Def.Quad { Name = "Mark", InitCommand = function(self) self:align(0, 0):diffuse(S.accent) end },
			Def.Quad { Name = "Rule", InitCommand = function(self) self:align(0, 0):diffuse(S.rule) end },
			T(Q and 12.5 or 15, true, function(self) self:align(0, 0.5) end) .. { Name = "Head" },
			T(14, Q, function(self) self:align(0, 0.5) end) .. { Name = "Label" },
			T(13.5, true, function(self) self:align(1, 0.5) end) .. { Name = "Value" },
			T(11.5, false, function(self) self:align(0, 0):diffuse(S.dim) end) .. { Name = "Info" },
			Def.Quad { Name = "Track", InitCommand = function(self) self:align(0, 0.5):diffuse(S.track) end },
			Def.Quad { Name = "Fill", InitCommand = function(self) self:align(0, 0.5):diffuse(S.accent) end },
			Def.Quad { Name = "B1", InitCommand = function(self) self:align(0, 0.5):diffuse(S.btn) end },
			Def.Quad { Name = "B2", InitCommand = function(self) self:align(0, 0.5):diffuse(S.btn) end },
			T(15, true, function(self) self:align(0.5, 0.5):settext("-"):diffuse(S.btnText) end) .. { Name = "T1" },
			T(15, true, function(self) self:align(0.5, 0.5):settext("+"):diffuse(S.btnText) end) .. { Name = "T2" },
		}
		if Q then
			-- Quaver: a white handle on the bar, a square check box
			r[#r + 1] = Def.Quad { Name = "Nub", InitCommand = function(self) self:zoomto(M(6), M(18)):diffuse(color("#FFFFFF")) end }
			r[#r + 1] = Def.Quad { Name = "Pill", InitCommand = function(self) self:zoomto(M(18), M(18)):diffuse(S.track) end }
			r[#r + 1] = Def.Quad { Name = "PillRim", InitCommand = function(self) self:zoomto(M(18), M(18)):diffuse(TW.rgb(68, 211, 255, 0.5)) end }
			r[#r + 1] = Def.Quad { Name = "PillIn", InitCommand = function(self) self:zoomto(M(16), M(16)):diffuse(S.track) end }
			r[#r + 1] = Def.Quad { Name = "Knob", InitCommand = function(self) self:zoomto(M(10), M(10)):diffuse(S.accent) end }
		else
			-- osu!: a round nub, a pill switch
			r[#r + 1] = TW.circle(M(8), color("#FFFFFF")) .. { Name = "Nub" }
			r[#r + 1] = Def.Quad { Name = "Pill", InitCommand = function(self) self:zoomto(M(20), M(20)) end }
			r[#r + 1] = TW.circle(M(10), color("#FFFFFF")) .. { Name = "PillRim" }
			r[#r + 1] = TW.circle(M(10), color("#FFFFFF")) .. { Name = "PillIn" }
			r[#r + 1] = TW.circle(M(7), color("#FFFFFF")) .. { Name = "Knob" }
		end
		return r
	end
	for i = 1, MAXR do p[#p + 1] = rowActor(i) end
	-- the lane cover's choices (one row), and its colours
	-- (segment rows and colour rows: a few of each, used in turn by the rows on show)
	local NSEG, NSW = 6, 3
	for si = 1, NSEG do
		local seg = Def.ActorFrame { Name = "Seg" .. si }
		for i = 1, 4 do
			seg[#seg + 1] = Def.Quad { Name = "B" .. i, InitCommand = function(self) self:align(0, 0) end }
			seg[#seg + 1] = T(13, true, function(self) self:align(0.5, 0.5) end) .. { Name = "T" .. i }
		end
		p[#p + 1] = seg
	end
	for si = 1, NSW do
		local sw = Def.ActorFrame { Name = "Sw" .. si }
		for _, n in ipairs({ "OT", "OB", "OL", "OR" }) do sw[#sw + 1] = Def.Quad { Name = n, InitCommand = function(self) self:align(0, 0):diffuse(color("#FFFFFF")) end } end
		for i = 1, #TW.coverColours do
			sw[#sw + 1] = Def.Quad { Name = "C" .. i, InitCommand = function(self) self:align(0, 0):diffuse(color(TW.coverColours[i][2])) end }
		end
		p[#p + 1] = sw
	end
	-- "more below" / "back up" when a tab doesn't fit
	p[#p + 1] = T(11.5, true, function(self) self:align(0.5, 0.5):diffuse(S.accent) end) .. { Name = "More" }
	p[#p + 1] = T(11.5, true, function(self) self:align(0.5, 0.5):diffuse(S.accent) end) .. { Name = "Less" }
	-- the bottom: the two resets and how it works
	p[#p + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(PAD, SH - FOOT + M(6)):zoomto(CW, 1):diffuse(S.rule) end }
	local BW = (CW - M(10)) / 2
	local BY = SH - FOOT + M(18)
	p[#p + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(PAD, BY):zoomto(BW, M(32)):diffuse(S.btn) end }
	p[#p + 1] = T(12.5, true, function(self) self:align(0.5, 0.5):xy(PAD + BW / 2, BY + M(16)):diffuse(S.btnText) end) .. {
		RenderCommand = function(self) self:settext((tab == "hud" and pickedOk()) and "Reset picked part" or "Reset this tab") end,
	}
	p[#p + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(PAD + BW + M(10), BY):zoomto(BW, M(32)):diffuse(S.danger) end }
	p[#p + 1] = T(12.5, true, function(self) self:align(0.5, 0.5):xy(PAD + BW + M(10) + BW / 2, BY + M(16)):settext("Reset everything") end)
	p[#p + 1] = T(10.5, false, function(self)
		self:align(0, 0):xy(PAD, BY + M(42)):diffuse(S.dim):wrapwidthpixels(CW / self:GetZoom())
		self:settext("Click a part on the screen to pick it: drag it, nudge it with the arrows (Shift: x10), size it with the mouse wheel (Shift: wider, Ctrl: taller). Right click lets go. Space skips the intro, Esc when done.")
		-- (kept on the screen)
		local avail = SH - (BY + M(42)) - M(4)
		local tries = 0
		while self:GetZoomedHeight() > avail and tries < 6 do
			self:zoom(self:GetZoom() * 0.92):wrapwidthpixels(CW / self:GetZoom())
			tries = tries + 1
		end
	end)

	local function resetTab()
		local items = { field = { "field", "columns" }, notes = { "notes", "lntail", "hint" }, receptors = { "receptors" }, cover = { "lanecover" },
			light = { "lighting", "holdlight", "collight" } }
		if tab == "hud" then
			if pickedOk() then TW.resetItem(selected) end
		else
			for _, it in ipairs(items[tab] or {}) do TW.resetItem(it) end
		end
		MESSAGEMAN:Broadcast("TWRelayout")
		MESSAGEMAN:Broadcast("TWLayoutSelected")
	end
	local function region(x0, y0, x1, y1, spec)
		spec.x0, spec.y0, spec.x1, spec.y1 = x0, y0, x1, y1
		regions[#regions + 1] = spec
	end

	-- draw the tab's rows; every clickable place goes in regions (panel coordinates)
	p.RenderCommand = function(self)
		placePanel()
		self:x(panel.x)
		regions = {}
		-- header: drag the panel
		region(0, 0, PW, HH, { press = function(mx) return { kind = "panel", mx = mx, base = TW.lv("editorpanel", "x") } end })
		for i, tb in ipairs(TABS) do
			region((i - 1) * TW_, HH, i * TW_, HH + TH, { press = function() tab = tb[1]; first = 1 end })
		end
		region(PAD, BY, PAD + BW, BY + M(32), { press = function() resetTab() end })
		region(PAD + BW + M(10), BY, PAD + CW, BY + M(32), { press = function()
			TW.resetLayout(); MESSAGEMAN:Broadcast("TWRelayout"); MESSAGEMAN:Broadcast("TWLayoutSelected")
		end })
		local rows = rowsFor(tab)
		first = math.max(1, math.min(first, #rows))
		local c = self:GetChildren()
		for si = 1, NSEG do c["Seg" .. si]:visible(false) end
		for si = 1, NSW do c["Sw" .. si]:visible(false) end
		local nSeg, nSw = 0, 0
		local y = CY0
		local n = 0
		local overflow = false
		for ri = first, #rows do
			local r = rows[ri]
			local h = HEIGHT[r.kind]
			if r.kind == "info" then
				h = M(14) + math.ceil(#r.text / 62) * M(15)
			end
			if y + h > CYMAX then overflow = true break end
			n = n + 1
			if n > MAXR then overflow = true break end
			local a = c["R" .. n]
			local ac = a:GetChildren()
			a:visible(true):y(y)
			for _, k in ipairs({ "Bg", "Mark", "Rule", "Head", "Label", "Value", "Info", "Track", "Fill", "Nub", "B1", "B2", "T1", "T2", "Pill", "PillRim", "PillIn", "Knob" }) do
				ac[k]:visible(false)
			end
			ac.Value:zoom(M(13.5) * FS / (Q and 24 or 17))
			ac.Label:maxwidth(CW * 0.62 / ac.Label:GetZoom())
			local item = (r.kind == "slider" and itemOf(r)) or (r.kind == "part" and r.name) or ((r.kind == "mode" or (r.kind == "colours" and not r.get)) and "lanecover") or nil
			-- (the picked part's own rows sit under its name: no highlight)
			local on = item ~= nil and item == selected and type(r.item) ~= "function" and tab ~= "cover"
			-- the row's card (Quaver) or its highlight when picked (osu!)
			if r.kind ~= "head" and r.kind ~= "info" then
				ac.Bg:visible(Q or on):xy(Q and PAD or PAD - M(8), 0):zoomto(Q and CW or CW + M(16), h - M(Q and 6 or 2)):diffuse(on and S.cardOn or S.card)
				ac.Mark:visible(on):xy(Q and PAD or PAD - M(8), 0):zoomto(M(3), h - M(Q and 6 or 2))
			end
			local LX = PAD + (Q and M(14) or M(4))
			local RX = PAD + CW - (Q and M(14) or M(4))
			if r.kind == "head" then
				ac.Head:visible(true):xy(PAD, M(20)):settext(Q and r.text:upper() or r.text):diffuse(Q and S.accent or S.text)
					:maxwidth(CW / ac.Head:GetZoom())
				ac.Rule:visible(true):xy(PAD, M(31)):zoomto(CW, 1)
			elseif r.kind == "info" then
				ac.Info:visible(true):xy(LX, M(4)):wrapwidthpixels((RX - LX) / ac.Info:GetZoom()):settext(r.text)
			elseif r.kind == "slider" then
				local v = (r.get and r.get()) or (item and TW.lv(item, r.field)) or 0
				ac.Label:visible(true):xy(LX, M(17)):settext(r.label):diffuse(on and S.accent or S.text)
				ac.Value:visible(true):xy(RX, M(17)):settext(string.format(r.fmt, r.fmt:find("d") and math.floor(v + 0.5) or v))
					:diffuse(Q and S.accent or S.text)
				local ty = M(39)
				local bx2 = RX - M(26)
				local bx1 = bx2 - M(30)
				local tx0, tx1 = LX + M(2), bx1 - M(16)
				local tw = tx1 - tx0
				local frac = math.max(0, math.min(1, (v - r.lo) / (r.hi - r.lo)))
				ac.Track:visible(true):xy(tx0, ty):zoomto(tw, Q and M(6) or M(4))
				ac.Fill:visible(true):xy(tx0, ty):zoomto(math.max(0.01, tw * frac), Q and M(6) or M(4))
				ac.Nub:visible(true):xy(tx0 + tw * frac, ty)
				if not Q then ac.Nub:diffuse(S.accent) end
				ac.B1:visible(true):xy(bx1, ty):zoomto(M(26), M(22))
				ac.B2:visible(true):xy(bx2, ty):zoomto(M(26), M(22))
				ac.T1:visible(true):xy(bx1 + M(13), ty - M(1))
				ac.T2:visible(true):xy(bx2 + M(13), ty - M(1))
				-- (the row first: the slider and buttons on it are found before it)
				region(PAD, y, PAD + CW, y + h, { press = function() touch(r); MESSAGEMAN:Broadcast("TWLayoutSelected") end,
					wheel = function(d) touch(r); setValue(r, ((r.get and r.get()) or TW.lv(itemOf(r), r.field)) + d * r.step) end })
				local function at(mx) return r.lo + (r.hi - r.lo) * math.max(0, math.min(1, (mx - panel.x - tx0) / tw)) end
				region(tx0 - M(8), y + ty - M(12), tx1 + M(8), y + ty + M(12), { press = function(mx)
					touch(r); setValue(r, at(mx), true)
					return { kind = "slider", move = function(mx2) setValue(r, at(mx2), true) end, done = function() setValue(r, (r.get and r.get()) or TW.lv(itemOf(r), r.field)) end }
				end })
				region(bx1, y + ty - M(12), bx1 + M(26), y + ty + M(12), { press = function() touch(r); setValue(r, v - r.step) end })
				region(bx2, y + ty - M(12), bx2 + M(26), y + ty + M(12), { press = function() touch(r); setValue(r, v + r.step) end })
			elseif r.kind == "mode" then
				ac.Label:visible(true):xy(LX, M(17)):settext(r.label):diffuse(on and S.accent or S.text)
				ac.Value:visible(true):xy(RX, M(17)):settext(TW.coverModes[TW.coverMode()]):diffuse(Q and S.accent or S.text)
				local opts = TW.coverHasArt and 4 or 3
				local gap = M(6)
				local sw_ = (RX - LX - gap * (opts - 1)) / opts
				local sy = M(28)
				nSeg = nSeg + 1
				local segA = c["Seg" .. nSeg]
				segA:visible(true):xy(LX, y + sy)
				local sc = segA:GetChildren()
				for k = 1, 4 do
					local mk = k - 1
					local show = k <= opts
					local act = TW.coverMode() == mk
					sc["B" .. k]:visible(show):xy((k - 1) * (sw_ + gap), 0):zoomto(sw_, M(24)):diffuse(act and S.accent or S.seg)
					sc["T" .. k]:visible(show):xy((k - 1) * (sw_ + gap) + sw_ / 2, M(12)):settext(TW.coverModes[mk])
						:diffuse(act and S.onText or S.dim):maxwidth((sw_ - M(6)) / sc["T" .. k]:GetZoom())
					if show then
						local x0 = LX + (k - 1) * (sw_ + gap)
						region(x0, y + sy, x0 + sw_, y + sy + M(24), { press = function() selected = "lanecover"; TW.setCoverMode(mk); MESSAGEMAN:Broadcast("TWLayoutSelected") end })
					end
				end
				region(PAD, y, PAD + CW, y + h, { wheel = function(d)
					selected = "lanecover"
					TW.setCoverMode((TW.coverMode() - d) % opts)
					MESSAGEMAN:Broadcast("TWLayoutSelected")
				end })
			elseif r.kind == "seg" and nSeg < NSEG then
				-- a choice of a few: get() / set(k), k from 0
				local cur = r.get()
				local opts = #r.opts
				ac.Label:visible(true):xy(LX, M(17)):settext(r.label):diffuse(S.text)
				ac.Value:visible(true):xy(RX, M(17)):settext(r.opts[cur + 1] or ""):diffuse(Q and S.accent or S.text)
				local gap = M(6)
				local sw_ = (RX - LX - gap * (opts - 1)) / opts
				local sy = M(28)
				nSeg = nSeg + 1
				local segA = c["Seg" .. nSeg]
				segA:visible(true):xy(LX, y + sy)
				local sc = segA:GetChildren()
				for k = 1, 4 do
					local show = k <= opts
					local act = cur == k - 1
					sc["B" .. k]:visible(show):xy((k - 1) * (sw_ + gap), 0):zoomto(sw_, M(24)):diffuse(act and S.accent or S.seg)
					sc["T" .. k]:visible(show):xy((k - 1) * (sw_ + gap) + sw_ / 2, M(12)):settext(r.opts[k] or "")
						:diffuse(act and S.onText or S.dim):maxwidth((sw_ - M(6)) / sc["T" .. k]:GetZoom())
					if show then
						local x0 = LX + (k - 1) * (sw_ + gap)
						region(x0, y + sy, x0 + sw_, y + sy + M(24), { press = function() r.set(k - 1); MESSAGEMAN:Broadcast("TWLayoutSelected") end })
					end
				end
				region(PAD, y, PAD + CW, y + h, { wheel = function(d) r.set((cur - d) % opts); MESSAGEMAN:Broadcast("TWLayoutSelected") end })
			elseif r.kind == "colours" and nSw < NSW then
				local ci = r.get and r.get() or TW.coverColour()
				local setC = r.set or function(k) TW.setLv("lanecover", "c", k) end
				ac.Label:visible(true):xy(LX, M(17)):settext(r.label):diffuse(on and S.accent or S.text)
				ac.Value:visible(true):xy(RX, M(17)):settext(TW.coverColours[ci][1]):diffuse(Q and S.accent or S.text)
				local nC = #TW.coverColours
				local gap = M(5)
				local sz = (RX - LX - gap * (nC - 1)) / nC
				local sy = M(30)
				nSw = nSw + 1
				local swA = c["Sw" .. nSw]
				swA:visible(true):xy(LX, y + sy)
				local sc = swA:GetChildren()
				for k = 1, nC do
					sc["C" .. k]:xy((k - 1) * (sz + gap), 0):zoomto(sz, sz)
					local x0 = LX + (k - 1) * (sz + gap)
					region(x0, y + sy, x0 + sz, y + sy + sz, { press = function()
						selected = "lanecover"; setC(k); MESSAGEMAN:Broadcast("TWLayoutSelected")
					end })
				end
				-- (a white frame round the chosen one)
				local ox = (ci - 1) * (sz + gap)
				local t2 = M(2)
				sc.OT:xy(ox - t2, -t2):zoomto(sz + 2 * t2, t2)
				sc.OB:xy(ox - t2, sz):zoomto(sz + 2 * t2, t2)
				sc.OL:xy(ox - t2, 0):zoomto(t2, sz)
				sc.OR:xy(ox + sz, 0):zoomto(t2, sz)
				region(PAD, y, PAD + CW, y + h, { wheel = function(d)
					selected = "lanecover"
					setC((ci - 1 - d) % nC + 1)
					MESSAGEMAN:Broadcast("TWLayoutSelected")
				end })
			elseif r.kind == "part" then
				local name = r.name
				local it = TW.layoutItems[name]
				local shown = TW.layoutOn(name)
				ac.Label:visible(true):xy(LX, h / 2 - M(2)):settext(it.label)
					:diffuse(on and S.accent or (shown and S.text or S.dim)):maxwidth(CW * 0.5 / ac.Label:GetZoom())
				local moved = TW.lv(name, "x") ~= 0 or TW.lv(name, "y") ~= 0 or TW.lv(name, "z") ~= 1
				ac.Value:visible(moved):xy(RX - M(52), h / 2 - M(2))
					:settext(moved and string.format("%+d, %+d   %.2fx", TW.lv(name, "x"), TW.lv(name, "y"), TW.lv(name, "z")) or "")
					:diffuse(S.dim):zoom(M(11) * FS / (Q and 24 or 17))
				-- the switch
				local kx, ky = RX - M(20), h / 2 - M(2)
				if Q then
					ac.PillRim:visible(true):xy(kx, ky)
					ac.PillIn:visible(true):xy(kx, ky)
					ac.Knob:visible(shown):xy(kx, ky)
				else
					local pw = M(36)
					ac.Pill:visible(true):xy(kx, ky):zoomto(pw - M(20), M(20)):diffuse(shown and S.accent or TW.rgb(255, 255, 255, 0.18))
					ac.PillRim:visible(true):xy(kx - (pw - M(20)) / 2, ky):diffuse(shown and S.accent or TW.rgb(255, 255, 255, 0.18))
					ac.PillIn:visible(true):xy(kx + (pw - M(20)) / 2, ky):diffuse(shown and S.accent or TW.rgb(255, 255, 255, 0.18))
					ac.Knob:visible(true):xy(kx + (shown and 1 or -1) * (pw - M(20)) / 2, ky):diffuse(color("#FFFFFF"))
				end
				region(kx - M(26), y, PAD + CW, y + h, { press = function() TW.setLv(name, "on", TW.layoutOn(name) and 0 or 1) end })
				region(PAD, y, kx - M(26), y + h, { press = function() selected = name; MESSAGEMAN:Broadcast("TWLayoutSelected") end })
			end
			y = y + h
		end
		for i = n + 1, MAXR do c["R" .. i]:visible(false) end
		-- scrolling
		c.More:visible(overflow):xy(PW / 2, CYMAX - M(10)):settext("more below")
		c.Less:visible(first > 1):xy(PW / 2, CY0 - M(2)):settext("back up")
		if overflow then region(PAD, CYMAX - M(20), PAD + CW, CYMAX, { press = function() first = first + 3 end }) end
		if first > 1 then region(PAD, CY0 - M(10), PAD + CW, CY0 + M(6), { press = function() first = math.max(1, first - 3) end }) end
		panel.overflow = overflow
	end

	-- the mouse on the panel (screen coordinates in, panel coordinates for the regions)
	local function find(mx, my, field)
		local lx = mx - panel.x
		-- (the last one added wins: buttons and sliders sit on their row)
		for i = #regions, 1, -1 do
			local rg = regions[i]
			if rg[field] and lx >= rg.x0 and lx <= rg.x1 and my >= rg.y0 and my <= rg.y1 then return rg end
		end
	end
	panel.press = function(mx, my)
		local rg = find(mx, my, "press")
		if not rg then return end
		held = rg.press(mx, my)
		if held and held.kind == "panel" then
			panel.held = function(mx2)
				TW.setLv("editorpanel", "x", math.floor(held.base + (mx2 - held.mx) + 0.5), true)
				placePanel()
				MESSAGEMAN:Broadcast("TWLayoutSelected")
			end
		elseif held and held.move then
			panel.held = function(mx2) held.move(mx2) end
		end
		MESSAGEMAN:Broadcast("TWLayoutSelected")
	end
	panel.release = function()
		if held and held.done then held.done() end
		if held and held.kind == "panel" then TW.setLv("editorpanel", "x", TW.lv("editorpanel", "x")) end
		held, panel.held = nil, nil
	end
	panel.wheel = function(d, mx, my)
		local rg = find(mx, my, "wheel")
		if rg then rg.wheel(d)
		elseif d < 0 and panel.overflow then first = first + 1
		elseif d > 0 then first = math.max(1, first - 1) end
		MESSAGEMAN:Broadcast("TWLayoutSelected")
	end
	-- a part picked on the screen opens its tab
	panel.follow = function(name)
		local it = TW.layoutItems[name]
		if not it then return end
		local want = (name == "field" and "field") or (name == "receptors" and "receptors") or (it.kind == "cover" and "cover") or (it.kind == "hud" and "hud") or tab
		if want ~= tab then tab, first = want, 1 end
	end
	f[#f + 1] = p
	return f
end
