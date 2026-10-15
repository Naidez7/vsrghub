-- A song's difficulties on song select, as osu! shows them: once the list stops on a song with more
-- than one chart, the song opens up and its charts show under it, one row each (name, keys, length,
-- notes, the main pattern type, MSD at the current rate and your best on it), and the whole list
-- moves up so the picked chart sits in the middle, where the selected song sits. Click a row to pick
-- that chart, click the picked one to play it; the mouse wheel and the arrow keys (osu!: up / down,
-- Quaver: left / right) go through them, the list gliding along, and past the first or the last one
-- they go on to the song before or after.
--
-- Etterna's song list can't hold the charts as items of their own, so the rows are drawn over it by
-- the song select overlay (TW.diffRows) and the song panels shift themselves (TW.wheelShift, from
-- each panel's update): all of them up by TW.diffLift, the ones below the selected one down by the
-- room the rows take, TW.diffGap.
--
-- Only 4K and 7K charts are VSRG Hub's (Etterna's "dance" game also has 8K doubles, 6K solo and 3K
-- charts, which have no notes or skins here): the others are left out of the lists (TW.playable),
-- and songs with none of them out of the song list (metrics.ini, StepsTypesToHide).

TW.diffGap = 0
TW.diffLift = 0

local function top() return SCREENMAN:GetTopScreen() end
local function onSelect()
	local s = top()
	return s and s:GetName() == "ScreenSelectMusic" and s or nil
end

-- the charts of the selected song, in the order Etterna's song select steps through them (kept for
-- a moment: the rows ask every frame)
local chartsCache = { t = -1 }
local function charts(song)
	local now, rate = GetTimeSinceStart(), getCurRateValue()
	local c = chartsCache
	if c.song == song and c.rate == rate and now - c.t < 1 then return c.list end
	local list = {}
	pcall(function() list = song:GetChartsMatchingFilter() or {} end)
	list = TW.onlyPlayable(list)
	if #list == 0 then list = TW.playable(song) end
	-- easiest first, as osu! and Quaver list them (and as Etterna orders them: by difficulty slot)
	local order = { Difficulty_Beginner = 1, Difficulty_Easy = 2, Difficulty_Medium = 3, Difficulty_Hard = 4, Difficulty_Challenge = 5, Difficulty_Edit = 6 }
	local key = {}
	for i, st in ipairs(list) do
		local d = 9
		pcall(function() d = order[st:GetDifficulty()] or 9 end)
		key[st] = { tostring(st:GetStepsType()), d, TW.msd(st), i }
	end
	table.sort(list, function(a, b)
		local x, y = key[a], key[b]
		if x[1] ~= y[1] then return x[1] < y[1] end
		if x[2] ~= y[2] then return x[2] < y[2] end
		if math.abs(x[3] - y[3]) > 0.001 then return x[3] < y[3] end
		return x[4] < y[4]
	end)
	chartsCache = { song = song, rate = rate, t = now, list = list }
	return list
end
local function indexOf(list, st)
	for i, s in ipairs(list) do if s == st then return i end end
	return nil
end

-- whether the list is open on a song now, and its charts
local function current()
	local s = onSelect()
	if not s then return nil end
	local w = s:GetMusicWheel()
	if not w or not w:IsSettled() then return nil end
	local song = GAMESTATE:GetCurrentSong()
	if not song then return nil end
	local list = charts(song)
	-- (osu! stable opens every song, even one with a single difficulty)
	if #list < (TW.diffMinCharts or 2) then return nil end
	return song, list, indexOf(list, GAMESTATE:GetCurrentSteps()) or 1
end
TW.diffCurrent = current
TW.diffCharts = charts
TW.diffIndexOf = indexOf

