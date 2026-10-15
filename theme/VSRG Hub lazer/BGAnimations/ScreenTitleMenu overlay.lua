-- osu!lazer's main menu, drawn and driven here (the scroller draws nothing): the logo waits in the
-- middle with the menu's music pulsing round it; a click (or any key) moves it left and lazer's
-- button bar opens through it: settings on the left, play / browse / exit on the right; play opens
-- back / solo / multi. Exit asks first. Left alone for a while, it goes back to the middle. The
-- toolbar along the top has the settings, the key modes, packs, the music and your profile.
TW.useInterfaceSkin()
local M = TW.M

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
		-- (song select puts VSRG Hub's saved noteskin back instead of the profile's default one)
		TW.syncedOnce = {}
	end
	GAMESTATE:ApplyGameCommand(THEME:GetMetric("ScreenTitleMenu", "Choice" .. name))
end
local function askExit()
	TW.openDialog { lines = { "Are you sure you want to exit VSRG Hub?" },
		buttons = { { "Let's do it!", "green", function() choose("Exit") end }, { "Cancel", "red" } } }
end
local function packs()
	TW.keepRedirect = false
	SCREENMAN:set_input_redirected(PLAYER_1, false)
	SCREENMAN:SetNewScreen("ScreenPackDownloader")
end

