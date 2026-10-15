-- The hit-offset plot on the results screen, with what Etterna's Til Death shows around it: every
-- hit across the whole chart by time (early below, late above), misses as faint red lines through
-- the whole height, the judge windows, mean / standard deviation / largest hit / combo breaks per hand,
-- a judge switcher that rescores Wife% (J4 to Justice) and a column filter, so you can see which
-- finger missed where. Hovering the plot shows the time and the score up to that point.
-- Both results screens use it; colours and fonts come from the theme that draws it.

local judgeKeys = { "TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3", "TapNoteScore_W4", "TapNoteScore_W5", "TapNoteScore_Miss" }
local windows = { 22.5, 45, 90, 135, 180 }

local function scaleFor(j) return (ms and ms.JudgeScalers and ms.JudgeScalers[j]) or ({ [4] = 1, [5] = 0.84, [6] = 0.66, [7] = 0.5, [8] = 0.33, [9] = 0.2 })[j] or 1 end
local function judgeOf(o, scale)
	local a = math.abs(o)
	if a > 500 then return 6 end
	for i, w in ipairs(windows) do if a <= w * scale then return i end end
	return 6
end
-- a clickable area centred on x, y
local function hit(w, h, x, y, fn, name)
	return TW.button(w, h, fn) .. { Name = name, InitCommand = function(self) self:xy(x, y):zoomto(w, h):diffusealpha(0) end }
end
local function fmtTime(s)
	s = math.max(0, s)
	return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

-- Which hand plays a column (0-based) of a cols-key game: "L", "R" or "M" (a middle column on its
-- own). In 7K the middle column goes to the hand whose thumb plays it: the right thumb by default
-- (left hand = columns 1-3, right hand = 4-7), the left thumb with "7K thumb" set to Left (left hand
-- = 1-4, right hand = 5-7). Other odd key counts keep their middle column apart.
function TW.thumb7()
	return (TW.settings and TW.settings.thumb7 == "left") and "left" or "right"
end
function TW.hasMiddle(cols) return cols % 2 == 1 and cols ~= 7 end
function TW.handOf(c, cols)
	local middle = (cols - 1) / 2
	if c < middle then return "L" end
	if c > middle then return "R" end
	if cols == 7 then return TW.thumb7() == "left" and "L" or "R" end
	return "M"
end

