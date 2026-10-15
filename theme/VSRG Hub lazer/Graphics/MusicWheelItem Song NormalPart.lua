-- osu!lazer's carousel cards (the 2025 song select): a dark rounded card with the song's picture
-- fading in from the right; the mania icon in the margin by it; your best grade on a small pill at
-- the left; the title in bold, the artist under it, then a RANKED pill, "[4K] chart name" and
-- "mapped by" on one line, and the chart's rating on a star pill (Etterna's MSD in lazer's star
-- colours) on the last. The selected card is lighter, reaches further left and has a white edge.
-- Group cards (packs) are lazer's blue headers: a chevron on a blue column, the name, a count pill.
TW.useInterfaceSkin()
local M = TW.M
local H = M(68)
local W = M(760)
local N = THEME:GetMetric("MusicWheel", "NumWheelItems")
local middle = math.ceil(N / 2)
local lastclick = 0
local white = color("#FFFFFF")
local ranked = TW.rgb(179, 255, 102) -- (lazer's "ranked" green)

local function hardest(song)
	local best, bestSteps = -1, nil
	for _, st in ipairs(TW.playable(song)) do
		local m = TW.msd(st)
		if m > best then best, bestSteps = m, st end
	end
	return bestSteps, math.max(best, 0)
end
-- the text column starts after the grade pill; the cards run off the right edge of the screen
local TX = M(60)
local TEXT_W = M(500)
local SEL_SHIFT = M(44) -- (the selected card reaches this much further left)

-- lazer's osu!mania icon: a ring with three bars in it
local function maniaIcon(size, init)
	return Def.ActorFrame {
		InitCommand = function(self) if init then init(self) end end,
		TW.box { w = size, h = size, r = size / 2, ax = 0.5, ay = 0.5, tex = "ring", col = white },
		Def.Quad { InitCommand = function(self) self:zoomto(size * 0.1, size * 0.42):x(-size * 0.2):diffuse(white) end },
		Def.Quad { InitCommand = function(self) self:zoomto(size * 0.1, size * 0.52):diffuse(white) end },
		Def.Quad { InitCommand = function(self) self:zoomto(size * 0.1, size * 0.42):x(size * 0.2):diffuse(white) end },
	}
end

local t = Def.ActorFrame {
	-- under the selected song, its difficulties open up: the panels below move down to make room
	InitCommand = function(self)
		local unit = M(76)
		self:SetUpdateFunction(function(s) if s.mine ~= false then TW.wheelShift(s, unit) end end)
	end,
	TWSearchResultsMessageCommand = function(self) TW.searchSlideIn(self, self.drawIndex, middle) end,
	-- coming into song select, the cards slide in from the right, the selected one first
	OnCommand = function(self)
		local off = math.abs((self.drawIndex or middle) - middle)
		TW.ianim(self, self, "x", 0, 0.45, "dec", 0.08 + 0.035 * off, TW.M(220))
		TW.ianim(self, self, "alpha", 1, 0.45, "dec", 0.08 + 0.035 * off, 0)
	end,
	FilterResultsMessageCommand = function() TW.groupCache = nil end,
	SetCommand = function(self, p)
		-- (this file is every kind of panel, song, pack and sort: Etterna loads it once per kind into
		-- each wheel item and tells them all; only the one of the item's kind may show, or each panel
		-- is drawn two or three times over itself)
		local name = self:GetName()
		self.mine = name == "" or name == (p.Type or "") .. "NormalPart"
		if not self.mine then self:visible(false) return end
		TW.everyFrame(self)
		self.drawIndex = p.DrawIndex
		self:visible(not TW.wheelWrapped(p, middle))
		local fresh = p.Song ~= self.song or p.Text ~= self.text
		-- (the card that becomes the selected one slides out to the left, as lazer's does)
		local body = self:GetChild("Body")
		local isGroup = not p.Song
		local wantX = (p.HasFocus and p.Song) and -SEL_SHIFT or 0
		if fresh then TW.ianim(self, body, "x", wantX, 0.25, "dec", 0, isGroup and 0 or (p.HasFocus and 0 or -SEL_SHIFT * 0.3))
		else TW.ianim(self, body, "x", wantX, 0.25, "dec") end
		self.text = p.Text
		self.song = p.Song
		body:GetChild("Thumb"):playcommand("Load", p)
	end,
	Def.ActorFrame {
		Name = "Body",
		-- the glow round the selected one
		TW.shadow { w = W, h = H, ay = 0.5, spread = M(12), alpha = 0.45, drop = M(3) } .. {
			SetCommand = function(self, p)
				TW.setBox(self, { col = p.HasFocus and LZ.a(LZ.pinkLight, 0.45) or { 0, 0, 0, 0.45 } })
			end,
		},
		TW.box { w = W, h = H, r = M(8), ay = 0.5 } .. {
			Name = "Panel",
			SetCommand = function(self, p)
				local c
				if not p.Song then c = { LZ.a(LZ.hsl(205, 0.35, 0.22), 0.92), LZ.a(LZ.hsl(205, 0.35, 0.16), 0.92) }
				elseif p.HasFocus then c = { LZ.a(LZ.hsl(220, 0.25, 0.32), 0.96), LZ.a(LZ.hsl(220, 0.25, 0.24), 0.96) }
				else c = { LZ.a(LZ.hsl(240, 0.08, 0.11), 0.9), LZ.a(LZ.hsl(240, 0.08, 0.08), 0.9) } end
				TW.setBox(self, { col = c[1], col2 = c[2] })
			end,
		},
		-- the song's picture, faded in from the right (loaded once the wheel stops on it)
		Def.Sprite {
			Name = "Thumb",
			InitCommand = function(self) self:align(1, 0.5):x(W - M(4)):visible(false) end,
			-- (no tweens in here: see TW.ianim)
			LoadCommand = function(self, p)
				local f = self:GetParent():GetParent()
				self.focus = p.HasFocus
				local want = p.Song and TW.thumbPath(p.Song) or nil
				if want and want == self.shown then
					TW.ilater(f, "thumb", 0, nil)
					self:visible(true)
					TW.ianim(f, self, "alpha", self.focus and 0.9 or 0.6, 0.15, "lin")
					return
				end
				self:visible(false)
				self.want = want
				TW.ilater(f, "thumb", TW.pictureDelay(p.DrawIndex, middle), want and function() self:playcommand("Show") end or nil)
			end,
			ShowCommand = function(self)
				if not self.want then return end
				self:LoadFromCached("Background", self.want)
				self.shown = self.want
				TW.keepTexture(self)
				self:scaletoclipped(W * 0.5, H - M(4)):fadeleft(0.7)
				self:visible(true)
				TW.ianim(self:GetParent():GetParent(), self, "alpha", self.focus and 0.9 or 0.6, 0.2, "lin", 0, 0)
			end,
		},
		-- (the picture dimmed a little towards the card's bottom, as lazer's)
		Def.Quad { InitCommand = function(self) self:align(1, 0.5):x(W - M(4)):zoomto(W * 0.5, H - M(4)):diffuse({ 0, 0, 0, 0 }):diffusebottomedge({ 0, 0, 0, 0.35 }) end,
			SetCommand = function(self, p) self:visible(p.Song ~= nil) end },
		-- groups: the blue column with a chevron on the left
		TW.box { w = M(38), h = H, r = M(8), ay = 0.5, col = LZ.blue } .. {
			Name = "GroupStrip",
			SetCommand = function(self, p) self:visible(p.Song == nil) end,
		},
		Def.Quad { InitCommand = function(self) self:align(0, 0.5):x(M(24)):zoomto(M(14), H):diffuse(LZ.blue) end,
			SetCommand = function(self, p) self:visible(p.Song == nil) end },
		Def.Sprite {
			Name = "GroupIcon",
			InitCommand = function(self) self:xy(M(19), 0) end,
			SetCommand = function(self, p)
				self:visible(p.Song == nil)
				if p.Song then return end
				self:Load(TW.iconPath(p.Type == "SectionExpanded" and "chevron-down" or "chevron-right")):zoomto(M(12), M(12)):diffuse(TW.rgb(20, 40, 70))
			end,
		},
		-- songs: lazer's mania icon in the margin, left of the card
		maniaIcon(M(14), function(self) self:x(-M(16)) end) .. {
			SetCommand = function(self, p) self:visible(p.Song ~= nil):diffusealpha(p.HasFocus and 1 or 0.6) end,
		},
		-- the white edge of the selected one
		TW.box { w = W, h = H, r = M(8), ay = 0.5, tex = "ring", col = { 1, 1, 1, 0 } } .. {
			SetCommand = function(self, p) TW.setBox(self, { col = p.HasFocus and { 1, 1, 1, 0.85 } or { 1, 1, 1, 0.05 } }) end,
		},
		-- your best grade on the song: a pill at the left (lazer's grade bubble)
		Def.ActorFrame {
			Name = "Grade",
			InitCommand = function(self) self:xy(M(30), M(5)):visible(false) end,
			SetCommand = function(self, p)
				self:visible(false)
				if not p.Song then return end
				local g
				pcall(function() g = p.Song:GetHighestGrade() end)
				local r = g and TW.GradeToRank[g]
				if not r or g == "Grade_Failed" or g == "Grade_NoData" then return end
				local b = TW.songBest and TW.songBest(p.Song)
				if b and b.pct and not b.failed and TW.accRank then r = TW.accRank(b.pct) end
				self:visible(true)
				TW.setBox(self:GetChild("Bg"), { col = LZ.rankColour(r) })
				self:GetChild("L"):settext(TW.RankLetter[r] or r):diffuse(LZ.rankText(r))
			end,
			TW.box { w = M(34), h = M(20), r = M(7), ax = 0.5, ay = 0.5 } .. { Name = "Bg" },
			LZ.text(M(12), "bold", function(self) self:align(0.5, 0.5) end) .. { Name = "L" },
		},
		LZ.text(M(15), "bold", function(self) self:align(0, 0.5) end) .. {
			Name = "Title",
			SetCommand = function(self, p)
				if p.Song then
					self:zoom(M(15) / 15):settext(p.Song:GetDisplayMainTitle()):xy(TX, -H / 2 + M(13)):maxwidth(TEXT_W / self:GetZoom())
				else
					self:settext(p.Text or ""):xy(M(52), 0):zoom(M(18) / 15):maxwidth((TEXT_W - M(60)) / self:GetZoom())
				end
				self:diffuse(white)
			end,
		},
		LZ.text(M(11), "regular", function(self) self:align(0, 0.5):xy(TX, -H / 2 + M(28)) end) .. {
			Name = "Sub",
			SetCommand = function(self, p)
				if not p.Song then self:settext("") return end
				self:settext(p.Song:GetDisplayArtist()):diffuse(LZ.a(white, 0.9)):maxwidth(TEXT_W / self:GetZoom())
			end,
		},
		-- the group's song count, in a pill on the right
		Def.ActorFrame {
			Name = "Count",
			InitCommand = function(self) self:xy(M(600), 0) end,
			SetCommand = function(self, p)
				local isGroup = not p.Song and (p.Type == "SectionCollapsed" or p.Type == "SectionExpanded")
				self:visible(isGroup)
				if not isGroup then return end
				local n = TW.groupCount(p.Text or "")
				local c = self:GetChildren()
				c.N:settext(tostring(n))
				TW.setBox(c.Bg, { w = c.N:GetZoomedWidth() + M(24) })
			end,
			TW.box { w = M(40), h = M(20), r = M(6), ax = 1, ay = 0.5, col = { 0, 0, 0, 0.5 } } .. { Name = "Bg" },
			LZ.text(M(11), "bold", function(self) self:align(1, 0.5):x(-M(12)) end) .. { Name = "N" },
		},
		-- RANKED, "[4K] chart name", "mapped by": the hardest chart
		Def.ActorFrame {
			Name = "Diff",
			InitCommand = function(self) self:xy(TX, -H / 2 + M(44)) end,
			SetCommand = function(self, p) self.p = p; self:playcommand("Fill") end,
			CurrentRateChangedMessageCommand = function(self) if self.p then self:playcommand("Fill") end end,
			FillCommand = function(self)
				local p = self.p
				local c = self:GetChildren()
				self:visible(p.Song ~= nil)
				if not p.Song then return end
				local st, m = hardest(p.Song)
				local by = TW.author(p.Song)
				c.Name:x(M(52)):settextf("[%dK] %s", TW.keys(st), st and TW.diffName(st) or ""):maxwidth((TEXT_W - M(200)) / c.Name:GetZoom())
				c.By:x(M(52) + c.Name:GetZoomedWidth() + M(5)):settext(by ~= "" and ("mapped by " .. by) or ""):maxwidth(M(150) / c.By:GetZoom())
				c.Star:playcommand("Msd", { v = m })
			end,
			TW.box { w = M(46), h = M(13), r = M(4), ay = 0.5, col = ranked } .. { Name = "RankedBg" },
			LZ.text(M(8), "bold", function(self) self:align(0.5, 0.5):xy(M(23), 0):settext("RANKED"):diffuse(TW.rgb(30, 50, 10)) end),
			LZ.text(M(11), "bold", function(self) self:align(0, 0.5) end) .. { Name = "Name" },
			LZ.text(M(11), "regular", function(self) self:align(0, 0.5):diffuse(LZ.a(white, 0.85)) end) .. { Name = "By" },
			LZ.starPill(M(15), function(self) self:y(M(17)) end) .. { Name = "Star" },
		},
		-- a soft light over the card under the mouse
		TW.box { w = W, h = H, r = TW.M(8), ay = 0.5, blend = "BlendMode_Add", col = { 1, 1, 1, 0.09 }, col2 = { 1, 1, 1, 0.03 } } .. {
			Name = "HoverLight", InitCommand = function(self) self:diffusealpha(0) end },
		-- click: the first click selects, clicking the selected one plays it
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self) self:align(0, 0.5):zoomto(W, H):diffusealpha(0) end,
			SetCommand = function(self, p) self.index = p.DrawIndex end,
			MouseOverCommand = function(self)
				local f = self:GetParent()
				TW.ianim(f:GetParent(), f:GetChild("HoverLight"), "alpha", 1, 0.1, "lin")
			end,
			MouseOutCommand = function(self)
				local f = self:GetParent()
				TW.ianim(f:GetParent(), f:GetChild("HoverLight"), "alpha", 0, 0.15, "lin")
			end,
			MouseDownCommand = function(self, params)
				if params.event ~= "DeviceButton_left mouse button" then return end
				local now = GetTimeSinceStart()
				if now - lastclick < 0.1 then return end
				lastclick = now
				local top = SCREENMAN:GetTopScreen()
				local we = top and top:GetMusicWheel()
				if not we or not self.index then return end
				local dist = self.index - middle
				if dist == 0 and we:IsSettled() then
					top:SelectCurrent()
				else
					local itemtype = we:MoveAndCheckType(dist)
					we:Move(0)
					if itemtype == "WheelItemDataType_Section" then top:SelectCurrent() end
				end
			end,
		},
	},
}
return t
