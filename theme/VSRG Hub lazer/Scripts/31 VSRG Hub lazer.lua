-- VSRG Hub lazer: osu!lazer's look over VSRG Hub osu!, which supplies the plumbing (options, lists,
-- collections, noteskins, scores) and the screens lazer shares with it. This sets lazer's colours,
-- its rounded font, the slant of its buttons and the pieces every screen shares: the toolbar along
-- the top, the "now playing" panel under it, the footer buttons and the dark slanted panels.
TW.isLazer = true
LZ = {}

-- lazer's slant (its buttons, tabs, the song info wedge and the scores lean right at the top)
LZ.SHEAR = 0.15

-- Nunito (SIL OFL 1.1), drawn as bitmap fonts under VSRG Hub's own names, stands in for lazer's Torus
TW.font = "_lz regular"
TW.bold = "_lz bold"
LZ.light = "_lz light"
TW.light = LZ.light
TW.fontBig = { ["_lz regular"] = "_lzx regular", ["_lz bold"] = "_lzx bold", ["_lz light"] = "_lzx light" }
TW.fontHuge = { ["_lz bold"] = "_lzy bold", ["_lz light"] = "_lzy light" }
TW.fontSmall = { ["_lz regular"] = "_lzs regular", ["_lz bold"] = "_lzs bold", ["_lz light"] = "_lzs light" }
-- text px tall (cap height); weight "light", "regular" (default) or "bold"
function LZ.text(px, weight, init)
	-- (the copy closest to the size drawn on screen, as TW.fontFor picks)
	local f, z = TW.pickFont(weight == "bold" and TW.bold or (weight == "light" and LZ.light or TW.font), px)
	return LoadFont(f) .. {
		InitCommand = function(self)
			self:zoom(z):halign(0):shadowlength(0)
			if init then init(self) end
		end
	}
end

-- lazer's colours (osu.Game.Graphics.OsuColour)
local rgb = TW.rgb
LZ.pink = rgb(255, 102, 170)
LZ.pinkLight = rgb(255, 153, 204)
LZ.pinkDark = rgb(187, 17, 119)
LZ.purple = rgb(136, 102, 238)
LZ.purpleLight = rgb(170, 136, 255)
LZ.purpleDark = rgb(102, 68, 204)
LZ.blue = rgb(102, 204, 255)
LZ.blueDark = rgb(68, 170, 221)
LZ.yellow = rgb(255, 204, 34)
LZ.yellowDark = rgb(238, 170, 0)
LZ.green = rgb(136, 179, 0)
LZ.greenLight = rgb(179, 217, 68)
LZ.lime = rgb(170, 220, 40)
LZ.red = rgb(237, 17, 33)
LZ.redLight = rgb(255, 102, 102)
LZ.orange = rgb(255, 136, 0)
LZ.white = color("#FFFFFF")
-- lazer's overlay greys: dark, a little tinted with the overlay's colour (pink here, hue 333)
local function hsl(h, s, l, a)
	local function f(n)
		local k = (n + h / 30) % 12
		local m = s * math.min(l, 1 - l)
		return l - m * math.max(-1, math.min(k - 3, 9 - k, 1))
	end
	return { f(0), f(8), f(4), a or 1 }
end
LZ.hsl = hsl
-- Background6 (darkest) .. Background1, then Dark6.. and Light4..1 as lazer's ColourProvider names them
LZ.bg6 = hsl(333, 0.1, 0.06)
LZ.bg5 = hsl(333, 0.1, 0.1)
LZ.bg4 = hsl(333, 0.1, 0.15)
LZ.bg3 = hsl(333, 0.1, 0.2)
LZ.bg2 = hsl(333, 0.1, 0.25)
LZ.bg1 = hsl(333, 0.1, 0.3)
LZ.fg1 = hsl(333, 0.1, 0.7)
LZ.light4 = hsl(333, 0.4, 0.5)
LZ.light3 = hsl(333, 0.4, 0.6)
LZ.light2 = hsl(333, 0.4, 0.7)
LZ.light1 = hsl(333, 0.4, 0.8)
LZ.content2 = hsl(333, 0.4, 0.9)
LZ.dim = hsl(333, 0.15, 0.75)
function LZ.a(c, a) return { c[1], c[2], c[3], a } end

