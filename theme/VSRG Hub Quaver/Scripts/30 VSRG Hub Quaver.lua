-- VSRG Hub Quaver: Quaver's look. Colours, fonts and the pieces every screen shares (the top
-- navigation bar, the bottom button bar, the gradient underline) measured off Quaver itself at
-- 1456x819 (TW.M / TW.R scale those to Etterna's screen).
TW.isQuaver = true
-- the main menu's Quit choice (metrics: ChoiceQuit) asks first, as Quaver does
function QVAskQuit() MESSAGEMAN:Broadcast("QVAskQuit") end
QV = {}

-- Quaver uses Lato; these bitmap fonts are drawn from Lato (SIL OFL 1.1) under another name, as the OFL asks
TW.font = "_twsans regular"
TW.bold = "_twsans bold"
QV.black = "_twsans black"
-- Text px tall the way Quaver sizes its fonts (VSRG Hub's shared panels keep TW.text's sizing).
-- (big text takes the fonts' sharper copies, twice the size, drawn at half the zoom)
QV.fontBig = { ["_twsans regular"] = "_twx regular", ["_twsans bold"] = "_twx bold", ["_twsans black"] = "_twx black" }
function QV.fontFor(px, font)
	local onScreen = px / 24 * DISPLAY:GetDisplayHeight() / SCREEN_HEIGHT
	if onScreen > 1.6 and QV.fontBig[font] then return QV.fontBig[font], px / 48 end
	return font, px / 24
end
-- (and for VSRG Hub's shared panels, which size text with TW.text)
if TW.fontBig then for k, v in pairs(QV.fontBig) do TW.fontBig[k] = v end end
function QV.text(px, font, init)
	local f, z = QV.fontFor(px, font)
	return LoadFont(f) .. {
		InitCommand = function(self)
			self:zoom(z):halign(0)
			if init then init(self) end
		end
	}
end
function QV.t(px, bold, init) return QV.text(px, bold and TW.bold or TW.font, init) end

-- the interface never uses an osu! skin here; in play the HUD only follows an osu! skin when your
-- notes come from one
function TW.useInterfaceSkin() TW_SKIN = nil end
function TW.useGameplaySkin()
	TW_SKIN = nil
	local ok, ns = pcall(function()
		return GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin()
	end)
	local info = ok and ns and TW.noteskinInfo(ns)
	TW.notesSkin = false
	if info and info.skin and TW_SKINS and TW_SKINS[info.skin] then
		TW_SKIN = TW_SKINS[info.skin]
		TW.notesSkin = true -- (its stage art and lane cover belong to the notes, as in the osu! look)
		local keys = 4
		pcall(function() if GAMESTATE:GetCurrentGame():GetName() == "kb7" then keys = 7 end end)
		TW_SKIN = TW.skinForKeys(TW_SKIN, keys)
	end
end
TW_SKIN = nil

-- The Quaver skin's own gameplay art (judgements, combo and score digits, health bar) when your notes
-- come from a Quaver skin; nil otherwise (Quaver's default look is drawn then).
function QV.hud()
	local ok, ns = pcall(function()
		return GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin()
	end)
	local info = ok and ns and TW.noteskinInfo(ns)
	return info and info.qv
end
-- a Quaver skin size (a percent of the picture, or pixels, scaled by 1920/1366 on a 1080-tall
-- screen) in Etterna pixels
function QV.size(v) return v * SCREEN_HEIGHT / 768.43 end
-- A row of the skin's digit pictures, aligned at x = 0 (halign 0 left, 0.5 centre, 1 right).
-- playcommand("Set", { text = "100.00%" }) shows a number; '.' and ',' use the decimal picture.
function QV.digits(pics, scale, halign, extra)
	-- (the same row the osu! look uses for Quaver skins: one place, with the minus for a negative accuracy)
	return TW.qvDigits(pics, scale, halign, extra)
end

-- Quaver's colours
QV.cyan = TW.rgb(12, 183, 231)
QV.lightCyan = TW.rgb(69, 211, 255)
QV.blue = TW.rgb(0, 174, 255)
QV.yellow = TW.rgb(249, 214, 90)
QV.orange = TW.rgb(244, 175, 56)
QV.green = TW.rgb(12, 192, 85)
QV.keysRed = TW.rgb(232, 45, 85)
QV.red = TW.rgb(255, 40, 70)
QV.grey = TW.rgb(150, 150, 155)
QV.panel = TW.rgb(0, 0, 0, 0.6)
QV.g1, QV.g2, QV.g3 = TW.rgb(7, 177, 210), TW.rgb(85, 19, 215), TW.rgb(216, 0, 92)
QV.judge = {
	TapNoteScore_W1 = { "MARV", color("#FFFFFF") },
	TapNoteScore_W2 = { "PERF", TW.rgb(255, 231, 107) },
	TapNoteScore_W3 = { "GREAT", TW.rgb(86, 254, 110) },
	TapNoteScore_W4 = { "GOOD", TW.rgb(0, 209, 255) },
	TapNoteScore_W5 = { "OKAY", TW.rgb(217, 107, 206) },
	TapNoteScore_Miss = { "MISS", TW.rgb(249, 100, 93) },
}
QV.judgeOrder = { "TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3", "TapNoteScore_W4", "TapNoteScore_W5", "TapNoteScore_Miss" }
-- osu!/VSRG Hub colours the shared panels use
TW.pink = QV.cyan
TW.yellow = QV.yellow
TW.green = QV.green

-- Quaver's grade letters and colours
QV.gradeColour = {
	X = TW.rgb(255, 255, 255), S = TW.rgb(251, 255, 106), A = TW.rgb(86, 254, 110),
	B = TW.rgb(0, 209, 255), C = TW.rgb(217, 107, 206), D = TW.rgb(255, 120, 60), F = TW.rgb(232, 30, 50)
}
QV.gradeColour.SS = TW.rgb(255, 230, 120)
QV.gradeLetter = { X = "X", SS = "SS", S = "S", A = "A", B = "B", C = "C", D = "D", F = "F" }
-- Quaver's grade for an accuracy: X at 100%, SS from 99, S 95, A 90, B 80, C 70, else D
function QV.accGrade(pct)
	pct = pct or 0
	if pct >= 99.9999 then return "X" elseif pct >= 99 then return "SS" elseif pct >= 95 then return "S"
	elseif pct >= 90 then return "A" elseif pct >= 80 then return "B" elseif pct >= 70 then return "C" end
	return "D"
end
function QV.grade(wifeGrade)
	if wifeGrade == "Grade_Failed" then return "F" end
	local r = TW.GradeToRank[wifeGrade] or "D"
	if wifeGrade == "Grade_Tier01" or wifeGrade == "Grade_Tier02" or wifeGrade == "Grade_Tier03" then return "X" end
	return r
end

-- A horizontal bar fading cyan -> purple -> pink, Quaver's highlight.
function QV.gradient(w, h, alpha)
	local a = alpha or 1
	local function c(col) local cc = { col[1], col[2], col[3], a }; return cc end
	local c1, c2, c3 = c(QV.g1), c(QV.g2), c(QV.g3)
	return Def.ActorMultiVertex {
		InitCommand = function(self)
			self:SetDrawState { Mode = "DrawMode_QuadStrip" }:SetVertices {
				{ { 0, 0, 0 }, c1 }, { { 0, h, 0 }, c1 },
				{ { w / 2, 0, 0 }, c2 }, { { w / 2, h, 0 }, c2 },
				{ { w, 0, 0 }, c3 }, { { w, h, 0 }, c3 },
			}
		end
	}
end
-- the same, standing up (top cyan, bottom pink), for the health bar
function QV.vgradient(w, h)
	return Def.ActorMultiVertex {
		InitCommand = function(self)
			self:SetDrawState { Mode = "DrawMode_QuadStrip" }:SetVertices {
				{ { 0, 0, 0 }, QV.g1 }, { { w, 0, 0 }, QV.g1 },
				{ { 0, h / 2, 0 }, QV.g2 }, { { w, h / 2, 0 }, QV.g2 },
				{ { 0, h, 0 }, QV.g3 }, { { w, h, 0 }, QV.g3 },
			}
		end
	}
end

-- A ring (the "Q" of the logo), as a quad strip.
function QV.ring(r, thick, col, from, to)
	from, to = from or 0, to or 360
	local verts = {}
	local n = 48
	for i = 0, n do
		local a = math.rad(from + (to - from) * i / n)
		verts[#verts + 1] = { { math.cos(a) * r, math.sin(a) * r, 0 }, col }
		verts[#verts + 1] = { { math.cos(a) * (r - thick), math.sin(a) * (r - thick), 0 }, col }
	end
	return Def.ActorMultiVertex {
		InitCommand = function(self) self:SetDrawState { Mode = "DrawMode_QuadStrip" }:SetVertices(verts) end
	}
end

-- The logo: a cyan ring with a white tail, then "VSRG Hub".
function QV.logo(h)
	local r = h * 0.42
	return Def.ActorFrame {
		QV.ring(r, h * 0.11, QV.cyan, 100, 330) .. { InitCommand = function(self) self:xy(r, h * 0.5) end },
		QV.ring(r, h * 0.11, color("#FFFFFF"), 330, 460) .. { InitCommand = function(self) self:xy(r, h * 0.5) end },
		QV.text(h * 0.86, TW.font, function(self) self:align(0, 0.5):xy(r * 2.35, h * 0.53):settext("VSRG Hub") end) .. { Name = "Word" },
	}
end

-- Clickable text: label plus an invisible button sized to it.
function QV.link(label, px, onClick, init, col)
	return Def.ActorFrame {
		InitCommand = function(self) if init then init(self) end end,
		-- sized before the button's own OnCommand registers it for clicks (overriding that OnCommand
		-- would leave the link dead)
		OnCommand = function(self) self:GetChild("Hit"):playcommand("Size") end,
		QV.t(px, true, function(self) self:align(0, 0.5):settext(label):diffuse(col or color("#FFFFFF")) end) .. { Name = "Label" },
		TW.button(1, 1, function() onClick() end, function(self, on)
			self:GetParent():GetChild("Label"):diffusealpha(on and 0.7 or 1)
		end) .. {
			Name = "Hit",
			SizeCommand = function(self)
				local l = self:GetParent():GetChild("Label")
				self:align(0, 0.5):zoomto(l:GetZoomedWidth() + TW.M(10), TW.M(30)):x(-TW.M(5))
			end
		},
	}
end

local function sessionClock()
	local s = math.floor(GetTimeSinceStart())
	return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end

-- Quaver's top navigation bar.
function QV.navbar()
	local M, R = TW.M, TW.R
	local function go(screen) return function()
		local top = SCREENMAN:GetTopScreen()
		if top and top:GetName() ~= screen then SCREENMAN:SetNewScreen(screen) end
	end end
	local t = Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, M(41)):diffuse(color("#000000")):diffusealpha(0.97) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):y(M(40)):zoomto(SCREEN_WIDTH, math.max(1, M(1.5))):diffuse(color("#FFFFFF")):diffusealpha(0.85) end },
		QV.logo(M(26)) .. { InitCommand = function(self) self:xy(M(19), M(7)) end },
		QV.link("HOME", M(13), go("ScreenTitleMenu"), function(self) self:xy(M(176), M(21)) end),
		QV.link("SONGS", M(13), function()
			local top = SCREENMAN:GetTopScreen()
			if top and top:GetName() == "ScreenTitleMenu" then MESSAGEMAN:Broadcast("TWTitleChoose", { index = 0 }) end
		end, function(self) self:xy(M(278), M(21)) end),
		QV.link("OPTIONS", M(13), function() TW.toggleOptions() end, function(self) self:xy(M(385), M(21)) end),
		QV.link("SKINS", M(13), function() TW.openOptions() end, function(self) self:xy(M(505), M(21)) end),
		-- Quaver's DOWNLOAD screen: Etterna's pack downloader
		QV.link("DOWNLOAD", M(13), function()
			TW.closeOptions(); TW.keepRedirect = false; SCREENMAN:set_input_redirected(PLAYER_1, false)
			SCREENMAN:SetNewScreen("ScreenPackDownloader")
		end, function(self) self:xy(M(612), M(21)) end),
		-- session time, like Quaver
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(R(1128), M(21)):zoomto(M(75), M(20)):diffuse(TW.rgb(40, 40, 40)) end },
		QV.t(M(11.5), false, function(self) self:align(0.5, 0.5):xy(R(1165), M(21)) end) .. {
			OnCommand = function(self) self:queuecommand("Tick") end,
			TickCommand = function(self) self:settext(sessionClock()):sleep(1):queuecommand("Tick") end
		},
		-- player
		Def.Sprite { InitCommand = function(self)
			local _, av = TW.profile()
			self:Load(av):align(0, 0.5):xy(R(1228), M(21)):zoomto(M(26), M(26))
		end },
		QV.t(M(13), true, function(self) self:align(0, 0.5):xy(R(1262), M(21)) end) .. {
			OnCommand = function(self)
				local p = TW.profile()
				local n = p and p:GetDisplayName() or ""
				QV.fit(self, n ~= "" and n or "Guest", M(110))
			end
		},
		QV.t(M(11), false, function(self) self:align(0, 0.5):xy(R(1262), M(33)):diffuse(QV.grey) end) .. {
			OnCommand = function(self)
				local p = TW.profile()
				self:settextf("%.2f", p and p:GetPlayerRating() or 0)
				self:visible(false)
			end
		},
		-- the "hamburger" opens the options
		Def.ActorFrame {
			InitCommand = function(self) self:xy(R(1421), M(21)) end,
			Def.Quad { InitCommand = function(self) self:zoomto(M(21), M(2.5)):y(-M(7)) end },
			Def.Quad { InitCommand = function(self) self:zoomto(M(21), M(2.5)) end },
			Def.Quad { InitCommand = function(self) self:zoomto(M(21), M(2.5)):y(M(7)) end },
			TW.button(M(36), M(36), function() TW.toggleOptions() end),
		},
	}
	return t
