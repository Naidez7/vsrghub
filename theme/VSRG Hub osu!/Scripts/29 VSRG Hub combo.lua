-- The combo's digits from any skin (Options > Combo skin, and VSRG Hub's menu in Til' Death and
-- Rebirth): the notes' own skin (as before) or any osu! skin with combo digits, or a Quaver skin's.
-- Kept as combo_skin = "" / "osu:<skin folder>" / "qv:<noteskin>".
function TW.comboChoice() return (TW.settings and TW.settings.combo_skin) or "" end
-- the skin picked, if it is still there: { kind = "osu", skin = TW_SKINS entry } or
-- { kind = "qv", hud = the Quaver skin's HUD } (nil: the notes' skin)
function TW.comboPick(v)
	v = v or TW.comboChoice()
	local f = v:match("^osu:(.*)$")
	if f then
		local e = TW_SKINS and TW_SKINS[f]
		if e and e.files and e.files.combo_0 then return { kind = "osu", skin = e, folder = f } end
		return nil
	end
	local n = v:match("^qv:(.*)$")
	if n then
		local info = TW_NOTESKINS and TW_NOTESKINS[n:lower()]
		if not info and TW_NOTESKINS_GAME then
			for _, g in pairs(TW_NOTESKINS_GAME) do if g[n:lower()] then info = g[n:lower()] end end
		end
		if info and info.qv and info.qv.combo then return { kind = "qv", hud = info.qv } end
	end
	return nil
end
-- the choices: { label, value, sub }
function TW.comboItems()
	local items = { { label = "The notes' skin", value = "", sub = "as the skin you play with has it" } }
	local folders = {}
	for f, e in pairs(TW_SKINS or {}) do if e.files and e.files.combo_0 then folders[#folders + 1] = f end end
	table.sort(folders, function(a, b) return (TW_SKINS[a].name or a):lower() < (TW_SKINS[b].name or b):lower() end)
	for _, f in ipairs(folders) do
		local e = TW_SKINS[f]
		items[#items + 1] = { label = e.name or f, value = "osu:" .. f, sub = "osu! skin" }
	end
	local seen, qv = {}, {}
	local function add(name, info)
		if info and info.qv and info.qv.combo and not seen[name] then
			seen[name] = true
			qv[#qv + 1] = name
		end
	end
	for name, info in pairs(TW_NOTESKINS or {}) do add(name, info) end
	for _, g in pairs(TW_NOTESKINS_GAME or {}) do for name, info in pairs(g) do add(name, info) end end
	table.sort(qv)
	for _, n in ipairs(qv) do
		items[#items + 1] = { label = (TW.prettyNoteskin and TW.prettyNoteskin(n) or n), value = "qv:" .. n, sub = "Quaver skin" }
	end
	return items
end
function TW.comboLabel()
	local v = TW.comboChoice()
	for _, it in ipairs(TW.comboItems()) do if it.value == v then return it.label end end
	return "The notes' skin"
end
function TW.setComboSkin(v)
	TW.saveSetting("combo_skin", v or "")
	MESSAGEMAN:Broadcast("TWComboSkinChanged")
end
-- a choice's digit pictures for the preview: { [0..9] = path }, their zoom for osu!'s size and
-- the overlap between them (nil: the notes' skin, which has no one picture set)
function TW.comboDigitPics(v)
	local p = TW.comboPick(v)
	if not p then
		-- (the notes' skin: the one in use now)
		local ok, ns = pcall(function() return GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin() end)
		local info = ok and ns and TW.noteskinInfo(ns)
		if info and info.skin and TW_SKINS and TW_SKINS[info.skin] then p = TW.comboPick("osu:" .. info.skin)
		elseif info and info.qv and info.qv.combo then p = { kind = "qv", hud = info.qv } end
		if not p then return nil end
	end
	local out = {}
	if p.kind == "osu" then
		local e = p.skin
		for i = 0, 9 do out[i] = e.files["combo_" .. i] and (e.dir .. e.files["combo_" .. i]) or nil end
		out.zoom = (e.hd and e.hd.combo_0) and 0.5 or 1
		out.overlap = e.comboOverlap or 0
	else
		for i = 0, 9 do out[i] = p.hud.combo[i] end
		out.zoom, out.overlap = 1, 0
	end
	return out
end
-- the preview in the list: "727" in the digits under the cursor, centred at 0,0, fitted to pw x ph
function TW.comboPreview(pw, ph)
	local row = Def.ActorFrame { Name = "Row" }
	for i = 1, 3 do row[#row + 1] = Def.Sprite { Name = "D" .. i, InitCommand = function(self) self:visible(false) end } end
	return Def.ActorFrame {
		Name = "ComboPreview",
		SetComboCommand = function(self, p)
			local pics = TW.comboDigitPics(p.value)
			local r = self:GetChild("Row")
			local plain = self:GetChild("Plain")
			local text = "727"
			if not pics then
				for i = 1, 3 do r:GetChild("D" .. i):visible(false) end
				plain:visible(true):settext(text)
				return
			end
			plain:visible(false)
			local x, h = 0, 0
			for i = 1, 3 do
				local s = r:GetChild("D" .. i)
				local path = pics[tonumber(text:sub(i, i))]
				s:visible(path ~= nil)
				if path then
					s:Load(path):align(0, 0.5):zoom(pics.zoom):x(x)
					x = x + s:GetZoomedWidth() - (i < 3 and pics.overlap * (pics.zoom == 0.5 and 1 or 1) or 0)
					h = math.max(h, s:GetZoomedHeight())
				end
			end
			local w = math.max(1, x)
			local fit = math.min(2.5, pw * 0.8 / w, ph * 0.5 / math.max(1, h))
			r:zoom(fit):x(-w * fit / 2)
		end,
		row,
		LoadFont("Common Normal") .. { Name = "Plain", InitCommand = function(self) self:zoom(1.5):visible(false) end },
	}
end
