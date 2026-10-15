-- Written by VSRG Hub next to its theme picker in Etterna's own themes and loaded by every look (the
-- VSRG Hub looks fall back to Til Death and load it from their scripts too). TWKeys: the keybinds.
--
--  * VSRG Hub's own shortcuts (options, random song, pausing...) can be changed; they are kept in
--    Save/VSRGHub/keys.ini as "id=binding", a binding being its modifiers (C, S, A) then "#" and
--    Etterna's name of the key ("C#o" is Ctrl+O, "#F1" is F1, "#space" is Space).
--  * Etterna's own buttons (the note keys of the mode being played, restart, rate up / down) are
--    changed in Etterna's key map (Save/Keymaps.ini) through INPUTMAPPER, as Etterna's key config does.
--  * Everything else a player should know is listed as it is (Etterna's and each theme's keys).
--
-- A key is picked by pressing it: TWKeys.capture(row) and the next key press is taken here, on
-- Etterna's system layer, before any screen sees it. A key that something else already uses where
-- the shortcut works is refused, with the reason; a key another shortcut has is swapped with it.

local FILE = "Save/VSRGHub/keys.ini"
local K = {}
TWKeys = K

-- the looks: osu!, Quaver, Til' Death, Rebirth
local function look()
	local ok, n = pcall(function() return THEME:GetCurThemeName() end)
	n = ok and n or ""
	if n == "VSRG Hub osu!" or n == "VSRG Hub lazer" then return "O" elseif n == "VSRG Hub Quaver" then return "Q"
	elseif n == "Rebirth" then return "R" end
	return "T"
end
K.look = look
local function inLook(looks, l) return looks == nil or looks:find(l or look(), 1, true) ~= nil end

-- VSRG Hub's shortcuts: default binding and where they work ("menu": main menu, song select and
-- results; "select": song select; "play": while playing)
local ACTIONS = {
	options = { def = "C#o", ctx = "menu" },
	keybinds = { def = "C#k", ctx = "menu" },
	pausetoggle = { def = "C#p", ctx = "menu" },
	mods = { def = "#F1", ctx = "select", looks = "OQ" },
	random = { def = "C#r", ctx = "select", looks = "OQ" },
	beatmap = { def = "#F3", ctx = "select", looks = "OQ" },
	preview = { def = "#tab", ctx = "select", looks = "OQ" },
	pause = { def = "#escape", ctx = "play" },
	skip = { def = "#space", ctx = "play" },
	-- (osu!'s and Quaver's: at the start of a song, as they allow)
	scrolldown = { def = "#F3", ctx = "play", looks = "OQ" },
	scrollup = { def = "#F4", ctx = "play", looks = "OQ" },
}
K.actions = ACTIONS

-- the saved bindings ------------------------------------------------------------------------------
local over = {}
-- what a key prints with the player's keyboard layout (Etterna names keys by a US layout: on a Spanish
-- keyboard its "/" is the key marked "-"), learnt when a key is picked: chars["/"] = "-"
local chars = {}
local function load()
	over, chars = {}, {}
	-- (no file yet: the defaults, without Etterna logging a read error)
	local okE, exists = pcall(function() return FILEMAN:DoesFileExist(FILE) end)
	if okE and exists == false then return end
	local ok, txt = pcall(function() return File.Read(FILE) end)
	if not ok or type(txt) ~= "string" then return end
	for line in txt:gmatch("[^\r\n]+") do
		local id, b = line:match("^([%w_]+)=(.*)$")
		if id and ACTIONS[id] and b:match("^[CSA]*#.+$") then over[id] = b end
		local k, ch = line:match("^@(.)=(.+)$")
		if k then chars[k] = ch end
	end