end

-- Quaver's bottom bar: { label, onClick } buttons on the left and the right.
function QV.bottombar(left, right)
	local M, R = TW.M, TW.R
	local t = Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:align(0, 1):xy(0, SCREEN_HEIGHT):zoomto(SCREEN_WIDTH, M(41)):diffuse(color("#000000")):diffusealpha(0.92) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):y(SCREEN_HEIGHT - M(42)):zoomto(SCREEN_WIDTH, math.max(1, M(1.5))):diffuse(color("#FFFFFF")):diffusealpha(0.85) end },
	}
	local x = M(22)
	for _, b in ipairs(left or {}) do
		local bx = x
		t[#t + 1] = QV.link(b[1], M(13), b[2], function(self) self:xy(bx, SCREEN_HEIGHT - M(20)) end, b[3])
		x = x + M(b[4] or (#b[1] * 9.5 + 50))
	end
	local xr = SCREEN_WIDTH - M(22)
	for i = #(right or {}), 1, -1 do
		local b = right[i]
		local w = M(#b[1] * 9.6)
		xr = xr - w
		local bx = xr
		t[#t + 1] = QV.link(b[1], M(13), b[2], function(self) self:xy(bx, SCREEN_HEIGHT - M(20)) end, b[3])
		xr = xr - M(48)
	end
	return t
end

-- A row panel: dark box with Quaver's white underline.
function QV.box(w, h, alpha)
	return Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(w, h):diffuse(color("#000000")):diffusealpha(alpha or 0.6) end },
		Def.Quad { InitCommand = function(self) self:align(0, 0):y(h - math.max(1, TW.M(2))):zoomto(w, math.max(1, TW.M(2))):diffuse(color("#FFFFFF")):diffusealpha(0.75) end },
	}
end

-- mm:ss
function QV.clock(s)
	s = math.max(0, math.floor(s))
	return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

-- Sets text on a BitmapText, cutting it with "..." so it never runs wider than maxw (screen px).
function QV.fit(actor, text, maxw)
	text = text or ""
	actor:maxwidth(0)
	actor:settext(text)
	if actor:GetZoomedWidth() <= maxw then return actor end
	local chars = {}
	for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
	local lo, hi = 0, #chars
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		actor:settext(table.concat(chars, "", 1, mid) .. "...")
		if actor:GetZoomedWidth() <= maxw then lo = mid else hi = mid - 1 end
	end
	actor:settext(table.concat(chars, "", 1, lo):gsub("%s+$", "") .. "...")
	return actor
end