-- picks the i-th chart of the selected song (Etterna moves through its own list one step at a time)
-- (one step at a time until it is the one: Etterna's own list may be in another order)
function TW.pickDiff(i)
	local s = onSelect()
	local song, list, cur = current()
	if not s or not song or not list[i] or i == cur then return end
	local want = list[i]
	local dir = i > cur and 1 or -1
	for _ = 1, 2 * #list + 2 do
		local before = GAMESTATE:GetCurrentSteps()
		if before == want then return end
		s:ChangeSteps(dir)
		if GAMESTATE:GetCurrentSteps() == before then dir = -dir end -- (at the end of Etterna's list)
	end
end

-- Keys before Etterna's song select gets them (from the look's input gate). axis "vertical": up and
-- down go through the charts (osu!), "horizontal": left and right (Quaver). Past the first or the last
-- chart the key moves the list to the song before or after.
function TW.diffKey(event, axis)
	if event.type ~= "InputEventType_FirstPress" and event.type ~= "InputEventType_Repeat" then return false end
	if event.DeviceInput.is_mouse or INPUTFILTER:IsControlPressed() or (TW.altHeld and TW.altHeld()) then return false end
	local b = event.DeviceInput.button
	local dir
	if axis == "vertical" then
		dir = (b == "DeviceButton_up" and -1) or (b == "DeviceButton_down" and 1) or nil
	else
		dir = (b == "DeviceButton_left" and -1) or (b == "DeviceButton_right" and 1) or nil
	end
	if not dir then return false end
	return TW.diffStep(dir)
end
-- one chart on (dir 1) or back (-1), past the ends to the song after / before; false when no song
-- is open on the list (then the list itself moves)
function TW.diffStep(dir)
	-- (the osu! stable look, scrolled away from the picked song: back to it first)
	if TW.browsing and TW.syncToPick then TW.syncToPick(function() TW.diffStep(dir) end) return true end
	local song, list, cur = current()
	if not song then return false end
	local s = onSelect()
	local want = cur + dir
	if want >= 1 and want <= #list then
		TW.pickDiff(want)
		return true
	end
	-- past the ends: the song before / after (a held key keeps going), on its first chart going down
	-- and its last going up, as in osu!
	local w = s:GetMusicWheel()
	TW.diffPending = { dir = dir, t = GetTimeSinceStart(), from = song }
	if w then
		w:MoveAndCheckType(dir)
		w:Move(0)
	end
	return true
end

-- The wheel goes round: with few songs (a search) the same ones show again above the first and below
-- the last. Those repeats are hidden, so the list has a top and a bottom (as osu!'s and Quaver's).
function TW.wheelWrapped(p, middle)
	if not (p and p.Index and p.DrawIndex) then return false end
	local s = SCREENMAN:GetTopScreen()
	local w = s and s.GetMusicWheel and s:GetMusicWheel()
	if not w then return false end
	local ok, n, sel = pcall(function() return w:GetNumItems(), w:GetCurrentIndex() end)
	if not ok or not n or not sel then return false end
	local want = sel + (p.DrawIndex - middle)
	return want < 0 or want >= n
end

-- the mouse wheel on song select (from the looks' overlays): through the open song's charts, as the
-- keys do. A quick run of wheel turns keeps going through the songs: a song opens its charts to the
-- wheel once the list has stayed on it for a moment (false: the list moves).
function TW.diffWheel(dir)
	local now = GetTimeSinceStart()
	if now - (TW.wheelSongAt or -1) < 0.3 then
		TW.wheelSongAt = now
		return false
	end
	local song, list, cur = current()
	if not song then
		TW.wheelSongAt = now
		return false
	end
	if cur + dir < 1 or cur + dir > #list then TW.wheelSongAt = now end
	return TW.diffStep(dir)
end

-- The song panels move up by TW.diffLift (so the picked chart is in the middle) and the ones under
-- the selected one down by the room the rows take; called each frame by a panel (self: the panel's
-- own frame, whose parent is the wheel item; unit: the list's spacing). A panel moved up under the
-- top bar fades as the list fades its panels there (TW.wheelFade: the look's fade for a height on
-- screen, the same as its metrics' ItemTransformFunction).
function TW.wheelShift(self, unit)
	TW.wheelStep(self) -- (the panel's own animations: 10 VSRG Hub.lua)
	local item = self:GetParent()
	if not item then return end
	local iy = item:GetY()
	-- (from the open song's panel: the list's middle, or where the picked song is while you browse
	-- the osu! stable look's list)
	local off = (iy - (TW.pickY or 0)) / unit
	local g = TW.diffGap or 0
	local y = ((off > 0.01 and g > 0.5) and g * math.min(1, off) or 0) - (TW.diffLift or 0)
	self:y(y)
	-- (osu! stable: the panels' curve, for where the panel is now)
	local curve = TW.wheelCurve
	if curve then self:x(curve((TW.wheelCentre or 0) + iy + y)) end
	local fade = TW.wheelFade
	if fade then
		-- (the list fades the item for where it would be; the panel inside fades the rest of the way
		-- for where it is, on top of its own fade-in: TW.ianim keeps that as twOwnAlpha)
		local c = TW.wheelCentre or 0
		local base, want = fade(c + iy), fade(c + iy + y)
		local f = base > 0.001 and math.max(0, math.min(1, want / base)) or 1
		if math.abs(f - (self.twFade or 1)) > 0.001 then
			self.twFade = f
			self:diffusealpha((self.twOwnAlpha or 1) * f)
		end
	end
end

-- your best play on a chart, at any rate: { wife = percent, grade = "Grade_TierNN", rate = r }
local bestCache = {}
local function bestOn(st)
	local ck
	pcall(function() ck = st:GetChartKey() end)
	if not ck then return nil end
	local n = 0
	pcall(function() n = SCOREMAN:GetTotalNumberOfScores() end)
	local c = bestCache[ck]
	if c and c.n == n then return c.best end
	local best
	pcall(function()
		local byRate = SCOREMAN:GetScoresByKey(ck)
		if not byRate then return end
		for r, l in pairs(byRate) do
			-- (each score on the timing it was played on: an osu! OD's accuracy or Wife% on its judge)
			for _, hs in ipairs(l:GetScores() or {}) do
				local pct, timing, failed = hs:GetWifeScore() * 100, "J4", false
				if TW.scoreAcc then pct, timing, failed = TW.scoreAcc(hs) end
				if not best or (best.failed and not failed) or ((failed == best.failed) and pct > best.pct) then
					best = { wife = hs:GetWifeScore() * 100, pct = pct, timing = timing, failed = failed, grade = hs:GetWifeGrade(),
						rate = tonumber((tostring(r):gsub("x", ""))) or 1 }
				end
			end
		end
	end)
	bestCache[ck] = { n = n, best = best }
	return best
end
TW.bestOn = bestOn
-- your best on any of a song's charts of this key mode (the song list's small grade)
function TW.songBest(song)
	local best
	pcall(function()
		for _, st in ipairs(TW.playable(song)) do
			local b = bestOn(st)
			if b and (not best or (best.failed and not b.failed) or ((b.failed == best.failed) and b.pct > best.pct)) then best = b end
		end
	end)
	return best
end

local function fmtLen(sec)
	sec = math.max(0, math.floor((sec or 0) / getCurRateValue() + 0.5))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end
local skillNames = { "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical" }
local function topSkill(st)
	local best, name = 0, ""
	for i = 1, 7 do
		local v = TW.msd(st, i + 1)
		if v > best then best, name = v, skillNames[i] end
	end
	return name
end
local function notes(st)
	local n = 0
	pcall(function()
		local rv = st:GetRadarValues(PLAYER_1)
		n = rv:GetValue("RadarCategory_Notes") + rv:GetValue("RadarCategory_Holds")
	end)
	return n
end
local function fmtInt(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- The rows. spec: look ("osu", "lazer" or "quaver"), x(), y() (the selected panel's left edge and its
-- bottom edge on screen, with the list at rest), centre() (the height of the list's middle on screen),
-- unit (the list's spacing, for TW.wheelShift), indent, rowH, step, maxActors (rows drawn at once),
-- fade(y) (how much a row at height y on screen shows: the look's list fades its panels under the top
-- and bottom bars), clear(y0, y1) (how far right a row from y0 to y1 on screen can put its text,
-- nil for the screen's edge: the play cookie is in the bottom right), fs (the look's font size against
-- osu!'s), msdColour(v), gradeText(grade, best) -> text, colour.
function TW.diffRows(spec)
	local M = TW.M
	local look = spec.look
	local fs = spec.fs or 1
	local ACTORS = spec.maxActors or 20
	local RH, ST = spec.rowH, spec.step
	local rows = {} -- the row actors; chart i of the song is drawn by row ((i - 1) % ACTORS) + 1
	local sig = ""
	local gapTarget, liftTarget = 0, 0
	local shownSong = nil
	-- the osu! look with a skin's song panel art: the rows are that art too (its top and bottom at the
	-- size the song panels have it, the middle left out, so it isn't squashed), tinted as osu! tints
	-- the difficulties: the picked one as it is, the others dimmer; the skin's text colours on it
	local art = look == "osu" and TW.has("songpanel")
	local PW, PH = M(760), M(84) -- (a song panel, as MusicWheelItem Song NormalPart.lua draws it)
	local activeText = TW.colour("SongSelectActiveText", color("#FFFFFF"))
	local inactiveText = TW.colour("SongSelectInactiveText", color("#FFFFFF"))
	local fade = spec.fade or function() return 1 end

	local function artBand(name, top)
		if not art then return Def.Actor { Name = name } end
		return Def.Sprite {
			Name = name,
			Texture = TW.img("songpanel"),
			InitCommand = function(self)
				self:align(0, top and 0 or 1):visible(false)
				-- (the texture's corners, a half texel in as TW.inset does it)
				pcall(function()
					local tex = self:GetTexture()
					local l, t, r, b = tex:GetTextureCoordRect(0)
					local tw, th = tex:GetTextureWidth(), tex:GetTextureHeight()
					local dx, dy = math.min(0.5 / tw, (r - l) / 4), math.min(0.5 / th, (b - t) / 4)
					self.rect = { l + dx, t + dy, r - dx, b - dy }
				end)
			end,
			-- the band of the art for a row h high: as much of the art's top (or bottom) as h / 2 is of a
			-- song panel's height
			BandCommand = function(self, p)
				local q = self.rect
				if not q then self:visible(false) return end
				local f = math.min(0.5, (p.h / 2) / PH)
				if top then self:customtexturerect(q[1], q[2], q[3], q[2] + (q[4] - q[2]) * f)
				else self:customtexturerect(q[1], q[4] - (q[4] - q[2]) * f, q[3], q[4]) end
				self:zoomto(PW, p.h / 2):xy(0, top and 0 or p.h):visible(true):diffuse(p.tint)
			end,
		}
	end

	local function rowActor(i)
		return Def.ActorFrame {
			Name = "Row" .. i,
			InitCommand = function(self) rows[i] = self; self:visible(false) end,
			Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0):visible(look == "quaver") end },
			Def.Quad { Name = "Edge", InitCommand = function(self) self:align(0, 0):visible(look == "quaver") end },
			-- (under the skin's art: VSRG Hub's see-through grey, as under the song panels)
			Def.Quad { Name = "Under", InitCommand = function(self) self:align(0, 0):visible(false) end },
			artBand("ArtTop", true),
			artBand("ArtBottom", false),
			-- (the osu! look without panel art: osu!'s difficulty panels, blue, the selected one white)
			TW.box { w = M(10), h = M(10), r = M(8), init = function(self) self:visible(false) end } .. { Name = "Box" },
			TW.box { w = M(38), h = M(20), r = M(10), ax = 0.5, ay = 0.5 } .. { Name = "Chip" },
			TW.text(M(12) * fs, true, function(self) self:align(0.5, 0.5):shadowlength(0) end) .. { Name = "Keys" },
			TW.text(M(16) * fs, true, function(self) self:align(0, 0.5) end) .. { Name = "Name" },
			TW.text(M(12) * fs, false, function(self) self:align(0, 0.5) end) .. { Name = "Sub" },
			TW.text(M(17) * fs, true, function(self) self:align(1, 0.5) end) .. { Name = "Msd" },
			TW.text(M(11) * fs, false, function(self) self:align(1, 0.5) end) .. { Name = "MsdLabel" },
			TW.text(M(14) * fs, true, function(self) self:align(1, 0.5) end) .. { Name = "Grade" },
			TW.text(M(11) * fs, false, function(self) self:align(1, 0.5) end) .. { Name = "Best" },
			UIElements.QuadButton(1, 1) .. {
				Name = "Click",
				InitCommand = function(self) self:align(0, 0):diffusealpha(0) end,
				MouseDownCommand = function(self, params)
					if params.event ~= "DeviceButton_left mouse button" or not self.index then return end
					local song, _, cur = current()
					if not song then return end
					if self.index == cur then
						local s = onSelect()
						if s then s:SelectCurrent() end
					else
						TW.pickDiff(self.index)
					end
				end,
			},
		}
	end

	-- a row's look for chart st (the i-th; cur is the picked one). sx, sy: where the rows' frame will
	-- be on screen once the list has moved, for how much room the row has on the right.
	local function fill(row, st, i, cur, sx, sy)
		local c = row:GetChildren()
		local on = i == cur
		local h = RH
		local m = TW.msd(st)
		local col = spec.msdColour(m)
		local x0 = on and 0 or spec.indent * 0.5
		row.tx = x0
		-- the room on screen: to the screen's edge, or to the left of the cookie
		local y0 = sy + (i - 1) * ST
		local edge = SCREEN_WIDTH + M(4)
		local cl = spec.clear and spec.clear(y0, y0 + h) or nil
		local rw = edge - sx - x0 -- (the row's width on screen)
		local right = math.min(rw, (cl or edge) - sx - x0) -- (the text's right edge)
		if cl then right = right - M(4) end
		c.Bg:visible(look == "quaver")
		c.Edge:visible(look == "quaver")
		c.Box:visible(look ~= "quaver" and not art)
		c.Under:visible(art)
		if look == "quaver" then
			c.Bg:zoomto(rw, h):diffuse(on and TW.rgb(16, 11, 34) or color("#000000")):diffusealpha(on and 0.92 or 0.7)
			c.Edge:zoomto(math.max(2, M(4)), h):diffuse(on and QV.cyan or col):diffusealpha(on and 1 or 0.7)
		elseif look == "lazer" then
			-- (osu!lazer: dark panels, the selected one lighter with the chart's colour along it)
			TW.setBox(c.Box, { w = rw, h = h - M(2), r = M(8), shear = 0,
				left = on and TW.mix(col, LZ.bg3, 0.55) or LZ.a(LZ.bg4, 0.92), right = on and LZ.a(LZ.bg2, 0.96) or LZ.a(LZ.bg5, 0.9) })
		elseif art then
			c.Under:xy(M(2), M(2)):zoomto(PW - M(2), h - M(6))
			TW.glassify(c.Under, on and "lift" or "panel")
			c.Under:diffuserightedge(on and { 0.5, 0.5, 0.55, 0.3 } or { 0.05, 0.05, 0.07, 0.4 })
			local band = { h = h - M(2), tint = on and color("#FFFFFF") or TW.rgb(165, 165, 178) }
			c.ArtTop:playcommand("Band", band)
			c.ArtBottom:playcommand("Band", band)
		else
			TW.setBox(c.Box, { w = rw, h = h - M(2), col = on and { 0.97, 0.97, 0.99, 0.96 } or { 0.24, 0.5, 0.86, 0.86 },
				col2 = on and { 0.84, 0.85, 0.9, 0.96 } or { 0.14, 0.33, 0.66, 0.86 } })
		end
		if not art then c.ArtTop:visible(false); c.ArtBottom:visible(false) end
		-- the chart's mark: a chip in its MSD colour with the key count
		local cx = M(14) + M(20)
		local ch = h - M(2)
		c.Chip:xy(cx, ch / 2)
		TW.setBox(c.Chip, { w = M(38), h = math.min(M(22), h - M(8)), r = math.min(M(11), (h - M(8)) / 2), col = col })
		c.Keys:xy(cx, ch / 2):settext(TW.keys(st) .. "K"):diffuse(TW.rgb(20, 20, 26))
		local dark = on and look == "osu" and not art
		local txt, dim
		if art then
			txt = on and activeText or inactiveText
			dim = TW.mix(txt, { 0.5, 0.5, 0.55, 1 }, 0.3)
		else
			txt = dark and TW.rgb(34, 30, 44) or color("#FFFFFF")
			dim = dark and TW.rgb(80, 80, 96) or TW.rgb(190, 200, 220)
		end
		local tx = cx + M(30)
		local name = TW.diffName(st)
		if look == "quaver" then name = name:upper() end
		local block = M(150) -- (the MSD and your best, on the right)
		local textW = math.max(M(30), right - tx - block - M(12))
		c.Name:xy(tx, ch * 0.33):settext(name):diffuse((look == "quaver") and (on and color("#FFFFFF") or TW.rgb(215, 215, 222)) or txt)
			:maxwidth(textW / c.Name:GetZoom())
		local sub = string.format("%s  ·  %s notes", fmtLen(st:GetLengthSeconds()), fmtInt(notes(st)))
		local skill = topSkill(st)
		if skill ~= "" then sub = sub .. "  ·  " .. skill end
		c.Sub:xy(tx, ch * 0.72):settext(sub):diffuse(look == "quaver" and TW.rgb(170, 170, 182) or dim):maxwidth(textW / c.Sub:GetZoom())
		-- MSD at the rate, and your best on the chart
		local rx = right - M(16)
		c.Msd:xy(rx, ch * 0.36):settextf("%.2f", m):diffuse(dark and TW.mix(col, { 0, 0, 0, 1 }, 0.25) or col)
		c.MsdLabel:xy(rx, ch * 0.8):settext(look == "quaver" and "DIFFICULTY" or "MSD"):diffuse(look == "quaver" and TW.rgb(150, 150, 160) or dim)
		local b = bestOn(st)
		local gx = rx - M(78)
		if b then
			local text, gcol = spec.gradeText(b.grade, b)
			c.Grade:visible(true):xy(gx, ch * 0.38):settext(text):diffuse(gcol)
			c.Best:visible(true):xy(gx, ch * 0.76):settextf("%.2f%%%s", b.pct or b.wife, math.abs(b.rate - 1) > 0.001 and string.format(" %.2gx", b.rate) or "")
				:diffuse(look == "quaver" and TW.rgb(170, 170, 182) or dim)
		else
			c.Grade:visible(false)
			c.Best:visible(false)
		end
		c.Click:zoomto(rw, h)
		c.Click.index = i
	end

	-- the list's spot for the song's charts: the picked one in the middle of the list
	local function lift(cur) return spec.y() + M(6) + (cur - 1) * ST + RH / 2 - spec.centre() end

	local function rebuild(self)
		local song, list, cur = current()
		if not song then
			gapTarget, liftTarget = 0, 0
			return
		end
		local n = #list
		local fresh = song ~= shownSong
		shownSong = song
		gapTarget = n * ST + M(8)
		liftTarget = lift(cur)
		-- the charts around the picked one (rows further away are off the screen)
		local first = math.max(1, math.min(cur - math.floor(ACTORS / 2), n - ACTORS + 1))
		local last = math.min(n, first + ACTORS - 1)
		local sx, sy = spec.x() + spec.indent, spec.y() + M(6) - liftTarget
		local used = {}
		for idx = first, last do
			local slot = (idx - 1) % ACTORS + 1
			local row = rows[slot]
			used[slot] = true
			fill(row, list[idx], idx, cur, sx, sy)
			-- (a row showing another chart than before starts at its place; one that stays slides there)
			if fresh or row.idx ~= idx or row.cx == nil then row.cx = row.tx end
			row.idx = idx
			row:visible(true):y((idx - 1) * ST)
		end
		for slot = 1, ACTORS do
			if not used[slot] then rows[slot].idx = nil; rows[slot]:visible(false) end
		end
	end

	local frame = Def.ActorFrame {
		Name = "TWDiffRows",
		InitCommand = function(self)
			TW.diffGap, TW.diffLift = 0, 0
			TW.wheelCurve, TW.diffMinCharts, TW.diffOpenSong = nil, nil, nil
			TW.wheelFade = spec.fade
			TW.wheelCentre = spec.centre()
			TW.everyFrame(self)
			-- (spec.browse: the list scrolls without picking, as osu! stable's and Quaver's: 29 VSRG
			-- Hub stable pick.lua; the rows stay closed while you browse)
			if spec.browse then
				TW.browsing, TW.pickY = false, 0
				TW.pick = { song = GAMESTATE:GetCurrentSong(), steps = GAMESTATE:GetCurrentSteps() }
				TW.pickMusicReset()
			end
			self:SetUpdateFunction(function(s, dt)
				if spec.browse then
					TW.syncStep()
					TW.pickMusicStep()
					local w = onSelect() and onSelect():GetMusicWheel()
					if w and w:IsSettled() then
						s.restAt = s.restAt or GetTimeSinceStart()
						if TW.browsing and GetTimeSinceStart() - s.restAt > 0.2 then TW.restorePick() end
						-- (a pack opened or closed from its name leaves Etterna's current song as it
						-- was, which while browsing was the picked one: the list is on a pack's name
						-- now, so nothing is picked and no song's rows show over the packs)
						if not TW.browsing and not TW.syncPending and GAMESTATE:GetCurrentSong() then
							local kind
							pcall(function() kind = w:GetSelectedType() end)
							if kind == "WheelItemDataType_Section" then
								TW.pick = {}
								GAMESTATE:SetCurrentSong(nil)
							end
						end
					else
						s.restAt = nil
					end
				end
				-- what to show: rebuilt when the song, the chart, the rate or your scores change
				local song, list, cur = current()
				if spec.browse and TW.browsing then song = nil end
				local key = ""
				if song then
					local n = 0
					pcall(function() n = SCOREMAN:GetTotalNumberOfScores() end)
					key = tostring(song) .. "|" .. tostring(list[cur]) .. "|" .. #list .. "|" .. getCurRateValue() .. "|" .. n
				end
				-- moved on past the last chart: the next song starts at its first one (its last going up)
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
					rebuild(s)
				end
				-- the room under the song and the list's spot glide to where they go
				local k = math.min(1, (dt or 0.016) * 14)
				local g, l = TW.diffGap or 0, TW.diffLift or 0
				g = g + (gapTarget - g) * k
				l = l + (liftTarget - l) * k
				if math.abs(gapTarget - g) < 0.3 then g = gapTarget end
				if math.abs(liftTarget - l) < 0.3 then l = liftTarget end
				TW.diffGap, TW.diffLift = g, l
				-- the rows show as the room opens (and go as soon as the list moves)
				local open = (gapTarget > 0 and song) and math.max(0, math.min(1, g / gapTarget)) or 0
				local f = s:GetChild("Rows")
				f:visible(open > 0.01)
				if open <= 0.01 then return end
				local fx, fy = spec.x() + spec.indent, spec.y() + M(6) - l
				f:xy(fx, fy):diffusealpha(open)
				-- each row: sliding to its place (the picked one sticks out), faded under the bars
				for slot = 1, ACTORS do
					local row = rows[slot]
					if row.idx then
						row.cx = row.cx + (row.tx - row.cx) * k
						if math.abs(row.tx - row.cx) < 0.3 then row.cx = row.tx end
						local a = fade(fy + (row.idx - 1) * ST + RH / 2)
						row:x(row.cx):diffusealpha(math.max(0, math.min(1, a))):visible(a > 0.01)
					end
				end
			end)
		end,
		OffCommand = function() TW.diffGap, TW.diffLift, TW.wheelFade = 0, 0, nil; if spec.browse then TW.browsing, TW.pickY = false, 0 end end,
		-- (browsing: the list moved, the picked song stays picked)
		CurrentSongChangedMessageCommand = function() if spec.browse then TW.keepPick() end end,
		CurrentStepsChangedMessageCommand = function() if spec.browse then TW.keepPick() end end,
		PlayingSampleMusicMessageCommand = function() if spec.browse then TW.pickMusicPlaying() end end,
		FilterResultsMessageCommand = function() if spec.browse then TW.browsing = false end end,
		TWSortChangedMessageCommand = function() if spec.browse then TW.browsing = false end end,
	}
	local f = Def.ActorFrame { Name = "Rows" }
	for i = 1, ACTORS do f[#f + 1] = rowActor(i) end
	frame[#frame + 1] = f
	return frame
end