-- the interface colour: lazer's pink, or the one picked in the options
function TW.applyAccent()
	local a = nil
	for _, c in ipairs(TW.ACCENTS or {}) do
		if c.key == (TW.settings and TW.settings.accent) and c.rgb then a = c.rgb end
	end
	TW.pink = a and TW.rgb(a[1], a[2], a[3]) or LZ.pink
	TW.pinkLight = TW.mix(TW.pink, { 1, 1, 1, 1 }, 0.3)
end
TW.applyAccent()
TW.yellow = LZ.yellow
TW.green = LZ.lime
TW.blue = LZ.blue

-- lazer draws its own interface (an osu! skin only dresses the notes and what you see while playing)
function TW.useInterfaceSkin()
	TW_SKIN = nil
	TW.applyAccent()
end
TW_SKIN = nil

-- osu!lazer's grade colours (OsuColour.ForRank: SS pink, S cyan, A green, B gold, C orange, D red),
-- for every grade VSRG Hub shows in this look
LZ.rank = {
	X = rgb(222, 49, 174), S = rgb(2, 181, 195), A = rgb(136, 218, 32), B = rgb(227, 177, 48),
	C = rgb(255, 142, 93), D = rgb(255, 90, 90), F = rgb(150, 150, 160),
}
TW.RankColour = LZ.rank
function LZ.rankColour(r) return LZ.rank[r] or rgb(150, 150, 160) end
-- the letter on a grade's tab: the grade's colour, much darker
function LZ.rankText(r) return TW.mix(LZ.rankColour(r), { 0, 0, 0, 1 }, 0.55) end

-- osu!lazer's star rating colours (blue, green, yellow, orange, red, purple, black), by MSD
local starStops = { { 0, rgb(79, 192, 255) }, { 8, rgb(79, 255, 213) }, { 12, rgb(124, 255, 79) }, { 17, rgb(246, 240, 92) },
	{ 22, rgb(255, 128, 104) }, { 27, rgb(255, 78, 111) }, { 32, rgb(198, 69, 184) }, { 37, rgb(101, 99, 222) }, { 42, rgb(24, 21, 142) } }
