-- The song select's background (the selected song's picture, full screen) with VSRG Hub's
-- options for it: how dark (bgDim_osu / bgDim_quaver, percent) and how blurred (bgBlur_osu /
-- bgBlur_quaver: 0 off, 1 soft, 2 strong). Each look keeps its own, since their defaults differ
-- (osu! barely dims it, Quaver dims it a lot).
local function key(name) return name .. "_" .. (TW.isQuaver and "quaver" or "osu") end
function TW.bgDim()
	local v = tonumber(TW.settings[key("bgDim")] or "")
	if not v then v = TW.isQuaver and 65 or 18 end
	return math.max(0, math.min(95, v))
end
function TW.bgBlur()
	local v = tonumber(TW.settings[key("bgBlur")] or "") or 0
	return math.max(0, math.min(2, math.floor(v)))
end
function TW.setBgDim(v)
	TW.saveSetting(key("bgDim"), tostring(math.max(0, math.min(95, math.floor(v + 0.5)))))
	MESSAGEMAN:Broadcast("TWBackgroundChanged")
end
function TW.setBgBlur(v)
	TW.saveSetting(key("bgBlur"), tostring(math.max(0, math.min(2, v))))
	MESSAGEMAN:Broadcast("TWBackgroundChanged")
end
local NTAPS = 17
TW.BLUR_LABEL = { [0] = "Off", "Soft", "Strong" }

