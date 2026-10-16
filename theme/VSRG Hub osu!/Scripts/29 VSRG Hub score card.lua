-- A score from VSRG Hub's ranking, opened from the song select's scoreboard (a click on it): a card
-- over the screen with what a results screen shows: the player and their place, the song, accuracy
-- and grade, the judgements, combo, the rating of the play in each skillset, when and in which game
-- it was played, and the spread of its hit offsets. The scoreboard's line has most of it; the
-- skillsets and the offsets come from the launcher (online/wantdetail.txt -> online/detail/<id>.txt,
-- online.go's answerDetail). Etterna can't play a replay it doesn't own, so there's no replay here.
--
-- TW.openHubScore(hs)    the card for a scoreboard score (28 VSRG Hub online.lua's hubScore)
-- TW.closeHubScore()
-- TW.hubScoreInput(event)  the screens' input callbacks: Esc closes, keys stay here while it's up
-- TW.hubScorePanel()     the actor, in the song select overlays

local ONLINE = "Save/VSRGHub/online/"
TW.hubCard = nil
local asked = 0

function TW.openHubScore(hs)
	if not hs then return end
	asked = asked + 1
	TW.hubCard = { hs = hs, id = hs.id, detail = nil, status = "loading", t0 = GetTimeSinceStart(), n = asked }
	if hs.id and hs.id ~= "" then
		pcall(function() File.Write(ONLINE .. "wantdetail.txt", hs.id .. "\t" .. asked .. "\n") end)
	else
		TW.hubCard.status = "none"
	end
	SCREENMAN:set_input_redirected(PLAYER_1, true)
	MESSAGEMAN:Broadcast("TWHubCard")
end
function TW.closeHubScore()
	if not TW.hubCard then return end
	TW.hubCard = nil
	SCREENMAN:set_input_redirected(PLAYER_1, TW.optionsOpen == true or TW.keepRedirect == true)
	MESSAGEMAN:Broadcast("TWHubCard")
end
function TW.hubScoreInput(event)
	if not TW.hubCard then return false end
	if event.DeviceInput.is_mouse and not event.DeviceInput.button:find("mousewheel") then return false end
	if event.type ~= "InputEventType_FirstPress" then return true end
	local b = event.DeviceInput.button
	if b == "DeviceButton_escape" or b == "DeviceButton_enter" or b == "DeviceButton_back" then TW.closeHubScore() end
	return true
end

-- the launcher's answer, once it's there
local function readDetail(card)
	local ok, txt = pcall(function() return File.Read(ONLINE .. "detail/" .. card.id .. ".txt") end)
	if not ok or not txt or txt == "" then return false end
	local lines = {}
	for line in (txt .. "\n"):gmatch("([^\r\n]*)\n") do lines[#lines + 1] = line end
	local id, status = (lines[1] or ""):match("^([^\t]*)\t(.*)$")
	if id ~= card.id then return false end
	card.status = status or "none"
	if status == "ok" then
		local f = {}
		for v in ((lines[2] or "") .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
		card.detail = {
			ssr = { tonumber(f[1]) or 0, tonumber(f[2]) or 0, tonumber(f[3]) or 0, tonumber(f[4]) or 0, tonumber(f[5]) or 0, tonumber(f[6]) or 0, tonumber(f[7]) or 0, tonumber(f[8]) or 0 },
			msd = tonumber(f[9]) or 0, holdsOK = tonumber(f[10]) or 0, holdsNG = tonumber(f[11]) or 0, mines = tonumber(f[12]) or 0,
			title = f[13] or "", chart = f[14] or "", keys = tonumber(f[15]) or 4, source = f[16] or "", playedAt = f[17] or "", mods = f[18] or "",
			offsets = {},
		}
		for v in ((lines[3] or "") .. ","):gmatch("([^,]*),") do
			local n = tonumber(v)
			if n then card.detail.offsets[#card.detail.offsets + 1] = n end
		end
	end
	return true
end

local SKILLS = { "Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "Jackspeed", "Chordjack", "Technical" }
local SOURCE = { osu = "osu!", lazer = "osu!lazer", quaver = "Quaver", etterna = "Etterna" }

function TW.hubScorePanel()
	local M = TW.M
	local W, H = M(780), M(560)
	local X, Y = SCREEN_CENTER_X - W / 2, SCREEN_CENTER_Y - H / 2
	local white = color("#FFFFFF")
	local dim = TW.rgb(170, 175, 190)
	local BUCKET, RANGE = 5, 180 -- (ms a bar, the plot's reach)
	local NB = RANGE * 2 / BUCKET
	local PX, PY, PW, PH = X + M(30), Y + M(392), W - M(60), M(110)
	local t = Def.ActorFrame {
		Name = "TWHubScorePanel",
		InitCommand = function(self) self:z(72):visible(false) end,
		TWHubCardMessageCommand = function(self)
			if not TW.hubCard then self:stoptweening():linear(0.1):diffusealpha(0):queuecommand("Hide") return end
			if not self:GetVisible() then self:visible(true):diffusealpha(0):linear(0.12):diffusealpha(1) end
			self:playcommand("Fill")
			self:SetUpdateFunction(function(a)
				local card = TW.hubCard
				if not card or card.status ~= "loading" then a:SetUpdateFunction(nil) return end
				local now = GetTimeSinceStart()
				if now - (card.lastLook or 0) < 0.4 then return end
				card.lastLook = now
				if readDetail(card) then a:playcommand("Detail")
				elseif now - card.t0 > 15 then card.status = "offline"; a:playcommand("Detail") end
			end)
		end,
		HideCommand = function(self) self:visible(false):SetUpdateFunction(nil) end,
		-- the screen behind, darkened; a click there closes
		Def.Quad { InitCommand = function(self) TW.shade(self:FullScreen(), 0.8) end },
		TW.button(SCREEN_WIDTH, SCREEN_HEIGHT, function() TW.closeHubScore() end) .. {
			InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffusealpha(0) end },
		TW.shadow { w = W, h = H, spread = M(24), alpha = 0.6, drop = M(6), init = function(self) self:xy(X, Y) end },
		TW.box { w = W, h = H, r = M(14), col = TW.rgb(28, 28, 36), col2 = TW.rgb(18, 18, 24), init = function(self) self:xy(X, Y) end },
		-- (a click on the card itself stays on it)
		TW.button(W, H, function() end) .. { InitCommand = function(self) self:align(0, 0):xy(X, Y):zoomto(W, H):diffusealpha(0) end },
	}
	-- header: place, player; the source and the date on the right
	t[#t + 1] = TW.text(M(12), true, function(self) self:align(0, 0.5):xy(X + M(30), Y + M(30)):diffuse(TW.pink) end) .. { Name = "Place",
		FillCommand = function(self) local hs = TW.hubCard.hs; self:settextf("#%d ON VSRG HUB", hs.place or 0) end }
	t[#t + 1] = TW.text(M(24), true, function(self) self:align(0, 0.5):xy(X + M(30), Y + M(58)):maxwidth(M(420) / self:GetZoom()) end) .. { Name = "Name",
		FillCommand = function(self) self:settext(TW.hubCard.hs.name or "") end }
	t[#t + 1] = TW.text(M(11), false, function(self) self:align(1, 0.5):xy(X + W - M(30), Y + M(30)):diffuse(dim) end) .. { Name = "When",
		FillCommand = function(self)
			local hs = TW.hubCard.hs
			local src = SOURCE[hs.source or ""] or ""
			local d = hs:GetDate() or ""
			self:settext((src ~= "" and (src .. "  ·  ") or "") .. d)
		end }
	-- the song
	t[#t + 1] = TW.text(M(15), true, function(self) self:align(0, 0.5):xy(X + M(30), Y + M(96)):maxwidth((W - M(60)) / self:GetZoom()) end) .. { Name = "Title",
		FillCommand = function(self)
			local s = GAMESTATE:GetCurrentSong()
			self:settext(s and s:GetDisplayMainTitle() or "")
		end }
	t[#t + 1] = TW.text(M(11), false, function(self) self:align(0, 0.5):xy(X + M(30), Y + M(116)):diffuse(dim):maxwidth((W - M(60)) / self:GetZoom()) end) .. { Name = "Sub",
		FillCommand = function(self)
			local s, st = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
			local hs = TW.hubCard.hs
			local parts = { s and s:GetDisplayArtist() or "" }
			if st then parts[#parts + 1] = TW.diffName(st) or "" end
			parts[#parts + 1] = (string.format("%.2f", hs:GetMusicRate()):gsub("0$", "")) .. "x"
			local mods = hs:GetModifiers() or ""
			if mods ~= "" then parts[#parts + 1] = mods end
			self:settext(table.concat(parts, "  ·  "))
		end }
	-- accuracy and grade, the play's rating and the chart's MSD
	t[#t + 1] = TW.box { w = M(64), h = M(64), r = M(12), ax = 0, ay = 0.5, init = function(self) self:xy(X + M(30), Y + M(176)) end } .. { Name = "GradeBg",
		FillCommand = function(self) TW.setBox(self, { col = TW.RankColour[TW.accRank(TW.hubCard.hs:GetWifeScore() * 100)] or white }) end }
	t[#t + 1] = TW.text(M(30), true, function(self) self:align(0.5, 0.5):xy(X + M(62), Y + M(177)):diffuse(TW.rgb(20, 20, 26)) end) .. { Name = "Grade",
		FillCommand = function(self) self:settext(TW.RankLetter[TW.accRank(TW.hubCard.hs:GetWifeScore() * 100)] or "") end }
	t[#t + 1] = TW.text(M(38), true, function(self) self:align(0, 0.5):xy(X + M(110), Y + M(170)) end) .. { Name = "Acc",
		FillCommand = function(self) self:settextf("%.2f%%", TW.hubCard.hs:GetWifeScore() * 100) end }
	t[#t + 1] = TW.text(M(10.5), false, function(self) self:align(0, 0.5):xy(X + M(112), Y + M(198)):diffuse(dim):settext("WIFE3 ON J4") end)
	t[#t + 1] = TW.text(M(38), true, function(self) self:align(1, 0.5):xy(X + W - M(30), Y + M(170)):diffuse(TW.yellow) end) .. { Name = "SSR",
		FillCommand = function(self) self:settextf("%.2f", TW.hubCard.hs:GetSkillsetSSR()) end }
	t[#t + 1] = TW.text(M(10.5), false, function(self) self:align(1, 0.5):xy(X + W - M(32), Y + M(198)):diffuse(dim) end) .. { Name = "MsdLine",
		FillCommand = function(self)
			local st = GAMESTATE:GetCurrentSteps()
			local m = st and TW.msd(st) or 0
			self:settextf("RATING  ·  CHART MSD %.2f  ·  %dx COMBO", m, TW.hubCard.hs:GetMaxCombo())
		end }
	-- the judgements
	local J = { { "MARV", "TapNoteScore_W1", TW.rgb(99, 238, 255) }, { "PERF", "TapNoteScore_W2", TW.rgb(255, 230, 100) },
		{ "GREAT", "TapNoteScore_W3", TW.rgb(130, 230, 120) }, { "GOOD", "TapNoteScore_W4", TW.rgb(90, 160, 255) },
		{ "BAD", "TapNoteScore_W5", TW.rgb(220, 120, 255) }, { "MISS", "TapNoteScore_Miss", TW.rgb(255, 90, 90) } }
	local jw = (W - M(60)) / #J
	for i, j in ipairs(J) do
		local jx = X + M(30) + (i - 1) * jw
		t[#t + 1] = TW.box { w = jw - M(6), h = M(50), r = M(8), col = TW.rgb(40, 40, 50), init = function(self) self:xy(jx, Y + M(228)) end }
		t[#t + 1] = TW.text(M(9.5), true, function(self) self:align(0.5, 0.5):xy(jx + (jw - M(6)) / 2, Y + M(241)):settext(j[1]):diffuse(j[3]) end)
		t[#t + 1] = TW.text(M(17), true, function(self) self:align(0.5, 0.5):xy(jx + (jw - M(6)) / 2, Y + M(262)) end) .. {
			FillCommand = function(self) self:settext(tostring(TW.hubCard.hs:GetTapNoteScore(j[2]))) end }
	end
	-- the skillsets (from the launcher)
	local sw = (W - M(60)) / #SKILLS
	for i, name in ipairs(SKILLS) do
		local sx = X + M(30) + (i - 1) * sw
		t[#t + 1] = TW.text(M(9), true, function(self) self:align(0, 0.5):xy(sx, Y + M(300)):settext(name:upper()):diffuse(dim) end)
		t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0.5):xy(sx, Y + M(310)):zoomto(sw - M(8), M(2)):diffuse(TW.rgb(60, 60, 72)) end }
		t[#t + 1] = TW.text(M(15), true, function(self) self:align(0, 0.5):xy(sx, Y + M(328)) end) .. {
			FillCommand = function(self) self:settext(i == 1 and string.format("%.2f", TW.hubCard.hs:GetSkillsetSSR()) or "–"):diffuse(i == 1 and TW.yellow or dim) end,
			DetailCommand = function(self)
				local d = TW.hubCard and TW.hubCard.detail
				if not d then return end
				local v = d.ssr[i] or 0
				self:settextf("%.2f", v):diffuse(i == 1 and TW.yellow or (v > 0.5 and white or dim))
			end }
	end
	-- the hit offsets: a bar per 5 ms, early to the left
	t[#t + 1] = TW.text(M(11), true, function(self) self:align(0, 0.5):xy(X + M(30), Y + M(372)):settext("HIT OFFSETS"):diffuse(TW.pink) end)
	t[#t + 1] = TW.text(M(10), false, function(self) self:align(1, 0.5):xy(X + W - M(30), Y + M(372)):diffuse(dim) end) .. { Name = "Stats",
		FillCommand = function(self) self:settext("Loading...") end,
		DetailCommand = function(self)
			local card = TW.hubCard
			if not card then return end
			local d = card.detail
			if not d or #d.offsets == 0 then
				self:settext(card.status == "offline" and "The launcher didn't answer (is the game started from VSRG Hub?)" or "No replay kept for this play")
				return
			end
			local n, sum, sum2, early, late = 0, 0, 0, 0, 0
			for _, o in ipairs(d.offsets) do
				if math.abs(o) < 500 then
					n = n + 1; sum = sum + o; sum2 = sum2 + o * o
					if o < 0 then early = early + 1 else late = late + 1 end
				end
			end
			if n == 0 then self:settext("") return end
			local mean = sum / n
			local sd = math.sqrt(math.max(0, sum2 / n - mean * mean))
			self:settextf("mean %+.1f ms  ·  SD %.1f ms  ·  %d early  %d late  ·  %d misses", mean, sd, early, late, #d.offsets - n)
		end }
	t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(PX, PY):zoomto(PW, PH):diffuse({ 0, 0, 0, 0.3 }) end }
	-- (the J4 windows as faint lines: 45, 90, 135 ms)
	for _, w in ipairs({ 45, 90, 135 }) do
		for _, sgn in ipairs({ -1, 1 }) do
			t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0.5, 0):xy(PX + PW / 2 + sgn * w / RANGE * PW / 2, PY):zoomto(1, PH):diffuse({ 1, 1, 1, 0.08 }) end }
		end
	end
	t[#t + 1] = Def.Quad { InitCommand = function(self) self:align(0.5, 0):xy(PX + PW / 2, PY):zoomto(1, PH):diffuse({ 1, 1, 1, 0.3 }) end }
	t[#t + 1] = TW.text(M(9), false, function(self) self:align(0, 0):xy(PX + M(4), PY + M(2)):settext("early"):diffuse(dim) end)
	t[#t + 1] = TW.text(M(9), false, function(self) self:align(1, 0):xy(PX + PW - M(4), PY + M(2)):settext("late"):diffuse(dim) end)
	t[#t + 1] = Def.ActorMultiVertex {
		Name = "Bars",
		InitCommand = function(self) self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices({}) end,
		FillCommand = function(self) self:SetVertices({}) end,
		DetailCommand = function(self)
			local d = TW.hubCard and TW.hubCard.detail
			local counts, top = {}, 0
			if d then
				for _, o in ipairs(d.offsets) do
					if math.abs(o) < RANGE then
						local b = math.floor((o + RANGE) / BUCKET) + 1
						counts[b] = (counts[b] or 0) + 1
						if counts[b] > top then top = counts[b] end
					end
				end
			end
			local verts = {}
			local bw = PW / NB
			for b = 1, NB do
				local c = counts[b] or 0
				if c > 0 and top > 0 then
					local h = math.max(M(2), c / top * (PH - M(16)))
					local x0, x1 = PX + (b - 1) * bw + 1, PX + b * bw - 1
					local y0, y1 = PY + PH - M(4) - h, PY + PH - M(4)
					local centre = math.abs((b - 0.5) * BUCKET - RANGE)
					local col = centre <= 45 and TW.rgb(99, 238, 255) or centre <= 90 and TW.rgb(255, 230, 100) or centre <= 135 and TW.rgb(130, 230, 120) or TW.rgb(90, 160, 255)
					verts[#verts + 1] = { { x0, y0, 0 }, col }
					verts[#verts + 1] = { { x1, y0, 0 }, col }
					verts[#verts + 1] = { { x1, y1, 0 }, col }
					verts[#verts + 1] = { { x0, y1, 0 }, col }
				end
			end
			self:SetVertices(verts)
		end }
	-- close
	t[#t + 1] = TW.box { w = M(110), h = M(34), r = M(17), ax = 1, ay = 1, col = TW.pink, init = function(self) self:xy(X + W - M(30), Y + H - M(22)) end }
	t[#t + 1] = TW.text(M(12), true, function(self) self:align(0.5, 0.5):xy(X + W - M(85), Y + H - M(39)):settext("Close") end)
	t[#t + 1] = TW.button(M(110), M(34), function() TW.closeHubScore() end) .. {
		InitCommand = function(self) self:align(1, 1):xy(X + W - M(30), Y + H - M(22)):zoomto(M(110), M(34)):diffusealpha(0) end }
	t[#t + 1] = TW.text(M(9.5), false, function(self) self:align(0, 0.5):xy(X + M(30), Y + H - M(39)):diffuse(dim):settext("Esc closes  ·  Replays can't be played for VSRG Hub scores: Etterna only plays its own and EtternaOnline's") end)
	return t
end
