-- Quaver's map rows: "Artist - Title", then the difficulty (Etterna's MSD at the current rate, in
-- Quaver's orange), the chart name and the mapper, the key count, where the song comes from and
-- the song's banner on the right. Packs show as rows with their song count.
local M = TW.M
local W, H = M(862), M(64)
local BANNER = M(324)
local N = THEME:GetMetric("MusicWheel", "NumWheelItems")
local middle = math.ceil(N / 2)
local lastclick = 0
local groupCounts = {}
local white = color("#FFFFFF")

local function chartFor(song, focus)
	if focus then
		local st = GAMESTATE:GetCurrentSteps()
		if st and GAMESTATE:GetCurrentSong() == song then return st, TW.msd(st) end
	end
	local best, bestSteps = -1, nil
	for _, st in ipairs(TW.playable(song)) do
		local m = TW.msd(st)
		if m > best then best, bestSteps = m, st end
	end
	return bestSteps, math.max(best, 0)
end
local function source(song)
	local g = song:GetGroupName() or ""
	local dir = (song:GetSongDir() or ""):lower()
	if g == "osu!" then return "OSU!", TW.rgb(255, 102, 170) end
	if g:lower() == "quaver" then return "QUAVER", QV.cyan end
	if dir:find("qwilight") then return "QWILIGHT", TW.rgb(190, 140, 255) end
	return g:upper(), QV.green
end

