-- osu!lazer's carousel panels: a dark rounded panel with the song's picture fading in from the right,
-- a strip of colour on the left (pink for songs, blue for groups), the title, the artist and mapper,
-- and the hardest chart on a star pill (Etterna's MSD in lazer's star colours) with its name and key
-- count; your best grade on a small tab. The selected one is lighter with a glowing white edge.
-- Group panels show the group's name and how many songs it holds.
TW.useInterfaceSkin()
local M = TW.M
local H = M(70)
local W = M(720)
local N = THEME:GetMetric("MusicWheel", "NumWheelItems")
local middle = math.ceil(N / 2)
local lastclick = 0
local white = color("#FFFFFF")

local function hardest(song)
	local best, bestSteps = -1, nil
	for _, st in ipairs(TW.playable(song)) do
		local m = TW.msd(st)
		if m > best then best, bestSteps = m, st end
	end
	return bestSteps, math.max(best, 0)
end
-- room for text: the panels run off the right edge of the screen
local TEXT_W = M(520)

local t = Def.ActorFrame {
	-- under the selected song, its difficulties open up: the panels below move down to make room
	InitCommand = function(self)
		local unit = M(78)
		self:SetUpdateFunction(function(s) if s.mine ~= false then TW.wheelShift(s, unit) end end)
	end,
	TWSearchResultsMessageCommand = function(self) TW.searchSlideIn(self, self.drawIndex, middle) end,
	-- coming into song select, the panels slide in from the right, the selected one first
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
		-- (the wheel's panels are copies of one, and a copy doesn't keep how often its update function
		-- runs: set here, on each)
		TW.everyFrame(self)
		self.drawIndex = p.DrawIndex
		self:visible(not TW.wheelWrapped(p, middle))
		-- (the panel that becomes the selected one pops a little, as osu!'s do)
		if p.HasFocus and (p.Song ~= self.song or p.Text ~= self.text) then
			TW.ianim(self, self, "zoom", 1, 0.3, "dec", 0, 1.035)
		end
		self.text = p.Text
		self.song = p.Song
		self:GetChild("Thumb"):playcommand("Load", p)
	end,
	-- the glow round the selected one
	TW.shadow { w = W, h = H, ay = 0.5, spread = M(12), alpha = 0.45, drop = M(3) } .. {
		SetCommand = function(self, p)
			TW.setBox(self, { col = p.HasFocus and LZ.a(LZ.pinkLight, 0.55) or { 0, 0, 0, 0.45 } })
		end,
	},
	TW.box { w = W, h = H, r = M(10), ay = 0.5 } .. {
		Name = "Panel",
		SetCommand = function(self, p)
			local c
			if p.HasFocus then c = { LZ.a(LZ.bg2, 0.97), LZ.a(LZ.bg3, 0.97) }
			elseif p.Song then c = { LZ.a(LZ.bg4, 0.92), LZ.a(LZ.bg5, 0.92) }
			else c = { LZ.a(LZ.hsl(210, 0.2, 0.18), 0.94), LZ.a(LZ.hsl(210, 0.2, 0.13), 0.94) } end
			TW.setBox(self, { col = c[1], col2 = c[2] })
		end,
	},
	-- the song's picture, faded in from the right (loaded once the wheel stops on it)
	Def.Sprite {
		Name = "Thumb",
		InitCommand = function(self) self:align(1, 0.5):x(W - M(6)):visible(false) end,
		-- (no tweens in here: see TW.ianim)
		LoadCommand = function(self, p)
			local f = self:GetParent()
			self.focus = p.HasFocus
			local want = p.Song and p.Song:GetBackgroundPath() or nil
			if want and want == self.shown then
				TW.ilater(f, "thumb", 0, nil)
				self:visible(true)
				TW.ianim(f, self, "alpha", self.focus and 0.75 or 0.45, 0.15, "lin")
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
			self:scaletoclipped(W * 0.62, H - M(8)):fadeleft(0.75)
			self:visible(true)
			TW.ianim(self:GetParent(), self, "alpha", self.focus and 0.75 or 0.45, 0.2, "lin", 0, 0)
		end,
	},
	-- the strip on the left
	TW.box { w = M(26), h = H, r = M(10), ay = 0.5 } .. {
		Name = "Strip",
		SetCommand = function(self, p) TW.setBox(self, { col = p.Song and (p.HasFocus and LZ.pink or LZ.a(LZ.pink, 0.85)) or LZ.blueDark }) end,
	},
	Def.Quad { InitCommand = function(self) self:align(0, 0.5):x(M(16)):zoomto(M(10), H):diffuse({ 0, 0, 0, 0 }) end,
		SetCommand = function(self, p) self:diffuse(p.Song and (p.HasFocus and LZ.pink or LZ.a(LZ.pink, 0.85)) or LZ.blueDark) end },
	Def.Sprite {
		Name = "StripIcon",
		InitCommand = function(self) self:xy(M(13), 0) end,
		SetCommand = function(self, p)
			local icon = p.Song and "circle-play" or (p.Type == "SectionExpanded" and "chevron-down" or "chevron-right")
			self:Load(TW.iconPath(icon)):zoomto(M(11), M(11)):diffuse(p.Song and TW.rgb(60, 20, 40) or white)
		end,
	},
	-- the white edge of the selected one
	TW.box { w = W, h = H, r = M(10), ay = 0.5, tex = "ring", col = { 1, 1, 1, 0 } } .. {
		SetCommand = function(self, p) TW.setBox(self, { col = p.HasFocus and { 1, 1, 1, 0.9 } or { 1, 1, 1, 0.06 } }) end,
	},
	LZ.text(M(17), "bold", function(self) self:align(0, 0.5) end) .. {
		Name = "Title",
		SetCommand = function(self, p)
			if p.Song then
				self:zoom(M(17) / 17):settext(p.Song:GetDisplayMainTitle()):xy(M(40), -M(18)):maxwidth(TEXT_W / self:GetZoom())
			else
				local name = p.Text or ""
				if p.Type == "SectionCollapsed" or p.Type == "SectionExpanded" then
					self:settext(name)
				else
					self:settext(name)
				end
				self:xy(M(40), 0):zoom(M(20) / 17):maxwidth((TEXT_W - M(80)) / self:GetZoom())
			end
			self:diffuse(white)
		end,
	},
	LZ.text(M(12.5), "regular", function(self) self:align(0, 0.5):xy(M(40), M(1)) end) .. {
		Name = "Sub",
		SetCommand = function(self, p)
			if not p.Song then self:settext("") return end
			local by = TW.author(p.Song)
			self:settext(p.Song:GetDisplayArtist() .. (by ~= "" and ("  //  " .. by) or "")):diffuse(LZ.content2):maxwidth(TEXT_W / self:GetZoom())
		end,
	},
	-- the group's song count, in a pill on the right
	Def.ActorFrame {
		Name = "Count",
		InitCommand = function(self) self:xy(M(560), 0) end,
		SetCommand = function(self, p)
			local isGroup = not p.Song and (p.Type == "SectionCollapsed" or p.Type == "SectionExpanded")
			self:visible(isGroup)
			if not isGroup then return end
			local n = TW.groupCount(p.Text or "")
			local c = self:GetChildren()
			c.N:settext(tostring(n))
			TW.setBox(c.Bg, { w = c.N:GetZoomedWidth() + M(22) })
		end,
		TW.box { w = M(40), h = M(22), r = M(11), ax = 1, ay = 0.5, col = { 0, 0, 0, 0.45 } } .. { Name = "Bg" },
		LZ.text(M(12), "bold", function(self) self:align(1, 0.5):x(-M(11)) end) .. { Name = "N" },
	},
	-- the hardest chart: star pill, name and keys
	Def.ActorFrame {
		Name = "Diff",
		InitCommand = function(self) self:xy(M(40), M(20)) end,
		SetCommand = function(self, p) self.p = p; self:playcommand("Fill") end,
		CurrentRateChangedMessageCommand = function(self) if self.p then self:playcommand("Fill") end end,
		FillCommand = function(self)
			local p = self.p
			local c = self:GetChildren()
			self:visible(p.Song ~= nil)
			if not p.Song then return end
			local st, m = hardest(p.Song)
			c.Star:playcommand("Msd", { v = m })
			local x = (c.Star.w or M(56)) + M(8)
			c.Name:x(x):settextf("%s (%dK)", st and TW.diffName(st) or "", TW.keys(st)):maxwidth((TEXT_W - x) / c.Name:GetZoom())
			c.Name:diffuse(LZ.a(white, 0.9))
		end,
		LZ.starPill(M(17)) .. { Name = "Star" },
		LZ.text(M(11.5), "bold", function(self) self:align(0, 0.5) end) .. { Name = "Name" },
	},
	-- your best grade on the song: a small tab in the grade's colour, by the strip
	Def.ActorFrame {
		Name = "Grade",
		InitCommand = function(self) self:xy(W - M(160), -M(18)):visible(false) end,
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
		LZ.panel { w = M(36), h = M(18), r = M(6), ax = 0.5, ay = 0.5 } .. { Name = "Bg" },
		LZ.text(M(11), "bold", function(self) self:align(0.5, 0.5) end) .. { Name = "L" },
	},
	-- click: the first click selects, clicking the selected one plays it
	-- a soft light over the panel under the mouse, which leans out to the left a little
	TW.box { w = W, h = H, r = TW.M(10), ay = 0.5, blend = "BlendMode_Add", col = { 1, 1, 1, 0.09 }, col2 = { 1, 1, 1, 0.03 } } .. {
		Name = "HoverLight", InitCommand = function(self) self:diffusealpha(0) end },
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self) self:align(0, 0.5):zoomto(W, H):diffusealpha(0) end,
		SetCommand = function(self, p) self.index = p.DrawIndex end,
		MouseOverCommand = function(self)
			local f = self:GetParent()
			TW.ianim(f, f, "x", -TW.M(12), 0.15, "dec")
			TW.ianim(f, f:GetChild("HoverLight"), "alpha", 1, 0.1, "lin")
		end,
		MouseOutCommand = function(self)
			local f = self:GetParent()
			TW.ianim(f, f, "x", 0, 0.2, "dec")
			TW.ianim(f, f:GetChild("HoverLight"), "alpha", 0, 0.15, "lin")
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
}
return t