function LZ.starColour(v)
	v = v or 0
	if v <= starStops[1][1] then return starStops[1][2] end
	for i = 2, #starStops do
		local a, b = starStops[i - 1], starStops[i]
		if v <= b[1] then return TW.mix(a[2], b[2], (v - a[1]) / (b[1] - a[1])) end
	end
	return starStops[#starStops][2]
end
-- dark text on light star pills, light text on dark ones (as lazer does)
function LZ.starText(v) return (v or 0) < 30 and rgb(30, 25, 35) or LZ.yellow end

-- The chart's difficulty on a pill in lazer's star-rating colours, a star before it (it's Etterna's
-- MSD, in lazer's dress). Set with :playcommand("Msd", { v = 23.4 }); its width is then self.w.
function LZ.starPill(h, init)
	return Def.ActorFrame {
		InitCommand = function(self) if init then init(self) end end,
		MsdCommand = function(self, p)
			local v = p.v or 0
			local c = self:GetChildren()
			c.V:settextf("%.2f", v):diffuse(LZ.starText(v))
			c.S:diffuse(LZ.starText(v))
			local w = h * 1.4 + c.V:GetZoomedWidth()
			TW.setBox(c.Bg, { w = w, col = LZ.starColour(v) })
			c.V:x(h * 1.0)
			self.w = w
		end,
		TW.box { w = h * 3, h = h, r = h / 2, ay = 0.5 } .. { Name = "Bg" },
		TW.icon("star", h * 0.5, function(self) self:xy(h * 0.6, -h * 0.02) end) .. { Name = "S" },
		LZ.text(h * 0.52, "bold", function(self) self:align(0, 0.5):y(-h * 0.02) end) .. { Name = "V" },
	}
end

-- A slanted panel (lazer's wedge, footer buttons, scores): w x h, top-left at the actor's position.
function LZ.panel(spec)
	spec.shear = spec.shear == nil and LZ.SHEAR or spec.shear
	spec.r = spec.r or TW.M(8)
	return TW.box(spec)
end

-- ------------------------------------------------------------------------------------------------
-- The toolbar (lazer's top bar): options and home on the left, the key mode (lazer's rulesets) next
-- to them; packs, collections, music, your profile and the clock on the right. opts: home (function),
-- profile (function or nil), collections (function or nil)
-- ------------------------------------------------------------------------------------------------
LZ.BAR = 40 -- (lazer's toolbar is 40 of its 768 pixels)
local function tbButton(spec)
	local M = TW.M
	local w = spec.w or M(48)
	local H = M(LZ.BAR)
	local f = Def.ActorFrame {
		InitCommand = function(self) self:x(spec.x) end,
		Def.Quad { Name = "Hl", InitCommand = function(self) self:align(spec.right and 1 or 0, 0):zoomto(w, H):diffuse({ 1, 1, 1, 0 }) end },
	}
	local cx = spec.right and -w / 2 or w / 2
	if spec.icon then
		f[#f + 1] = TW.icon(spec.icon, M(17), function(self) self:xy(cx, H / 2) end) .. { Name = "Icon" }
	end
	if spec.content then f[#f + 1] = spec.content end
	-- the tooltip under it, as lazer's: what it is, and what it does
	if spec.tip then
		f[#f + 1] = Def.ActorFrame {
			Name = "Tip",
			InitCommand = function(self) self:xy(spec.right and -w or 0, H + M(6)):visible(false):diffusealpha(0):z(40) end,
			HideCommand = function(self) self:visible(false) end,
			TW.shadow { w = M(230), h = M(52), spread = M(10), alpha = 0.5, init = function(self) self:x(spec.right and -M(230) + w or 0) end },
			TW.box { w = M(230), h = M(52), r = M(6), col = LZ.a(LZ.bg5, 0.97), init = function(self) self:x(spec.right and -M(230) + w or 0) end },
			LZ.text(M(13), "bold", function(self) self:align(0, 0):xy((spec.right and -M(230) + w or 0) + M(10), M(8)):settext(spec.tip[1]) end),
			LZ.text(M(11), "regular", function(self) self:align(0, 0):xy((spec.right and -M(230) + w or 0) + M(10), M(29)):settext(spec.tip[2]):diffuse(LZ.dim)
				self:maxwidth(M(210) / self:GetZoom()) end),
		}
	end
	f[#f + 1] = TW.button(w, H, function() if spec.onClick then spec.onClick() end end, function(self, on)
		local p = self:GetParent()
		p:GetChild("Hl"):stoptweening():linear(0.1):diffusealpha(on and 0.12 or 0)
		local tip = p:GetChild("Tip")
		if tip then
			tip:stoptweening()
			if on then tip:visible(true):sleep(0.35):linear(0.12):diffusealpha(1) else tip:linear(0.08):diffusealpha(0):queuecommand("Hide") end
		end
	end) .. { InitCommand = function(self) self:align(spec.right and 1 or 0, 0):zoomto(w, H):diffusealpha(0) end }
	return f
end
LZ.tbButton = tbButton

function LZ.toolbar(opts)
	opts = opts or {}
	local M = TW.M
	local H = M(LZ.BAR)
	local t = Def.ActorFrame {
		Name = "LZToolbar",
		InitCommand = function(self) self:z(25) end,
		OnCommand = function(self) self:y(-H):decelerate(0.3):y(0) end,
		-- the bar: near black, a little see-through
		Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, H):diffuse({ 0.09, 0.09, 0.1, 0.94 }) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):y(H):zoomto(SCREEN_WIDTH, M(10)):diffuse({ 0, 0, 0, 0.3 }):diffusebottomedge({ 0, 0, 0, 0 }) end },
		-- (clicks on the bar itself go nowhere)
		TW.button(1, 1, function() end) .. { InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, H):diffusealpha(0) end },
	}
	-- left: options, home
	t[#t + 1] = tbButton { x = 0, icon = "gear", tip = { "settings", "Change the way VSRG Hub behaves (Ctrl+O)" }, onClick = function() TW.openOptions() end }
	t[#t + 1] = tbButton { x = M(48), icon = "house", tip = { "home", "Return to the main menu" }, onClick = opts.home }
	-- the key modes, where lazer has its rulesets: the one you play lit, a line under it
	local x0 = M(110)
	for i, g in ipairs({ { "dance", "4K", "osu!mania 4K" }, { "kb7", "7K", "osu!mania 7K" } }) do
		local on = TW.gameName() == g[1]
		t[#t + 1] = tbButton {
			x = x0 + (i - 1) * M(52), w = M(52), tip = { g[3], on and "The mode you are playing" or "Switch to " .. g[2] .. " (VSRG Hub restarts its menus)" },
			onClick = function() if not on then TW.switchGame(g[1]) end end,
			content = Def.ActorFrame {
				TW.box { w = M(30), h = M(22), r = M(6), ax = 0.5, ay = 0.5, tex = "ring", col = on and { 1, 1, 1, 1 } or { 1, 1, 1, 0.45 }, init = function(self) self:xy(M(26), H / 2) end },
				LZ.text(M(10.5), "bold", function(self) self:align(0.5, 0.5):xy(M(26), H / 2):settext(g[2]):diffusealpha(on and 1 or 0.5) end),
				Def.Quad { InitCommand = function(self) self:align(0.5, 1):xy(M(26), H):zoomto(M(26), M(3)):diffuse(on and LZ.lime or { 1, 1, 1, 0 }) end },
				on and TW.glow(M(40), LZ.a(LZ.lime, 0.25), function(self) self:xy(M(26), H) end) or Def.Actor {},
			},
		}
	end
	-- right, from the right edge: clock, profile, music, collections, packs
	local rx = SCREEN_WIDTH
	-- clock (and how long VSRG Hub has been running, as lazer's clock can show)
	t[#t + 1] = tbButton { x = rx, w = M(118), right = true, tip = { "clock", "The time, and how long VSRG Hub has been running" },
		content = Def.ActorFrame {
			LZ.text(M(13), "regular", function(self) self:align(1, 0.5):xy(-M(14), H / 2 - M(6)) end) .. {
				OnCommand = function(self) self:playcommand("Tick") end,
				TickCommand = function(self)
					local h, m, s = Hour(), Minute(), Second()
					self:settextf("%d:%02d:%02d %s", (h % 12 == 0) and 12 or (h % 12), m, s, h < 12 and "AM" or "PM")
					self:sleep(0.5):queuecommand("Tick")
				end,
			},
			LZ.text(M(9.5), "regular", function(self) self:align(1, 0.5):xy(-M(14), H / 2 + M(9)):diffuse(LZ.lime) end) .. {
				OnCommand = function(self) self:playcommand("Tick") end,
				TickCommand = function(self)
					local s = math.floor(GetTimeSinceStart())
					self:settextf("%d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
					self:sleep(0.5):queuecommand("Tick")
				end,
			},
		} }
	rx = rx - M(118)
	-- your profile: name, rating and avatar (click: the profile page on song select)
	local UW = M(196)
	t[#t + 1] = tbButton { x = rx, w = UW, right = true, tip = { "profile", opts.profile and "Your profile: ratings, top plays, recent plays" or "Your profile (open it on song select)" },
		onClick = opts.profile,
		content = Def.ActorFrame {
			BeginCommand = function(self) self:playcommand("Set") end,
			PlayerRatingUpdatedMessageCommand = function(self) self:playcommand("Set") end,
			LZ.text(M(13), "bold", function(self) self:align(1, 0.5):xy(-M(48), H / 2 - M(6)):maxwidth(M(120) / self:GetZoom()) end) .. {
				SetCommand = function(self)
					local p = TW.profile()
					local n = p and p:GetDisplayName() or ""
					self:settext(n ~= "" and n or "Guest")
				end,
			},
			LZ.text(M(10), "regular", function(self) self:align(1, 0.5):xy(-M(48), H / 2 + M(9)):diffuse(LZ.pinkLight) end) .. {
				SetCommand = function(self) local p = TW.profile(); self:settextf("%.2f", p and p:GetPlayerRating() or 0) end,
			},
			Def.Sprite { SetCommand = function(self)
				local _, av = TW.profile()
				self:Load(av):align(0.5, 0.5):xy(-M(24), H / 2):zoomto(M(28), M(28))
			end },
			TW.box { w = M(30), h = M(30), r = M(8), ax = 0.5, ay = 0.5, tex = "ring", col = { 1, 1, 1, 0.25 }, init = function(self) self:xy(-M(24), H / 2) end },
		} }
	rx = rx - UW
	t[#t + 1] = tbButton { x = rx, right = true, icon = "music", tip = { "now playing", "Manage the music that's playing (Ctrl+F6 in lazer)" },
		onClick = function() MESSAGEMAN:Broadcast("LZNowPlaying", { toggle = true }) end }
	rx = rx - M(48)
	if opts.collections then
		t[#t + 1] = tbButton { x = rx, right = true, icon = "layer-group", tip = { "collections", "Your collections and the charts in them" }, onClick = opts.collections }
		rx = rx - M(48)
	end
	t[#t + 1] = tbButton { x = rx, right = true, icon = "download", tip = { "packs", "Download packs of charts (Etterna's pack downloader)" },
		onClick = function()
			TW.keepRedirect = false
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			SCREENMAN:SetNewScreen("ScreenPackDownloader")
		end }
	t[#t + 1] = LZ.nowPlaying()
	return t
end

-- ------------------------------------------------------------------------------------------------
-- Now playing (lazer's music controller), under the toolbar's music button: the song's picture,
-- its title and artist, previous / play-pause / next and how far it has played. On the main menu it
-- drives the menu's music; elsewhere it shows the song that's selected.
-- ------------------------------------------------------------------------------------------------
function LZ.nowPlaying()
	local M = TW.M
	local W, H = M(400), M(130)
	local open = false
	local function song()
		if TW.menu and TW.menu.playing and TW.menu.song then return TW.menu.song end
		return GAMESTATE:GetCurrentSong()
	end
	local onMenu = function() return TW.menu ~= nil and TW.menu.playing == true end
	local f = Def.ActorFrame {
		Name = "LZNowPlaying",
		InitCommand = function(self) self:xy(SCREEN_WIDTH - W - M(10), M(LZ.BAR) + M(8)):visible(false):z(45) end,
		LZNowPlayingMessageCommand = function(self, p)
			if p.toggle then open = not open elseif p.open ~= nil then open = p.open end
			self:stoptweening()
			if open then
				self:visible(true):diffusealpha(0):y(M(LZ.BAR)):decelerate(0.2):diffusealpha(1):y(M(LZ.BAR) + M(8))
				self:playcommand("Fill")
			else
				self:linear(0.12):diffusealpha(0):queuecommand("Hide")
			end
		end,
		HideCommand = function(self) self:visible(false) end,
		TWMenuMusicMessageCommand = function(self) if open then self:playcommand("Fill") end end,
		CurrentSongChangedMessageCommand = function(self) if open then self:playcommand("Fill") end end,
		TW.shadow { w = W, h = H, spread = M(16), alpha = 0.6, drop = M(4) },
		TW.box { w = W, h = H, r = M(10), col = LZ.a(LZ.bg5, 0.98) },
		-- the song's picture, faded towards the bottom
		Def.Sprite { Name = "Pic", FillCommand = function(self)
			local s = song()
			local p = s and TW.bigPicture(s)
			if p and p ~= "" and p ~= self.shown then self.shown = p; self:LoadBackground(p) end
			self:visible(p ~= nil and p ~= ""):scaletocover(M(4), M(4), W - M(4), H - M(40)):cropbottom(0):diffusealpha(0.45):fadebottom(0.5)
		end },
		LZ.text(M(17), "bold", function(self) self:align(0.5, 0.5):xy(W / 2, M(30)):maxwidth((W - M(30)) / self:GetZoom()) end) .. {
			FillCommand = function(self) local s = song(); self:settext(s and s:GetDisplayMainTitle() or "Nothing is playing") end },
		LZ.text(M(12), "regular", function(self) self:align(0.5, 0.5):xy(W / 2, M(52)):diffuse(LZ.dim):maxwidth((W - M(30)) / self:GetZoom()) end) .. {
			FillCommand = function(self) local s = song(); self:settext(s and s:GetDisplayArtist() or "") end },
		-- how far it has played (the menu's music only: song select plays its preview)
		TW.box { w = W - M(32), h = M(4), r = M(2), col = { 1, 1, 1, 0.15 }, init = function(self) self:xy(M(16), H - M(14)) end },
		Def.ActorFrame {
			InitCommand = function(self)
				local bar = self:GetChild("P")
				TW.everyRefresh(self)
				self:SetUpdateFunction(function()
					if not self:GetParent():GetVisible() then return end
					local m = TW.menu
					local frac = 0
					if onMenu() and m.len and m.len > 0 then
						local t = m.paused and ((m.pausedAt or m.start) - m.start) or (GetTimeSinceStart() - m.startedAt)
						frac = (t % m.len) / m.len
					end
					-- (redrawn only when it has grown by a pixel's worth)
					local w = math.max(M(4), (W - M(32)) * frac)
					if not bar.twW or math.abs(w - bar.twW) >= TW.px() * 0.5 then bar.twW = w; TW.setBox(bar, { w = w }) end
				end)
			end,
			TW.box { w = M(4), h = M(4), r = M(2), col = LZ.pink, init = function(self) self:xy(M(16), H - M(14)) end } .. { Name = "P" },
		},
	}
	local controls = {
		{ "backward-step", function() if onMenu() then TW.menuMusicPrev() end end },
		{ "pause", function() if onMenu() then TW.menuMusicToggle() end end, true },
		{ "forward-step", function() if onMenu() then TW.menuMusicNext() end end },
	}
	for i, c in ipairs(controls) do
		f[#f + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(W / 2 + (i - 2) * M(56), M(86)) end,
			FillCommand = function(self) self:diffusealpha(onMenu() and 1 or 0.35) end,
			TW.box { w = M(44), h = M(30), r = M(15), ax = 0.5, ay = 0.5, col = { 1, 1, 1, 0.08 } } .. { Name = "Bg" },
			Def.Sprite { Name = "I", Texture = TW.iconPath(c[1]), InitCommand = function(self) self:zoomto(M(14), M(14)) end,
				FillCommand = function(self) if c[3] then self:Load(TW.iconPath((TW.menu and TW.menu.paused) and "play" or "pause")):zoomto(M(14), M(14)) end end,
				TWMenuMusicMessageCommand = function(self) self:playcommand("Fill") end },
			TW.button(M(44), M(30), function() c[2]() end, function(self, on)
				TW.setBox(self:GetParent():GetChild("Bg"), { col = on and LZ.a(LZ.pink, 0.8) or { 1, 1, 1, 0.08 } })
			end) .. { InitCommand = function(self) self:zoomto(M(44), M(30)):diffusealpha(0) end },
		}
	end
	-- (a click on the panel stays on it)
	table.insert(f, 3, TW.button(W, H, function() end) .. { InitCommand = function(self) self:align(0, 0):zoomto(W, H):diffusealpha(0) end })
	return f
end

-- ------------------------------------------------------------------------------------------------
-- Footer buttons (lazer's song select, results): slanted tabs with an icon, a word and a line of
-- their colour along the bottom that lights up under the mouse.
-- ------------------------------------------------------------------------------------------------
LZ.FOOT = 64
function LZ.footerButton(spec)
	local M = TW.M
	local w, h = spec.w or M(120), M(LZ.FOOT) - M(14)
	local col = spec.col or LZ.pink
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(spec.x, SCREEN_HEIGHT - M(8) - h) end,
		OnCommand = function(self) self:addy(M(80)):sleep(spec.delay or 0):decelerate(0.3):addy(-M(80)) end,
		LZActiveMessageCommand = function(self, p)
			if spec.id and p.id == spec.id then
				TW.setBox(self:GetChild("Line"), { col = p.on and col or LZ.a(col, 0.6) })
				self:GetChild("Glow"):stoptweening():linear(0.1):diffusealpha(p.on and 0.3 or 0)
			end
		end,
		TW.shadow { w = w, h = h, spread = M(8), alpha = 0.4, drop = M(2) },
		LZ.panel { w = w, h = h, col = LZ.a(LZ.bg3, 0.96), col2 = LZ.a(LZ.bg4, 0.96) } .. { Name = "Bg" },
		LZ.panel { w = w, h = h, blend = "BlendMode_Add", col = LZ.a(col, 0.0), col2 = LZ.a(col, 0.6) } .. { Name = "Glow", InitCommand = function(self) self:diffusealpha(0) end },
		-- (the line along the bottom in the button's colour)
		LZ.panel { w = w - M(24), h = M(4), r = M(2), shear = 0, col = LZ.a(col, 0.6), init = function(self) self:xy(M(12), h - M(8)) end } .. { Name = "Line" },
		TW.icon(spec.icon, M(16), function(self) self:xy(w / 2 + M(2), h * 0.36) end) .. { Name = "Icon" },
		LZ.text(M(12.5), "bold", function(self) self:align(0.5, 0.5):xy(w / 2, h * 0.7):settext(spec.label) end) .. { Name = "Label" },
		spec.key and LZ.text(M(8.5), "regular", function(self) self:align(1, 0):xy(w - M(10), M(4)):settext(spec.key):diffuse(LZ.a(col, 0.9)) end) or Def.Actor {},
		TW.button(w, h, function() if spec.onClick then spec.onClick() end end, function(self, on)
			local p = self:GetParent()
			p:GetChild("Glow"):stoptweening():linear(0.1):diffusealpha(on and 0.3 or 0)
			TW.setBox(p:GetChild("Line"), { col = on and col or LZ.a(col, 0.6) })
			p:GetChild("Icon"):stoptweening():decelerate(0.1):zoomto(M(on and 18 or 16), M(on and 18 or 16))
		end) .. { InitCommand = function(self) self:align(0, 0):zoomto(w, h):diffusealpha(0) end },
	}
end
-- lazer's big pink back button at the bottom left
function LZ.backButton(onClick, label)
	local M = TW.M
	local w, h = M(250), M(LZ.FOOT) - M(14)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(-M(20), SCREEN_HEIGHT - M(8) - h) end,
		OnCommand = function(self) self:addx(-M(120)):decelerate(0.3):addx(M(120)) end,
		TW.shadow { w = w, h = h, spread = M(8), alpha = 0.45, drop = M(2) },
		LZ.panel { w = w, h = h, col = TW.mix(LZ.pink, { 1, 1, 1, 1 }, 0.06), col2 = TW.mix(LZ.pink, { 0, 0, 0, 1 }, 0.1) } .. { Name = "Bg" },
		TW.icon("chevron-left", M(16), function(self) self:xy(M(76), h / 2) end) .. { Name = "Arrow" },
		LZ.text(M(15), "bold", function(self) self:align(0, 0.5):xy(M(104), h / 2):settext(label or "Back") end),
		TW.button(w, h, function() onClick() end, function(self, on)
			local p = self:GetParent()
			p:stoptweening():decelerate(0.12):x(on and -M(6) or -M(20))
			p:GetChild("Arrow"):stoptweening():decelerate(0.12):x(on and M(70) or M(76))
		end) .. { InitCommand = function(self) self:align(0, 0):zoomto(w, h):diffusealpha(0) end },
	}
end

-- lazer's backgrounds behind its menus: the picture dimmed, with outlined triangles drifting up
function LZ.triangles(w, h, n)
	return TW.triangles { w = w, h = h, count = n or 26, outline = true, lineWidth = TW.M(1.8),
		colours = { LZ.pink, LZ.orange, LZ.pinkLight, LZ.yellow }, alpha = { 0.18, 0.55 }, size = { TW.M(40), TW.M(150) }, speed = TW.M(18) }
end

-- ------------------------------------------------------------------------------------------------
-- Dialogs (exit, beatmap options, mode...): lazer's popup, a dark card in the middle with an icon,
-- the question, and its choices as slanted buttons, each with a strip of its colour; the picked one
-- lights up. Keys as before: the number picks, arrows move, Enter takes, Esc is the last (Cancel).
-- ------------------------------------------------------------------------------------------------
local dialogCol = { green = LZ.lime, red = TW.rgb(255, 90, 110), purple = LZ.purpleLight, grey = LZ.bg1 }
function TW.dialogPanel()
	local M = TW.M
	local W, BH, GAP = M(560), M(46), M(8)
	local BW = W - M(64)
	local cx = SCREEN_CENTER_X
	local layout = { top = 0, h = 0 }
	local t = Def.ActorFrame {
		Name = "TWDialogPanel",
		InitCommand = function(self) self:z(70):visible(false) end,
		TWDialogMessageCommand = function(self)
			local spec = TW.dialogSpec
			if not spec then self:stoptweening():linear(0.12):diffusealpha(0):queuecommand("Hide") return end
			if not self:GetVisible() then
				self:visible(true):diffusealpha(0):linear(0.15):diffusealpha(1)
				self:GetChild("Card"):stoptweening():zoom(0.92):decelerate(0.25):zoom(1)
			end
			-- the card's height for this question and its choices
			local nl = #spec.lines
			local textH = M(40) + math.max(0, nl - 1) * M(22)
			local h = M(96) + textH + #spec.buttons * (BH + GAP) + M(18)
			layout.h, layout.top = h, SCREEN_CENTER_Y - h / 2
			self:playcommand("Fill")
		end,
		HideCommand = function(self) self:visible(false) end,
		Def.Quad { InitCommand = function(self) self:FullScreen():diffuse({ 0, 0, 0, 0.65 }) end },
		TW.button(1, 1, function() end) .. { InitCommand = function(self) self:FullScreen():diffusealpha(0) end },
	}
	local card = Def.ActorFrame {
		Name = "Card",
		InitCommand = function(self) self:xy(cx, SCREEN_CENTER_Y) end,
		FillCommand = function(self) self:y(SCREEN_CENTER_Y) end,
		TW.shadow { w = W, h = M(300), ax = 0.5, spread = M(22), alpha = 0.7, drop = M(6) } .. { Name = "Shadow",
			FillCommand = function(self) TW.setBox(self, { h = layout.h + M(44) }); self:y(-layout.h / 2) end },
		TW.box { w = W, h = M(300), r = M(14), ax = 0.5, col = LZ.a(LZ.bg4, 0.99), col2 = LZ.a(LZ.bg5, 0.99) } .. { Name = "Bg",
			FillCommand = function(self) TW.setBox(self, { h = layout.h }); self:y(-layout.h / 2) end },
		-- the icon, in a pink ring, on the card's top edge
		Def.ActorFrame {
			FillCommand = function(self) self:y(-layout.h / 2 + M(46)) end,
			TW.glow(M(130), LZ.a(LZ.pink, 0.35)),
			TW.disc(M(32), LZ.a(LZ.bg6, 1)),
			TW.ringShape(M(33), M(3), LZ.pink),
			TW.icon("circle-info", M(26), function(self) self:diffuse(LZ.pinkLight) end),
		},
		LZ.text(M(19), "bold", function(self) self:align(0.5, 0) end) .. {
			FillCommand = function(self)
				self:y(-layout.h / 2 + M(92)):settext(TW.dialogSpec.lines[1] or ""):maxwidth((W - M(50)) / self:GetZoom())
			end },
		LZ.text(M(13.5), "regular", function(self) self:align(0.5, 0):diffuse(LZ.dim) end) .. {
			FillCommand = function(self)
				local rest = {}
				for i = 2, #TW.dialogSpec.lines do rest[#rest + 1] = TW.dialogSpec.lines[i] end
				self:y(-layout.h / 2 + M(122)):settext(table.concat(rest, "\n")):maxwidth((W - M(50)) / self:GetZoom())
			end },
	}
	for i = 1, 7 do
		card[#card + 1] = Def.ActorFrame {
			InitCommand = function(self) self:z(2) end,
			FillCommand = function(self)
				local spec = TW.dialogSpec
				local b = spec.buttons[i]
				self:visible(b ~= nil)
				if not b then return end
				local nl = #spec.lines
				local textH = M(40) + math.max(0, nl - 1) * M(22)
				local y0 = -layout.h / 2 + M(96) + textH
				self:xy(-BW / 2, y0 + (i - 1) * (BH + GAP))
				local col = dialogCol[b[2]] or LZ.bg1
				local on = i == TW.dialogSelected()
				local c = self:GetChildren()
				TW.setBox(c.Bg, { col = on and TW.mix(col, LZ.bg3, 0.45) or LZ.a(LZ.bg3, 1), col2 = on and TW.mix(col, LZ.bg4, 0.6) or LZ.a(LZ.bg3, 1) })
				TW.setBox(c.Strip, { col = col })
				c.Label:settext(i .. ". " .. b[1])
				self:stoptweening():decelerate(0.1):addx(0)
				c.Glow:stoptweening():linear(0.1):diffusealpha(on and 0.25 or 0)
			end,
			LZ.panel { w = BW, h = BH, r = M(8) } .. { Name = "Bg" },
			LZ.panel { w = BW, h = BH, r = M(8), blend = "BlendMode_Add", col = { 1, 1, 1, 0.4 }, col2 = { 1, 1, 1, 0 } } .. { Name = "Glow", InitCommand = function(self) self:diffusealpha(0) end },
			LZ.panel { w = M(12), h = BH, r = M(6), init = function(self) self:x(M(6)) end } .. { Name = "Strip" },
			LZ.text(M(14.5), "bold", function(self) self:align(0.5, 0.5):xy(BW / 2, BH / 2) end) .. { Name = "Label" },
			TW.button(BW, BH, function() TW.dialogPress(i) end, function(self, on)
				if on then TW.dialogSelect(i) end
			end) .. { InitCommand = function(self) self:align(0, 0):zoomto(BW, BH):diffusealpha(0) end },
		}
	end
	t[#t + 1] = card
	return t
end
