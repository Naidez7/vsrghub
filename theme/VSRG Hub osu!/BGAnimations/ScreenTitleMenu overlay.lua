-- osu!'s main menu, drawn and driven here (Graphics/ScreenTitleMenu scroll.lua draws nothing):
-- the cookie waits in the middle with the menu's music pulsing round it; a click (or any key) moves
-- it left and Play / Options / Exit slide out beside it; Play opens Solo / Multi / Back; Exit asks
-- first, like osu!. Left alone for a while, it goes back to the middle. The packs button (osu!direct)
-- opens Etterna's pack downloader.
TW.useInterfaceSkin()
local M, R = TW.M, TW.R

local function choose(name)
	local top = SCREENMAN:GetTopScreen()
	if top then
		top:playcommand("MadeChoicePlayer_1")
		top:playcommand("Choose")
	end
	TW.keepRedirect = false
	SCREENMAN:set_input_redirected(PLAYER_1, false)
	if name == "GameStart" or name == "Multi" then
		GAMESTATE:JoinPlayer()
		-- starting from the title applies the profile's default modifiers (its noteskin among them);
		-- song select then puts VSRG Hub's saved noteskin back instead of taking that one as a change
		TW.syncedOnce = {}
	end
	GAMESTATE:ApplyGameCommand(THEME:GetMetric("ScreenTitleMenu", "Choice" .. name))
end
local function askExit()
	TW.openDialog { lines = { "Are you sure you want to exit VSRG Hub?" },
		buttons = { { "Let's do it!", "green", function() choose("Exit") end }, { "Cancel", "red" } } }
end

-- the two levels of buttons, at osu!'s places
local levels = {
	main = {
		{ label = "Play", sub = "Enjoy some beat-clicking action!", icon = "circle-play", col = { 0.55, 0.40, 0.95 }, act = function() return "play" end },
		{ label = "Options", sub = "Change VSRG Hub settings", icon = "gear", col = { 0.25, 0.60, 0.92 }, act = function() TW.openOptions() end },
		{ label = "Exit", sub = "Thanks for playing!", icon = "power-off", col = { 0.93, 0.33, 0.50 }, act = askExit },
	},
	play = {
		{ label = "Solo", sub = "Play on your own", icon = "user", col = { 0.55, 0.40, 0.95 }, act = function() choose("GameStart") end },
		{ label = "Multi", sub = "Play online with others", icon = "users", col = { 0.95, 0.62, 0.20 }, act = function() TW.startMulti(function() choose("Multi") end) end },
		{ label = "Back", sub = "", icon = "arrow-left", col = { 0.42, 0.42, 0.52 }, act = function() return "main" end },
	},
}
local level, sel, hover = "main", 0, nil
-- idle: the cookie alone in the middle; awake: moved left with the buttons beside it
local awake, lastInput = false, 0
local IDLE_AFTER = 12

