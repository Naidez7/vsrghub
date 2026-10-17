-- osu! stable's open song: the selected song's panel gives way to one panel per difficulty, blue
-- (the picked one white), each with a tenth of a panel's height above it and further out to the left
-- than the songs, the picked one in the middle of the list. Each shows the song's thumbnail, title,
-- "Artist // Mapper" (faint on the ones not picked, as in osu!), the difficulty's name in bold, the
-- skin's stars (Etterna's MSD as osu!'s star rating: a star for every 4 MSD) with the MSD itself after
-- them, and your best grade as the skin's small grade art. Click one to pick it, the picked one to play.
-- (Etterna's song list can't hold the difficulties as items: they are drawn over it and the song
-- panels move out of their way, TW.wheelShift, as for the other looks: 28 VSRG Hub difficulties.lua.)

local STARS_PER_MSD = 0.25

local function onSelect()
	local s = SCREENMAN:GetTopScreen()
	return s and s:GetName() == "ScreenSelectMusic" and s or nil
end

-- the picked song and its charts: the list's settled song, or while you browse (29 VSRG Hub stable
-- pick.lua) the picked one wherever the list is
local function current()
	if TW.browsing then
		local song = TW.pick.song
		if not song then return nil end
		local list = TW.diffCharts(song)
		if #list < 1 then return nil end
		return song, list, TW.diffIndexOf(list, TW.pick.steps) or 1
	end
	return TW.diffCurrent()
end