-- The background, as an ActorFrame: name its frame with o.name (the osu! look's frosted panels
-- show this frame, blurred again). The blur: with OpenGL the picture is drawn small through
-- ActorFrameTextures and stretched back (smooth); with Direct3D (no drawing into textures there,
-- see TW.canFrost) a ring of shifted, faded copies of it (softer, a little ghostly).
function TW.songBackground(o)
	o = o or {}
	local W, H = SCREEN_WIDTH, SCREEN_HEIGHT
	local function cover(self) self:align(0.5, 0.5):scaletocover(0, 0, W, H) end
	local gl = TW.canFrost and TW.canFrost()
	local want = nil

	local root = Def.ActorFrame {}
	-- (the blur passes: the picture at a quarter of the screen's size, then at a tenth, averaged)
	local sizes = { { math.floor(W / 4), math.floor(H / 4) }, { math.floor(W / 10), math.floor(H / 10) } }
	if gl then
		local chain = Def.ActorFrame { Name = "BlurChain" }
		for i, sz in ipairs(sizes) do
			local f = Def.ActorFrameTexture {
				Name = "P" .. i,
				InitCommand = function(self) self:SetWidth(sz[1]):SetHeight(sz[2]):EnableAlphaBuffer(false):Create() end,
			}
			if i == 1 then
				f[#f + 1] = Def.ActorProxy { Name = "Proxy", InitCommand = function(self) self:zoom(sz[1] / W) end }
			else
				local n = 0
				for dy = -1, 1 do
					for dx = -1, 1 do
						n = n + 1
						local k = n
						f[#f + 1] = Def.Sprite { Name = "S" .. k, InitCommand = function(self) self:align(0, 0):xy(dx * 0.9, dy * 0.9):diffusealpha(1 / k) end }
					end
				end
			end
			f[#f + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(sz[1], sz[2]):diffuse({ 0, 0, 0, 1 }):blend("BlendMode_Add") end }
			chain[#chain + 1] = f
		end
		root[#root + 1] = chain
		-- (the snapshot of the picture as shown, taken when the song changes; drawn only then)
		root[#root + 1] = Def.ActorFrameTexture {
			Name = "Snap",
			InitCommand = function(self) self:SetWidth(math.floor(W / 2)):SetHeight(math.floor(H / 2)):EnableAlphaBuffer(false):Create():visible(false) end,
			Def.ActorProxy { Name = "Proxy", InitCommand = function(self) self:zoom(0.5) end },
		}
	end

	local bg = Def.ActorFrame {
		Name = o.name or "SongBackground",
		InitCommand = function(self) if o.init then o.init(self) end end,
		OnCommand = function(self)
			if not gl then return end
			-- the passes draw the sharp picture small, then average it
			local chain = self:GetParent():GetChild("BlurChain")
			if not chain then return end
			chain:GetChild("P1"):GetChild("Proxy"):SetTarget(self:GetChild("Pic"):GetChild("Sharp"))
			local snap = self:GetParent():GetChild("Snap")
			if snap then snap:GetChild("Proxy"):SetTarget(self:GetChild("Pic")) end
			local src = chain:GetChild("P1"):GetTexture()
			local p2 = chain:GetChild("P2")
			if src then
				local l, t, r, b = src:GetTextureCoordRect(0)
				for k = 1, 9 do p2:GetChild("S" .. k):SetTexture(src):customtexturerect(l, t, r, b):zoomto(sizes[2][1], sizes[2][2]) end
			end
			self:playcommand("Look")
		end,
		CurrentSongChangedMessageCommand = function(self)
			-- (the osu! stable list scrolled past songs: the picked song's picture stays)
			if TW.browsingSkip and TW.browsingSkip() then return end
			local s = GAMESTATE:GetCurrentSong()
			-- (the list on a pack's name: the last song's picture stays, as osu!'s does, instead of
			-- the screen going dark and the next song's picture coming up from black)
			if not s then return end
			self:stoptweening()
			want = TW.bigPicture(s)
			if not want then return end
			-- (the same picture again, e.g. the game's song put back to the picked one after a
			-- scroll: nothing to do, or it would fade in over itself)
			if want == self.shownPath then return end
			self.changedAt = GetTimeSinceStart()
			-- a full-size picture is only loaded once the list rests on the song: while it runs
			-- past songs (a long spin of the mouse wheel), loading each one's picture made it stutter
			self:sleep(0.08):queuecommand("Wait")
		end,
		WaitCommand = function(self)
			local top = SCREENMAN:GetTopScreen()
			local w = top and top.GetMusicWheel and top:GetMusicWheel()
			if (w and not w:IsSettled()) or GetTimeSinceStart() - (self.changedAt or 0) < 0.12 then
				self:sleep(0.05):queuecommand("Wait")
				return
			end
			self:playcommand("Show")
		end,
		-- (the old picture stays under the new one while it fades in, as osu!'s do, instead of the
		-- screen dipping to dark between songs. Sharp, it's simply loaded again; blurred with OpenGL,
		-- a snapshot of the blurred one is taken first, one frame before the new picture comes in;
		-- blurred with Direct3D, the soft copies are copied)
		ShowCommand = function(self)
			local prev = self:GetChild("Prev")
			local psharp, ptaps = prev:GetChild("Sharp"), prev:GetChild("Taps")
			local snap = gl and self:GetParent():GetChild("Snap")
			self.prevKind = nil
			if ptaps then ptaps:visible(false) end
			psharp:visible(true)
			if want and self.shownPath and self.shownPath ~= want then
				local taps = self:GetChild("Pic"):GetChild("Taps")
				if TW.bgBlur() == 0 then
					psharp:LoadBackground(self.shownPath); cover(psharp)
					self.prevKind = "sharp"
				elseif ptaps and taps then
					psharp:visible(false)
					for i = 1, NTAPS do
						local c, src = ptaps:GetChild("T" .. i), taps:GetChild("T" .. i)
						c:LoadBackground(self.shownPath); cover(c)
						c:xy(src:GetX(), src:GetY()):diffusealpha(src:GetDiffuseAlpha())
					end
					ptaps:visible(true)
					self.prevKind = "taps"
				elseif snap and snap:GetTexture() then
					snap:visible(true)
					self.prevKind = "snap"
					self:sleep(0.02):queuecommand("Swap")
					return
				end
			end
			self:playcommand("Swap")
		end,
		SwapCommand = function(self)
			local sharp = self:GetChild("Pic"):GetChild("Sharp")
			local taps = self:GetChild("Pic"):GetChild("Taps")
			local prev = self:GetChild("Prev")
			if self.prevKind == "snap" then
				local snap = self:GetParent():GetChild("Snap")
				snap:visible(false)
				local tex = snap:GetTexture()
				local l, t, r, b = tex:GetTextureCoordRect(0)
				prev:GetChild("Sharp"):SetTexture(tex):customtexturerect(l, t, r, b):align(0, 0):xy(0, 0):zoomto(W, H)
			end
			if self.prevKind then
				prev:stoptweening():visible(true):diffusealpha(1):sleep(0.45):queuecommand("Off")
			else
				prev:stoptweening():visible(false)
			end
			self.shownPath = want
			if want then
				sharp:LoadBackground(want); cover(sharp)
				if taps and TW.bgBlur() > 0 then
					for i = 1, NTAPS do local c = taps:GetChild("T" .. i); c:LoadBackground(want); cover(c) end
				end
				self:GetChild("Pic"):stoptweening():diffusealpha(0):decelerate(0.4):diffusealpha(1)
				self:playcommand("Look")
			else
				self:GetChild("Pic"):stoptweening():decelerate(0.3):diffusealpha(0)
			end
		end,
		TWBackgroundChangedMessageCommand = function(self)
			-- (the soft copies load the picture only once the blur is on)
			local taps = self:GetChild("Pic"):GetChild("Taps")
			if taps and want and TW.bgBlur() > 0 then
				for i = 1, NTAPS do local c = taps:GetChild("T" .. i); c:LoadBackground(want); cover(c) end
			end
			self:playcommand("Look")
		end,
		LookCommand = function(self)
			local blur = TW.bgBlur()
			self:GetChild("Dim"):diffusealpha(TW.bgDim() / 100)
			local pic = self:GetChild("Pic")
			local blurred = pic:GetChild("Blurred")
			local taps = pic:GetChild("Taps")
			if gl and blurred then
				local chain = self:GetParent():GetChild("BlurChain")
				local tex = chain and chain:GetChild("P" .. blur) and chain:GetChild("P" .. blur):GetTexture()
				if blur > 0 and tex then
					local l, t, r, b = tex:GetTextureCoordRect(0)
					blurred:SetTexture(tex):customtexturerect(l, t, r, b):zoomto(W, H):visible(true)
				else
					blurred:visible(false)
				end
			elseif taps then
				local on = blur > 0
				taps:visible(on)
				pic:GetChild("Sharp"):visible(not on)
				local r = TW.M(blur == 2 and 9 or 4)
				for n = 1, NTAPS do
					local c = taps:GetChild("T" .. n)
					c:xy(W / 2 + math.cos(c.twAngle) * r * c.twRing, H / 2 + math.sin(c.twAngle) * r * c.twRing):diffusealpha(1 / n)
				end
			end
		end,
		Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(o.base or color("#000000")) end },
	}
	-- the centre and two rings of eight around it, each faded so they add up to one picture
	local function makeTaps()
		local taps = Def.ActorFrame { Name = "Taps", InitCommand = function(self) self:visible(false) end }
		taps[#taps + 1] = Def.Sprite { Name = "T1", InitCommand = function(self) self.twAngle, self.twRing = 0, 0 end }
		for ring = 1, 2 do
			for i = 0, 7 do
				local a = (i + (ring == 2 and 0.5 or 0)) * math.pi / 4
				taps[#taps + 1] = Def.Sprite { Name = "T" .. (#taps + 1), InitCommand = function(self) self.twAngle, self.twRing = a, ring * 0.5 + 0.25 end }
			end
		end
		return taps
	end
	-- the picture before, under the new one while it fades in
	local prev = Def.ActorFrame { Name = "Prev", InitCommand = function(self) self:visible(false) end,
		OffCommand = function(self) self:visible(false) end, Def.Sprite { Name = "Sharp" } }
	if not gl then prev[#prev + 1] = makeTaps() end
	bg[#bg + 1] = prev
	local pic = Def.ActorFrame { Name = "Pic", Def.Sprite { Name = "Sharp" } }
	if gl then
		pic[#pic + 1] = Def.Sprite { Name = "Blurred", InitCommand = function(self) self:align(0, 0):visible(false) end }
	else
		pic[#pic + 1] = makeTaps()
	end
	bg[#bg + 1] = pic
	bg[#bg + 1] = Def.Quad { Name = "Dim", InitCommand = function(self) self:FullScreen():diffuse(color("#000000")):diffusealpha(TW.bgDim() / 100) end }
	root[#root + 1] = bg
	return root
end

-- The song's small picture for the list: the launcher makes one per converted song (thumbs.go),
-- since a background of 4K in a panel's corner is slow to read and looks wrong shrunk that far.
-- The full background when there's none (a song not converted, or one not made yet).
local thumbs = {}
function TW.thumbPath(song)
	if not song then return nil end
	local dir = song:GetSongDir()
	local t = dir and thumbs[dir]
	if t then return t end
	if dir and FILEMAN:DoesFileExist(dir .. "vsrghub-thumb-mipmaps.jpg") then
		thumbs[dir] = dir .. "vsrghub-thumb-mipmaps.jpg"
		return thumbs[dir]
	end
	local bg = song:GetBackgroundPath()
	return (bg and bg ~= "") and bg or nil
end

-- The song's background for a screen: the launcher's 1080p copy when the original is bigger (a 4K
-- photo takes long to read on each change of song), else the original.
local bigs = {}
function TW.bigPicture(song)
	if not song then return nil end
	local dir = song:GetSongDir()
	local t = dir and bigs[dir]
	if t then return t end
	if dir and FILEMAN:DoesFileExist(dir .. "vsrghub-bg.jpg") then
		bigs[dir] = dir .. "vsrghub-bg.jpg"
		return bigs[dir]
	end
	local bg = song:GetBackgroundPath()
	return (bg and bg ~= "") and bg or nil
end