end
local function save()
	local lines = { "# VSRG Hub keybinds (change them in the options: Keybinds). Delete this file for the defaults." }
	local ids = {}
	for id in pairs(over) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do lines[#lines + 1] = id .. "=" .. over[id] end
	for k, ch in pairs(chars) do lines[#lines + 1] = "@" .. k .. "=" .. ch end
	pcall(function() File.Write(FILE, table.concat(lines, "\n") .. "\n") end)
end
load()
K.reload = load

function K.binding(id)
	local a = ACTIONS[id]
	if not a then return nil end
	return over[id] or a.def
end
local function parse(b)
	if not b then return nil end
	local m, n = b:match("^([CSA]*)#(.+)$")
	if not m then return nil end
	return { ctrl = m:find("C", 1, true) ~= nil, shift = m:find("S", 1, true) ~= nil, alt = m:find("A", 1, true) ~= nil, name = n }
end
K.parse = parse

-- the keys held down -----------------------------------------------------------------------------
local held = { alt = false }
local function altHeld()
	local ok, a = pcall(function() return INPUTFILTER:IsBeingPressed("left alt") or INPUTFILTER:IsBeingPressed("right alt") end)
	if ok then return a == true end
	return held.alt
end
local function mods()
	local c, s = false, false
	pcall(function() c = INPUTFILTER:IsControlPressed(); s = INPUTFILTER:IsShiftPressed() end)
	return c, s, altHeld()
end
local MODIFIERS = { ["left ctrl"] = true, ["right ctrl"] = true, ["left shift"] = true, ["right shift"] = true,
	["left alt"] = true, ["right alt"] = true, ["left meta"] = true, ["right meta"] = true,
	["left super"] = true, ["right super"] = true, ["menu"] = true, ["function"] = true }
local function keyName(event)
	local b = event and event.DeviceInput and event.DeviceInput.button
	return b and b:match("^DeviceButton_(.+)$") or nil
end

-- true when this key press is the shortcut's key (its modifiers exactly)
function K.is(event, id)
	local p = parse(K.binding(id))
	if not p then return false end
	if keyName(event) ~= p.name then return false end
	local c, s, a = mods()
	return c == p.ctrl and s == p.shift and a == p.alt
end

-- names as a player reads them -----------------------------------------------------------------
local NAMES = { escape = "Esc", space = "Space", tab = "Tab", enter = "Enter", backspace = "Backspace", delete = "Delete",
	comma = ",", period = ".", colon = ":", backslash = "\\", insert = "Insert", home = "Home", ["end"] = "End",
	pgup = "Page Up", pgdn = "Page Down", up = "Up", down = "Down", left = "Left", right = "Right",
	["scroll lock"] = "Scroll Lock", ["caps lock"] = "Caps Lock", ["num lock"] = "Num Lock", prtsc = "Print Screen",
	pause = "Pause", menu = "Menu", ["left shift"] = "Left Shift", ["right shift"] = "Right Shift",
	["left ctrl"] = "Left Ctrl", ["right ctrl"] = "Right Ctrl", ["left alt"] = "Left Alt", ["right alt"] = "Right Alt",
	["KP enter"] = "Num Enter", ["`"] = "` (~)" }
function K.keyText(name)
	if not name or name == "" then return "none" end
	if NAMES[name] then return NAMES[name] end
	local kp = name:match("^KP (.+)$")
	if kp then return "Num " .. kp end
	if #name == 1 then return (chars[name] or name):upper() end
	return name
end
function K.text(b)
	local p = parse(b)
	if not p then return "none" end
	return (p.ctrl and "Ctrl+" or "") .. (p.shift and "Shift+" or "") .. (p.alt and "Alt+" or "") .. K.keyText(p.name)
end
function K.label(id) return K.text(K.binding(id)) end

-- Etterna's buttons (its key map) ---------------------------------------------------------------
local function gameName()
	local ok, g = pcall(function() return GAMESTATE:GetCurrentGame():GetName() end)
	return ok and g or "dance"
end
K.gameName = gameName
local COLUMNS = { dance = { "Left", "Down", "Up", "Right" }, kb7 = { "Key1", "Key2", "Key3", "Key4", "Key5", "Key6", "Key7" } }
function K.columns()
	local c = COLUMNS[gameName()]
	if c then return c end
	local ok, list = pcall(function() return INPUTMAPPER:GetGameButtonsToMap() end)
	return ok and list or {}
end
-- the device keys of a button, player 1 (Etterna's "Key_z")
function K.gameKeys(button, controller)
	local out = {}
	for col = 0, 4 do
		local ok, d = pcall(function() return INPUTMAPPER:GetButtonMapping(button, controller or 0, col) end)
		if ok and d and d ~= "" then out[#out + 1] = d end
	end
	return out
end
local function devText(d)
	local dev, name = d:match("^([^_]+)_(.+)$")
	if not dev then return d end
	if dev == "Key" then return K.keyText(name) end
	return dev .. " " .. name
end
K.devText = devText
-- (Etterna names them with the keyboard's layout: "Key ¡" on a Spanish keyboard for the US "=")
local function shownDev(button, col, d)
	local ok, s = pcall(function() return INPUTMAPPER:GetButtonMappingString(button, 0, col) end)
	if ok and type(s) == "string" and s ~= "" then
		local ch = s:match("^Key (.+)$")
		if ch and (#ch == 1 or not ch:match("^%a")) and not ch:find(" ") then return ch end
	end
	return devText(d)
end
function K.gameText(button)
	local t = {}
	for col = 0, 4 do
		local ok, d = pcall(function() return INPUTMAPPER:GetButtonMapping(button, 0, col) end)
		if ok and d and d ~= "" then t[#t + 1] = shownDev(button, col, d) end
	end
	if #t == 0 then return "none" end
	return table.concat(t, ", ")
end
local function allButtons()
	local out = {}
	pcall(function() for _, b in ipairs(INPUTMAPPER:GetGameButtonsToMap()) do out[#out + 1] = b end end)
	pcall(function() for _, b in ipairs(INPUTMAPPER:GetMenuButtonsToMap()) do out[#out + 1] = b end end)
	for _, b in ipairs({ "MenuLeft", "MenuRight", "MenuUp", "MenuDown" }) do out[#out + 1] = b end
	return out
end
-- which button of the mode being played (player 1) has this device key
local function holderOf(dev)
	for _, b in ipairs(allButtons()) do
		for _, d in ipairs(K.gameKeys(b)) do if d == dev then return b end end
	end
	return nil
end
-- the keys Etterna's key map uses, for both modes (the one not being played read from the saved map)
local function mappedKeys()
	local keys = {}
	pcall(function()
		if FILEMAN and not FILEMAN:DoesFileExist("Save/Keymaps.ini") then return end
		local txt = File.Read("Save/Keymaps.ini")
		if type(txt) ~= "string" then return end
		local section = ""
		for line in txt:gmatch("[^\r\n]+") do
			local s = line:match("^%[(.-)%]")
			if s then section = s
			else
				local btn, val = line:match("^1_([%w]+)=(.*)$")
				if btn and (section == "dance" or section == "kb7") then
					for d in val:gmatch("[^:]+") do
						local name = d:match("^Key_(.+)$")
						if name then keys[name] = keys[name] or { game = section, button = btn } end
					end
				end
			end
		end
	end)
	for _, b in ipairs(allButtons()) do
		for _, d in ipairs(K.gameKeys(b)) do
			local name = d:match("^Key_(.+)$")
			if name then keys[name] = { game = gameName(), button = b } end
		end
	end
	return keys
end
local BUTTON_NAMES = { RestartGameplay = "Restart", EffectUp = "Rate up", EffectDown = "Rate down", Select = "Select",
	Start = "Start (Enter)", Back = "Back (Esc)", Coin = "Coin", Operator = "Operator", MenuLeft = "menu Left",
	MenuRight = "menu Right", MenuUp = "menu Up", MenuDown = "menu Down" }
local function buttonName(b, game)
	game = game or gameName()
	local cols = COLUMNS[game]
	if cols then for i, c in ipairs(cols) do if c == b then return (game == "kb7" and "7K" or "4K") .. " column " .. i end end end
	return BUTTON_NAMES[b] or b
end

-- what may be picked ---------------------------------------------------------------------------
-- keys Etterna handles itself before any theme sees them, everywhere
local ENGINE = { F2 = "Etterna's reload key", prtsc = "the screenshot key", pause = "taken by Etterna" }
local SELECT_CTRL = { f = "favourite", m = "permanent mirror", g = "goal", q = "load new songs", s = "save profile",
	a = "add to playlist", t = "calc test list", backspace = "delete song", v = "paste", l = "log in", n = "new profile",
	["1"] = "Rebirth's search", ["2"] = "Rebirth's random", ["3"] = "Rebirth's downloads", ["4"] = "Rebirth's help", ["5"] = "Rebirth's settings" }
local PLAY_F = { F4 = "undo offset change", F6 = "autosync", F7 = "assist clap", F8 = "autoplay", F11 = "song offset -", F12 = "song offset +" }
local function ctxOf(id) return ACTIONS[id].ctx end
local function overlaps(a, b)
	if a == b then return true end
	return (a == "menu" and b == "select") or (a == "select" and b == "menu")
end
-- nil when the binding can be used for this shortcut, else why not
local function refusal(id, b)
	local p = parse(b)
	if not p then return "that key can't be used" end
	local n, ctx = p.name, ctxOf(id)
	local txt = K.text(b)
	if MODIFIERS[n] then return nil end -- (not reached: a modifier alone waits for the key)
	if n:find("mouse") then return "mouse buttons can't be used" end
	if n == "enter" or n == "KP enter" then return "Enter is Etterna's Start" end
	if n == "escape" and id ~= "pause" then return "Esc is Etterna's Back" end
	if n == "up" or n == "down" or n == "left" or n == "right" then return "the arrow keys move through the menus" end
	if ENGINE[n] then return txt .. " is " .. ENGINE[n] end
	if p.alt and (n == "enter" or n == "F4") then return txt .. " is Etterna's" end
	if n == "F10" then return "holding F10 opens Etterna's debug menu" end
	-- (F3 is the debug menu in Til' Death and Rebirth; the osu! and Quaver looks moved it to F10)
	if n == "F3" and ACTIONS[id].looks ~= "OQ" then return "holding F3 opens Etterna's debug menu in Til' Death and Rebirth" end
	if ctx == "play" then
		if PLAY_F[n] then return txt .. " is Etterna's " .. PLAY_F[n] .. " key while playing" end
		if n == "tab" or n == "`" then return "holding " .. K.keyText(n) .. " changes Etterna's speed" end
		if n == "F1" then return "F1 is Etterna's practice / replay key" end
		if not p.ctrl and not p.alt then
			local m = mappedKeys()[n]
			if m then
				local isNote = COLUMNS[m.game] and (function() for _, c in ipairs(COLUMNS[m.game]) do if c == m.button then return true end end end)()
				if not (isNote and id == "skip") then
					return txt .. " is " .. buttonName(m.button, m.game) .. " (Etterna's key map)"
				end
			end
		end
	else
		if n == "F9" then return "F9 is Etterna's song select key (romanized titles)" end
		if n == "F12" then return "F12 is Til' Death's help" end
		if p.ctrl and not p.alt and not p.shift and SELECT_CTRL[n] then return txt .. " is Etterna's " .. SELECT_CTRL[n] .. " key" end
		if p.ctrl and p.shift and not p.alt and (n == "r" or n == "p" or n == "o") then return txt .. " is Etterna's reload key" end
		if not p.ctrl and not p.alt and (#n == 1 or n == "space" or n == "backspace" or n == "delete") then
			return "a plain " .. K.keyText(n) .. " types into the search (add Ctrl or Alt)"
		end
		if not p.ctrl and not p.alt and n:match("^KP ") then return "the number pad keys are menu keys" end
		if n == "F1" and id ~= "mods" then return "F1 is Etterna's Coin key (Rebirth's search, custom judge windows on results)" end
	end
	return nil
end
K.refusal = refusal

-- changing them --------------------------------------------------------------------------------
local function tell(msg)
	K.message = msg
	pcall(function() SCREENMAN:SystemMessage(msg) end)
end
local NAMES_OF = { options = "Options", keybinds = "Keybinds", pausetoggle = "Pausing on / off", mods = "Mods",
	random = "Random song", beatmap = "Beatmap options", preview = "Play from the preview", pause = "Pause", skip = "Skip the intro",
	scrolldown = "Scroll speed slower", scrollup = "Scroll speed faster" }
function K.set(id, b)
	if not ACTIONS[id] then return false end
	if b == K.binding(id) then tell(NAMES_OF[id] .. ": " .. K.text(b) .. " (no change)") return true end
	if b ~= ACTIONS[id].def then
		local why = refusal(id, b)
		if why then tell("Not changed: " .. why) return false end
	end
	-- another shortcut with this key where both work: they swap keys
	local old = K.binding(id)
	local swapped
	for other, a in pairs(ACTIONS) do
		if other ~= id and K.binding(other) == b and overlaps(a.ctx, ACTIONS[id].ctx) then
			-- (only when the other one can have this one's old key)
			if old ~= a.def and refusal(other, old) then
				tell("Not changed: " .. K.text(b) .. " is " .. NAMES_OF[other]) return false
			end
			over[other] = old ~= a.def and old or nil
			swapped = other
		end
	end
	over[id] = b ~= ACTIONS[id].def and b or nil
	save()
	if swapped then tell(NAMES_OF[id] .. ": " .. K.text(b) .. "   (" .. NAMES_OF[swapped] .. " is now " .. K.label(swapped) .. ")")
	else tell(NAMES_OF[id] .. ": " .. K.text(b)) end
	MESSAGEMAN:Broadcast("TWKeysChanged")
	return true
end
function K.reset(id)
	if not ACTIONS[id] then return end
	K.set(id, ACTIONS[id].def)
end
function K.resetAll()
	over = {}
	save()
	tell("VSRG Hub's shortcuts are back to their defaults")
	MESSAGEMAN:Broadcast("TWKeysChanged")
end

-- Etterna's buttons: defaults of the mode being played (Etterna's own)
local GAME_DEFAULTS = {
	dance = { Left = "Key_z", Down = "Key_x", Up = "Key_comma", Right = "Key_period" },
	kb7 = { Key1 = "Key_s", Key2 = "Key_d", Key3 = "Key_f", Key4 = "Key_space", Key5 = "Key_j", Key6 = "Key_k", Key7 = "Key_l" },
	any = { RestartGameplay = "Key_`", EffectUp = "Key_=", EffectDown = "Key_-" },
}
function K.gameDefault(button)
	local g = GAME_DEFAULTS[gameName()]
	return (g and g[button]) or GAME_DEFAULTS.any[button]
end
-- the arrows are kept on the menu buttons whenever no note key uses them (as Rebirth does)
local function menuNavigable()
	local arrows = { MenuLeft = "Key_left", MenuDown = "Key_down", MenuUp = "Key_up", MenuRight = "Key_right" }
	for mb, key in pairs(arrows) do
		local h = holderOf(key)
		if h == nil then pcall(function() INPUTMAPPER:SetInputMap(key, mb, 2, 0) end) end
	end
end
local GAME_BANNED = { escape = "Esc is Etterna's Back", enter = "Enter is Etterna's Start", ["KP enter"] = "Enter is Etterna's Start",
	prtsc = "the screenshot key", pause = "taken by Etterna", tab = "holding Tab changes Etterna's speed" }
function K.setGame(button, dev)
	if not dev:match("^%a[%w]*_.+$") then tell("Not changed: Etterna refused that key") return false end
	local name = dev:match("^Key_(.+)$")
	if dev:find("^Mouse") or (name and name:find("mouse")) then tell("Not changed: mouse buttons can't be used") return false end
	if name and GAME_BANNED[name] then tell("Not changed: " .. GAME_BANNED[name]) return false end
	if name and name:match("^F%d+$") then tell("Not changed: Etterna keeps F1-F12 for itself") return false end
	local isColumn = false
	for _, c in ipairs(K.columns()) do if c == button then isColumn = true end end
	if name and not isColumn and MODIFIERS[name] then tell("Not changed: " .. K.keyText(name) .. " is a modifier key") return false end
	-- a key of VSRG Hub's pause (with no modifier) can't also be a note
	local pp = parse(K.binding("pause"))
	if name and pp and not pp.ctrl and not pp.alt and not pp.shift and pp.name == name then
		tell("Not changed: " .. K.keyText(name) .. " is VSRG Hub's Pause (change that first)") return false
	end
	local old = K.gameKeys(button)
	if #old == 1 and old[1] == dev then tell(buttonName(button) .. ": " .. devText(dev) .. " (no change)") return true end
	local holder = holderOf(dev)
	if holder == button then holder = nil end
	local arrow = name == "left" or name == "right" or name == "up" or name == "down"
	-- (the old keys by column, to put back if Etterna doesn't take the new one)
	local before = {}
	for col = 0, 4 do
		local okc, d = pcall(function() return INPUTMAPPER:GetButtonMapping(button, 0, col) end)
		before[col] = okc and d or nil
	end
	local ok = pcall(function()
		for col = 0, 4 do INPUTMAPPER:SetInputMap("", button, col, 0) end
		INPUTMAPPER:SetInputMap(dev, button, 2, 0)
	end)
	local got
	pcall(function() got = INPUTMAPPER:GetButtonMapping(button, 0, 2) end)
	if not ok or got ~= dev then
		pcall(function() for col = 0, 4 do if before[col] then INPUTMAPPER:SetInputMap(before[col], button, col, 0) end end end)
		tell("Not changed: Etterna refused that key") return false
	end
	local msg = buttonName(button) .. ": " .. devText(dev)
	-- the key came from another button: that one gets this one's old key (a swap), unless it still has one
	if holder and not (arrow and holder:find("^Menu")) and #K.gameKeys(holder) == 0 and old[1] then
		pcall(function() INPUTMAPPER:SetInputMap(old[1], holder, 2, 0) end)
		msg = msg .. "   (" .. buttonName(holder) .. " is now " .. devText(old[1]) .. ")"
	elseif holder and #K.gameKeys(holder) == 0 and not holder:find("^Menu") then
		msg = msg .. "   (" .. buttonName(holder) .. " has no key now)"
	end
	menuNavigable()
	pcall(function() INPUTMAPPER:SaveMappingsToDisk() end)
	tell(msg)
	MESSAGEMAN:Broadcast("TWKeysChanged")
	return true
end
function K.resetGame(button)
	local d = K.gameDefault(button)
	if d then K.setGame(button, d) end
end

-- picking a key by pressing it -------------------------------------------------------------------
-- row: { id = shortcut } or { game = button }
function K.capture(row)
	K.cap = row
	K.message = nil
	MESSAGEMAN:Broadcast("TWKeysChanged")
end
function K.capturing(row)
	if not K.cap then return false end
	if row == nil then return true end
	return (row.id ~= nil and row.id == K.cap.id) or (row.game ~= nil and row.game == K.cap.game)
end
function K.cancel()
	if not K.cap then return end
	K.cap = nil
	MESSAGEMAN:Broadcast("TWKeysChanged")
end
local function captureInput(event)
	local n = keyName(event)
	if n == "left alt" or n == "right alt" then held.alt = event.type ~= "InputEventType_Release" end
	if not K.cap then return false end
	if event.DeviceInput.is_mouse then
		if event.type == "InputEventType_FirstPress" and n and not n:find("mousewheel") then
			K.cancel(); tell("Not changed")
		end
		return true
	end
	if event.type ~= "InputEventType_FirstPress" then return true end
	if not n or MODIFIERS[n] then return true end -- (a modifier: wait for the key it goes with)
	local row = K.cap
	K.cap = nil
	if n == "escape" and not (row.id == "pause") then tell("Not changed"); MESSAGEMAN:Broadcast("TWKeysChanged") return true end
	if row.id then
		local c, s, a = mods()
		-- (the key's own character on this keyboard, for showing it)
		local ch = event.charNoModifiers
		if #n == 1 and type(ch) == "string" and ch:match("^%p$") and ch ~= n then chars[n] = ch end
		K.set(row.id, (c and "C" or "") .. (s and "S" or "") .. (a and "A" or "") .. "#" .. n)
	elseif row.game then
		-- (Etterna's device names: "InputDevice_Key" for the keyboard, "InputDevice_Joy1"...; its key map
		-- wants "Key_z")
		local dev = tostring(event.DeviceInput.device or "InputDevice_Key"):gsub("^InputDevice_", ""):gsub("^Device_", "")
		if dev == "" or dev:find("_") then tell("Not changed: Etterna refused that key") MESSAGEMAN:Broadcast("TWKeysChanged") return true end
		K.setGame(row.game, dev .. "_" .. n)
	end
	MESSAGEMAN:Broadcast("TWKeysChanged")
	return true
end
K.captureInput = captureInput

-- the list: every key worth knowing, by category, for the look in use --------------------------
-- rows: { label, desc, id (a VSRG Hub shortcut) | game (an Etterna button) | key (fixed text) }
local function rateKeys() return K.gameText("EffectDown") .. " / " .. K.gameText("EffectUp") end
local function rowsFor(l)
	local O, Q, T, R = l == "O", l == "Q", l == "T", l == "R"
	local tw = O or Q
	local cats = {}
	local function cat(title) local c = { title = title, rows = {} }; cats[#cats + 1] = c; return c end
	local function add(c, r) c.rows[#c.rows + 1] = r end

	local g = cat("General")
	add(g, { label = tw and "Options" or "VSRG Hub menu", id = "options",
		desc = tw and "VSRG Hub's options (main menu, song select, results)" or "VSRG Hub's menu in this theme (main menu, song select, results)" })
	add(g, { label = "Keybinds (this list)", id = "keybinds", desc = "every useful key; change VSRG Hub's and Etterna's here" })
	add(g, { label = "Pausing on / off", id = "pausetoggle",
		desc = (T or R) and "main menu and results (on song select Ctrl+P is Etterna's new playlist)" or "with it on, a song pauses instead of ending" })
	add(g, { label = "Volume", key = "Alt + mouse wheel", desc = "anywhere, like osu! and Quaver" })
	add(g, { label = "Screenshot", key = "Print Screen", desc = "saved in Etterna's Screenshots folder (Shift: a small JPEG)" })
	add(g, { label = "Fullscreen / window", key = "Alt+Enter", desc = "not while playing" })
	add(g, { label = "Leave / close", key = "Esc", desc = "leaves a screen or closes what is open" })
	add(g, { label = "Quit the game", key = "Alt+F4" })

	local s = cat("Song select")
	if tw then
		add(s, { label = "Play the chart", key = "Enter", desc = O and "or click the cookie" or "or double click it" })
		add(s, { label = "Search", key = "just type", desc = "Esc clears it" })
		add(s, { label = "Move through the songs", key = "Arrows, mouse wheel" })
		add(s, { label = O and "Mods" or "Modifiers", id = "mods", desc = "Mirror, Full LN, Inverse, rates, Hidden..." })
		add(s, { label = "Random song", id = "random" })
		add(s, { label = O and "Beatmap options" or "Options (Quaver's key)", id = "beatmap",
			desc = O and "chart actions, new playlist" or "VSRG Hub's options" })
		add(s, { label = "Play from the map preview", id = "preview", desc = "practice from the spot the preview is at" })
	else
		add(s, { label = "Play the chart", key = "Enter", desc = "Enter twice quickly: player options" })
		add(s, { label = "Move through the songs", key = "Left / Right", desc = "Up,Down,Up,Down: sort menu" })
		add(s, { label = "Tabs", key = T and "1 to 0" or "1 to 6", desc = T and "General, MSD, Scores, Search, Profile, Filters, Goals, Playlists, Packs, Tags"
			or "General, Scores, Profile, Goals, Playlists, Tags" })
		add(s, { label = "Chart preview", key = "Space" })
		if R then
			add(s, { label = "Search / Random / Downloads", key = "Ctrl+1 / 2 / 3", desc = "F1 also opens the search" })
			add(s, { label = "Help / Settings", key = "Ctrl+4 / 5" })
		else
			add(s, { label = "Help", key = "F12" })
		end
	end
	add(s, { label = "Rate up", game = "EffectUp", desc = (tw and "music rate +0.1 (Shift: +0.05)" or "music rate +0.1 (with Select held: +0.05)") .. "; default: 2nd key right of 0" })
	add(s, { label = "Rate down", game = "EffectDown", desc = (tw and "music rate -0.1 (Shift: -0.05)" or "music rate -0.1; both together: back to 1.0x") .. "; default: the key right of 0" })
	add(s, { label = "Favourite", key = "Ctrl+F" })
	add(s, { label = "Permanent mirror", key = "Ctrl+M", desc = "always play this chart mirrored" })
	add(s, { label = "Goal from this chart", key = "Ctrl+G" })
	add(s, { label = "Add to the playlist", key = "Ctrl+A", desc = "the playlist in use" })
	add(s, { label = "Load new songs", key = "Ctrl+Q", desc = "songs added to the folders since Etterna started" })

	local p = cat("Gameplay")
	add(p, { label = "Restart the song", game = "RestartGameplay", desc = "starts the song again at once (default: the key left of 1)" })
	add(p, { label = "Pause", id = "pause", desc = "with Pausing on; again (or Esc) to go on" })
	add(p, { label = "Skip the intro", id = "skip", desc = "while \"Press ... to skip\" shows (long intros)" })
	if tw then
		local unit = Q and "1.0 (Ctrl: 0.1)" or "1 (osu!lazer look, Ctrl: 0.1)"
		add(p, { label = "Scroll speed slower", id = "scrolldown", desc = "in the first seconds of a song, before its notes: -" .. unit .. ", held: faster" })
		add(p, { label = "Scroll speed faster", id = "scrollup", desc = "the same, +" .. unit })
	end
	add(p, { label = "Leave the song", key = "Esc", desc = "with Pausing off (on: the pause menu's Quit)" })
	add(p, { label = "Give up", key = "hold Enter", desc = "ends the song as failed" })
	add(p, { label = "Song offset", key = "F11 / F12", desc = "-/+ 20 ms (Alt: 1 ms, Shift: global offset, F4 undoes)" })
	add(p, { label = "Autoplay", key = "F8" })
	add(p, { label = "Pause menu", key = "1 / 2 / 3", desc = "Continue, Retry, Quit (or Up / Down and Enter)" })

	local n = cat("Note keys (" .. (gameName() == "kb7" and "7K" or "4K") .. ")")
	for i, b in ipairs(K.columns()) do
		add(n, { label = "Column " .. i, game = b })
	end
	add(n, { label = gameName() == "kb7" and "4K's keys" or "7K's keys", key = "switch Keys",
		desc = "each mode has its own keys: switch to " .. (gameName() == "kb7" and "4K" or "7K") .. " (Keys) to change them" })

	local pr = cat("Practice and replays")
	if tw then
		add(pr, { label = "Practice mode", key = O and "PR mod, or Tab" or "PRACTICE, or Tab", desc = "plays with a seek bar; nothing is scored" })
		add(pr, { label = "Jump in the song", key = "click the bar" })
		add(pr, { label = "Loop start / end", key = "right click the bar", desc = "or Ctrl + click" })
	else
		add(pr, { label = "Practice mode", key = "Ctrl+O menu", desc = "Practice mode in VSRG Hub's menu" })
		add(pr, { label = "Pause / play", key = "right click" })
	end
	add(pr, { label = "Back to the loop start", key = "Backspace" })
	add(pr, { label = "Bookmark / loop", key = "F1", desc = "Etterna's practice: twice while paused resets it" })
	add(pr, { label = "Practice rate", key = rateKeys, desc = "-/+ 0.05 (Etterna's rate keys)" })
	add(pr, { label = "Replay: pause / play", key = "F1 or right click" })
	add(pr, { label = "Replay: seek", key = rateKeys, desc = "-/+ 5 s (Ctrl: 0.1 s); Shift: replay rate" })

	local r = cat("Results")
	add(r, { label = "Retry the song", key = function() return K.gameText("RestartGameplay") end, desc = "Etterna's restart key" })
	add(r, { label = "Judge (rescore)", key = rateKeys, desc = "your score on another judge (J4 to Justice)" })
	if tw then
		add(r, { label = "One column / all", key = "1-" .. #K.columns() .. " / 0", desc = "the hit offsets of one finger" })
		add(r, { label = "Hands", key = "H", desc = "left hand, right hand, both" })
		add(r, { label = "Accuracy on other timings", key = "hover the accuracy", desc = "J4 to Justice, OD 6 to OD 10" })
		add(r, { label = "Watch the replay", key = "Watch replay button" })
	else
		add(r, { label = "Custom judge windows", key = "F1" })
		add(r, { label = "Screenshot", key = "/ (Select)" })
	end

	local c = cat("Customize gameplay")
	if tw then
		add(c, { label = "Pick / let go of a part", key = "click / right click" })
		add(c, { label = "Move it", key = "drag, or arrows", desc = "Shift + arrows: 10 at a time" })
		add(c, { label = "Size it", key = "mouse wheel", desc = "Shift: wider / narrower, Ctrl: taller / flatter" })
		add(c, { label = "Reset the part", key = "R" })
		add(c, { label = "Show / hide the part", key = "V" })
		add(c, { label = "Hide the panel", key = "H" })
		add(c, { label = "Skip the intro", key = "Space", desc = "intros of 8 seconds or more" })
		add(c, { label = "Done", key = "Esc" })
	elseif T then
		add(c, { label = "Pick a setting", key = "1-0, Q-P, A-L, Z-M", desc = "each key picks one; arrows change it" })
		add(c, { label = "Hit position", key = "hold R + Up / Down", desc = "moves the notefield" })
		add(c, { label = "Done", key = "Esc" })
	else
		add(c, { label = "Pick a part", key = "Enter", desc = "right click lets go" })
		add(c, { label = "Move it", key = "arrows", desc = "Shift: small steps" })
		add(c, { label = "Size / zoom / rotate", key = "Space", desc = "cycles what the arrows change" })
		add(c, { label = "Undo", key = "Backspace", desc = "Ctrl: reset the part" })
		add(c, { label = "Done", key = "Esc" })
	end

	local e = cat("Etterna tools")
	add(e, { label = "Debug menu", key = tw and "hold F10" or "hold F3", desc = "Etterna's tools (F5-F8 pages)" })
	add(e, { label = "Reload the theme's scripts", key = "Ctrl+F2", desc = "F2: textures and metrics too" })
	add(e, { label = "Reload this song from disk", key = "Ctrl+Shift+R", desc = "song select" })
	return cats
end
function K.catalog(l) return rowsFor(l or look()) end

-- a row's key, as shown
function K.rowText(row)
	if K.capturing(row) then return "press a key...  (Esc: cancel)" end
	if row.id then return K.label(row.id) end
	if row.game then return K.gameText(row.game) end
	if type(row.key) == "function" then return row.key() end
	return row.key or ""
end
function K.editable(row) return row.id ~= nil or row.game ~= nil end
function K.resetRow(row)
	if row.id then K.reset(row.id) elseif row.game then K.resetGame(row.game) end
end

-- the actor: on Etterna's system layer it takes the key being picked before anything else
local hooked = false
return Def.ActorFrame {
	InitCommand = function(self) self:queuecommand("Hook") end,
	HookCommand = function(self)
		if hooked then return end
		local s = self
		while s:GetParent() do s = s:GetParent() end
		-- (through the global: the scripts may load this file again, e.g. after Ctrl+F2)
		if s.AddInputCallback then
			s:AddInputCallback(function(event) return TWKeys and TWKeys.captureInput and TWKeys.captureInput(event) or false end)
			hooked = true
		end
	end,
	ScreenChangedMessageCommand = function() if K.cap then K.cap = nil end end,
}
