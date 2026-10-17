-- The map preview both looks use (Quaver's "View Map", and the preview tab in the osu! look): the
-- chart scrolling with the song inside a box, a graph beside it of how hard each moment is on the
-- MSD scale with a line that follows the song, click the graph to jump there, Tab to play from there.
--
-- spec: x, y, w, h (the whole box, graph included), isOpen() (is the preview showing),
--       openMessage (message that means it just opened), text(px, bold, init), colour(msd) -> color,
--       accent, bg

function TW.previewSongSpan()
	local st = GAMESTATE:GetCurrentSteps()
	if not st then return nil end
	local r = getCurRateValue()
	return (st:GetFirstSecond() / r + st:GetLengthSeconds()) * r
end

-- While a preview's notes are being drawn: is a hold going by in this column (0-based)? VSRG Hub's
-- noteskins then draw the hold's head on the receptor (Etterna's preview holds nothing, so it lets
-- the head scroll away and only the body shows).
TW.previewDrawing = nil
function TW.previewHeld(col)
	local d = TW.previewDrawing
	local list = d and d.spans and d.spans[col]
	if not list then return false end
	local beat = d.beat
	for _, h in ipairs(list) do
		if h.s > beat then return false end
		if beat < h.e then return true end
	end
	return false
end

-- The selected chart's notes playing with the song, in a box: box = x (its centre), y (its top), w,
-- h. LoadCommand { noteskin = name } (re)loads it, with that noteskin or the player's own.
-- (the field sits in a frame that is moved and zoomed: Etterna sets the preview's own zoom and
-- column spacing itself, so zooming the field directly leaves the columns spread too wide)
function TW.previewField(box)
	local M = TW.M
	local spans = nil
	return Def.ActorFrame {
		Name = "FieldFrame",
		InitCommand = function(self)
			self:x(box.x)
			-- (the holds going by are known only while this field draws)
			self:SetDrawFunction(function(frame)
				local ok, beat = pcall(function() return GAMESTATE:GetSongPosition():GetSongBeatVisible() end)
				TW.previewDrawing = spans and ok and { spans = spans, beat = beat } or nil
				frame:GetChild("NoteField"):Draw()
				TW.previewDrawing = nil
			end)
		end,
		LoadCommand = function(self, p)
			local nf = self:GetChild("NoteField")
			local steps = GAMESTATE:GetCurrentSteps()
			-- the mods that change which notes there are show here too: Full LN / Inverse (the
			-- converted copy of the chart, written once as when you play it) and Mirror
			local song = GAMESTATE:GetCurrentSong()
			if steps and song and TW.lnMod and TW.lnModChart and song:GetGroupName() ~= "VSRG Hub Mods" then
				local ok, _, st2 = pcall(TW.lnModChart, song, steps, TW.lnMod)
				if ok and st2 then steps = st2 end
			end
			local mirror = false
			pcall(function() mirror = GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):Mirror() end)
			spans = TW.holdSpans and TW.holdSpans(steps) or nil
			if spans and mirror then
				-- (the held-head drawing follows the columns as mirrored)
				local n = steps:GetNumColumns()
				local m = {}
				for c, list in pairs(spans) do m[n - 1 - c] = list end
				spans = m
			end
			-- Etterna turns the notes by the options in force now: just Mirror, just while loading
			local cur = GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Current")
			local keepMirror, keepShuffle = cur:Mirror(), cur:Shuffle()
			local function load(st)
				if not st then nf:LoadDummyNoteData() return end
				if mirror then cur:Mirror(true); cur:Shuffle(false) end
				local ok = pcall(function() nf:LoadNoteData(st, mirror) end)
				if mirror then cur:Mirror(keepMirror); cur:Shuffle(keepShuffle) end
				if not ok then nf:LoadNoteData(st) end
			end
			local po = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions()
			local skin = p and p.noteskin or po:NoteSkin()
			if p and p.noteskin then
				-- Etterna's preview loads the noteskin the player has (Etterna keeps the ones in its
				-- Current and Stage options): the one to show is put there just while it loads
				local ps = GAMESTATE:GetPlayerState()
				local keep = {}
				for _, lvl in ipairs({ "ModsLevel_Stage", "ModsLevel_Current" }) do
					keep[lvl] = ps:GetPlayerOptions(lvl):NoteSkin()
					ps:GetPlayerOptions(lvl):NoteSkin(p.noteskin)
				end
				pcall(load, steps)
				for lvl, v in pairs(keep) do ps:GetPlayerOptions(lvl):NoteSkin(v) end
			else load(steps) end
			-- columns spaced to the noteskin's width (as in play), the field zoomed to fit the box
			local info = TW.noteskinInfo(skin)
			local w = info and info.width or 64
			local cols = nf:get_column_actors()
			local n = math.max(1, #cols)
			-- (a column actor's x is added to the style's own 64-pixel spacing, as in gameplay)
			for i, col in ipairs(cols) do col:x((i - (n + 1) / 2) * (w - 64)) end
			local zoom = math.min(1, box.w * 0.86 / (n * w))
			self:zoom(zoom)
			local rev = po:UsingReverse()
			local ry = THEME:GetMetric("Player", rev and "ReceptorArrowsYReverse" or "ReceptorArrowsYStandard")
			local target = rev and (box.y + box.h - M(45)) or (box.y + M(45))
			self:y(target - ry * zoom)
			self.twReach = { w = w, zoom = zoom, mini = po:Mini() or 0, rev = rev }
			self:playcommand("Reach")
		end,
		-- notes are drawn only as far as the box reaches: Etterna measures that distance in the
		-- field's own pixels, scaled up by Mini (Til Death's receptor size), and draws the field at
		-- the Mini zoom, so both are taken out here, with room for half a note at the edge
		ReachCommand = function(self)
			local r = self.twReach
			if not r then return end
			local nf = self:GetChild("NoteField")
			local miniZoom = math.max(0.1, 1 - r.mini * 0.5)
			local scale = r.zoom * (1 + math.abs(r.mini)) * miniZoom
			local note = r.w * r.zoom * miniZoom
			local reach = box.h - M(45) - note / 2
			nf:UpdateDrawDistance(0, math.max(1, math.floor(reach / scale)))
			if box.edge then MESSAGEMAN:Broadcast("TWPreviewEdge", { note = note, rev = r.rev }) end
		end,
		Def.NoteFieldPreview {
			Name = "NoteField",
			DrawDistanceBeforeTargetsPixels = 600,
			DrawDistanceAfterTargetsPixels = 0,
		},
	}