-- lazer's buttons, its colours: left of the logo and right of it, for each level
local levels = {
	main = {
		left = { { label = "settings", icon = "gear", col = TW.rgb(85, 85, 85), act = function() TW.openOptions() end, key = "O" } },
		right = {
			{ label = "play", icon = "circle-play", col = TW.rgb(102, 68, 204), act = function() return "play" end, key = "P" },
			{ label = "browse", icon = "download", col = TW.rgb(165, 204, 0), act = packs, key = "D" },
			{ label = "exit", icon = "power-off", col = TW.rgb(238, 51, 153), act = askExit, key = "Q" },
		},
	},
	play = {
		left = { { label = "back", icon = "arrow-left", col = TW.rgb(51, 58, 94), act = function() return "main" end } },
		right = {
			{ label = "solo", icon = "user", col = TW.rgb(102, 68, 204), act = function() choose("GameStart") end, key = "S" },
			{ label = "multi", icon = "users", col = TW.rgb(94, 63, 186), act = function() choose("Multi") end, key = "M" },
		},
	},
}
-- the order the arrow keys go through them (left to right on screen)
local function ordered(lvl)
	local out = {}
	for i = #levels[lvl].left, 1, -1 do out[#out + 1] = levels[lvl].left[i] end
	for _, b in ipairs(levels[lvl].right) do out[#out + 1] = b end
	return out
end
local level, sel, hover = "main", 0, nil
local awake, lastInput = false, 0
local IDLE_AFTER = 12

local function refresh() MESSAGEMAN:Broadcast("TWTitleMenu") end
local function wake()
	lastInput = GetTimeSinceStart()
	if not awake then awake = true; refresh() end
end
local function activateButton(b)
	wake()
	if not b then return end
	local nxt = b.act()
	if nxt then level, sel, hover = nxt, 0, nil; refresh() end
end
local function activate(i) activateButton(ordered(level)[i]) end
local function byKey(letter)
	for _, b in ipairs(ordered(level)) do if b.key == letter then activateButton(b) return true end end
	return false
end
local function home()
	if level ~= "main" then level, sel = "main", 0; wake(); refresh()
	elseif awake then awake = false; sel = 0; refresh() end
end

local function input(event)
	if TW.dialogInput(event) then return true end
	if TW.listInput(event) then return true end
	if TW.optionsInput(event) then return true end
	if event.type == "InputEventType_FirstPress" then lastInput = GetTimeSinceStart() end
	if event.type ~= "InputEventType_FirstPress" or event.DeviceInput.is_mouse then return false end
	local b = event.DeviceInput.button
	-- (the first key wakes the menu up, as in lazer: it isn't also a choice)
	if not awake and not TW.dialogSpec and not TW.list and not TW.optionsOpen and b ~= "DeviceButton_escape" then wake() return true end
	if TW.key(event, "options", b == "DeviceButton_o" and INPUTFILTER:IsControlPressed()) then TW.openOptions() return true end
	if TW.key(event, "keybinds", false) then TW.openKeybinds() return true end
	local n = #ordered(level)
	if b == "DeviceButton_left" or b == "DeviceButton_up" then sel = (sel <= 1) and n or sel - 1; refresh()
	elseif b == "DeviceButton_right" or b == "DeviceButton_down" or b == "DeviceButton_tab" then sel = (sel % n) + 1; refresh()
	elseif b == "DeviceButton_enter" or b == "DeviceButton_KP enter" or b == "DeviceButton_space" then
		if sel > 0 then activate(sel) else activateButton(levels[level].right[1]) end
	elseif b == "DeviceButton_escape" then
		if level ~= "main" then level, sel = "main", 0; refresh()
		elseif awake then awake = false; refresh()
		else askExit() end
	-- (lazer's letters: P(lay), O(ptions), D(irect: browse), Q(uit), S(olo), M(ulti); only on their
	-- own, so a shortcut with Ctrl or Alt isn't also one of them)
	elseif INPUTFILTER:IsControlPressed() or TW.altHeld() then return true
	elseif b:match("^DeviceButton_%a$") then byKey(b:sub(-1):upper())
	end
	return true
end

-- the logo's places: big in the middle while idle, smaller left of the middle on the bar once awake
local R0 = M(250)
local AWAKE_ZOOM = 0.5
local BY = M(420) -- the bar's middle
local BH = M(100) -- its height
local BW = M(150) -- a button's width
local LX = SCREEN_CENTER_X - M(240)
local GAP = M(3)
local logo -- (the logo's frame, for the buttons to follow while it moves)
-- (the logo covers the first button's left end: a click there is the logo's)
local function onLogo()
	if not logo then return false end
	local dx, dy = INPUTFILTER:GetMouseX() - logo:GetX(), INPUTFILTER:GetMouseY() - logo:GetY()
	local r = R0 * logo:GetZoom()
	return dx * dx + dy * dy <= r * r
end
local function logoClick()
	if not awake then wake()
	elseif level == "main" then level, sel = "play", 0; wake(); refresh()
	else activateButton(levels.play.right[1]) end
end

local t = Def.ActorFrame {
	TW.mouse(),
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
		TW.keepRedirect = true
		SCREENMAN:set_input_redirected(PLAYER_1, true)
		refresh()
		-- (Etterna locks the menu's input while the screen's longest opening animation runs: unlocked
		-- on the next frame, after it has set that lock)
		self:queuecommand("Unlock")
		self:sleep(0.05):queuecommand("Theme")
		TW.menuMusicStart()
	end,
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
	TWTitleChooseMessageCommand = function(self, p) if p.index == 0 then activate(1) end end,
}

-- the bar behind the buttons, right across the screen; it opens out from the logo
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, BY):zoomx(0):diffusealpha(0) end,
	TWTitleMenuMessageCommand = function(self)
		self:stoptweening():decelerate(0.3):zoomx(awake and 1 or 0):diffusealpha(awake and 1 or 0)
	end,
	Def.Quad { InitCommand = function(self) self:zoomto(SCREEN_WIDTH, BH):diffuse({ 0.16, 0.2, 0.24, 0.55 }):diffuseleftedge({ 0.12, 0.15, 0.2, 0.75 }):diffuserightedge({ 0.12, 0.15, 0.2, 0.75 }) end },
}

-- the buttons: every one is laid out each frame (the one under the mouse or picked grows wider and
-- pushes the others along, as in lazer)
local all = {}
local function buttonActor(lvl, side, i, s)
	local rec = { lvl = lvl, side = side, i = i, s = s, w = BW, first = side == "right" and i == 1 }
	all[#all + 1] = rec
	local id = lvl .. side .. i
	local light = TW.mix(s.col, { 1, 1, 1, 1 }, 0.08)
	local dark = TW.mix(s.col, { 0, 0, 0, 1 }, 0.12)
	return Def.ActorFrame {
		InitCommand = function(self) rec.actor = self; self:y(BY - BH / 2):diffusealpha(0):visible(false) end,
		TWTitleMenuMessageCommand = function(self)
			local shown = awake and level == lvl
			self:stoptweening()
			if shown then
				self:visible(true):sleep(0.04 * i):linear(0.18):diffusealpha(1)
			else
				self:linear(0.12):diffusealpha(0):queuecommand("Hide")
			end
			local focus = shown and (hover == id or ordered(lvl)[sel] == s)
			rec.focus = focus
			local c = self:GetChildren()
			c.Glow:stoptweening():linear(0.12):diffusealpha(focus and 0.35 or 0)
		end,
		HideCommand = function(self) if not (awake and level == lvl) then self:visible(false) end end,
		TW.shadow { w = BW, h = BH, spread = M(8), alpha = 0.35 } .. { Name = "Shadow" },
		LZ.panel { w = BW, h = BH, r = M(3), col = light, col2 = dark } .. { Name = "Bg" },
		LZ.panel { w = BW, h = BH, r = M(3), blend = "BlendMode_Add", col = { 1, 1, 1, 0.5 }, col2 = { 1, 1, 1, 0.1 } } .. { Name = "Glow", InitCommand = function(self) self:diffusealpha(0) end },
		-- (the icon of the button under the mouse hops to the beat, as lazer's do)
		TW.icon(s.icon, M(30), function(self) self:y(BH * 0.42) end) .. { Name = "Icon",
			TWMenuBeatMessageCommand = function(self)
				if not rec.focus then return end
				self:stoptweening():decelerate(0.1):y(BH * 0.42 - M(5)):accelerate(0.18):y(BH * 0.42)
			end },
		LZ.text(M(13.5), "regular", function(self) self:align(0.5, 0.5):y(BH * 0.78):settext(s.label) end) .. { Name = "Label" },
		TW.button(BW, BH, function()
			if onLogo() then logoClick() return end
			if awake and level == lvl then activateButton(s) end
		end, function(self, on)
			if not awake or level ~= lvl then return end
			lastInput = GetTimeSinceStart()
			hover = on and id or (hover == id and nil or hover)
			refresh()
		end) .. { Name = "Click", InitCommand = function(self) self:align(0, 0):zoomto(BW, BH):diffusealpha(0):z(5) end },
	}
end
for _, lvl in ipairs({ "main", "play" }) do
	for i, s in ipairs(levels[lvl].left) do t[#t + 1] = buttonActor(lvl, "left", i, s) end
	for i, s in ipairs(levels[lvl].right) do t[#t + 1] = buttonActor(lvl, "right", i, s) end
end
-- the layout, every frame
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		TW.everyFrame(self)
		self:SetUpdateFunction(function(_, dt)
			dt = dt or 0
			-- (back to the middle after a while with nothing pressed)
			if awake and level == "main" and not TW.dialogSpec and not TW.list and not TW.optionsOpen
				and GetTimeSinceStart() - lastInput > IDLE_AFTER then
				awake = false; sel = 0; hover = nil; refresh()
			end
			local lx = logo and logo:GetX() or LX
			local ra = R0 * (logo and logo:GetZoom() or AWAKE_ZOOM)
			local xr = { main = lx, play = lx }
			local xl = { main = lx - ra * 0.9, play = lx - ra * 0.9 }
			for _, b in ipairs(all) do
				if b.actor then
					local extra = b.first and ra or 0
					local target = BW + extra + (b.focus and M(28) or 0)
					b.w = b.w + (target - b.w) * math.min(1, dt * 12)
					local x
					if b.side == "right" then
						x = xr[b.lvl]; xr[b.lvl] = x + b.w + GAP
					else
						x = xl[b.lvl] - b.w; xl[b.lvl] = x - GAP
					end
					b.actor:x(x)
					if math.abs((b.drawn or 0) - b.w) > 0.4 then
						b.drawn = b.w
						local c = b.actor:GetChildren()
						TW.setBox(c.Bg, { w = b.w }); TW.setBox(c.Glow, { w = b.w }); TW.setBox(c.Shadow, { w = b.w + M(16) })
						c.Click:zoomto(b.w, BH)
						-- (the word and icon in the part the logo doesn't cover)
						local mid = extra + (b.w - extra) / 2
						c.Icon:x(mid); c.Label:x(mid)
					end
				end
			end
		end)
	end,
}

-- the logo, in front of the buttons: in the middle while idle, on the bar once awake; clicking it
-- wakes the menu, then opens play, then solo. It and the bars round it move to the music's beat.
t[#t + 1] = Def.ActorFrame {
	Name = "Logo",
	InitCommand = function(self) logo = self; self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + M(10)) end,
	OnCommand = function(self) self:zoom(0.85):diffusealpha(0):decelerate(0.5):zoom(1):diffusealpha(1) end,
	TWTitleMenuMessageCommand = function(self)
		-- (diffusealpha: ends the fade-in it may have cut short, which left the logo see-through)
		self:stoptweening():decelerate(0.4):diffusealpha(1)
		if awake then self:xy(LX, BY):zoom(AWAKE_ZOOM) else self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + M(10)):zoom(1) end
	end,
	TW.cookieShadow(R0),
	TW.ringShape(R0, TW.M(4), { 1, 1, 1, 1 }, function(self) self:diffusealpha(0) end) .. { Name = "Ripple",
		RippleCommand = function(self) self:stoptweening():zoom(1):diffusealpha(0.35):decelerate(0.8):zoom(1.4):diffusealpha(0) end },
	Def.ActorFrame { Name = "Hover", Def.ActorFrame {
		Name = "Pulse",
		TW.visualizer(R0, { 1, 1, 1, 0.42 }, 180),
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
						MESSAGEMAN:Broadcast("TWMenuBeat")
						TW.visualKick(strong and 1 or 0.6)
						pulse:stoptweening():linear(0.05):zoom(strong and 1.04 or 1.02):decelerate(0.4):zoom(1)
						if strong then pulse:GetParent():GetParent():GetChild("Ripple"):playcommand("Ripple") MESSAGEMAN:Broadcast("TWBeatFlash") end
					end
					last = whole
				end)
			end,
		},
	} },
	TW.button(R0 * 2, R0 * 2, function() if onLogo() then logoClick() end end, function(self, on)
		self:GetParent():GetChild("Hover"):stoptweening():decelerate(0.15):zoom(on and 1.05 or 1)
	end)
}

-- lazer's toolbar: hidden while the logo waits alone, down once the menu is awake
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:y(-M(60)) end,
	TWTitleMenuMessageCommand = function(self) self:stoptweening():decelerate(0.3):y(awake and 0 or -M(60)) end,
	LZ.toolbar { home = home },
}

t[#t + 1] = TW.optionsPanel()
t[#t + 1] = TW.listPanel()
t[#t + 1] = TW.dialogPanel()
return t