local function refresh()
	-- (a closed menu forgets the button the mouse was on: it can't have left it while hidden)
	if not awake then hover = nil end
	TW.titleAwake = awake
	MESSAGEMAN:Broadcast("TWTitleMenu")
end
-- (the cookie covers the buttons' left ends: a click there is the cookie's, anywhere else on a
-- button is the button's)
local cookie, R0 = nil, TW.M(277)
local function onCookie()
	if not cookie then return false end
	local dx, dy = INPUTFILTER:GetMouseX() - cookie:GetX(), INPUTFILTER:GetMouseY() - cookie:GetY()
	local r = R0 * cookie:GetZoom()
	return dx * dx + dy * dy <= r * r
end
local cookieClick
local function wake()
	lastInput = GetTimeSinceStart()
	if not awake then awake = true; refresh() end
end
local function activate(i)
	wake()
	local b = levels[level][i]
	if not b then return end
	local nxt = b.act()
	if nxt then level, sel, hover = nxt, 0, nil; refresh() end
end

local function input(event)
	if TW.dialogInput(event) then return true end
	if TW.listInput(event) then return true end
	if TW.optionsInput(event) then return true end
	if event.type == "InputEventType_FirstPress" then lastInput = GetTimeSinceStart() end
	if event.type ~= "InputEventType_FirstPress" or event.DeviceInput.is_mouse then return false end
	local b = event.DeviceInput.button
	-- (the first key wakes the menu up, as in osu!: it isn't also a choice)
	if not awake and not TW.dialogSpec and not TW.list and not TW.optionsOpen and b ~= "DeviceButton_escape" then wake() return true end
	if TW.key(event, "options", b == "DeviceButton_o" and INPUTFILTER:IsControlPressed()) then TW.openOptions() return true end
	if TW.key(event, "keybinds", false) then TW.openKeybinds() return true end
	local n = #levels[level]
	if b == "DeviceButton_up" or b == "DeviceButton_left" then sel = (sel <= 1) and n or sel - 1; refresh()
	elseif b == "DeviceButton_down" or b == "DeviceButton_right" or b == "DeviceButton_tab" then sel = (sel % n) + 1; refresh()
	elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" or b == "DeviceButton_space" then
		activate(sel > 0 and sel or 1)
	elseif b == "DeviceButton_escape" then
		if level ~= "main" then level, sel, hover = "main", 0, nil; refresh()
		elseif awake then awake = false; refresh()
		else askExit() end
	-- (osu!'s letters: P(lay), O(ptions), S(olo), M(ulti), Q(uit); only on their own, so a shortcut
	-- with Ctrl or Alt isn't also one of them)
	elseif INPUTFILTER:IsControlPressed() or TW.altHeld() then return true
	elseif b == "DeviceButton_p" then activate(1)
	elseif b == "DeviceButton_o" then if level == "main" then activate(2) end
	elseif b == "DeviceButton_s" then if level == "play" then activate(1) end
	elseif b == "DeviceButton_m" then if level == "play" then activate(2) end
	elseif b == "DeviceButton_q" then if level == "main" then askExit() end
	end
	return true
end

local t = Def.ActorFrame {
	TW.mouse(),
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
		TW.keepRedirect = true
		SCREENMAN:set_input_redirected(PLAYER_1, true)
		refresh()
		-- Etterna locks the menu's input for as long as the screen's longest animation started on
		-- coming in (the song name's 3.6 s fade among them), so the cookie took no clicks for seconds:
		-- unlocked on the next frame (after Etterna has set that lock)
		self:queuecommand("Unlock")
		self:sleep(0.05):queuecommand("Theme")
		-- (a moment later: Etterna's own screen music handling has run by then, so it can't silence ours)
		self:sleep(0.2):queuecommand("MenuMusic")
		-- (back to the middle after a while with nothing pressed)
		self:SetUpdateFunction(function()
			if awake and level == "main" and not TW.dialogSpec and not TW.list and not TW.optionsOpen
				and GetTimeSinceStart() - lastInput > IDLE_AFTER then
				awake = false; sel = 0; refresh()
			end
		end)
	end,
	MenuMusicCommand = function(self) TW.menuMusicStart() end,
	UnlockCommand = function(self)
		local top = SCREENMAN:GetTopScreen()
		if top and top.lockinput then top:lockinput(0) end
	end,
	ThemeCommand = function(self)
		if not TW.enforceTheme() and TW.takeResume() then choose("GameStart") end
	end,
	OffCommand = function(self)
		TW.menuMusicStop()
		TW.keepRedirect = false
		TW.closeOptions()
		TW.closeDialog()
	end,
	-- (older choices from the options panel / metrics)
	TWTitleChooseMessageCommand = function(self, p) if p.index == 0 then activate(1) end end,
}

-- osu! stable's buttons (measured on osu! itself): purple bars coming out from behind the cookie,
-- one under the other, fanned round it (the middle ones reach further right); the word in italics,
-- the icon at the right end. Under the mouse a bar turns pink, slides out to the right and shows
-- what it does under its word.
local CX, CY = M(511), M(406) -- (the cookie, moved left)
local BH, PITCH = M(89), M(111)
local TX, IX = M(322), M(555) -- (the word and the icon, from the cookie's middle)
local PURPLE = { left = TW.rgb(146, 118, 243), right = TW.rgb(104, 78, 210) }
local PINK = { left = TW.rgb(240, 112, 176), right = TW.rgb(214, 80, 146) }
local function rowY(lvl, i) local n = #levels[lvl]; return CY + (i - (n + 1) / 2) * PITCH end
local function rowLen(lvl, i) local n = #levels[lvl]; return M(657) - M(14) * math.abs(i - (n + 1) / 2) end

-- osu!'s icons, drawn: Play two numbered circles, Options two ticked boxes, Exit a door
local function buttonIcon(kind)
	local f = Def.ActorFrame { Name = "Icon" }
	local white = { 1, 1, 1, 1 }
	if kind == "play" then
		for k, p in ipairs({ { -M(16), M(8), M(13) }, { M(18), -M(8), M(15) } }) do
			f[#f + 1] = TW.ringShape(p[3], M(2.5), white, function(self) self:xy(p[1], p[2]) end)
			f[#f + 1] = TW.text(p[3] * 1.1, true, function(self) self:align(0.5, 0.5):xy(p[1], p[2]):settext(tostring(k)):shadowlength(0) end)
		end
	elseif kind == "options" then
		f[#f + 1] = TW.box { w = M(24), h = M(24), r = M(2), ax = 0.5, ay = 0.5, tex = "ring", stroke = M(2.5), col = white, init = function(self) self:xy(-M(8), -M(10)) end }
		f[#f + 1] = TW.icon("check", M(18), function(self) self:xy(-M(6), -M(12)) end)
		f[#f + 1] = TW.box { w = M(24), h = M(24), r = M(2), ax = 0.5, ay = 0.5, tex = "ring", stroke = M(2.5), col = white, init = function(self) self:xy(M(10), M(14)) end }
		f[#f + 1] = TW.icon("xmark", M(16), function(self) self:xy(M(10), M(14)) end)
	elseif kind == "exit" then
		f[#f + 1] = TW.box { w = M(30), h = M(50), r = M(1), ax = 0.5, ay = 0.5, tex = "ring", stroke = M(3), col = white }
		f[#f + 1] = Def.Quad { InitCommand = function(self) self:zoomto(M(3), M(3)):xy(M(7), M(2)) end }
	else
		f[#f + 1] = TW.icon(kind, M(40), function(self) end)
	end
	return f
end
levels.main[1].draw, levels.main[2].draw, levels.main[3].draw = "play", "options", "exit"
levels.play[1].draw, levels.play[2].draw, levels.play[3].draw = "fire", "users", "chevron-left"

for _, lvl in ipairs({ "main", "play" }) do
	for i, s in ipairs(levels[lvl]) do
		local len = rowLen(lvl, i)
		t[#t + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(CX - M(160), rowY(lvl, i)):diffusealpha(0):visible(false) end,
			TWTitleMenuMessageCommand = function(self)
				local shown = awake and level == lvl
				local focus = shown and (sel == i or hover == lvl .. i)
				self:stoptweening()
				-- (a level's buttons that aren't shown are hidden too, so they can't take the clicks
				-- meant for the ones shown in their place)
				if shown and not self.out then self:visible(true):x(CX - M(160)):sleep((i - 1) * 0.03) end
				self:decelerate(0.3):x(shown and CX or CX - M(160)):diffusealpha(shown and 1 or 0)
				self.out = shown
				if not shown then self:queuecommand("Hide") end
				local c = self:GetChildren()
				local b = c.Body:GetChildren()
				c.Body:stoptweening():decelerate(0.25):x(focus and M(38) or 0)
				b.Pink:stoptweening():linear(0.15):diffusealpha(focus and 1 or 0)
				b.Sub:stoptweening():linear(0.15):diffusealpha(focus and 1 or 0)
				b.Label:stoptweening():decelerate(0.15):y(focus and s.sub ~= "" and -M(6) or 0)
				b.Icon:stoptweening():decelerate(0.15):zoom(focus and 1.12 or 1)
			end,
			HideCommand = function(self) if not (awake and level == lvl) then self:visible(false) end end,
			Def.ActorFrame {
				Name = "Body",
				TW.box { w = len, h = BH, r = M(7), ay = 0.5, shear = -0.2, left = PURPLE.left, right = PURPLE.right },
				TW.box { w = len, h = BH, r = M(7), ay = 0.5, shear = -0.2, left = PINK.left, right = PINK.right, init = function(self) self:diffusealpha(0) end } .. { Name = "Pink" },
				-- a faint light along the top edge
				TW.box { w = len - M(10), h = BH * 0.5, r = M(6), ay = 0, shear = -0.2, col = { 1, 1, 1, 0.08 }, col2 = { 1, 1, 1, 0 }, init = function(self) self:xy(M(2), -BH / 2 + M(1)) end },
				TW.text(M(34), false, function(self) self:align(0, 0.5):x(TX):settext(s.label):skewx(-0.16):shadowlength(M(1.5)) end) .. { Name = "Label" },
				TW.text(M(10.5), false, function(self) self:align(0, 0.5):xy(TX + M(4), M(28)):settext(s.sub):skewx(-0.16):diffusealpha(0):shadowlength(1)
					self:maxwidth((IX - TX - M(30)) / math.max(0.01, self:GetZoom())) end) .. { Name = "Sub" },
				buttonIcon(s.draw) .. { InitCommand = function(self) self:x(IX) end },
			},
			TW.button(len, BH, function(self)
				if onCookie() then cookieClick() return end
				if awake and level == lvl then sel = i; activate(i) end
			end, function(self, on)
				if not awake or level ~= lvl then return end
				lastInput = GetTimeSinceStart()
				hover = on and (lvl .. i) or (hover == lvl .. i and nil or hover)
				refresh()
			end) .. { InitCommand = function(self)
				-- (from the cookie's edge: the cookie in front takes the clicks on it)
				local dy = math.min(R0, math.abs(rowY(lvl, i) - CY))
				local x0 = math.sqrt(R0 * R0 - dy * dy)
				self:align(0, 0.5):x(x0):zoomto(len + M(40) - x0, BH):diffusealpha(0):z(5)
			end },
		}
	end
end

-- the cookie, in front of the buttons: in the middle while idle, at the left beside them once
-- awake; clicking it wakes the menu, then opens Play like osu!. It and the bars round it move to the
-- music's beat.
cookieClick = function()
	if not awake then wake()
	elseif level == "main" then level, sel, hover = "play", 0, nil; wake(); refresh()
	else activate(1) end
end
t[#t + 1] = Def.ActorFrame {
	Name = "Cookie",
	InitCommand = function(self) cookie = self; self:xy(SCREEN_CENTER_X, M(410)) end,
	OnCommand = function(self) self:zoom(0.85):diffusealpha(0):decelerate(0.5):zoom(1):diffusealpha(1) end,
	TWTitleMenuMessageCommand = function(self)
		-- (also ends the fade-in it may have cut short: a click while it was still coming in left
		-- the cookie see-through, or gone)
		self:stoptweening():decelerate(0.45):zoom(1):diffusealpha(1)
		if awake then self:xy(CX, CY) else self:xy(SCREEN_CENTER_X, M(410)) end
	end,
	-- under the mouse the cookie grows a little, as osu!'s does
	Def.ActorFrame {
	Name = "Hover",
	InitCommand = function(self)
		local z = 1
		TW.everyFrame(self)
		self:SetUpdateFunction(function(s, dt)
			local want = (onCookie() and not TW.dialogSpec and not TW.optionsOpen) and 1.08 or 1
			z = z + (want - z) * math.min(1, (dt or 0.016) * 10)
			s:zoom(z)
		end)
	end,
	TW.cookieShadow(R0),
	-- osu! stable has no visualizer lines round its cookie: on every beat of the music a faint ring
	-- spreads out from the rim and fades (stronger on the bar's first beat)
	(function()
		local f = Def.ActorFrame { Name = "Ripples" }
		for i = 1, 4 do
			f[#f + 1] = TW.box { w = R0 * 2, h = R0 * 2, r = R0, ax = 0.5, ay = 0.5, tex = "ring", stroke = TW.M(5), col = { 1, 1, 1, 1 },
				blend = "BlendMode_Add", init = function(self) self:diffusealpha(0) end } .. { Name = "R" .. i,
				RippleCommand = function(self, p)
					self:stoptweening():zoom(1):diffusealpha(p.strong and 0.3 or 0.18):decelerate(1.1):zoom(p.strong and 1.5 or 1.38):diffusealpha(0)
				end }
		end
		return f
	end)(),
	Def.ActorFrame {
		Name = "Pulse",
		-- (osu!'s cookie has a see-through band just outside its white rim)
		TW.ringShape(R0 * 1.045, R0 * 0.05, { 1, 1, 1, 0.28 }),
		TW.cookie(R0, "VSRG Hub", TW.cookieColour()),
		Def.ActorFrame {
			InitCommand = function(self)
				local last = nil
				local pulse = self:GetParent()
				TW.everyFrame(self)
				self:SetUpdateFunction(function()
					local b = TW.menuBeat() or GetTimeSinceStart() * 100 / 60
					local whole = math.floor(b)
					if last and whole ~= last then
						local strong = whole % 4 == 0
						TW.visualKick(strong and 1 or 0.6)
						pulse:stoptweening():linear(0.05):zoom(strong and 1.035 or 1.02):decelerate(0.35):zoom(1)
						local rings = pulse:GetParent():GetChild("Ripples")
						rings.next = (rings.next or 0) % 4 + 1
						rings:GetChild("R" .. rings.next):playcommand("Ripple", { strong = strong })
						if strong then MESSAGEMAN:Broadcast("TWBeatFlash") end
					end
					last = whole
				end)
			end,
		},
	},
	},
	TW.button(R0 * 2, R0 * 2, function() if onCookie() then cookieClick() end end)
}

-- the packs button, as osu!direct's tab on the right edge: Etterna's pack downloader
local DW, DH = M(40), M(294)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(SCREEN_WIDTH - DW, M(263)) end,
	TW.box { w = DW + M(12), h = DH, r = M(8), col = { 0, 0, 0, 0.5 } } .. { Name = "Bg" },
	TW.box { w = DW + M(12), h = DH, r = M(8), tex = "ring", stroke = M(1.5), col = { 1, 1, 1, 0.85 } },
	Def.ActorMultiVertex { InitCommand = function(self)
		self:SetDrawState { Mode = "DrawMode_Triangles" }
		local w = { 1, 1, 1, 1 }
		self:SetVertices { { { M(10), M(60), 0 }, w }, { { M(32), M(60), 0 }, w }, { { M(21), M(78), 0 }, w } }
	end },
	TW.text(M(22), false, function(self) self:align(0, 0.5):rotationz(90):xy(M(21), M(92)):settext("packs"):shadowlength(1) end),
	TW.button(DW, DH, function() TW.keepRedirect = false; SCREENMAN:set_input_redirected(PLAYER_1, false); SCREENMAN:SetNewScreen("ScreenPackDownloader") end,
		function(self, on) TW.setBox(self:GetParent():GetChild("Bg"), { col = on and { TW.pink[1], TW.pink[2], TW.pink[3], 0.7 } or { 0, 0, 0, 0.5 } }) end) ..
		{ InitCommand = function(self) self:align(0, 0):zoomto(DW, DH):diffusealpha(0) end },
}

t[#t + 1] = TW.optionsPanel()
t[#t + 1] = TW.multiStatus()
t[#t + 1] = TW.updateNotice()
t[#t + 1] = TW.listPanel()
t[#t + 1] = TW.dialogPanel()
return t