end

function TW.mapPreview(o)
	local M = TW.M
	local X, Y, W, H = o.x, o.y, o.w, o.h
	local GW = M(62) -- graph width
	local FW = W - GW -- field width
	local text = o.text or TW.text
	local colour = o.colour or function() return color("#FFFFFF") end
	local isOpen = o.isOpen or function() return true end

	-- Etterna's preview normally plays only the song's sample section; the preview plays the whole
	-- song (Etterna's "extended" preview, as Til Death's chart preview does) so every part is reachable.
	-- It is started with accurate seeking (a quick seek into an ogg or mp3 can land "past the end" of
	-- the file, and the song then starts over from its sample, in the middle), and the music is
	-- stopped first, as Til Death does: Etterna ignores a new start of the file that is already playing.
	local extending = false
	local extendedFor = nil -- the song the whole-song preview is playing for
	local function extendPreview()
		local top = SCREENMAN:GetTopScreen()
		if extending or not isOpen() or not (top and top.PlayCurrentSongSampleMusic) then return end
		extending = true
		if pcall(function()
			SOUND:StopMusic()
			top:PlayCurrentSongSampleMusic(true, true)
		end) then extendedFor = GAMESTATE:GetCurrentSong() end
		extending = false
	end
	-- jumps the preview to a share (0 - 1) of the song; when Etterna is playing only its short sample
	-- (it does after a song change), the whole song is started first, or the jump would land back at
	-- the sample's start whenever it is past the sample's end
	local pendingSeek = nil
	local function seek(self, p)
		local top, span = SCREENMAN:GetTopScreen(), TW.previewSongSpan()
		if not (top and top.SetSampleMusicPosition and span) then return end
		p = math.max(0, math.min(1, p))
		if extendedFor ~= GAMESTATE:GetCurrentSong() then
			extendPreview()
			pendingSeek = p
			self:stoptweening():sleep(0.15):queuecommand("Seek")
			return
		end
		top:SetSampleMusicPosition(p * span)
	end

	local f = Def.ActorFrame {}
	f[o.openMessage .. "MessageCommand"] = function(self)
		self:playcommand("Load"); self:playcommand("Fill"); self:playcommand("Set"); extendPreview()
	end
	f.CurrentStepsChangedMessageCommand = function(self) if isOpen() and not (TW.browsingSkip and TW.browsingSkip()) then self:playcommand("Load"); self:playcommand("Fill"); self:playcommand("Set") end end
	-- a new noteskin shows in the open preview at once
	f.TWNoteskinChangedMessageCommand = function(self) if isOpen() then self:playcommand("Load"); self:playcommand("Set") end end
	-- Mirror, Full LN or Inverse turned on or off while it is open
	f.TWModsChangedMessageCommand = function(self) if isOpen() then self:playcommand("Load"); self:playcommand("Set") end end
	f.TWLnModChangedMessageCommand = function(self) if isOpen() then self:playcommand("Load"); self:playcommand("Set") end end
	-- a rate change restarts the music (Etterna's, or the osu! look's own preview): the preview goes on
	-- from where it was, at the new rate
	local rateSeek = nil
	f.CurrentRateChangedMessageCommand = function(self)
		if not isOpen() then return end
		local top, span = SCREENMAN:GetTopScreen(), TW.previewSongSpan()
		local pos = (top and top.GetSampleMusicPosition) and top:GetSampleMusicPosition() or 0
		if span and span > 0 and pos > 0 then rateSeek = { p = math.max(0, math.min(1, pos / span)), t = GetTimeSinceStart() } end
		self:playcommand("Fill"); self:playcommand("Set")
	end
	f.RateSeekCommand = function(self) self:playcommand("Seek") end
	f.PlayingSampleMusicMessageCommand = function(self)
		-- (Etterna's own short sample started: the whole song is played again)
		if not extending then extendedFor = nil end
		extendPreview()
		if rateSeek and GetTimeSinceStart() - rateSeek.t < 2 then
			pendingSeek = rateSeek.p
			rateSeek = nil
			self:stoptweening():sleep(0.15):queuecommand("RateSeek")
		end
	end
	f.CurrentSongChangedMessageCommand = function(self) extendedFor = nil end

	f[#f + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(X, Y):zoomto(FW, H)
		if o.bg then self:diffuse(o.bg) else TW.glassify(self, "field", { 0.03, 0.03, 0.05, 0.88 }) end end }
	-- the graph's side: a see-through panel like osu!'s bottom bar
	f[#f + 1] = Def.Quad { InitCommand = function(self)
		TW.glassify(self:align(0, 0):xy(X + FW, Y):zoomto(GW, H), "panel", { 0.05, 0.05, 0.07, 0.72 })
	end }
	f[#f + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):xy(X + FW, Y):zoomto(1, H):diffuse(color("1,1,1,0.12")) end }
	f[#f + 1] = TW.previewField { x = X + FW / 2, y = Y, w = FW, h = H, edge = true }
	-- the edge the notes come in at: a band in the field's colour, solid where Etterna stops
	-- drawing (notes pop in there and holds are cut off) and fading out below it, so notes and holds
	-- slide in from under it whole
	local fieldCol = o.bg or TW.glassColour("field")
	f[#f + 1] = Def.ActorFrame {
		Name = "Edge",
		InitCommand = function(self) self:visible(false) end,
		TWPreviewEdgeMessageCommand = function(self, p)
			local solid, fade = math.min(H * 0.12, p.note * 0.55), math.min(H * 0.15, p.note * 0.8)
			local c = self:GetChildren()
			local col = { fieldCol[1], fieldCol[2], fieldCol[3], 1 }
			local clear = { fieldCol[1], fieldCol[2], fieldCol[3], 0 }
			if p.rev then
				-- (downscroll: notes come in at the top)
				c.Solid:align(0, 0):xy(X, Y):zoomto(FW, solid):diffuse(col)
				c.Fade:align(0, 0):xy(X, Y + solid):zoomto(FW, fade):diffuse(col):diffusebottomedge(clear)
			else
				c.Solid:align(0, 1):xy(X, Y + H):zoomto(FW, solid):diffuse(col)
				c.Fade:align(0, 1):xy(X, Y + H - solid):zoomto(FW, fade):diffuse(clear):diffusebottomedge(col)
			end
			self:visible(true)
		end,
		Def.Quad { Name = "Solid" },
		Def.Quad { Name = "Fade" },
	}
	-- how hard each moment is, on the MSD scale: the chart's MSD where it is densest, the rest in
	-- proportion to its notes per second; the song starts at the bottom, like the notes coming down
	f[#f + 1] = Def.ActorMultiVertex {
		Name = "Density",
		InitCommand = function(self) self:xy(X + FW + M(2), Y) end,
		FillCommand = function(self)
			local steps = GAMESTATE:GetCurrentSteps()
			local verts = {}
			local ok, gv = pcall(function() return steps and steps:GetCDGraphVectors(math.max(0.05, getCurRateValue())) end)
			local v = ok and gv and gv[1]
			if v and #v > 0 then
				local maxv = 1
				for i = 1, #v do maxv = math.max(maxv, v[i]) end
				local Wd = GW - M(6)
				local bh = H / #v
				local top = TW.msd(steps)
				for i = 1, #v do
					local y1 = H - (i - 1) * bh
					local w = Wd * v[i] / maxv
					local c = colour(top * v[i] / maxv)
					verts[#verts + 1] = { { 0, y1, 0 }, c }; verts[#verts + 1] = { { w, y1, 0 }, c }
					verts[#verts + 1] = { { w, y1 - bh, 0 }, c }; verts[#verts + 1] = { { 0, y1 - bh, 0 }, c }
				end
			end
			self:visible(#verts > 0)
			if #verts > 0 then self:SetDrawState { Mode = "DrawMode_Quads" }:SetVertices(verts) end
		end,
	}
	-- the line that follows the song up the graph; clicking the graph plays from there
	f[#f + 1] = Def.ActorFrame {
		Name = "Playhead",
		InitCommand = function(self) self:xy(X + FW, Y) end,
		OnCommand = function(self)
			TW.everyFrame(self)
			self:SetUpdateFunction(function()
				if not isOpen() then return end
				local top, span = SCREENMAN:GetTopScreen(), TW.previewSongSpan()
				if not (top and top.GetSampleMusicPosition and span and span > 0) then return end
				local p = math.max(0, math.min(1, top:GetSampleMusicPosition() / span))
				self:GetChild("Line"):y(H * (1 - p))
			end)
		end,
		Def.Quad { Name = "Line", InitCommand = function(self) self:align(0, 0.5):zoomto(GW, M(2)):diffuse(color("#FFFFFF")) end },
		TW.button(GW, H, function(self)
			-- (the song starts at the bottom of the graph)
			seek(self, 1 - (INPUTFILTER:GetMouseY() - Y) / H)
		end) .. {
			InitCommand = function(self) self:align(0, 0):zoomto(GW, H):diffusealpha(0) end,
			SeekCommand = function(self)
				local top, span = SCREENMAN:GetTopScreen(), TW.previewSongSpan()
				if pendingSeek and top and top.SetSampleMusicPosition and span then top:SetSampleMusicPosition(pendingSeek * span) end
				pendingSeek = nil
			end,
		},
	}
	-- the chart's MSD in the graph's top corner, on a dark tab so the graph doesn't run through it
	f[#f + 1] = Def.Quad { Name = "MsdBg", InitCommand = function(self) self:align(1, 0):xy(X + W, Y):diffuse({ 0.03, 0.03, 0.05, 0.85 }) end }
	f[#f + 1] = text(M(10), true, function(self) self:align(1, 0):xy(X + W - M(4), Y + M(3)):diffuse(color("0.8,0.8,0.8,1")) end) .. {
		SetCommand = function(self)
			self:settextf("MSD %.1f", TW.msd(GAMESTATE:GetCurrentSteps()))
			self:GetParent():GetChild("MsdBg"):zoomto(self:GetZoomedWidth() + M(8), self:GetZoomedHeight() + M(4))
		end,
	}
	return f
end
