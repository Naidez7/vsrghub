-- A searchable list, for picking a skin, a noteskin or an osu! collection: type to filter, arrows
-- or the mouse wheel to move, Enter or a click to pick, Esc to go back.
--   TW.openList { title = "...", items = { { label = "...", value = ..., sub = "..." }, ... },
--                 current = value, onPick = function(value) ... end,
--                 preview = function(item) return TW.cursorSpec(...) end }  (optional: a pointer preview)
--                 notes = true  (optional: the items are noteskins, shown playing the selected chart;
--                                only on song select, whose list panel is made with { notes = true })
--   TW.openInput { title = "...", value = "current", hint = "...", onDone = function(text) ... end }
--   asks for a typed value instead (Enter keeps it, Esc goes back)

TW.list = nil -- the open list, if any
local ROWS = 11
local state = { filter = "", cursor = 1, scroll = 0, shown = {} }

local function refilter()
	local l = TW.list
	state.shown = {}
	local f = state.filter:lower()
	for _, it in ipairs(l.items) do
		if f == "" or it.label:lower():find(f, 1, true) or (it.sub and it.sub:lower():find(f, 1, true)) then
			state.shown[#state.shown + 1] = it
		end
	end
	state.cursor = math.max(1, math.min(state.cursor, #state.shown))
	if state.scroll > state.cursor - 1 then state.scroll = state.cursor - 1 end
	if state.cursor > state.scroll + ROWS then state.scroll = state.cursor - ROWS end
	state.scroll = math.max(0, math.min(state.scroll, math.max(0, #state.shown - ROWS)))
	MESSAGEMAN:Broadcast("TWListRefresh")
end

function TW.openList(spec)
	TW.list = spec
	state.filter = ""
	state.cursor = 1
	for i, it in ipairs(spec.items) do
		if spec.current ~= nil and tostring(it.value):lower() == tostring(spec.current):lower() then state.cursor = i end
	end
	state.scroll = math.max(0, state.cursor - math.floor(ROWS / 2))
	SCREENMAN:set_input_redirected(PLAYER_1, true)
	refilter()
	MESSAGEMAN:Broadcast("TWList", { open = true })
end
function TW.openInput(spec)
	TW.openList { title = spec.title, items = {}, input = true, secret = spec.secret, hint = spec.hint, initial = spec.value or "",
		onPick = function(text) if spec.onDone then spec.onDone(text) end end }
	state.filter = spec.value or ""
	refilter()
end
function TW.closeList()
	if not TW.list then return end
	TW.list = nil
	-- the options panel underneath keeps the keyboard if it is open
	SCREENMAN:set_input_redirected(PLAYER_1, TW.optionsOpen == true or TW.keepRedirect == true)
	MESSAGEMAN:Broadcast("TWList", { open = false })
end
local function pick(it)
	local l = TW.list
	if not l or not it then return end
	TW.closeList()
	l.onPick(it.value)
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
end
local function move(d)
	if #state.shown == 0 then return end
	state.cursor = math.max(1, math.min(#state.shown, state.cursor + d))
	refilter()
end

function TW.listInput(event)
	if not TW.list then return false end
	local b = event.DeviceInput.button
	if event.type == "InputEventType_Release" then return not event.DeviceInput.is_mouse end
	if b == "DeviceButton_mousewheel up" then move(-1) return true end
	if b == "DeviceButton_mousewheel down" then move(1) return true end
	if event.DeviceInput.is_mouse then return false end
	if b == "DeviceButton_escape" then if event.type == "InputEventType_FirstPress" then TW.closeList() end
	elseif b == "DeviceButton_up" then move(-1)
	elseif b == "DeviceButton_down" then move(1)
	elseif b == "DeviceButton_pgup" then move(-ROWS)
	elseif b == "DeviceButton_pgdn" then move(ROWS)
	elseif b == "DeviceButton_home" then move(-100000)
	elseif b == "DeviceButton_end" then move(100000)
	elseif (b == "DeviceButton_enter" or b == "DeviceButton_KP enter") and TW.list.input then
		local l = TW.list
		TW.closeList()
		l.onPick(state.filter)
		MESSAGEMAN:Broadcast("TWOptionsRefresh")
	elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" then pick(state.shown[state.cursor])
	elseif b == "DeviceButton_backspace" then state.filter = state.filter:sub(1, -2); state.cursor = 1; refilter()
	elseif b == "DeviceButton_delete" then state.filter = ""; state.cursor = 1; refilter()
	elseif event.char and event.char ~= "" and event.char:match("[%w%p ]") and not INPUTFILTER:IsControlPressed() then
		state.filter = state.filter .. event.char; state.cursor = 1; state.scroll = 0; refilter()
	end
	return true
end

function TW.listPanel(opts)
	opts = opts or {}
	local M = TW.M
	local W, RH = M(760), M(44)
	local x0, y0 = SCREEN_CENTER_X - W / 2, M(150)
	local t = Def.ActorFrame {
		Name = "TWListPanel",
		InitCommand = function(self) self:z(60):visible(false) end,
		TWListMessageCommand = function(self, p)
			self:stoptweening()
			if p.open then self:visible(true):diffusealpha(0):linear(0.1):diffusealpha(1)
			else self:linear(0.1):diffusealpha(0):queuecommand("Hide") end
		end,
		HideCommand = function(self) self:visible(false) end,
		Def.Quad { InitCommand = function(self) TW.shade(self:FullScreen(), 0.8, { 0, 0, 0, 0.75 }) end },
		TW.button(SCREEN_WIDTH, SCREEN_HEIGHT, function() TW.closeList() end) .. {
			InitCommand = function(self) self:FullScreen():diffusealpha(0) end },
		-- (the Quaver look: Quaver's dialog, grey with a cyan edge)
		Def.Quad { InitCommand = function(self)
			self:visible(TW.isQuaver == true):align(0, 0):xy(x0 - M(17), y0 - M(111)):zoomto(W + M(34), RH * ROWS + M(142)):diffuse(TW.rgb(12, 183, 231))
		end },
		Def.Quad { InitCommand = function(self)
			self:align(0, 0):xy(x0 - M(16), y0 - M(110)):zoomto(W + M(32), RH * ROWS + M(140)):visible(TW.isQuaver == true)
			if TW.isQuaver then self:diffuse(TW.rgb(36, 36, 36)) end
		end },
		-- (the osu! looks: a rounded dark card with a soft shadow and a line of the interface colour)
		TW.shadow { w = W + M(32), h = RH * ROWS + M(140), spread = M(20), alpha = 0.6, drop = M(4), init = function(self)
			self:xy(x0 - M(16), y0 - M(110)):visible(not TW.isQuaver) end },
		TW.box { w = W + M(32), h = RH * ROWS + M(140), r = M(12), col = { 0.12, 0.12, 0.16, 0.98 }, col2 = { 0.08, 0.08, 0.11, 0.98 }, init = function(self)
			self:xy(x0 - M(16), y0 - M(110)):visible(not TW.isQuaver) end },
		TW.box { w = M(60), h = M(4), r = M(2), col = TW.pink, init = function(self) self:xy(x0, y0 - M(60)):visible(not TW.isQuaver) end },
		TW.button(W + M(32), RH * ROWS + M(140), function() end) .. {
			InitCommand = function(self) self:align(0, 0):xy(x0 - M(16), y0 - M(110)):zoomto(W + M(32), RH * ROWS + M(140)):diffusealpha(0) end },
		TW.text(M(28), not TW.isQuaver, function(self) self:align(0, 0):xy(x0, y0 - M(100)) end) .. {
			TWListRefreshMessageCommand = function(self) if TW.list then self:settext(TW.list.title or "") end end
		},
		TW.text(M(16), true, function(self) self:align(0, 0):xy(x0, y0 - M(50)) end) .. {
			TWListRefreshMessageCommand = function(self)
				if not TW.list then return end
				if TW.list.input then
					-- (a password shows as dots)
					self:settextf("%s_", TW.list.secret and string.rep("*", #state.filter) or state.filter):diffuse(TW.yellow)
					return
				end
				self:settextf("Search: %s_     %d of %d", state.filter, #state.shown, #TW.list.items)
				self:diffuse(state.filter ~= "" and TW.yellow or TW.green)
			end
		},
		TW.text(M(13), false, function(self)
			self:align(0, 0):xy(x0, y0 + RH * ROWS + M(4)):diffusealpha(0.6):maxwidth(W / self:GetZoom())
		end) .. { TWListRefreshMessageCommand = function(self)
			if not TW.list then return end
			self:settext(TW.list.input and ((TW.list.hint and (TW.list.hint .. "  ") or "") .. "Type the value, Enter to keep it, Esc to go back.")
				or "Type to search. Arrows, Page Up/Down or the mouse wheel to move, Enter or click to pick, Esc to go back.")
		end },
	}
	-- a list with a preview (the Cursor option) leaves room for it on the right
	local PW = M(240)
	local function hasPreview(l) return l and (l.preview or l.combo or (l.notes and opts.notes)) end
	local function rowW() return hasPreview(TW.list) and (W - PW - M(16)) or W end
	for i = 1, ROWS do
		t[#t + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(x0, y0 + (i - 1) * RH) end,
			TWListRefreshMessageCommand = function(self)
				local it = TW.list and state.shown[state.scroll + i]
				self:visible(it ~= nil)
				if not it then return end
				self.item = it
				local c = self:GetChildren()
				local rw = rowW()
				local isCursor = state.scroll + i == state.cursor
				local isCurrent = TW.list.current ~= nil and tostring(it.value):lower() == tostring(TW.list.current):lower()
				if TW.isQuaver then
					-- Quaver's rows: grey, the picked one darker cyan with its cyan bar
					c.Bg:zoomto(rw, RH - M(4)):diffuse(isCursor and TW.rgb(36, 48, 48) or TW.rgb(47, 47, 47))
					c.Bar:visible(isCursor):zoomto(M(3), RH - M(4))
					c.Label:diffuse(isCurrent and TW.rgb(69, 211, 255) or color("#FFFFFF"))
				else
					c.Bg:visible(false)
					TW.setBox(c.Box, { w = rw, col = isCursor and TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.1) or { 1, 1, 1, 0.05 }, col2 = isCursor and TW.pink or { 1, 1, 1, 0.04 } })
					c.Bar:visible(false)
				end
				c.Label:maxwidth(rw * 0.64 / c.Label:GetZoom()):settext((isCurrent and "> " or "") .. it.label)
				c.Sub:x(rw - M(12)):maxwidth(rw * 0.3 / c.Sub:GetZoom()):settext(it.sub or "")
				c.Hit:zoomto(rw, RH - M(4))
			end,
			Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0):zoomto(W, RH - M(4)) end },
			TW.box { w = W, h = RH - M(4), r = M(8), init = function(self) self:visible(not TW.isQuaver) end } .. { Name = "Box" },
			Def.Quad { Name = "Bar", InitCommand = function(self) self:align(0, 0):visible(false):diffuse(TW.rgb(68, 211, 255)) end },
			TW.text(M(17), false, function(self) self:align(0, 0.5):xy(M(12), RH / 2 - M(2)):maxwidth(W * 0.66 / self:GetZoom()) end) .. { Name = "Label" },
			TW.text(M(12), false, function(self) self:align(1, 0.5):xy(W - M(12), RH / 2 - M(2)):maxwidth(W * 0.3 / self:GetZoom()):diffusealpha(0.7) end) .. { Name = "Sub" },
			TW.button(W, RH - M(4), function(self) pick(self:GetParent().item) end) .. {
				Name = "Hit",
				InitCommand = function(self) self:align(0, 0):zoomto(W, RH - M(4)):diffusealpha(0) end },
		}
	end
	-- the preview: the item under the cursor drawn as it will look (at its real size, or smaller to
	-- fit when it is very big, which the note under it says)
	local PH = RH * ROWS - M(34)
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(x0 + W - PW, y0) end,
		TWListRefreshMessageCommand = function(self)
			local l = TW.list
			self:visible(l ~= nil and l.preview ~= nil)
			if not (l and l.preview) then return end
			local it = state.shown[state.cursor]
			local c = self:GetChildren()
			c.Fit:visible(it ~= nil)
			if not it then c.Note:settext("") return end
			local spec = l.preview(it)
			local art = c.Fit:GetChild("Art")
			art:playcommand("SetCursor", { spec = spec, size = TW.cursorSize() })
			-- how big it is drawn
			local w, h = M(20), M(20)
			local img = art:GetChild("Grow"):GetChild("Spin"):GetChild("Img")
			if img:GetVisible() then w, h = img:GetZoomedWidth(), img:GetZoomedHeight() end
			local room = PW * 0.8
			local fit = math.min(1, room / math.max(1, w), room / math.max(1, h))
			c.Fit:zoom(fit)
			local note
			if spec.kind == "osu" then
				local tw, th = img:GetWidth(), img:GetHeight()
				note = string.format("%dx%d%s", math.floor(tw + 0.5), math.floor(th + 0.5), spec.hd and " @2x" or "")
			elseif spec.kind == "quaver" then note = "Quaver's pointer"
			elseif spec.kind == "etterna" then note = "Etterna's pointer"
			else note = "plain pointer" end
			if fit < 0.999 then note = note .. string.format("  (shown at %d%%)", math.floor(fit * 100 + 0.5)) end
			c.Note:settext(note)
		end,
		Def.Quad { InitCommand = function(self) TW.glassify(self:align(0, 0):zoomto(PW, PH), "card", TW.rgb(10, 11, 13, 1)) end },
		-- a soft frame and a faint grid behind the pointer, so light and dark pointers both show
		Def.Quad { InitCommand = function(self) self:xy(PW / 2, PH / 2):zoomto(PW, 1):diffuse(color("1,1,1,0.06")) end },
		Def.Quad { InitCommand = function(self) self:xy(PW / 2, PH / 2):zoomto(1, PH):diffuse(color("1,1,1,0.06")) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(PW, M(2)):diffuse(TW.pink):diffusealpha(0.8) end },
		Def.ActorFrame { Name = "Fit", InitCommand = function(self) self:xy(PW / 2, PH / 2) end,
			TW.cursorArt(true) .. { Name = "Art" } },
		TW.text(M(12), false, function(self) self:align(0.5, 0):xy(PW / 2, PH + M(8)):diffusealpha(0.7):maxwidth(PW / self:GetZoom()) end) .. { Name = "Note" },
	}
	-- combo skins: "727" in the digits under the cursor
	if TW.comboPreview then
		t[#t + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(x0 + W - PW, y0) end,
			TWListRefreshMessageCommand = function(self)
				local l = TW.list
				local on = l ~= nil and l.combo == true
				self:visible(on)
				if not on then return end
				local it = state.shown[state.cursor]
				local c = self:GetChildren()
				c.Fit:visible(it ~= nil)
				if not it then c.Note:settext("") return end
				c.Fit:GetChild("ComboPreview"):playcommand("SetCombo", { value = it.value })
				c.Note:settext(it.value == "" and "the digits of the skin your notes are from" or "the combo, as it will look")
			end,
			Def.Quad { InitCommand = function(self) TW.glassify(self:align(0, 0):zoomto(PW, PH), "card", TW.rgb(10, 11, 13, 1)) end },
			Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(PW, M(2)):diffuse(TW.pink):diffusealpha(0.8) end },
			Def.ActorFrame { Name = "Fit", InitCommand = function(self) self:xy(PW / 2, PH / 2) end, TW.comboPreview(PW, PH) },
			TW.text(M(12), false, function(self) self:align(0.5, 0):xy(PW / 2, PH + M(8)):diffusealpha(0.7):maxwidth(PW / self:GetZoom()) end) .. { Name = "Note" },
		}
	end
	-- noteskins: the one under the cursor playing the selected chart with the song (small, on a
	-- translucent panel); it loads a moment after the cursor stops, so scrolling stays quick
	if opts.notes then
		local shownSkin = nil
		t[#t + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(x0 + W - PW, y0) end,
			TWListMessageCommand = function(self, p) if not p.open then shownSkin = nil end end,
			TWListRefreshMessageCommand = function(self)
				local l = TW.list
				local on = l ~= nil and l.notes == true
				self:visible(on)
				if not on then return end
				local it = state.shown[state.cursor]
				local c = self:GetChildren()
				if not it then c.Note:settext(""); c.FieldFrame:visible(false) return end
				if l.game and l.game ~= TW.gameName() then
					c.FieldFrame:visible(false)
					c.Note:settext("switch to " .. (l.game == "kb7" and "7K" or "4K") .. " to see these notes")
					return
				end
				c.Note:settext(GAMESTATE:GetCurrentSteps() and "the selected song" or "pick a song to see it played")
				if shownSkin == it.value then return end
				self:stoptweening():sleep(0.2):queuecommand("LoadSkin")
			end,
			LoadSkinCommand = function(self)
				local it = TW.list and state.shown[state.cursor]
				if not it or shownSkin == it.value then return end
				shownSkin = it.value
				local ff = self:GetChild("FieldFrame")
				ff:visible(true):playcommand("Load", { noteskin = it.value })
			end,
			Def.Quad { InitCommand = function(self) TW.glassify(self:align(0, 0):zoomto(PW, PH), "card", { 0.12, 0.12, 0.14, 0.75 }) end },
			Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(PW, M(2)):diffuse(TW.pink):diffusealpha(0.8) end },
			TW.previewField { x = PW / 2, y = 0, w = PW, h = PH },
			TW.text(M(12), false, function(self) self:align(0.5, 0):xy(PW / 2, PH + M(8)):diffusealpha(0.7):maxwidth(PW / self:GetZoom()) end) .. { Name = "Note" },
		}
	end
	return t
end
