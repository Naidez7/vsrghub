-- osu! stable's song select panels (27 VSRG Hub stable panels.lua has the sizes): the skin's
-- menu-button-background at its own shape, tinted as osu! tints it (song sets pink, pack headers
-- dark blue, an open one green); the song's background as a 4:3 thumbnail (skins of version 2.2 and
-- later, as in osu!); the title, and "Artist // Mapper" under it, in the skin's song select text
-- colours. Packs show their name and how many songs they hold, like osu!'s "Today (23 maps)".
-- The selected song's panel makes way for its difficulties (one panel each: TW.stableDiffRows).
TW.useInterfaceSkin()
local M = TW.M
local plain = TW.fallback("songpanel")
local art = TW.has("songpanel")
local inactiveText = TW.colour("SongSelectInactiveText", color("#FFFFFF"))
local activeText = TW.colour("SongSelectActiveText", color("#000000"))
-- osu!'s tints (osu_songbrowser_*_color)
local TINT = {
	set = TW.rgb(235, 73, 153, 240 / 255),
	groupClosed = TW.rgb(35, 50, 143),
	groupOpen = TW.rgb(163, 240, 44),
	active = TW.rgb(255, 255, 255, 230 / 255),
}
local N = THEME:GetMetric("MusicWheel", "NumWheelItems")
local middle = math.ceil(N / 2)
local lastclick = 0

-- text with its letters' top k * ah above a baseline at y (as osu! sizes its song panel text)
local function place(t, k, x, baseline, g)
	local px = 0.83 * k * g.ah
	t:zoom(t.zr * px):xy(x, baseline - 0.75 * px)
end
local function zr(px) return function(self) self.zr = self:GetZoom() / px; self:shadowlength(0) end end

local function layout(self, g)
	local c = self:GetChild("Body"):GetChildren()
	c.Panel:visible(true)
	if art then c.Panel:zoomto(g.bw, g.bh)
	elseif plain then TW.setBox(c.Panel, { w = g.bw - 2 * g.ox, h = g.bh - 2 * g.oy }) c.Panel:xy(g.ox, 0) end
	c.Click:zoomto(g.bw - 2 * g.ox, g.ah):x(g.ox)
end