-- p: x, y, w, h (box), text(px, bold, init), colour(judgeIndex 1..6) -> color, accent, bg
function TW.offsetPlot(p)
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
	local hs = pss:GetHighScore()
	local steps = GAMESTATE:GetCurrentSteps()
	local td = steps and steps:GetTimingData()
	local cols = steps and steps:GetNumColumns() or 4
	local rate = getCurRateValue and getCurRateValue() or 1

	-- data: from the stage stats, or the score's replay when those are empty
	local offs, rows, tracks, types = {}, {}, {}, {}
	pcall(function()
		offs = pss:GetOffsetVector() or {}
		rows = pss:GetNoteRowVector() or {}
		tracks = pss:GetTrackVector() or {}
		types = pss:GetTapNoteTypeVector() or {}
	end)
	if (#offs == 0 or #tracks == 0) and hs then
		pcall(function()
			local r = hs:GetReplay()
			r:LoadAllData()
			offs, rows, tracks, types = r:GetOffsetVector() or {}, r:GetNoteRowVector() or {}, r:GetTrackVector() or {}, r:GetTapNoteTypeVector() or {}
		end)
	end
	-- keep taps, hold heads and lifts (not mines), with their song time
	local H = {}
	for i, o in ipairs(offs) do
		local ty = types[i]
		if ty == nil or ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then
			local tm = (td and rows[i]) and td:GetElapsedTimeFromNoteRow(rows[i]) or 0
			H[#H + 1] = { o = o, t = tm, c = tracks[i] }
		end
	end
	local last = steps and steps:GetLastSecond() or 1
	if last <= 0 then last = 1 end

	local played = 1
	pcall(function() played = hs:GetJudgeScale() end)
	if not played or played <= 0 then played = 1 end
	local state = { scale = played, judge = nil, filter = 0 } -- filter: 0 all, -1 left hand, -2 right hand, n column

	local X, Y, W, Hh = p.x, p.y, p.w, p.h
	local s = Hh / 300 -- unit
	local headH, footH = 34 * s, 40 * s
	local PX, PY, PW, PH = X + 44 * s, Y + headH, W - 52 * s, Hh - headH - footH
	local CY = PY + PH / 2
	local function maxMs() return math.max(180, 180 * state.scale) end
	local function fy(o) return CY - math.max(-1, math.min(1, o / maxMs())) * PH / 2 end
	local function fx(t) return PX + math.max(0, math.min(1, t / last)) * PW end
	local function inFilter(c)
		if state.filter == 0 or c == nil then return true end
		if state.filter == -1 then return TW.handOf(c, cols) == "L" end
		if state.filter == -2 then return TW.handOf(c, cols) == "R" end
		return c == state.filter - 1
	end

	local function stats(filter)
		local n, sum, sq, largest, miss, cbL, cbR, cbM = 0, 0, 0, 0, 0, 0, 0, 0
		for _, h in ipairs(H) do
			if filter == nil or filter(h.c) then
				if math.abs(h.o) > 500 then
					miss = miss + 1
				else
					n = n + 1; sum = sum + h.o; sq = sq + h.o * h.o
					if math.abs(h.o) > math.abs(largest) then largest = h.o end
				end
				if math.abs(h.o) > 90 * state.scale and h.c then
					local hand = TW.handOf(h.c, cols)
					if hand == "L" then cbL = cbL + 1 elseif hand == "R" then cbR = cbR + 1 else cbM = cbM + 1 end
				end
			end
		end
		local mean = n > 0 and sum / n or 0
		local sd = n > 1 and math.sqrt(math.max(0, (sq - n * mean * mean) / (n - 1))) or 0
		return { mean = mean, sd = sd, largest = largest, miss = miss, cb = cbL + cbR + cbM, cbL = cbL, cbR = cbR, cbM = cbM, n = n }
	end

	local function rescored()
		if not state.judge then return pss:GetWifeScore() * 100 end
		local v
		pcall(function()
			local dvt = {}
			for _, h in ipairs(H) do dvt[#dvt + 1] = h.o end
			local taps = 0
			for _, k in ipairs(judgeKeys) do taps = taps + pss:GetTapNoteScores(k) end
			-- (holds let go or missed, mines hit: as judged, so a play left early isn't charged for
			-- the holds and mines it never reached)
			local missed = pss:GetHoldNoteScores("HoldNoteScore_LetGo") + pss:GetHoldNoteScores("HoldNoteScore_MissedHold")
			v = getRescoredWife3Judge(3, state.judge, {
				dvt = dvt, holdsMissed = missed, minesHit = pss:GetTapNoteScores("TapNoteScore_HitMine"), totalTaps = taps
			})
		end)
		return v or pss:GetWifeScore() * 100
	end

	local function judgeLabel()
		if not state.judge then
			local j
			for k = 4, 9 do if math.abs(scaleFor(k) - played) < 0.005 then j = k end end
			if j then return (j == 9 and "Justice" or ("J" .. j)) .. " (played)" end
			return string.format("x%.2f (played)", played)
		end
		return state.judge == 9 and "Justice" or ("J" .. state.judge)
	end
	local function setJudge(d)
		-- the played judge first, then J4 to Justice without the one that was played (it would show the same)
		local order = { false }
		for k = 4, 9 do if math.abs(scaleFor(k) - played) >= 0.005 then order[#order + 1] = k end end
		local idx = 1
		for i, v in ipairs(order) do if (v or nil) == state.judge then idx = i end end
		idx = (idx - 1 + d) % #order + 1
		state.judge = order[idx] or nil
		state.scale = state.judge and scaleFor(state.judge) or played
		MESSAGEMAN:Broadcast("TWPlotChanged")
	end
	local function setFilter(f)
		state.filter = (state.filter == f and f ~= 0) and 0 or f
		MESSAGEMAN:Broadcast("TWPlotChanged")
	end

	local text, colour = p.text, p.colour
	local accent = p.accent or color("#FFFFFF")
	local f = Def.ActorFrame {
		OnCommand = function(self)
			-- number keys pick a column, 0 / ` shows every column, H steps through the hands,
			-- Left/Right (with Ctrl) change the judge, like Etterna's results screen
			SCREENMAN:GetTopScreen():AddInputCallback(function(event)
				if event.type ~= "InputEventType_FirstPress" then return false end
				local b = event.DeviceInput.button
				local n = tonumber(b:match("^DeviceButton_(%d)$") or "")
				if n then
					if n == 0 then setFilter(0) elseif n <= cols then setFilter(n) end
					return false
				end
				if b == "DeviceButton_`" then setFilter(0) return false end
				if b == "DeviceButton_h" then
					state.filter = state.filter == 0 and -1 or (state.filter == -1 and -2 or 0)
					MESSAGEMAN:Broadcast("TWPlotChanged")
				end
				return false
			end)
		end,
		CodeMessageCommand = function(self, params)
			if params.Name == "PrevJudge" then setJudge(-1) elseif params.Name == "NextJudge" then setJudge(1) end
		end,
	}
	-- background
	if p.bg or TW.isQuaver or not TW.box then
		f[#f + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(X, Y):zoomto(W, Hh)
			if p.bg then self:diffuse(p.bg) else TW.glassify(self, "panel", { 0, 0, 0, 0.6 }) end end }
	else
		-- (osu!: a rounded dark card with a soft shadow)
		f[#f + 1] = TW.shadow { w = W, h = Hh, spread = 12 * s, alpha = 0.5, drop = 3 * s, init = function(self) self:xy(X, Y) end }
		f[#f + 1] = TW.box { w = W, h = Hh, r = 10 * s, col = { 0.1, 0.1, 0.14, 0.86 }, col2 = { 0.06, 0.06, 0.09, 0.86 }, init = function(self) self:xy(X, Y) end }
	end
	f[#f + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(PX, PY):zoomto(PW, PH):diffuse({ 0, 0, 0, 0.25 }) end }

	-- header: title, judge switcher with the rescored Wife%, column filter
	f[#f + 1] = text(13 * s, true, function(self) self:align(0, 0.5):xy(X + 8 * s, Y + headH / 2):settext("Hit offsets"):diffuse(accent) end)
	local jx = X + 120 * s
	f[#f + 1] = text(12 * s, true, function(self) self:align(0.5, 0.5):xy(jx, Y + headH / 2):settext("<") end)
	f[#f + 1] = hit(18 * s, headH, jx, Y + headH / 2, function() setJudge(-1) end)
	f[#f + 1] = text(12 * s, true, function(self) self:align(0, 0.5):xy(jx + 12 * s, Y + headH / 2) end) .. {
		OnCommand = function(self) self:playcommand("Set") end, TWPlotChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			self:settextf("%s  %.2f%%", judgeLabel(), rescored())
			self:diffuse(state.judge and color("#FFDD55") or color("#FFFFFF"))
			local nx = self:GetParent():GetChild("JNext")
			if nx then nx:x(self:GetX() + self:GetZoomedWidth() + 10 * s) end
			local nb = self:GetParent():GetChild("JNextB")
			if nb then nb:x(self:GetX() + self:GetZoomedWidth() + 10 * s) end
		end
	}
	f[#f + 1] = text(12 * s, true, function(self) self:align(0.5, 0.5):xy(jx + 200 * s, Y + headH / 2):settext(">") end) .. { Name = "JNext" }
	f[#f + 1] = hit(18 * s, headH, jx + 200 * s, Y + headH / 2, function() setJudge(1) end, "JNextB")

	-- filter chips, right aligned: All, L, R, 1..n; each column chip shows its miss count
	local chips = { { 0, "All" }, { -1, "L" }, { -2, "R" } }
	for c = 1, cols do chips[#chips + 1] = { c, tostring(c) } end
	local cw = math.min(30 * s, (W * 0.5) / #chips)
	local cx0 = X + W - 8 * s - cw * #chips
	local missBy = {}
	for c = 1, cols do missBy[c] = stats(function(cc) return cc == c - 1 end) end
	for i, ch in ipairs(chips) do
		local cx = cx0 + (i - 0.5) * cw
		f[#f + 1] = Def.Quad {
			InitCommand = function(self) self:xy(cx, Y + headH / 2):zoomto(cw - 3 * s, headH - 8 * s) end,
			OnCommand = function(self) self:playcommand("Set") end, TWPlotChangedMessageCommand = function(self) self:playcommand("Set") end,
			SetCommand = function(self)
				local on = state.filter == ch[1]
				self:diffuse(on and accent or color("1,1,1,0.12"))
			end
		}
		f[#f + 1] = text(11 * s, true, function(self)
			self:align(0.5, 0.5):xy(cx, Y + headH / 2 - (ch[1] > 0 and 4 * s or 0)):settext(ch[2])
		end) .. {
			OnCommand = function(self) self:playcommand("Set") end, TWPlotChangedMessageCommand = function(self) self:playcommand("Set") end,
			SetCommand = function(self) self:diffuse(state.filter == ch[1] and color("#000000") or color("#FFFFFF")) end
		}
		if ch[1] > 0 then
			local m = missBy[ch[1]]
			f[#f + 1] = text(8 * s, false, function(self)
				-- (the column's combo breaks: just the number, so the chips' labels don't run together)
				self:align(0.5, 0.5):xy(cx, Y + headH / 2 + 7 * s):settext(m.cb > 0 and tostring(m.cb) or "-")
				self:maxwidth((cw - 5 * s) / self:GetZoom())
				self:diffuse(m.cb > 0 and color("#FF6060") or color("0.7,0.7,0.7,1")):shadowlength(0)
			end)
		end
		f[#f + 1] = hit(cw - 3 * s, headH - 8 * s, cx, Y + headH / 2, function() setFilter(ch[1]) end)
	end

	-- judge window lines, centre line, ms labels
	f[#f + 1] = Def.ActorMultiVertex {
		OnCommand = function(self) self:playcommand("Set") end, TWPlotChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			local v = {}
			local function line(y, c)
				v[#v + 1] = { { PX, y - 0.5, 0 }, c }; v[#v + 1] = { { PX + PW, y - 0.5, 0 }, c }
				v[#v + 1] = { { PX + PW, y + 0.5, 0 }, c }; v[#v + 1] = { { PX, y + 0.5, 0 }, c }
			end
			line(CY, { 1, 1, 1, 0.5 })
			for i, w in ipairs(windows) do
				local c = colour(i)
				local cc = { c[1], c[2], c[3], 0.3 }
				line(fy(w * state.scale), cc); line(fy(-w * state.scale), cc)
			end
			self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(v)
		end
	}
	for _, sign in ipairs({ 1, 0, -1 }) do
		f[#f + 1] = text(9 * s, false, function(self) self:align(1, 0.5):xy(PX - 5 * s, CY - sign * PH / 2 + sign * 5 * s):diffuse(color("0.8,0.8,0.8,1")) end) .. {
			OnCommand = function(self) self:playcommand("Set") end, TWPlotChangedMessageCommand = function(self) self:playcommand("Set") end,
			SetCommand = function(self) self:settext(sign == 0 and "0" or string.format("%s%dms", sign > 0 and "+" or "-", maxMs())) end
		}
	end
	f[#f + 1] = text(8 * s, false, function(self) self:align(0, 0):xy(PX + 3 * s, PY + 2 * s):settext("late"):diffuse(color("0.8,0.8,0.8,0.8")) end)
	f[#f + 1] = text(8 * s, false, function(self) self:align(0, 1):xy(PX + 3 * s, PY + PH - 2 * s):settext("early"):diffuse(color("0.8,0.8,0.8,0.8")) end)

	-- the hits
	f[#f + 1] = Def.ActorMultiVertex {
		OnCommand = function(self) self:playcommand("Set") end, TWPlotChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			local v, dots = {}, {}
			local d = math.max(1, 1.4 * s)
			for _, h in ipairs(H) do
				local on = inFilter(h.c)
				local x = fx(h.t)
				local j = judgeOf(h.o, state.scale)
				if j == 6 then
					-- a miss: a thin, faint line through the whole height (like Etterna's, so a run
					-- of misses doesn't paint the graph red) with a short solid tick at each edge
					local c = on and { 1, 0.25, 0.25, 0.16 } or { 1, 0.25, 0.25, 0.04 }
					local hw = 0.5
					v[#v + 1] = { { x - hw, PY, 0 }, c }; v[#v + 1] = { { x + hw, PY, 0 }, c }
					v[#v + 1] = { { x + hw, PY + PH, 0 }, c }; v[#v + 1] = { { x - hw, PY + PH, 0 }, c }
					if on then
						local tc, tl, tw = { 1, 0.3, 0.3, 0.85 }, 4 * s, math.max(0.75, 0.6 * s)
						for _, y0 in ipairs({ PY, PY + PH - tl }) do
							dots[#dots + 1] = { { x - tw, y0, 0 }, tc }; dots[#dots + 1] = { { x + tw, y0, 0 }, tc }
							dots[#dots + 1] = { { x + tw, y0 + tl, 0 }, tc }; dots[#dots + 1] = { { x - tw, y0 + tl, 0 }, tc }
						end
					end
				else
					local base = colour(j)
					local c = { base[1], base[2], base[3], on and 1 or 0.12 }
					local y = fy(h.o)
					dots[#dots + 1] = { { x - d, y - d, 0 }, c }; dots[#dots + 1] = { { x + d, y - d, 0 }, c }
					dots[#dots + 1] = { { x + d, y + d, 0 }, c }; dots[#dots + 1] = { { x - d, y + d, 0 }, c }
				end
			end
			-- (the hits are drawn over the miss lines)
			for _, q in ipairs(dots) do v[#v + 1] = q end
			if #v > 0 then self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(v) else self:SetVertices({}) end
		end
	}

	-- pauses (with pausing on): a green line where each one was, like Quaver
	local pauses = TWPausesForResults and TWPausesForResults()
	if pauses then
		f[#f + 1] = Def.ActorMultiVertex {
			OnCommand = function(self)
				local v, c = {}, { 0.35, 1, 0.45, 0.9 }
				local hw = math.max(0.75, 0.8 * s)
				for _, t in ipairs(pauses) do
					local x = fx(t)
					v[#v + 1] = { { x - hw, PY, 0 }, c }; v[#v + 1] = { { x + hw, PY, 0 }, c }
					v[#v + 1] = { { x + hw, PY + PH, 0 }, c }; v[#v + 1] = { { x - hw, PY + PH, 0 }, c }
				end
				self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(v)
			end
		}
		f[#f + 1] = text(10 * s, true, function(self)
			self:align(1, 0):xy(PX + PW - 4 * s, PY + 2 * s):diffuse(color("#55FF77"))
				:settext("Pauses: " .. #pauses)
		end)
	end

	-- footer: stats for what the filter shows
	f[#f + 1] = text(11 * s, true, function(self) self:align(0, 0.5):xy(X + 8 * s, Y + Hh - footH / 2) end) .. {
		OnCommand = function(self) self:playcommand("Set") end, TWPlotChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			local st = stats(function(c) return inFilter(c) end)
			local what = state.filter == 0 and "All" or (state.filter == -1 and "Left hand" or (state.filter == -2 and "Right hand" or ("Column " .. state.filter)))
			local cb
			if state.filter == 0 then
				cb = string.format("CB  L %d  R %d", st.cbL, st.cbR) .. (TW.hasMiddle(cols) and string.format("  M %d", st.cbM) or "")
			else
				cb = string.format("CB %d", st.cb)
			end
			self:settextf("%s:   Mean %.2fms   SD %.2fms   Largest %.2fms   Misses %d   %s", what, st.mean, st.sd, st.largest, st.miss, cb)
			self:maxwidth((W - 16 * s) / self:GetZoom())
		end
	}
	f[#f + 1] = text(8 * s, false, function(self)
		self:align(1, 0.5):xy(X + W - 8 * s, Y + Hh - 6 * s):diffuse(color("0.7,0.7,0.7,1")):shadowlength(0)
		self:settext("click a column or press 1-" .. cols .. " (0 = all, H = hands)")
	end)

	-- hover: a bar and what you had up to there
	local hover = Def.ActorFrame { Name = "Hover", InitCommand = function(self) self:visible(false) end,
		Def.Quad { Name = "Bar", InitCommand = function(self) self:align(0.5, 0):y(PY):zoomto(1, PH):diffuse(color("1,1,1,0.6")) end },
		Def.Quad { Name = "BG", InitCommand = function(self) TW.glassify(self:align(0, 0), "float", { 0, 0, 0, 0.85 }) end },
		text(10 * s, false, function(self) self:align(0, 0):shadowlength(0) end) .. { Name = "T" },
	}
	f[#f + 1] = hover
	f[#f + 1] = Def.Actor {
		OnCommand = function(self)
			local box = self:GetParent()
			TW.everyFrame(box)
			box:SetUpdateFunction(function()
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				local hv = box:GetChild("Hover")
				if mx < PX or mx > PX + PW or my < PY or my > PY + PH then hv:visible(false) return end
				hv:visible(true)
				local t = (mx - PX) / PW * last
				local cnt = { 0, 0, 0, 0, 0, 0 }
				for _, h in ipairs(H) do
					if h.t <= t and inFilter(h.c) then local j = judgeOf(h.o, state.scale); cnt[j] = cnt[j] + 1 end
				end
				local wife
				if state.judge == nil then
					pcall(function()
						local row = td:GetBeatFromElapsedTime(t) * 48
						wife = REPLAYS:GetActiveReplay():GetReplaySnapshotForNoterow(row):GetWifePercent() * 100
					end)
					if wife and (wife ~= wife or wife == math.huge or wife == -math.huge) then wife = nil end
				end
				local tx = hv:GetChild("T")
				tx:settextf("%s%s\nMarv %d  Perf %d  Great %d\nGood %d  Bad %d  Miss %d",
					fmtTime(t / rate), wife and string.format("   %.2f%%", wife) or "", cnt[1], cnt[2], cnt[3], cnt[4], cnt[5], cnt[6])
				local bw, bh = tx:GetZoomedWidth() + 8 * s, tx:GetZoomedHeight() + 6 * s
				local bx = mx + 8 * s
				if bx + bw > X + W then bx = mx - 8 * s - bw end
				hv:GetChild("Bar"):x(mx)
				hv:GetChild("BG"):xy(bx, PY + 2 * s):zoomto(bw, bh)
				tx:xy(bx + 4 * s, PY + 5 * s)
			end)
		end
	}
	return f
end

-- What Til' Death's results show besides the plot, for the osu! and Quaver looks: the MA and PA
-- ratios, the clear type, holds and mines, the score's skillset ratings and the judge it was played
-- on. Returns rows { label, value, highlight }.
local function ratio(a, b)
	if b <= 0 then return a > 0 and (a .. ":0") or "-" end
	return string.format("%.2f:1", a / b)
end
function TW.clearType(c)
	local cb = c.W4 + c.W5 + c.Miss
	-- (nothing judged: a pausable play left before its first key press)
	if cb + c.W1 + c.W2 + c.W3 == 0 then return "-" end
	if cb == 0 then
		if c.W3 == 0 then
			if c.W2 == 0 then return "MFC" end
			if c.W2 == 1 then return "WF" end
			if c.W2 < 10 then return "SDP" end
			return "PFC"
		end
		if c.W3 == 1 then return "BF" end
		if c.W3 < 10 then return "SDG" end
		return "FC"
	end
	if cb == 1 then return "MF" end
	if cb < 10 then return "SDCB" end
	return "Clear"
end
function TW.evalFacts()
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
	local hs = pss:GetHighScore()
	local c = {}
	for _, k in ipairs(judgeKeys) do c[k:gsub("TapNoteScore_", "")] = pss:GetTapNoteScores(k) end
	local failed = false
	pcall(function() failed = pss:GetFailed() end)
	-- (a past score opened from the ranking: its grade says whether it failed)
	pcall(function() if hs:GetWifeGrade() == "Grade_Failed" then failed = true end end)
	local rows = {
		{ "MA ratio", ratio(c.W1, c.W2), true },
		{ "PA ratio", ratio(c.W2, c.W3), true },
		{ "Result", failed and "Failed" or TW.clearType(c) },
		{ "Max combo", tostring(pss:MaxCombo()) .. "x" },
	}
	pcall(function()
		local poss, act = pss:GetRadarPossible(), pss:GetRadarActual()
		local holds = poss:GetValue("RadarCategory_Holds") + poss:GetValue("RadarCategory_Rolls")
		local held = act:GetValue("RadarCategory_Holds") + act:GetValue("RadarCategory_Rolls")
		local mines = poss:GetValue("RadarCategory_Mines")
		-- (the mines actually hit: the radar counts mines never reached as not dodged)
		local hit = pss:GetTapNoteScores("TapNoteScore_HitMine")
		rows[#rows + 1] = { "Holds OK", string.format("%d / %d", held, holds) }
		rows[#rows + 1] = { "Mines hit", string.format("%d / %d", math.min(mines, hit), mines) }
	end)
	local scale = 1
	pcall(function() scale = hs:GetJudgeScale() end)
	local judge = 4
	for j = 4, 9 do if math.abs(scaleFor(j) - scale) < 0.01 then judge = j end end
	rows[#rows + 1] = { "Judge", judge == 9 and "Justice" or ("J" .. judge) }
	pcall(function()
		local ssr = hs:GetSkillsetSSR("Overall")
		rows[#rows + 1] = { "Score SSR", string.format("%.2f", ssr), true }
		local best = {}
		for _, k in ipairs({ "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical" }) do
			best[#best + 1] = { k, hs:GetSkillsetSSR(k) }
		end
		table.sort(best, function(a, b) return a[2] > b[2] end)
		local names = { JackSpeed = "Jackspeed" }
		for i = 1, 2 do
			if best[i] and best[i][2] > 0 then rows[#rows + 1] = { names[best[i][1]] or best[i][1], string.format("%.2f", best[i][2]) } end
		end
	end)
	return rows
end

-- The facts in a box of columns: p = x, y, w, h, cols, text(px, bold, init), accent, bg, label colour
function TW.evalPanel(p)
	local rows = TW.evalFacts()
	local f = Def.ActorFrame { InitCommand = function(self) self:xy(p.x, p.y) end }
	if p.bg or TW.isQuaver or not TW.box then
		f[#f + 1] = Def.Quad { InitCommand = function(self)
			self:align(0, 0):zoomto(p.w, p.h)
			if p.bg then self:diffuse(p.bg) else TW.glassify(self, "panel", { 0, 0, 0, 0.6 }) end
		end }
	else
		f[#f + 1] = TW.shadow { w = p.w, h = p.h, spread = p.h * 0.12, alpha = 0.5, drop = p.h * 0.03 }
		f[#f + 1] = TW.box { w = p.w, h = p.h, r = p.h * 0.1, col = { 0.1, 0.1, 0.14, 0.86 }, col2 = { 0.06, 0.06, 0.09, 0.86 } }
	end
	local ncol = p.cols or 1
	local perCol = math.ceil(#rows / ncol)
	local pad = p.pad or p.h * 0.06
	local cw = (p.w - pad * 2) / ncol
	local rh = (p.h - pad * 2) / perCol
	local px = p.px or math.min(rh * 0.62, p.h * 0.1)
	local gap = pad
	for i, r in ipairs(rows) do
		local ci, ri = math.floor((i - 1) / perCol), (i - 1) % perCol
		local x0 = pad + ci * cw
		local y = pad + (ri + 0.5) * rh
		local right = x0 + cw - (ci < ncol - 1 and gap or 0)
		f[#f + 1] = p.text(px, false, function(self)
			self:align(0, 0.5):xy(x0, y):settext(r[1]):diffuse(p.label or color("0.75,0.75,0.75,1"))
			self:maxwidth((right - x0) * 0.56 / self:GetZoom())
		end)
		f[#f + 1] = p.text(px, true, function(self)
			self:align(1, 0.5):xy(right, y):settext(r[2]):diffuse(r[3] and (p.accent or color("#FFFFFF")) or color("#FFFFFF"))
			self:maxwidth((right - x0) * 0.42 / self:GetZoom())
		end)
	end
	return f
end

-- Watching a score's replay, as osu! and Quaver let you: from its results ("Watch replay") or by
-- right clicking it on song select. Etterna plays replays from song select, so from the results
-- VSRG Hub goes back there first and starts it once the chart is selected again.
function TW.findScore(chartKey, scoreKey)
	local byRate = SCOREMAN:GetScoresByKey(chartKey)
	for _, sar in pairs(byRate or {}) do
		for _, hs in ipairs(sar:GetScores()) do
			if hs:GetScoreKey() == scoreKey then return hs end
		end
	end
	return nil
end
local function hasReplay(hs)
	local ok, has = pcall(function() return hs:HasReplayData() end)
	return ok and has == true
end
-- on song select
function TW.playReplay(hs)
	local top = SCREENMAN:GetTopScreen()
	if not (hs and top and top.PlayReplay) then return false end
	if not hasReplay(hs) then SCREENMAN:SystemMessage("This score has no replay") return false end
	-- (a replay isn't a practice run)
	pcall(function() GAMESTATE:SetPracticeMode(false) end)
	-- the replay plays with the score's mods and rate; yours are put back afterwards (Etterna does
	-- too, but not always: TW.afterReplay on song select makes sure)
	pcall(function()
		local ps = GAMESTATE:GetPlayerState()
		TW.beforeReplay = {
			mods = ps:GetPlayerOptionsString("ModsLevel_Preferred"),
			skin = ps:GetPlayerOptions("ModsLevel_Preferred"):NoteSkin(),
			rate = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(),
		}
	end)
	local ok, started = pcall(function() return top:PlayReplay(hs) end)
	if not (ok and started) then TW.keepPractice(); TW.beforeReplay = nil else TW.replayStarted = true end
	return ok and started
end
-- A score's results from song select (Etterna's ShowEvalScreenForScore). Etterna switches to the
-- score's rate to show them and puts yours back only when the results are left with its own
-- Start button, so VSRG Hub keeps it too and puts it back on song select (TW.afterScoreView).
function TW.showScore(hs)
	if TW.isHubScore and TW.isHubScore(hs) then
		SCREENMAN:SystemMessage(string.format("%s: %.2f%% at %sx", hs:GetDisplayName(), hs:GetWifeScore() * 100, (string.format("%.2f", hs:GetMusicRate()):gsub("0$", ""))))
		return true
	end
	local top = SCREENMAN:GetTopScreen()
	if not (hs and top and top.ShowEvalScreenForScore) then return false end
	local rate = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate()
	local ok, shown = pcall(function() return top:ShowEvalScreenForScore(hs) end)
	if ok and shown then TW.rateBeforeView = rate end
	return ok and shown
end
local function setRate(r)
	for _, lvl in ipairs({ "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song", "ModsLevel_Current" }) do
		pcall(function() GAMESTATE:GetSongOptionsObject(lvl):MusicRate(r) end)
	end
end
function TW.afterScoreView()
	local r = TW.rateBeforeView
	TW.rateBeforeView = nil
	if not r then return end
	setRate(r)
	MESSAGEMAN:Broadcast("CurrentRateChanged")
end

-- song select after a replay: your mods, noteskin and rate as they were
function TW.afterReplay()
	local b = TW.beforeReplay
	TW.beforeReplay = nil
	if not b then return end
	pcall(function()
		local ps = GAMESTATE:GetPlayerState()
		for _, lvl in ipairs({ "ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song", "ModsLevel_Current" }) do
			ps:SetPlayerOptions(lvl, b.mods)
			if b.skin and b.skin ~= "" then ps:GetPlayerOptions(lvl):NoteSkin(b.skin) end
			GAMESTATE:GetSongOptionsObject(lvl):MusicRate(b.rate)
		end
	end)
	MESSAGEMAN:Broadcast("CurrentRateChanged")
end

-- the score the results screen shows, as saved (nil when it wasn't)
function TW.resultsScore()
	local hs = nil
	pcall(function() hs = STATSMAN:GetCurStageStats():GetPlayerStageStats():GetHighScore() end)
	if not hs then return nil end
	local key, chart = "", ""
	pcall(function() key, chart = hs:GetScoreKey(), hs:GetChartKey() end)
	if key == "" or chart == "" then return nil end
	return TW.findScore(chart, key)
end
function TW.canWatchReplay()
	local hs = TW.resultsScore()
	return hs ~= nil and hasReplay(hs)
end
function TW.watchReplay()
	local hs = TW.resultsScore()
	if not hs or not hasReplay(hs) then SCREENMAN:SystemMessage("This score has no replay") return end
	TW.pendingReplay = { chart = hs:GetChartKey(), key = hs:GetScoreKey() }
	SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
end
-- song select, once it is up: the replay asked for on the results
function TW.startPendingReplay()
	local p = TW.pendingReplay
	TW.pendingReplay = nil
	if not p then return end
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps or steps:GetChartKey() ~= p.chart then return end
	local hs = TW.findScore(p.chart, p.key)
	if hs then TW.playReplay(hs) end
end
-- a button for the results screens: w x h at its centre
function TW.replayButton(w, h, text, accent)
	if not TW.canWatchReplay() then return Def.Actor {} end
	if not TW.isQuaver and TW.box then
		-- osu!: a pill in the interface colour, lighter under the mouse
		return Def.ActorFrame {
			TW.shadow { w = w, h = h, ax = 0.5, ay = 0.5, spread = h * 0.3, alpha = 0.45, drop = h * 0.06 },
			TW.box { w = w, h = h, r = h / 2, ax = 0.5, ay = 0.5, col = TW.mix(accent, { 1, 1, 1, 1 }, 0.12), col2 = accent } .. { Name = "Bg" },
			TW.box { w = w - h * 0.4, h = h * 0.45, r = h * 0.22, ax = 0.5, ay = 0, col = { 1, 1, 1, 0.18 }, col2 = { 1, 1, 1, 0 }, init = function(self) self:y(-h / 2 + h * 0.06) end },
			TW.icon("play", h * 0.32, function(self) self:x(-w / 2 + h * 0.62) end),
			text(h * 0.34, true, function(self) self:align(0.5, 0.5):x(h * 0.2):settext("Watch replay"):shadowlength(1):maxwidth((w - h) / self:GetZoom()) end),
			TW.button(w, h, function() TW.watchReplay() end, function(self, on)
				self:GetParent():stoptweening():decelerate(0.1):zoom(on and 1.05 or 1)
			end) .. { InitCommand = function(self) self:zoomto(w, h):diffusealpha(0) end },
		}
	end
	return Def.ActorFrame {
		Def.Quad { Name = "Bg", InitCommand = function(self) TW.glassify(self:zoomto(w, h), "card", { 0.05, 0.05, 0.07, 0.72 }) end },
		Def.Quad { InitCommand = function(self) self:align(0.5, 1):y(h / 2):zoomto(w, 2):diffuse(accent) end },
		text(h * 0.34, true, function(self) self:align(0.5, 0.5):settext("Watch replay"):maxwidth(w * 0.9 / self:GetZoom()) end),
		TW.button(w, h, function() TW.watchReplay() end, function(self, on)
			local bg = self:GetParent():GetChild("Bg")
			if on then bg:diffuse(accent):diffusealpha(0.5) else TW.glassify(bg, "card", { 0.05, 0.05, 0.07, 0.72 }) end
		end),
	}
end

-- ---------------------------------------------------------------------------------------------
-- Accuracy on other timings (results screens of both looks): Wife% rescored to Etterna's judges and
-- to osu!'s ODs, and osu!'s own accuracy (300g and 300 both count in full, 200 two thirds, 100 a
-- third, 50 a sixth, a miss nothing).
-- ---------------------------------------------------------------------------------------------
local accJudges = { 4, 5, 6, 7, 9 }
local accODs = { 6, 7, 8, 9, 10 }
-- what a rescore needs: every hit's offset (misses included), holds and mines, the taps
function TW.accData()
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
	local hs = pss:GetHighScore()
	local offs, types = {}, {}
	pcall(function() offs = pss:GetOffsetVector() or {}; types = pss:GetTapNoteTypeVector() or {} end)
	if #offs == 0 and hs then
		pcall(function()
			local r = hs:GetReplay()
			r:LoadAllData()
			offs, types = r:GetOffsetVector() or {}, r:GetTapNoteTypeVector() or {}
		end)
	end
	local dvt = {}
	for i, o in ipairs(offs) do
		local ty = types[i]
		if ty == nil or ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then dvt[#dvt + 1] = o end
	end
	local d = { dvt = dvt, totalTaps = 0, holdsMissed = 0, minesHit = 0, failed = false }
	-- (a play that failed: Etterna's Wife% counts the notes never reached as lost; its accuracy on
	-- what was played is the one that means something, as osu! and Quaver show it)
	pcall(function() if pss:GetFailed() then d.failed = true end end)
	pcall(function() if hs and hs:GetWifeGrade() == "Grade_Failed" then d.failed = true end end)
	pcall(function()
		for _, k in ipairs(judgeKeys) do d.totalTaps = d.totalTaps + pss:GetTapNoteScores(k) end
		-- (as judged: a play left early isn't charged for holds and mines it never reached)
		d.holdsMissed = pss:GetHoldNoteScores("HoldNoteScore_LetGo") + pss:GetHoldNoteScores("HoldNoteScore_MissedHold")
		d.minesHit = pss:GetTapNoteScores("TapNoteScore_HitMine")
	end)
	return d
end
-- Wife3 at a window scale (Etterna's rescoring, for any scale: judges and ODs)
function TW.wifeAt(d, ts)
	if not d or d.totalTaps <= 0 or not wife3 then return nil end
	local p = 0
	for _, o in ipairs(d.dvt) do p = p + wife3(math.abs(o), ts, 3) end
	p = p + d.holdsMissed * -4.5 + d.minesHit * -7
	return p / (d.totalTaps * 2) * 100
end
-- The rescores start from what Etterna saved: the rescore at the scale it was played on is moved onto
-- Etterna's own Wife% (they differ a little for some plays, e.g. one left early), and every other
-- scale by the same amount.
local function rescoreBase(d)
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
	local actual = pss:GetWifeScore() * 100
	local played = 1
	pcall(function() played = pss:GetHighScore():GetJudgeScale() end)
	if not played or played <= 0 then played = 1 end
	local at = TW.wifeAt(d, played)
	return actual, played, at and (actual - at) or 0
end
function TW.wifeFixed(d, ts)
	if d and d.failed then return TW.wifeAt(d, ts) end
	local actual, played, fix = rescoreBase(d)
	if math.abs(ts - played) < 0.005 then return actual end
	local v = TW.wifeAt(d, ts)
	return v and (v + fix) or nil
end
-- The accuracy a results screen shows big: on the timing the play was played on (an osu! OD: osu!'s
-- own accuracy, as shown while playing; a judge: Wife% on that judge) and, for a failed play, on the
-- notes that were played. Returns the value and its name ("OD 8", "J4", "Justice").
function TW.mainAcc(d, hs)
	d = d or TW.accData()
	local mode, v = TW.playedTiming(hs or STATSMAN:GetCurStageStats():GetPlayerStageStats():GetHighScore())
	if mode == "od" then return TW.osuAcc(), "OD " .. v end
	if mode == "quaver" and TW.quaverAcc then
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		local c = {}
		for i, k in ipairs(judgeKeys) do c[i] = pss:GetTapNoteScores(k) end
		return TW.quaverAcc(c), "Quaver " .. v
	end
	local j = (mode == "judge" and v) or 4
	local name = j == 9 and "Justice" or ("J" .. j)
	local val = TW.wifeFixed(d, scaleFor(j))
	if not val then val = STATSMAN:GetCurStageStats():GetPlayerStageStats():GetWifeScore() * 100 end
	return val, name
end
-- The grade a results screen shows big: osu!'s letter for the accuracy on the timing played (an
-- osu! OD's accuracy, or Wife% on the judge): SS at 100%, S from 95, A 90, B 80, C 70, else D.
-- Etterna's own grade (AAAA, AA...) is written small next to the J4 accuracy (TW.etternaGrade).
function TW.accRank(pct)
	pct = pct or 0
	if pct >= 99.9999 then return "X" elseif pct >= 95 then return "S" elseif pct >= 90 then return "A"
	elseif pct >= 80 then return "B" elseif pct >= 70 then return "C" end
	return "D"
end
-- A saved score's accuracy on the timing it was played on (for the song select's scoreboard, as on
-- the results): an osu! OD's accuracy, or Wife% on its judge. Returns the accuracy, the timing's name
-- ("OD 8", "J4") and whether it failed.
function TW.scoreAcc(hs)
	local wife = 0
	pcall(function() wife = hs:GetWifeScore() * 100 end)
	local failed = false
	pcall(function() failed = hs:GetWifeGrade() == "Grade_Failed" end)
	local played
	pcall(function() played = hs:GetJudgeScale() end)
	if played and played > 0 then
		for od = 0, 10 do
			if TW.odScale and math.abs(TW.odScale(od) - played) < 0.005 and math.abs(played - 1) > 0.005 then
				local c = {}
				for i, k in ipairs(judgeKeys) do c[i] = 0; pcall(function() c[i] = hs:GetTapNoteScore(k) end) end
				return TW.osuAcc(c), "OD " .. od, failed
			end
		end
		for j = 4, 9 do if math.abs(scaleFor(j) - played) < 0.005 then return wife, j == 9 and "Justice" or ("J" .. j), failed end end
	end
	return wife, "J4", failed
end
local ETT_GRADES = { "AAAAA", "AAAA:", "AAAA.", "AAAA", "AAA:", "AAA.", "AAA", "AA:", "AA.", "AA", "A:", "A.", "A", "B", "C", "D" }
function TW.etternaGrade(g)
	if g == "Grade_Failed" then return "F" end
	local n = tonumber(tostring(g or ""):match("Tier(%d+)"))
	return n and ETT_GRADES[n] or ""
end
-- the J4 accuracy (what Etterna ranks by), whatever the timing was
function TW.accJ4(d)
	d = d or TW.accData()
	local v = TW.wifeFixed(d, scaleFor(4))
	if v then return v end
	return STATSMAN:GetCurStageStats():GetPlayerStageStats():GetWifeScore() * 100
end
-- osu!'s accuracy from judgment counts (a table W1..W5, Miss, or the stage stats)
function TW.osuAcc(c)
	if not c then
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		c = {}
		for i, k in ipairs(judgeKeys) do c[i] = pss:GetTapNoteScores(k) end
	end
	local n = c[1] + c[2] + c[3] + c[4] + c[5] + c[6]
	if n <= 0 then return 100 end
	return (300 * (c[1] + c[2]) + 200 * c[3] + 100 * c[4] + 50 * c[5]) / (300 * n) * 100
end
-- the timing a score was played on: "od", n or "judge", n (nil when it was neither)
function TW.playedTiming(hs)
	local played
	pcall(function() played = hs:GetJudgeScale() end)
	-- (just played on Quaver's windows: the J4 scale, so only known while they are still in force,
	-- and not for a past score or a replay)
	if TW.timingMode and not TW.rateBeforeView and not TW.beforeReplay then
		local m, v = TW.timingMode()
		if m == "quaver" and (not played or math.abs(played - 1) < 0.005) then return m, v end
	end
	if not played or played <= 0 then
		if TW.timingMode then return TW.timingMode() end
		return nil
	end
	for j = 4, 9 do if math.abs(scaleFor(j) - played) < 0.005 then return "judge", j end end
	for od = 0, 10 do if TW.odScale and math.abs(TW.odScale(od) - played) < 0.005 then return "od", od end end
	return nil
end
-- the lines of the accuracy tooltip
function TW.accLines(d)
	d = d or TW.accData()
	local out = {}
	for _, j in ipairs(accJudges) do
		local v = TW.wifeFixed(d, scaleFor(j))
		out[#out + 1] = { j == 9 and "Justice" or ("J" .. j), v }
	end
	for _, od in ipairs(accODs) do
		local v = TW.odScale and TW.wifeFixed(d, TW.odScale(od))
		out[#out + 1] = { "OD" .. od, v }
	end
	return out
end
-- A small window that follows the mouse while it is over the accuracy (rect() -> x, y, w, h, in
-- screen pixels), listing it on Etterna's judges and osu!'s ODs, as Til' Death does.
-- style: text(px, bold, init), px (text size), accent (the heading colour), bg (colour; else the
-- look's glass), pad
function TW.accTooltip(rect, style)
	local px = style.px or 12
	local pad = style.pad or 6
	local lines = nil
	local f = Def.ActorFrame {
		InitCommand = function(self) self:visible(false) end,
		OnCommand = function(self)
			TW.everyFrame(self)
			self:SetUpdateFunction(function()
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				local x, y, w, h = rect()
				local inside = x and mx >= x and mx <= x + w and my >= y and my <= y + h
				if not inside then self:visible(false) return end
				if not lines then
					lines = TW.accLines()
					local names, vals = {}, {}
					for _, l in ipairs(lines) do
						names[#names + 1] = l[1]
						vals[#vals + 1] = l[2] and string.format("%.2f%%", l[2]) or "-"
					end
					self:GetChild("Body"):settext(table.concat(names, "\n"))
					self:GetChild("Vals"):settext(table.concat(vals, "\n"))
				end
				local body, vals, head = self:GetChild("Body"), self:GetChild("Vals"), self:GetChild("Head")
				local cw = body:GetZoomedWidth() + px * 1.5 + vals:GetZoomedWidth()
				local bw = math.max(cw, head:GetZoomedWidth()) + pad * 2
				local bh = head:GetZoomedHeight() + body:GetZoomedHeight() + pad * 3
				-- beside the pointer, kept on screen and out of its way
				local bx, by = mx + 18, my + 18
				if bx + bw > SCREEN_WIDTH - 4 then bx = mx - 18 - bw end
				if by + bh > SCREEN_HEIGHT - 4 then by = math.max(4, my - 18 - bh) end
				self:visible(true):xy(bx, by)
				self:GetChild("BG"):zoomto(bw, bh)
				head:xy(pad, pad)
				body:xy(pad, pad * 2 + head:GetZoomedHeight())
				vals:xy(bw - pad, pad * 2 + head:GetZoomedHeight())
			end)
		end,
		Def.Quad { Name = "BG", InitCommand = function(self)
			self:align(0, 0)
			if style.bg then self:diffuse(style.bg) else TW.glassify(self, "float", { 0, 0, 0, 0.88 }) end
		end },
		style.text(px, true, function(self) self:align(0, 0):settext("Accuracy on other timings"):diffuse(style.accent or color("#FFFFFF")) end) .. { Name = "Head" },
		style.text(px, false, function(self) self:align(0, 0):settext("") end) .. { Name = "Body" },
		-- (the same font as the names: a bold one's taller lines would drift off their names)
		style.text(px, false, function(self) self:align(1, 0):settext("") end) .. { Name = "Vals" },
	}
	return f
end

-- A fail with nothing hit: Etterna leaves the song at once and keeps no score (no results screen),
-- which looks as if nothing happened. Say so.
function TW.failNotice()
	return Def.Actor {
		PlayerFailedMessageCommand = function()
			local hit = 0
			pcall(function()
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				for _, k in ipairs({ "TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3", "TapNoteScore_W4", "TapNoteScore_W5" }) do
					hit = hit + pss:GetTapNoteScores(k)
				end
			end)
			if hit == 0 then SCREENMAN:SystemMessage("Failed! Nothing was hit, so Etterna keeps no score of it") end
		end,
	}
end