function TW.stableDiffRows(spec)
	local M = TW.M
	local ACTORS = 16
	local rows = {}
	local sig = ""
	local gapTarget, liftTarget = 0, 0
	local shownSong
	local art = TW.has("songpanel")
	local plain = TW.fallback("songpanel")
	local starArt = TW.has("star")
	local activeText = TW.colour("SongSelectActiveText", color("#000000"))
	local inactiveText = TW.colour("SongSelectInactiveText", color("#FFFFFF"))
	local TINT_ON = TW.rgb(255, 255, 255, 230 / 255)
	local TINT_OFF = TW.rgb(0, 150, 236)
	local rankArt = { X = "rank_X_small", S = "rank_S_small", A = "rank_A_small", B = "rank_B_small", C = "rank_C_small", D = "rank_D_small" }

	local function place(t, k, x, baseline, ah)
		local px = 0.83 * k * ah
		t:zoom(t.zr * px):xy(x, baseline - 0.75 * px)
	end
	local function zr(px) return function(self) self.zr = self:GetZoom() / px; self:shadowlength(0) end end
	-- where the i-th difficulty's panel's middle is, from the list's middle, with the list at rest
	-- (before it moves up by the lift)
	local function rowY(i)
		local g = TW.stableGeom()
		local P = g.ah + 0.1 * g.bh
		return 0.1 * g.bh + (i - 1) * P
	end

	local function starActor(i)
		if starArt then
			return Def.Sprite { Name = "S" .. i, Texture = TW.img("star"), InitCommand = function(self) TW.inset(self) end }
		end
		return TW.icon("star", M(20), function(self) end) .. { Name = "S" .. i }
	end

	local function rowActor(i)
		local r = Def.ActorFrame {
			Name = "Row" .. i,
			InitCommand = function(self) rows[i] = self; self:visible(false) end,
			(art and Def.Sprite { Texture = TW.img("songpanel") } or (plain and TW.box { w = M(700), h = M(90), r = M(12), ax = 0, ay = 0.5 } or Def.Actor {})) .. {
				Name = "Panel",
				InitCommand = function(self) if art then TW.stableSawPanel(self); TW.inset(self); self:align(0, 0.5) end end,
			},
			Def.Sprite { Name = "Thumb", InitCommand = function(self) self:visible(false) end },
			-- (the mania icon: three white keys, two black ones over them; 100 units wide)
			Def.ActorFrame {
				Name = "Mode",
				InitCommand = function(self) self.base = 100 end,
				Def.Quad { InitCommand = function(self) self:zoomto(100, 80) end },
				Def.Quad { InitCommand = function(self) self:zoomto(5, 80):x(-17):diffuse(color("0,0,0,0.85")) end },
				Def.Quad { InitCommand = function(self) self:zoomto(5, 80):x(17):diffuse(color("0,0,0,0.85")) end },
				Def.Quad { InitCommand = function(self) self:zoomto(14, 46):xy(-17, -17):diffuse(color("0,0,0,0.9")) end },
				Def.Quad { InitCommand = function(self) self:zoomto(14, 46):xy(17, -17):diffuse(color("0,0,0,0.9")) end },
			},
			Def.Sprite { Name = "Grade", InitCommand = function(self) self:visible(false) end },
			TW.text(M(18), true, zr(M(18))) .. { Name = "GradeText" },
			TW.text(M(16), false, zr(M(16))) .. { Name = "Title" },
			TW.text(M(10.5), false, zr(M(10.5))) .. { Name = "Sub" },
			TW.text(M(13.5), true, zr(M(13.5))) .. { Name = "Name" },
			TW.text(M(12), true, zr(M(12))) .. { Name = "Msd" },
			UIElements.QuadButton(1, 1) .. {
				Name = "Click",
				InitCommand = function(self) self:align(0, 0.5):diffusealpha(0) end,
				MouseOverCommand = function(self) self:GetParent().hover = true end,
				MouseOutCommand = function(self) self:GetParent().hover = false end,
				MouseDownCommand = function(self, params)
					if params.event ~= "DeviceButton_left mouse button" or not self.index then return end
					local song, _, cur = current()
					if not song then return end
					local i = self.index
					-- (while browsing, the list goes back to the picked song first)
					TW.syncToPick(function()
						if i == cur then
							local s = onSelect()
							if s then s:SelectCurrent() end
						else
							TW.pickDiff(i)
						end
					end)
				end,
			},
		}
		for k = 0, 9 do r[#r + 1] = starActor(k) end
		return r
	end

	-- one difficulty's panel
	local function fill(row, song, st, i, cur, showKeys)
		local g = TW.stableGeom()
		local c = row:GetChildren()
		local on = i == cur
		local tint = on and TINT_ON or TINT_OFF
		if art then c.Panel:zoomto(g.bw, g.bh):diffuse(tint)
		elseif plain then
			TW.setBox(c.Panel, { w = g.bw - 2 * g.ox, h = g.bh - 2 * g.oy, col = { tint[1], tint[2], tint[3], tint[4] },
				col2 = { tint[1] * 0.75, tint[2] * 0.75, tint[3] * 0.75, tint[4] } })
			c.Panel:x(g.ox)
		end
		local px, top, ah = g.ox, -g.bh / 2 + g.oy, g.ah
		local bgPath = song:GetBackgroundPath()
		local hasThumb = g.thumbs and bgPath ~= nil and bgPath ~= ""
		local thumbW = hasThumb and ah * 4 / 3 or 0
		local txt = on and activeText or inactiveText
		-- your best grade (osu!'s ranking-*-small, 0.45 of the panel's inside tall)
		local b = TW.bestOn and TW.bestOn(st)
		local rank
		if b then
			rank = TW.GradeToRank[b.grade] or "D"
			if b.pct and TW.accRank then rank = TW.accRank(b.pct) end
			if b.failed or b.grade == "Grade_Failed" then rank = nil end
		end
		-- (as osu! lays a mania difficulty out: the piano icon at the top of a column before the words,
		-- your grade under it)
		local T = hasThumb and (thumbW + g.aw * 0.02) or g.aw * 0.012
		local iw = 0.26 * ah
		local ix = px + T + iw / 2
		c.Mode:xy(ix, top + 0.25 * ah):zoom(iw / c.Mode.base):diffuse(txt)
		c.Grade:visible(false)
		c.GradeText:visible(false)
		if rank then
			local id = rankArt[rank]
			if id and TW.has(id) then
				if c.Grade.loaded ~= id then c.Grade:Load(TW.img(id)); c.Grade.loaded = id; TW.inset(c.Grade) end
				local h = c.Grade:GetHeight()
				c.Grade:zoom(h > 0 and (0.34 * ah / h) or 1):visible(true):xy(ix, top + 0.74 * ah)
			else
				c.GradeText:visible(true):settext(TW.RankLetter[rank] or rank):diffuse(TW.RankColour[rank] or color("#FFFFFF"))
				c.GradeText:zoom(c.GradeText.zr * 0.3 * ah):halign(0.5):xy(ix, top + 0.74 * ah)
			end
		end
		T = T + iw + 0.12 * ah
		local room = math.max(M(60), SCREEN_WIDTH - TW.stableX(1, 0.075) - px - T - M(10))
		-- title, artist // mapper (faint unless picked), the difficulty's name
		place(c.Title, 0.22, px + T, top + 0.295 * ah, ah)
		c.Title:settext(song:GetDisplayMainTitle()):diffuse(txt):diffusealpha(on and 1 or 0.2):maxwidth(room / c.Title:GetZoom())
		place(c.Sub, 0.14, px + T, top + 0.489 * ah, ah)
		local by = TW.author(song)
		c.Sub:settext(song:GetDisplayArtist() .. (by ~= "" and (" // " .. by) or "")):diffuse(txt):diffusealpha(on and 1 or 0.2):maxwidth(room / c.Sub:GetZoom())
		place(c.Name, 0.18, px + T, top + 0.708 * ah, ah)
		local name = TW.diffName(st)
		-- (osu! adds the key count to a mania difficulty's name)
		name = name .. " (" .. TW.keys(st) .. "K)"
		c.Name:settext(name):diffuse(txt):maxwidth(room / c.Name:GetZoom())
		-- stars: MSD / 4, osu!'s row of them (full ones growing a little, a part one at least half
		-- size, faint ones up to ten), then the MSD
		local m = TW.msd(st)
		local stars = m * STARS_PER_MSD
		local full = math.max(0, math.min(9, math.floor(stars)))
		local sw = 0.2 * ah
		local sy = top + 0.85 * ah
		for k = 0, 9 do
			local s = c["S" .. k]
			local h = s:GetHeight()
			local base = h > 0 and sw / h or 1
			-- (VSRG Hub's own star has a margin round it: drawn a little larger to match osu!'s)
			if not starArt then base = base * 1.35 end
			s:xy(px + T + 0.1 * ah + k * 0.35 * ah, sy)
			if k < full then
				s:zoom(math.min(base * 1.175, base * (1 + k * 0.015))):diffuse(txt):blend("BlendMode_Normal"):visible(true)
			elseif k == full then
				s:zoom(base * math.max(0.5, math.min(1, stars - full))):diffuse(txt):blend("BlendMode_Normal"):visible(stars > 0)
			else
				s:zoom(base * 0.6):diffuse(TW.rgb(255, 255, 255, 30 / 255)):blend("BlendMode_Add"):visible(true)
			end
		end
		c.Msd:settextf("%.2f", m):diffuse(txt)
		place(c.Msd, 0.16, px + T + 0.1 * ah + 9 * 0.35 * ah + 0.25 * ah, sy + 0.08 * ah, ah)
		-- the song's background as the thumbnail
		local want = hasThumb and TW.thumbPath(song) or nil
		if want then
			if c.Thumb.shown ~= want then
				c.Thumb:LoadFromCached("Background", want)
				c.Thumb.shown = want
				TW.keepTexture(c.Thumb)
			end
			c.Thumb:x(px + thumbW / 2):scaletoclipped(thumbW + M(3), ah):visible(true)
		else
			c.Thumb:visible(false)
		end
		c.Click:zoomto(g.bw - 2 * g.ox, ah):x(px)
		c.Click.index = i
	end

	local function rebuild()
		local song, list, cur = current()
		if not song then
			gapTarget, liftTarget = 0, 0
			shownSong = nil
			TW.diffOpenSong = nil
			for slot = 1, ACTORS do rows[slot].idx = nil; rows[slot]:visible(false) end
			return
		end
		local g = TW.stableGeom()
		local n = #list
		local fresh = song ~= shownSong
		shownSong = song
		local P = g.ah + 0.1 * g.bh
		-- the songs after it make room for the difficulties (and a tenth of a panel after them)
		gapTarget = n * P + 0.1 * g.bh - g.ah
		liftTarget = rowY(cur)
		local keys, mixed = nil, false
		for _, st in ipairs(list) do
			local k = TW.keys(st)
			if keys and k ~= keys then mixed = true end
			keys = k
		end
		local first = math.max(1, math.min(cur - math.floor(ACTORS / 2), n - ACTORS + 1))
		local last = math.min(n, first + ACTORS - 1)
		local used = {}
		for idx = first, last do
			local slot = (idx - 1) % ACTORS + 1
			local row = rows[slot]
			used[slot] = true
			fill(row, song, list[idx], idx, cur, mixed)
			if fresh or row.idx ~= idx then row.cx = nil; row.h = 0; row.p = fresh and 0 or row.p end
			row.idx = idx
			row:visible(true)
		end
		for slot = 1, ACTORS do
			if not used[slot] then rows[slot].idx = nil; rows[slot]:visible(false) end
		end
		TW.diffOpenSong = song
	end

	local frame = Def.ActorFrame {
		Name = "TWDiffRows",
		InitCommand = function(self)
			TW.diffGap, TW.diffLift = 0, 0
			TW.diffMinCharts = 1
			TW.wheelFade = TW.stableFade
			TW.wheelCentre = TW.stableCentre()
			TW.wheelCurve = TW.stableCurveX
			TW.wheelAbsFade = true
			TW.everyFrame(self)
			TW.browsing, TW.pickY = false, 0
			TW.pick = { song = GAMESTATE:GetCurrentSong(), steps = GAMESTATE:GetCurrentSteps() }
			TW.pickMusicReset()
			self:SetUpdateFunction(function(s, dt)
				dt = dt or 0.016
				TW.syncStep()
				TW.pickMusicStep()
				-- where the picked song's panel is: in the middle unless you browse (its panel reports
				-- where it is; off the list's shown part, from how far the list has moved)
				local w = onSelect() and onSelect():GetMusicWheel()
				-- (browsing and the list at rest: the game's song back to the picked one)
				-- (after a moment at rest: between quick turns of the mouse wheel the list stops briefly)
				if w and w:IsSettled() then
					s.restAt = s.restAt or GetTimeSinceStart()
					if TW.browsing and GetTimeSinceStart() - s.restAt > 0.2 then TW.restorePick() end
				else
					s.restAt = nil
				end
				if not TW.browsing then
					TW.pickY = 0
					if w and w:IsSettled() then TW.pickIndex = w:GetCurrentIndex() end
				elseif TW.pickSeenAt ~= nil and GetTimeSinceStart() - TW.pickSeenAt < 0.05 then
					TW.pickY = TW.pickSeenY
				elseif w and TW.pickIndex then
					TW.pickY = (TW.pickIndex - w:GetCurrentIndex()) * TW.stableGeom().ah
				end
				local song, list, cur = current()
				local key = ""
				if song then
					local n = 0
					pcall(function() n = SCOREMAN:GetTotalNumberOfScores() end)
					key = tostring(song) .. "|" .. tostring(list[cur]) .. "|" .. #list .. "|" .. getCurRateValue() .. "|" .. n
				end
				local pend = TW.diffPending
				if pend and (GetTimeSinceStart() - pend.t > 2) then TW.diffPending = nil; pend = nil end
				if pend and song and song ~= pend.from then
					TW.diffPending = nil
					TW.pickDiff(pend.dir > 0 and 1 or #list)
					song, list, cur = current()
					key = song and (tostring(song) .. "|" .. tostring(list[cur]) .. "|" .. #list .. "|" .. getCurRateValue() .. "|" .. key:match("[^|]*$")) or ""
				end
				if key ~= sig then
					sig = key
					rebuild()
				end
				-- the list glides so the picked difficulty is in the middle (osu!: 0.15 s)
				local k = math.min(1, dt * 14)
				local gp, l = TW.diffGap or 0, TW.diffLift or 0
				gp = gp + (gapTarget - gp) * k
				l = l + (liftTarget - l) * k
				if math.abs(gapTarget - gp) < 0.3 then gp = gapTarget end
				if math.abs(liftTarget - l) < 0.3 then l = liftTarget end
				TW.diffGap, TW.diffLift = gp, l
				if not shownSong then return end
				local centre = TW.stableCentre()
				local V = TW.stableGeom().V
				for slot = 1, ACTORS do
					local row = rows[slot]
					if row.idx then
						local y = centre + (TW.pickY or 0) + rowY(row.idx) - l
						-- (the curve, the pull of an open song's difficulties, the mouse's slide)
						row.p = (row.p or 0) + (1 - (row.p or 0)) * math.min(1, dt * 8)
						row.h = (row.h or 0) + ((row.hover and 1 or 0) - (row.h or 0)) * math.min(1, dt * 3)
						local x = TW.stableX(TW.stableCurve(y - centre), 0.075 * row.p) - 0.075 * V * row.h
						row.cx = row.cx and (row.cx + (x - row.cx) * math.min(1, dt * 10)) or x
						local a = TW.stableFade(y)
						row:xy(row.cx, y):diffusealpha(a):visible(a > 0.01)
					end
				end
			end)
		end,
		-- the list moved: the picked song stays picked while you browse
		CurrentSongChangedMessageCommand = function() TW.keepPick() end,
		CurrentStepsChangedMessageCommand = function() TW.keepPick() end,
		PlayingSampleMusicMessageCommand = function() TW.pickMusicPlaying() end,
		-- (a new list: search, filters, sort, a pack opened)
		FilterResultsMessageCommand = function() TW.browsing = false end,
		TWSortChangedMessageCommand = function() TW.browsing = false end,
		OffCommand = function()
			TW.diffGap, TW.diffLift, TW.wheelFade, TW.wheelCurve, TW.diffOpenSong = 0, 0, nil, nil, nil
			TW.diffMinCharts, TW.wheelAbsFade = nil, nil
			TW.browsing, TW.pickY = false, 0
		end,
	}
	for i = 1, ACTORS do frame[#frame + 1] = rowActor(i) end
	return frame
end
