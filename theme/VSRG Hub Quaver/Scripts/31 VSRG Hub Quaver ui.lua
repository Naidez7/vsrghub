-- Quaver's controls: the difficulty colours, drop-down menus, dialogs, toggles and the options
-- dialog, measured off Quaver (Quaver's own difficulty colours, from its ColorHelper).

-- Quaver colours a difficulty number by its value: Beginner, Easy, Normal, Hard, Insane, Expert,
-- Expert+ and beyond. Etterna's MSD is shown in the same colours.
local diffSteps = {
	{ 1, TW.rgb(209, 255, 250) }, { 2.5, TW.rgb(94, 255, 117) }, { 10, TW.rgb(94, 196, 255) },
	{ 20, TW.rgb(245, 178, 91) }, { 30, TW.rgb(249, 100, 93) }, { 40, TW.rgb(215, 97, 235) },
	{ 50, TW.rgb(123, 97, 235) },
}
function QV.diffColour(v)
	for _, s in ipairs(diffSteps) do if (v or 0) < s[1] then return s[2] end end
	return TW.rgb(183, 183, 183)
end

-- A Quaver drop-down: label, box with the current value and a chevron; clicking opens the list
-- under it. spec = { label, x, y, w, colour, items() -> {{label, value}}, current() -> value,
-- text() -> shown text, onPick(value) }
QV.openDropdown = nil
function QV.dropdown(spec)
	local M = TW.M
	local w, h = spec.w, M(27)
	local rowH = M(28)
	local items = spec.items()
	local col = spec.colour or color("#FFFFFF")
	local t = Def.ActorFrame {
		InitCommand = function(self) self:xy(spec.x, spec.y) end,
		QVDropdownMessageCommand = function(self, p)
			local open = p.id == spec.label
			local list = self:GetChild("List")
			list:visible(open)
			if open then list:playcommand("Fill") end
			self:GetChild("Chev"):rotationz(open and 180 or 0)
		end,
		QV.t(M(14), true, function(self) self:align(1, 0.5):x(-M(12)):settext(spec.label) end),
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):zoomto(w, h):diffuse(TW.rgb(25, 25, 25)) end },
		QV.t(M(13.5), true, function(self) self:align(0, 0.5):x(M(9)):diffuse(col) end) .. {
			OnCommand = function(self) self:playcommand("Refresh") end,
			TWSortChangedMessageCommand = function(self) self:playcommand("Refresh") end,
			TWCollectionChangedMessageCommand = function(self) self:playcommand("Refresh") end,
			RefreshCommand = function(self) QV.fit(self, spec.text(), w - M(36)) end,
		},
		Def.ActorFrame {
			Name = "Chev",
			InitCommand = function(self) self:x(w - M(14)) end,
			Def.Quad { InitCommand = function(self) self:x(-M(3)):zoomto(M(8), M(2.5)):rotationz(40):diffuse(col) end },
			Def.Quad { InitCommand = function(self) self:x(M(2.5)):zoomto(M(8), M(2.5)):rotationz(-40):diffuse(col) end },
		},
		TW.button(w, h, function()
			MESSAGEMAN:Broadcast("QVDropdown", { id = QV.openDropdown == spec.label and "" or spec.label })
			QV.openDropdown = QV.openDropdown ~= spec.label and spec.label or nil
		end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(w, h):diffusealpha(0) end },
	}
	local list = Def.ActorFrame {
		Name = "List",
		InitCommand = function(self) self:visible(false):z(30) end,
		-- a click anywhere else closes it
		TW.button(1, 1, function() QV.openDropdown = nil; MESSAGEMAN:Broadcast("QVDropdown", { id = "" }) end) ..
			{ InitCommand = function(self) self:zoomto(SCREEN_WIDTH * 4, SCREEN_HEIGHT * 4) end },
		FillCommand = function(self)
			items = spec.items()
			local cur = spec.current()
			for i = 1, #items + 20 do
				local r = self:GetChild("R" .. i)
				if not r then break end
				local it = items[i]
				r:visible(it ~= nil)
				if it then
					local c = r:GetChildren()
					QV.fit(c.Text, it.label, w - M(18))
					c.Text:diffuse(it.value == cur and col or color("#FFFFFF"))
					r.value = it.value
				end
			end
		end,
	}
	for i = 1, math.max(#items, 2) + 6 do
		list[#list + 1] = Def.ActorFrame {
			Name = "R" .. i,
			InitCommand = function(self) self:y(h / 2 + (i - 0.5) * rowH):z(1) end,
			Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0.5):zoomto(w, rowH):diffuse(TW.rgb(22, 22, 22)):diffusealpha(0.97) end },
			QV.t(M(13), true, function(self) self:align(0, 0.5):x(M(9)) end) .. { Name = "Text" },
			TW.button(w, rowH, function(self)
				local v = self:GetParent().value
				QV.openDropdown = nil
				MESSAGEMAN:Broadcast("QVDropdown", { id = "" })
				if v ~= nil then spec.onPick(v) end
			end, function(self, on)
				self:GetParent():GetChild("Bg"):diffuse(on and TW.rgb(45, 45, 45) or TW.rgb(22, 22, 22))
			end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(w, rowH):diffusealpha(0) end },
		}
	end
	t[#t + 1] = list
	return t
end

-- A rounded-looking Quaver button (pill): colour, label, width, height, onClick.
function QV.pill(label, col, w, h, onClick, init)
	return Def.ActorFrame {
		InitCommand = function(self) if init then init(self) end end,
		Def.Quad { Name = "Bg", InitCommand = function(self) self:zoomto(w - h, h):diffuse(col) end },
		TW.circle(h / 2, col) .. { InitCommand = function(self) self:x(-(w - h) / 2) end },
		TW.circle(h / 2, col) .. { InitCommand = function(self) self:x((w - h) / 2) end },
		QV.t(h * 0.55, true, function(self) self:align(0.5, 0.5):y(TW.M(1)):settext(label) end) .. { Name = "Label" },
		TW.button(w, h, onClick, function(self, on) self:GetParent():diffusealpha(on and 0.85 or 1) end) ..
			{ InitCommand = function(self) self:zoomto(w, h):diffusealpha(0) end },
	}
end

-- Quaver's on/off switch: a red pill with OFF, or a green one with ON, and its knob.
function QV.switch(getOn)
	local M = TW.M
	local w, h = M(52), M(16)
	return Def.ActorFrame {
		RefreshCommand = function(self)
			local on = getOn()
			local c = self:GetChildren()
			local col = on and TW.rgb(12, 192, 85) or TW.rgb(244, 100, 99)
			c.Bg:diffuse(col); c.L:diffuse(col); c.Rc:diffuse(col)
			c.State:settext(on and "ON" or "OFF"):x(on and -M(9) or M(9))
			c.Knob:stoptweening():decelerate(0.1):x(on and (w / 2 - h / 2) or (-w / 2 + h / 2))
		end,
		Def.Quad { Name = "Bg", InitCommand = function(self) self:zoomto(w - h, h) end },
		TW.circle(h / 2, color("#FFFFFF")) .. { Name = "L", InitCommand = function(self) self:x(-(w - h) / 2) end },
		TW.circle(h / 2, color("#FFFFFF")) .. { Name = "Rc", InitCommand = function(self) self:x((w - h) / 2) end },
		QV.t(M(8.5), true, function(self) self:align(0.5, 0.5) end) .. { Name = "State" },
		TW.circle(h * 0.38, color("#FFFFFF")) .. { Name = "Knob" },
	}
end

-- Quaver's options dialog (Ctrl+O, OPTIONS): sections on the left, settings on the right, the
-- same settings as VSRG Hub's osu! options panel.
function QV.optionsPanel()
	local M, R = TW.M, TW.R
	local X, Y, W, H = M(210), M(118), M(1036), M(582)
	local SB = M(220) -- sidebar width
	local RH = M(52)
	local sections = {}
	local function build()
		sections = {}
		local cur
		for gi, r in ipairs(TW.optionRows()) do
			if r.kind == "head" then
				cur = { title = r.text, rows = {} }
				sections[#sections + 1] = cur
			elseif cur then
				r.gi = gi
				cur.rows[#cur.rows + 1] = r
			end
		end
	end
	local sel = 1
	-- a section longer than the dialog scrolls (Keybinds): the first of its rows shown
	local VISIBLE = 8
	local first = 1
	-- the keyboard's place (VSRG Hub's options cursor, shared with the osu! look): its section is shown
	-- and its row marked (and scrolled into view)
	local function syncSel()
		local gi = TW.optionsCursor()
		for si, sec in ipairs(sections) do
			for ri, r in ipairs(sec.rows) do
				if r.gi == gi then
					if si ~= sel then first = 1 end
					sel = si
					if ri < first then first = ri end
					if ri > first + VISIBLE - 1 then first = ri - VISIBLE + 1 end
					-- (a group's title stays over its first row)
					if ri == first and ri > 1 and sec.rows[ri - 1].kind == "sub" then first = ri - 1 end
					return
				end
			end
		end
	end
	-- the mouse wheel scrolls the section; the keyboard's place stays among the rows shown
	function QV.optionsScroll(d)
		local s = sections[sel]
		if not s then return end
		first = math.max(1, math.min(first + d * 3, math.max(1, #s.rows - VISIBLE + 1)))
		local gi = TW.optionsCursor()
		local inView = false
		for ri = first, math.min(#s.rows, first + VISIBLE - 1) do if s.rows[ri].gi == gi then inView = true end end
		if not inView then
			for ri = first, math.min(#s.rows, first + VISIBLE - 1) do
				local row = s.rows[ri]
				if row.kind ~= "sub" then TW.setOptionsCursor(row.gi) break end
			end
		end
		MESSAGEMAN:Broadcast("TWOptionsRefresh")
	end
	local names = { LOOK = "Theme & Skin", GAMEPLAY = "Gameplay", KEYBINDS = "Keybinds", VIDEO = "Video", PERFORMANCE = "Performance", AUDIO = "Audio", ETTERNA = "Etterna" }
	local t = Def.ActorFrame {
		Name = "QVOptions",
		InitCommand = function(self) self:z(40):visible(false) end,
		TWOptionsMessageCommand = function(self, p)
			self:stoptweening()
			if p.open then
				build(); sel = 1; first = 1; syncSel()
				self:visible(true):diffusealpha(0):linear(0.12):diffusealpha(1):playcommand("Show")
			else
				self:linear(0.1):diffusealpha(0):queuecommand("Hide")
			end
		end,
		HideCommand = function(self) self:visible(false) end,
		TWOptionsRefreshMessageCommand = function(self) build(); syncSel(); self:playcommand("Show") end,
		TWKeysChangedMessageCommand = function(self) self:playcommand("Show") end,
		TWNoteskinChangedMessageCommand = function(self) self:playcommand("Show") end,
		Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(color("#000000")):diffusealpha(0.65) end },
		TW.button(1, 1, function() TW.closeOptions() end) .. { InitCommand = function(self) self:FullScreen():diffusealpha(0) end },
		Def.ActorFrame {
			InitCommand = function(self) self:xy(X, Y):z(5) end,
			Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(W, H):diffuse(TW.rgb(47, 47, 47)) end },
			TW.button(W, H, function() end) .. { InitCommand = function(self) self:align(0, 0):zoomto(W, H):diffusealpha(0) end },
			Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(SB, H):diffuse(TW.rgb(36, 36, 36)) end },
			Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(W, M(50)):diffuse(TW.rgb(31, 31, 31)) end },
			QV.t(M(15), true, function(self) self:align(0, 0.5):xy(M(15), M(25)):settext("OPTIONS MENU") end),
			QV.t(M(15), true, function(self) self:align(0, 0.5):xy(SB + M(15), M(25)) end) .. {
				ShowCommand = function(self) self:settext(sections[sel] and (names[sections[sel].title] or sections[sel].title):upper() .. " SETTINGS" or "") end
			},
			QV.t(M(11), false, function(self) self:align(1, 0.5):xy(W - M(15), M(25)):diffuse(QV.grey) end) .. {
				-- (on a keybind: how to change it)
				ShowCommand = function(self)
					local r = TW.optionRows()[TW.optionsCursor()]
					if r and r.keyRow and not r.info then
						self:settext(TWKeys.capturing(r.keyRow) and "Press the new key (Esc cancels)" or "Enter: new key   Delete: default   Esc: close")
					else
						self:settext("Esc or " .. TW.keyLabel("options", "Ctrl+O") .. " to close")
					end
				end
			},
		}
	}
	local box = t[#t]
	for i = 1, 7 do
		box[#box + 1] = Def.ActorFrame {
			InitCommand = function(self) self:y(M(50) + (i - 1) * M(50)) end,
			ShowCommand = function(self)
				local s = sections[i]
				self:visible(s ~= nil)
				if not s then return end
				local c = self:GetChildren()
				c.Label:settext(names[s.title] or s.title):diffuse(i == sel and QV.lightCyan or color("#FFFFFF"))
				c.Sel:visible(i == sel)
				c.Bar:visible(i == sel)
			end,
			Def.Quad { Name = "Sel", InitCommand = function(self) self:align(0, 0):zoomto(SB, M(50)):diffuse(TW.rgb(36, 48, 48)) end },
			Def.Quad { Name = "Bar", InitCommand = function(self) self:align(0, 0):zoomto(M(3), M(50)):diffuse(TW.rgb(68, 211, 255)) end },
			QV.t(M(14), true, function(self) self:align(0, 0.5):xy(M(22), M(25)) end) .. { Name = "Label" },
			TW.button(SB, M(50), function()
				local sec = sections[i]
				if sec then
					for _, row in ipairs(sec.rows) do if row.kind ~= "sub" then TW.setOptionsCursor(row.gi) break end end
				end
				first = 1
				MESSAGEMAN:Broadcast("TWOptionsRefresh")
			end) ..
				{ InitCommand = function(self) self:align(0, 0):zoomto(SB, M(50)):diffusealpha(0) end },
		}
	end
	-- the settings of the chosen section
	local RX, RW = SB + M(15), W - SB - M(30)
	for j = 1, 8 do
		box[#box + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(RX, M(68) + (j - 1) * (RH + M(8))) end,
			ShowCommand = function(self)
				local s = sections[sel]
				local r = s and s.rows[first + j - 1]
				self:visible(r ~= nil)
				self.row = r
				if not r then return end
				local c = self:GetChildren()
				-- a group of keybinds: its name in Quaver's cyan, no box
				local sub = r.kind == "sub"
				for _, n in ipairs({ "Bg", "Mark", "Label", "ValueBg", "Value", "Chev", "Less", "More", "LessHit", "MoreHit", "Desc" }) do
					if c[n] then c[n]:visible(not sub) end
				end
				c.Group:visible(sub):settext(sub and r.text:upper() or "")
				c.GroupRule:visible(sub)
				if sub then return end
				c.Mark:visible(r.gi == TW.optionsCursor())
				c.Label:settext(r.label)
				-- keybinds: what it does under the name; the key in cyan when it can be changed (yellow while
				-- waiting for the new one), grey when it can't
				local d = r.keyRow and r.desc or nil
				c.Desc:visible(d ~= nil)
				if d then QV.fit(c.Desc, d, RW - M(340)) end
				c.Label:y(d and RH * 0.36 or RH / 2)
				local v = r.value and r.value() or ""
				-- settings that step up and down get < > on their box (a click on the rest still opens or steps up)
				local arrows = r.change ~= nil and r.activate == nil
				QV.fit(c.Value, v, arrows and M(220) or M(260))
				c.Value:x(arrows and RW - M(276) or RW - M(304))
				c.Value:diffuse(r.change and QV.lightCyan or color("#FFFFFF"))
				if r.keyRow then
					local picking = TWKeys and TWKeys.capturing(r.keyRow)
					c.Value:diffuse(picking and color("#FFDD55") or (r.info and QV.grey or QV.lightCyan))
				end
				c.Chev:visible(not arrows and not r.keyRow)
				c.Less:visible(arrows); c.More:visible(arrows)
				c.LessHit:visible(arrows); c.MoreHit:visible(arrows)
			end,
			Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0):zoomto(RW, RH):diffuse(TW.rgb(38, 38, 38)) end },
			Def.Quad { Name = "Mark", InitCommand = function(self) self:align(0, 0):zoomto(M(3), RH):diffuse(TW.rgb(68, 211, 255)) end },
			QV.t(M(14), true, function(self) self:align(0, 0.5):xy(M(12), RH / 2) end) .. { Name = "Label" },
			QV.t(M(10.5), false, function(self) self:align(0, 0.5):xy(M(12), RH * 0.72):diffuse(QV.grey) end) .. { Name = "Desc" },
			QV.t(M(12), true, function(self) self:align(0, 1):xy(M(2), RH - M(10)):diffuse(QV.cyan) end) .. { Name = "Group" },
			Def.Quad { Name = "GroupRule", InitCommand = function(self) self:align(0, 0.5):xy(0, RH - M(6)):zoomto(RW, 1):diffuse(TW.rgb(12, 183, 231)):diffusealpha(0.5) end },
			Def.Quad { Name = "ValueBg", InitCommand = function(self) self:align(1, 0.5):xy(RW - M(12), RH / 2):zoomto(M(300), M(30)):diffuse(TW.rgb(25, 25, 25)) end },
			QV.t(M(13.5), true, function(self) self:align(0, 0.5):xy(RW - M(304), RH / 2) end) .. { Name = "Value" },
			QV.t(M(13), true, function(self) self:align(0.5, 0.5):xy(RW - M(26), RH / 2):settext("v"):diffuse(QV.lightCyan) end) .. { Name = "Chev" },
			QV.t(M(15), true, function(self) self:align(0.5, 0.5):xy(RW - M(294), RH / 2):settext("<"):diffuse(QV.lightCyan) end) .. { Name = "Less" },
			QV.t(M(15), true, function(self) self:align(0.5, 0.5):xy(RW - M(26), RH / 2):settext(">"):diffuse(QV.lightCyan) end) .. { Name = "More" },
			TW.button(RW, RH, function(self)
				local r = self:GetParent().row
				if not r or r.kind == "sub" then return end
				if r.gi then TW.setOptionsCursor(r.gi) end
				if r.activate then r.activate() elseif r.change then r.change(1) end
				MESSAGEMAN:Broadcast("TWOptionsRefresh")
			end) .. { InitCommand = function(self) self:align(0, 0):zoomto(RW, RH):diffusealpha(0) end },
			-- (after the row's own button, so these take the click on the arrows)
			TW.button(M(36), RH, function(self)
				local r = self:GetParent().row
				if not (r and r.change) or r.kind == "sub" then return end
				if r.gi then TW.setOptionsCursor(r.gi) end
				r.change(-1)
				MESSAGEMAN:Broadcast("TWOptionsRefresh")
			end) .. { Name = "LessHit", InitCommand = function(self) self:align(0.5, 0.5):xy(RW - M(294), RH / 2):zoomto(M(36), RH):diffusealpha(0):z(1) end },
			TW.button(M(36), RH, function(self)
				local r = self:GetParent().row
				if not (r and r.change) or r.kind == "sub" then return end
				if r.gi then TW.setOptionsCursor(r.gi) end
				r.change(1)
				MESSAGEMAN:Broadcast("TWOptionsRefresh")
			end) .. { Name = "MoreHit", InitCommand = function(self) self:align(0.5, 0.5):xy(RW - M(26), RH / 2):zoomto(M(36), RH):diffusealpha(0):z(1) end },
		}
	end
	return t
end

-- A Quaver dialog: title over a box with a cyan edge. Children go in the returned frame's "Body".
function QV.dialog(name, title, w, h)
	local M = TW.M
	local x, y = SCREEN_CENTER_X - w / 2, SCREEN_CENTER_Y - h / 2
	return Def.ActorFrame {
		Name = name,
		InitCommand = function(self) self:visible(false):z(45) end,
		Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(color("#000000")):diffusealpha(0.7) end },
		TW.button(1, 1, function() end) .. { InitCommand = function(self) self:FullScreen():diffusealpha(0) end },
		QV.t(M(16), true, function(self) self:align(0, 1):xy(x, y - M(4)):settext(title) end),
		Def.Quad { InitCommand = function(self) self:align(0, 0):xy(x - 1, y - 1):zoomto(w + 2, h + 2):diffuse(TW.rgb(12, 183, 231)) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):xy(x, y):zoomto(w, h):diffuse(TW.rgb(36, 36, 36)) end },
		Def.ActorFrame { Name = "Body", InitCommand = function(self) self:xy(x, y):z(3) end },
	}
end

-- Quaver's CUSTOMIZE JUDGEMENT WINDOWS dialog (Options > Gameplay > Judgement windows): its presets
-- (Peaceful to Impossible) and your own, made with CREATE from the one picked and named by typing;
-- yours have their six windows set with the sliders (the presets are fixed, as in Quaver). Picking
-- one puts it in force (Scripts/24 VSRG Hub timing.lua); USE ETTERNA'S JUDGE goes back to J4.
QV.windows = nil -- the dialog's state while open: { pick = name, custom = list }
local WIN_NAMES = { "Marvelous", "Perfect", "Great", "Good", "Okay", "Miss" }
local WIN_KEYS = { "TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3", "TapNoteScore_W4", "TapNoteScore_W5", "TapNoteScore_Miss" }
local WIN_MAX = 250
local function winRefresh() MESSAGEMAN:Broadcast("QVWindowsRefresh") end
local function winList()
	local out = {}
	for _, p in ipairs(TW.QV_PRESETS) do out[#out + 1] = { name = p[1], preset = true } end
	for _, c in ipairs(QV.windows and QV.windows.custom or TW.qvCustom()) do out[#out + 1] = { name = c.name, custom = c } end
	return out
end
local function winPicked()
	local s = QV.windows
	if not s then return nil end
	for _, c in ipairs(s.custom) do if c.name == s.pick then return c end end
	return nil
end
local function winValues()
	local c = winPicked()
	if c then return c.w end
	return TW.qvWindows(QV.windows and QV.windows.pick or "Standard") or TW.QV_STANDARD
end
local function winSave()
	local s = QV.windows
	if not s then return end
	TW.saveQvCustom(s.custom)
	if s.pick and TW.qvWindows(s.pick) then TW.setQuaverWindows(s.pick) end
end
local function winPick(name)
	QV.windows.pick = name
	TW.setQuaverWindows(name)
	winRefresh()
end
local function winSet(i, v)
	local c = winPicked()
	if not c then return end
	v = math.floor(math.max(1, math.min(WIN_MAX, v)) + 0.5)
	c.w[i] = v
	-- (each window at least as wide as the one before it)
	for k = i + 1, 6 do if c.w[k] < c.w[k - 1] then c.w[k] = c.w[k - 1] end end
	for k = i - 1, 1, -1 do if c.w[k] > c.w[k + 1] then c.w[k] = c.w[k + 1] end end
	winSave()
	winRefresh()
end
local function winCreate()
	local s = QV.windows
	local base = winValues()
	local n, name = 1, "Custom"
	local function taken(x)
		for _, l in ipairs(winList()) do if l.name == x then return true end end
		return false
	end
	while taken(name) do n = n + 1; name = "Custom " .. n end
	local w = {}
	for i = 1, 6 do w[i] = base[i] end
	s.custom[#s.custom + 1] = { name = name, w = w }
	s.pick = name
	winSave()
	winRefresh()
end
local function winDelete()
	local s = QV.windows
	local c = winPicked()
	if not c then return end
	for i, x in ipairs(s.custom) do if x == c then table.remove(s.custom, i) break end end
	s.pick = "Standard"
	TW.saveQvCustom(s.custom)
	TW.setQuaverWindows("Standard")
	winRefresh()
end
function QV.openWindows()
	local m, v = TW.timingMode()
	QV.windows = { pick = m == "quaver" and v or "Standard", custom = TW.qvCustom() }
	MESSAGEMAN:Broadcast("QVWindows", { open = true })
	winRefresh()
end
function QV.closeWindows()
	QV.windows = nil
	MESSAGEMAN:Broadcast("QVWindows", { open = false })
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
end
-- the keyboard while it is open: Esc closes, typing renames one of yours, up/down pick
function QV.windowsInput(event)
	if not QV.windows then return false end
	if event.type == "InputEventType_Release" then return true end
	local b = event.DeviceInput.button
	if event.DeviceInput.is_mouse then return false end
	if b == "DeviceButton_escape" then
		if event.type == "InputEventType_FirstPress" then QV.closeWindows() end
		return true
	end
	local c = winPicked()
	if c and b == "DeviceButton_backspace" then
		local name = c.name:sub(1, -2)
		if name ~= "" then c.name = name; QV.windows.pick = name; winSave(); winRefresh() end
		return true
	end
	if c and event.char and event.char:match("^[%w %-_%.!]$") and #c.name < 20 and not INPUTFILTER:IsControlPressed() then
		local name = c.name .. event.char
		local clash = false
		for _, l in ipairs(winList()) do if l.name == name then clash = true end end
		if not clash then c.name = name; QV.windows.pick = name; winSave(); winRefresh() end
		return true
	end
	if b == "DeviceButton_up" or b == "DeviceButton_down" then
		local list = winList()
		local i = 1
		for k, l in ipairs(list) do if l.name == QV.windows.pick then i = k end end
		i = math.max(1, math.min(#list, i + (b == "DeviceButton_up" and -1 or 1)))
		winPick(list[i].name)
	end
	return true
end
function QV.windowsDialog()
	local M = TW.M
	local DW, DH = M(780), M(470)
	local LW = M(220)
	local d = QV.dialog("QVWindowsDialog", "CUSTOMIZE JUDGEMENT WINDOWS", DW, DH)
	d.QVWindowsMessageCommand = function(self, p) self:visible(p.open) end
	local body = d[#d]
	-- the presets and yours
	body[#body + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(LW, DH):diffuse(TW.rgb(30, 30, 30)) end }
	local ROWS, RH = 13, M(29)
	for i = 1, ROWS do
		body[#body + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(0, M(10) + (i - 1) * RH) end,
			QVWindowsRefreshMessageCommand = function(self)
				local l = winList()[i]
				self:visible(l ~= nil)
				self.name = l and l.name
				if not l then return end
				local on = QV.windows and QV.windows.pick == l.name
				local c = self:GetChildren()
				c.Sel:visible(on)
				c.Bar:visible(on)
				QV.fit(c.Label, (l.name == "Standard" and "Standard*" or l.name), LW - M(40))
				c.Label:diffuse(on and QV.lightCyan or color("#FFFFFF"))
				c.Kind:settext(l.custom and "YOURS" or "")
			end,
			Def.Quad { Name = "Sel", InitCommand = function(self) self:align(0, 0):zoomto(LW, RH):diffuse(TW.rgb(36, 48, 48)) end },
			Def.Quad { Name = "Bar", InitCommand = function(self) self:align(0, 0):zoomto(M(3), RH):diffuse(TW.rgb(68, 211, 255)) end },
			QV.t(M(13), true, function(self) self:align(0, 0.5):xy(M(16), RH / 2) end) .. { Name = "Label" },
			QV.t(M(9), true, function(self) self:align(1, 0.5):xy(LW - M(10), RH / 2):diffuse(QV.grey) end) .. { Name = "Kind" },
			TW.button(LW, RH, function(self) local n = self:GetParent().name; if n then winPick(n) end end) ..
				{ InitCommand = function(self) self:align(0, 0):zoomto(LW, RH):diffusealpha(0) end },
		}
	end
	body[#body + 1] = QV.pill("CREATE", TW.rgb(25, 170, 100), LW - M(40), M(26), function() winCreate() end,
		function(self) self:xy(LW / 2, DH - M(58)) end)
	body[#body + 1] = QV.pill("DELETE", TW.rgb(244, 100, 99), LW - M(40), M(26), function() winDelete() end,
		function(self) self:xy(LW / 2, DH - M(24)) end) .. {
		QVWindowsRefreshMessageCommand = function(self) self:diffusealpha(winPicked() and 1 or 0.35) end }
	-- the picked one: its name and its six windows
	local RX = LW + M(24)
	local RW = DW - RX - M(24)
	body[#body + 1] = QV.t(M(13), true, function(self) self:align(0, 0.5):xy(RX, M(26)):settext("Preset name") end)
	body[#body + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(RX + M(120), M(26)):zoomto(RW - M(120), M(28)):diffuse(TW.rgb(54, 54, 54)) end }
	body[#body + 1] = QV.t(M(13), false, function(self) self:align(0, 0.5):xy(RX + M(130), M(26)) end) .. {
		QVWindowsRefreshMessageCommand = function(self)
			local s = QV.windows
			if not s then return end
			local c = winPicked()
			QV.fit(self, c and (c.name .. "_") or s.pick, RW - M(140))
			self:diffuse(c and color("#FFFFFF") or QV.grey)
		end }
	body[#body + 1] = QV.t(M(10.5), false, function(self) self:align(0, 0.5):xy(RX, M(52)):diffuse(QV.grey) end) .. {
		QVWindowsRefreshMessageCommand = function(self)
			self:settext(winPicked() and "Type to rename it. Drag a bar or use < > to set its windows."
				or "Quaver's presets can't be changed: CREATE makes your own from this one.")
		end }
	local BX, BW = RX + M(130), RW - M(250)
	for i = 1, 6 do
		local y = M(92) + (i - 1) * M(44)
		local col = QV.judge[WIN_KEYS[i]][2]
		body[#body + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(0, y) end,
			QVWindowsRefreshMessageCommand = function(self)
				if not QV.windows then return end
				local v = winValues()[i]
				local c = self:GetChildren()
				local edit = winPicked() ~= nil
				c.Fill:zoomto(BW * math.min(1, v / WIN_MAX), M(8))
				c.Knob:x(BX + BW * math.min(1, v / WIN_MAX))
				c.Value:settext(string.format("%d ms", v))
				-- (past 180 ms Etterna stops judging: what it uses then)
				c.Note:settext((i == 5 and v > 180) and "(Etterna: 180)" or (i == 6 and "(shown only)" or ""))
				self:diffusealpha(edit and 1 or 0.6)
			end,
			QV.t(M(13), true, function(self) self:align(0, 0.5):x(RX):settext(WIN_NAMES[i]):diffuse(col) end),
			Def.Quad { InitCommand = function(self) self:align(0, 0.5):x(BX):zoomto(BW, M(8)):diffuse(TW.rgb(25, 25, 25)) end },
			Def.Quad { Name = "Fill", InitCommand = function(self) self:align(0, 0.5):x(BX):diffuse(col) end },
			TW.circle(M(8), color("#FFFFFF")) .. { Name = "Knob" },
			QV.t(M(13), true, function(self) self:align(1, 0.5):x(BX + BW + M(92)) end) .. { Name = "Value" },
			QV.t(M(9.5), false, function(self) self:align(0, 0.5):xy(BX, M(15)):diffuse(QV.grey) end) .. { Name = "Note" },
			QV.t(M(15), true, function(self) self:align(0.5, 0.5):x(BX + BW + M(18)):settext("<"):diffuse(QV.lightCyan) end),
			QV.t(M(15), true, function(self) self:align(0.5, 0.5):x(BX + BW + M(108)):settext(">"):diffuse(QV.lightCyan) end),
			TW.button(M(26), M(30), function() winSet(i, winValues()[i] - 1) end) ..
				{ InitCommand = function(self) self:x(BX + BW + M(18)):zoomto(M(26), M(30)):diffusealpha(0) end },
			TW.button(M(26), M(30), function() winSet(i, winValues()[i] + 1) end) ..
				{ InitCommand = function(self) self:x(BX + BW + M(108)):zoomto(M(26), M(30)):diffusealpha(0) end },
			-- a click (or a drag) along the bar sets it there
			TW.button(BW, M(26), function(self)
				local row = self:GetParent()
				row.dragging, row.left = true, self:GetTrueX()
				winSet(i, (INPUTFILTER:GetMouseX() - row.left) / BW * WIN_MAX)
			end) .. {
				InitCommand = function(self)
					self:align(0, 0.5):x(BX):zoomto(BW, M(26)):diffusealpha(0)
					-- (the row follows a drag along the bar)
					TW.everyFrame(self:GetParent())
					self:GetParent():SetUpdateFunction(function(row)
						if not row.dragging then return end
						if not INPUTFILTER:IsBeingPressed("left mouse button", "Mouse") then row.dragging = false return end
						local v = math.floor((INPUTFILTER:GetMouseX() - row.left) / BW * WIN_MAX + 0.5)
						if v ~= winValues()[i] then winSet(i, v) end
					end)
				end },
		}
	end
	body[#body + 1] = QV.t(M(10.5), false, function(self)
		self:align(0, 0):xy(RX, M(362)):wrapwidthpixels(RW / (M(10.5) / 24)):diffuse(QV.grey)
			:settext("Etterna judges your notes on these windows (Marvelous to Okay) and still scores Wife% at J4; the accuracy shown is Quaver's. Combo breaks and long note misses stay as Etterna has them.")
	end)
	body[#body + 1] = QV.pill("USE ETTERNA'S JUDGE", TW.rgb(90, 90, 110), M(220), M(26), function()
		TW.setJudge(4); QV.closeWindows()
	end, function(self) self:xy(RX + M(110), DH - M(24)) end)
	body[#body + 1] = QV.pill("CLOSE", TW.rgb(12, 160, 210), M(146), M(26), function() QV.closeWindows() end,
		function(self) self:xy(DW - M(24) - M(73), DH - M(24)) end)
	return d
end