local t = Def.ActorFrame {
	-- under the selected song, its difficulties open up: the panels below move down to make room
	InitCommand = function(self)
		local unit = M(73.6)
		self:SetUpdateFunction(function(s)
			if s.mine == false then return end
			TW.wheelShift(s, unit)
			-- (browsing: the picked map's row keeps the selected look, the list's middle doesn't)
			if s.p then
				local focus = TW.browsing and (s.p.Song ~= nil and s.p.Song == TW.pick.song) or (not TW.browsing and s.p.HasFocus)
				if focus ~= s.focus then s:playcommand("Set", s.p) end
			end
		end)
	end,
	-- new search results slide in (28 VSRG Hub search.lua)
	TWSearchResultsMessageCommand = function(self) TW.searchSlideIn(self, self.drawIndex, middle) end,
	-- the wheel's list changed (search, filters): pack counts are counted again
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
		-- (the wheel can show a song twice when it holds only a few; only the middle row is "selected")
		p.HasFocus = p.HasFocus and (p.DrawIndex == nil or p.DrawIndex == middle)
		self.p = p
		local focus = TW.browsing and (p.Song ~= nil and p.Song == TW.pick.song) or (not TW.browsing and p.HasFocus)
		self.focus = focus
		p.Focus = focus
		local c = self:GetChildren()
		local w = W + (focus and M(38) or 0)
		c.Bg:zoomto(w, H):diffuse(focus and TW.rgb(16, 11, 34) or color("#000000")):diffusealpha(focus and 0.9 or 0.6)
		c.Line:zoomto(w, math.max(1, M(2))):visible(not focus)
		c.Grad:visible(focus)
		c.Banner:x(w - BANNER)
		c.Click:zoomto(w, H)
		self:playcommand("Fill")
	end,
	CurrentRateChangedMessageCommand = function(self) if self.p then self:playcommand("Fill") end end,
	CurrentStepsChangedMessageCommand = function(self) if self.p and self.p.Focus then self:playcommand("Fill") end end,
	FillCommand = function(self)
		local p = self.p
		local c = self:GetChildren()
		local song = p.Song
		if not song then
			-- a pack
			local name = p.Text or ""
			if p.Type == "SectionCollapsed" or p.Type == "SectionExpanded" then
				local n = TW.groupCount(name)
				c.Title:x(M(20)):y(-M(9)):zoom(M(16) / 24)
				QV.fit(c.Title, name, W - M(150))
				c.Msd:settextf("%d %s", n, n == 1 and "song" or "songs"):diffuse(QV.grey):x(M(20)):maxwidth(0)
			else
				c.Title:x(M(20)):y(0):zoom(M(16) / 24)
				QV.fit(c.Title, name, W - M(150))
				c.Msd:settext("")
			end
			c.Sep:settext(""); c.By:settext(""); c.Mapper:settext(""); c.Keys:settext(""); c.Grade:settext("")
			c.Status:settext(p.Type == "SectionExpanded" and "OPEN" or ""):diffuse(QV.grey)
			c.Banner:visible(false)
			TW.ilater(self, "banner", 0, nil)
			c.Banner.song = nil
			return
		end
		-- best grade on the left, like Quaver
		local g
		pcall(function() g = song:GetHighestGrade() end)
		local x0 = M(20)
		if g and g ~= "Grade_Invalid" and g ~= "Grade_NoData" then
			local q = QV.grade(g)
			-- (your best on the song by its accuracy on the timing it was played on, as on the results)
			local b = TW.songBest and TW.songBest(song)
			if b and b.pct and not b.failed then q = QV.accGrade(b.pct) end
			c.Grade:settext(QV.gradeLetter[q]):diffuse(QV.gradeColour[q])
			x0 = M(62)
		else
			c.Grade:settext("")
		end
		local maxw = M(396) - x0 - M(30)
		c.Title:zoom(M(14) / 24):x(x0):y(-M(10)):diffuse(p.Focus and white or TW.rgb(225, 225, 225))
		QV.fit(c.Title, song:GetDisplayArtist() .. " - " .. song:GetDisplayMainTitle(), maxw)
		local st, m = chartFor(song, p.Focus)
		c.Msd:diffuse(QV.diffColour(m)):x(x0)
		QV.fit(c.Msd, string.format("%.2f - %s", m, st and TW.diffName(st) or "?"), maxw * 0.62)
		local x = x0 + c.Msd:GetZoomedWidth() + M(5)
		c.Sep:settext("|"):x(x):diffuse(QV.grey)
		x = x + c.Sep:GetZoomedWidth() + M(5)
		local by = TW.author(song)
		c.By:settext(by ~= "" and "By:" or ""):x(x)
		x = x + c.By:GetZoomedWidth() + M(4)
		c.Mapper:x(x)
		QV.fit(c.Mapper, by, math.max(M(10), x0 + maxw - x))
		c.Keys:settext(st and (TW.keys(st) .. "k") or "")
		local label, col = source(song)
		c.Status:diffuse(col)
		QV.fit(c.Status, label, M(110))
		c.Banner:playcommand("Load", { song = song, index = p.DrawIndex })
	end,
	Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0.5) end },
	Def.Quad { Name = "Line", InitCommand = function(self) self:align(0, 1):y(H / 2):diffuse(white):diffusealpha(0.75) end },
	-- the song's banner (or background), loaded once the wheel stops on it
	Def.Sprite {
		Name = "Banner",
		InitCommand = function(self) self:align(0, 0.5):visible(false) end,
		LoadCommand = function(self, p)
			if self.song == p.song then return end
			self.song = p.song
			self:visible(false)
			local b = p.song:GetBannerPath()
			if not b or b == "" then b = p.song:GetBackgroundPath() end
			self.want = (b and b ~= "") and b or nil
			-- (waits without a tween: a tween inside the wheel stops it placing its panels, see TW.ianim)
			TW.ilater(self:GetParent(), "banner", TW.pictureDelay(p.index, middle), self.want and function() self:playcommand("Show") end or nil)
		end,
		ShowCommand = function(self)
			if not self.want then return end
			self:LoadFromCached("Banner", self.want)
			TW.keepTexture(self)
			self:scaletoclipped(BANNER, H):visible(true)
			TW.ianim(self:GetParent(), self, "alpha", 1, 0.15, "lin", 0, 0)
		end
	},
	QV.gradient(W + M(38) - BANNER, math.max(2, M(4))) .. { Name = "Grad", InitCommand = function(self) self:y(H / 2 - math.max(2, M(4))):visible(false) end },
	QV.t(M(19), true, function(self) self:align(0.5, 0.5):x(M(34)) end) .. { Name = "Grade" },
	QV.t(M(14), true, function(self) self:align(0, 0.5) end) .. { Name = "Title" },
	QV.t(M(12.5), true, function(self) self:align(0, 0.5):y(M(12)) end) .. { Name = "Msd" },
	QV.t(M(12.5), true, function(self) self:align(0, 0.5):y(M(12)) end) .. { Name = "Sep" },
	QV.t(M(12.5), true, function(self) self:align(0, 0.5):y(M(12)):diffuse(QV.blue) end) .. { Name = "By" },
	QV.t(M(12.5), true, function(self) self:align(0, 0.5):y(M(12)):diffuse(QV.blue) end) .. { Name = "Mapper" },
	QV.t(M(12.5), true, function(self) self:align(0.5, 0.5):x(M(396)):diffuse(QV.keysRed) end) .. { Name = "Keys" },
	QV.t(M(12.5), true, function(self) self:align(0.5, 0.5):x(M(480)) end) .. { Name = "Status" },
	-- click: the first click selects, clicking the selected one plays it
	UIElements.QuadButton(1, 1) .. {
		Name = "Click",
		InitCommand = function(self) self:align(0, 0.5):zoomto(W, H):diffusealpha(0) end,
		SetCommand = function(self, p) self.index = p.DrawIndex end,
		MouseDownCommand = function(self, params)
			-- right click: select this map and open Quaver's map menu
			if params.event == "DeviceButton_right mouse button" then
				local top = SCREENMAN:GetTopScreen()
				local we = top and top:GetMusicWheel()
				if not we or not self.index then return end
				local dist = self.index - middle
				TW.browsing = false
				if dist ~= 0 then
					if we:MoveAndCheckType(dist) == "WheelItemDataType_Section" then we:Move(0) return end
					we:Move(0)
				end
				MESSAGEMAN:Broadcast("QVMapMenu")
				return
			end
			if params.event ~= "DeviceButton_left mouse button" then return end
			local now = GetTimeSinceStart()
			if now - lastclick < 0.1 then return end
			lastclick = now
			local top = SCREENMAN:GetTopScreen()
			local we = top and top:GetMusicWheel()
			if not we or not self.index then return end
			local dist = self.index - middle
			local root = self:GetParent()
			if dist == 0 and TW.browsing then
				-- (the list's middle while you browse: picked where it is)
				local song = root.p and root.p.Song
				if song then TW.pickHere(song) else TW.browsing = false; top:SelectCurrent() end
			elseif dist == 0 and we:IsSettled() then
				top:SelectCurrent()
			else
				TW.browsing = false
				local itemtype = we:MoveAndCheckType(dist)
				we:Move(0)
				if itemtype == "WheelItemDataType_Section" then top:SelectCurrent() end
			end
		end
	}
}
return t