local t = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function(s)
			if s.mine == false then return end
			-- the open song's difficulties below it, the curve for where the panel ends up
			TW.wheelShift(s, TW.stableGeom().ah)
			-- (the selected song's panel gives way to its difficulties' panels)
			-- (where the picked song's panel is, for its difficulties while you browse)
			if s.song ~= nil and s.song == TW.pick.song and s:GetVisible() then
				local item = s:GetParent()
				if item then TW.pickSeenY, TW.pickSeenAt = item:GetY(), GetTimeSinceStart() end
			end
			local hide = s.song ~= nil and s.song == TW.diffOpenSong
			local b = s:GetChild("Body")
			if hide ~= s.hidden then s.hidden = hide; b:visible(not hide) end
		end)
	end,
	-- new search results slide in (28 VSRG Hub search.lua)
	TWSearchResultsMessageCommand = function(self)
		local b = self:GetChild("Body")
		local off = math.abs((self.drawIndex or middle) - middle)
		TW.ianim(self, b, "alpha", 1, 0.2, "dec", 0.02 * off, 0)
		TW.ianim(self, b, "x", 0, 0.2, "dec", 0.02 * off, TW.M(16))
	end,
	-- coming into song select, the panels slide in from the right, the middle ones first
	OnCommand = function(self)
		local b = self:GetChild("Body")
		local off = math.abs((self.drawIndex or middle) - middle)
		TW.ianim(self, b, "x", 0, 0.45, "dec", 0.05 + 0.035 * off, TW.M(220))
		TW.ianim(self, b, "alpha", 1, 0.45, "dec", 0.05 + 0.035 * off, 0)
	end,
	-- the wheel's list changed (search, filters): pack counts are counted again
	FilterResultsMessageCommand = function() TW.groupCache = nil end,
	SetCommand = function(self, p)
		-- (this file is every kind of panel: song, pack, sort. Etterna loads it once per kind into each
		-- wheel item, shows the one that matches and tells them all: the others must stay hidden, or
		-- each panel is drawn two or three times over itself)
		local name = self:GetName()
		self.mine = name == "" or name == (p.Type or "") .. "NormalPart"
		if not self.mine then
			self.song = nil
			self:visible(false)
			return
		end
		TW.everyFrame(self)
		self.drawIndex = p.DrawIndex
		self:visible(not TW.wheelWrapped(p, middle))
		self.text = p.Text
		self.song = p.Song
		local g = TW.stableGeom()
		layout(self, g)
		local b = self:GetChild("Body")
		local c = b:GetChildren()
		local section = p.Type == "SectionCollapsed" or p.Type == "SectionExpanded"
		-- the tint
		local tint
		if p.Song then tint = TINT.set
		elseif p.Type == "SectionExpanded" then tint = TINT.groupOpen
		elseif section then tint = TINT.groupClosed
		else tint = p.HasFocus and TINT.active or TINT.groupClosed end
		if art then c.Panel:diffuse(tint)
		elseif plain then TW.setBox(c.Panel, { col = { tint[1], tint[2], tint[3], tint[4] }, col2 = { tint[1] * 0.75, tint[2] * 0.75, tint[3] * 0.75, tint[4] } }) end
		-- the inside of the panel
		local px, top = g.ox, -g.bh / 2 + g.oy
		-- (osu! keeps room for the thumbnail only when the song has a picture)
		local bg = p.Song and p.Song:GetBackgroundPath() or nil
		local hasThumb = g.thumbs and bg ~= nil and bg ~= ""
		local thumbW = hasThumb and g.ah * 4 / 3 or 0
		local T = hasThumb and (thumbW + g.aw * 0.02) or g.aw * 0.012
		-- (the text stops at the screen's edge: the panel sticks out past it)
		local room = math.max(M(60), SCREEN_WIDTH - TW.stableX(1, 0) - px - T - M(10))
		local txt = (p.Type == "SectionExpanded") and activeText or inactiveText
		if p.Song then
			place(c.Title, 0.22, px + T, top + 0.295 * g.ah, g)
			c.Title:settext(p.Song:GetDisplayMainTitle()):diffuse(txt):maxwidth(room / c.Title:GetZoom()):visible(true)
			place(c.Sub, 0.14, px + T, top + 0.489 * g.ah, g)
			local by = TW.author(p.Song)
			c.Sub:settext(p.Song:GetDisplayArtist() .. (by ~= "" and (" // " .. by) or "")):diffuse(txt):maxwidth(room / c.Sub:GetZoom()):visible(true)
			c.Group:visible(false)
		else
			c.Title:visible(false)
			c.Sub:visible(false)
			local name = p.Text or ""
			if section then
				local n = TW.groupCount(name)
				name = string.format("%s (%d %s)", name, n, n == 1 and "map" or "maps")
			end
			place(c.Group, 0.35, px + g.aw * 0.02, top + 0.675 * g.ah, g)
			c.Group:settext(name):diffuse(txt):maxwidth((room + T) / c.Group:GetZoom()):visible(true)
		end
		-- the thumbnail, loaded once the wheel stops
		c.Thumb:playcommand("Load", { p = p, x = px + thumbW / 2, w = thumbW, h = g.ah })
	end,
	Def.ActorFrame {
		Name = "Body",
		-- the panel
		(art and Def.Sprite { Texture = TW.img("songpanel") } or (plain and TW.box { w = M(700), h = M(90), r = M(12), ax = 0, ay = 0.5 } or Def.Actor {})) .. {
			Name = "Panel",
			InitCommand = function(self)
				if art then
					TW.stableSawPanel(self)
					TW.inset(self)
					self:align(0, 0.5)
				end
			end,
		},
		-- the song's background as a 4:3 thumbnail, inside the panel's edge
		Def.Sprite {
			Name = "Thumb",
			InitCommand = function(self) self:visible(false) end,
			-- (no tweens in here: see TW.ianim)
			LoadCommand = function(self, a)
				local f = self:GetParent():GetParent()
				local p = a.p
				self.box = a
				local want = (TW.stableGeom().thumbs and p.Song) and TW.thumbPath(p.Song) or nil
				if want and want == self.shown then
					TW.ilater(f, "thumb", 0, nil)
					self:x(a.x):scaletoclipped(a.w + M(3), a.h):visible(true)
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
				local a = self.box
				self:x(a.x):scaletoclipped(a.w + M(3), a.h):visible(true)
				TW.ianim(self:GetParent():GetParent(), self, "alpha", 1, 0.1, "dec", 0, 0)
			end
		},
		TW.text(M(16), false, zr(M(16))) .. { Name = "Title" },
		TW.text(M(10.5), false, zr(M(10.5))) .. { Name = "Sub" },
		TW.text(M(26), false, zr(M(26))) .. { Name = "Group" },
		-- click: like osu!, the first click selects, clicking the selected one plays it; under the
		-- mouse the panel slides out to the left (osu!'s hover)
		UIElements.QuadButton(1, 1) .. {
			Name = "Click",
			InitCommand = function(self) self:align(0, 0.5):diffusealpha(0) end,
			SetCommand = function(self, p) self.index = p.DrawIndex end,
			MouseOverCommand = function(self)
				local b = self:GetParent()
				TW.ianim(b:GetParent(), b, "x", -0.075 * TW.stableGeom().V, 0.6, "dec")
			end,
			MouseOutCommand = function(self)
				local b = self:GetParent()
				TW.ianim(b:GetParent(), b, "x", 0, 0.6, "dec")
			end,
			MouseDownCommand = function(self, params)
				if params.event ~= "DeviceButton_left mouse button" then return end
				if self:GetParent():GetParent().hidden then return end
				local now = GetTimeSinceStart()
				if now - lastclick < 0.1 then return end
				lastclick = now
				local top = SCREENMAN:GetTopScreen()
				local we = top and top:GetMusicWheel()
				if not we or not self.index then return end
				local dist = self.index - middle
				local root = self:GetParent():GetParent()
				if dist == 0 and TW.browsing then
					-- (the list's middle while you browse: picked where it is)
					if root.song then TW.pickHere(root.song) else top:SelectCurrent(); TW.packToggled() end
				elseif dist == 0 and we:IsSettled() then
					top:SelectCurrent()
				else
					TW.browsing = false
					local itemtype = we:MoveAndCheckType(dist)
					we:Move(0)
					if itemtype == "WheelItemDataType_Section" then top:SelectCurrent(); TW.packToggled() end
				end
			end
		}
	}
}
return t
