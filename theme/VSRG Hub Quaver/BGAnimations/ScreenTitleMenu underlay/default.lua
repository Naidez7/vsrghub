-- Quaver's main menu: a song's background, the logo, the menu on the left, a "news" card with a
-- random song from your library on the right, a tip under it, and the top and bottom bars.
local M, R = TW.M, TW.R

local function randomSong()
	local songs = SONGMAN:GetAllSongs()
	for _ = 1, 30 do
		local s = songs[math.random(1, math.max(1, #songs))]
		local b = s and s:GetBackgroundPath()
		-- (a song whose picture is gone would show as a pink square)
		if b and b ~= "" and FILEMAN:DoesFileExist(b) then return s end
	end
	return songs[1]
end
local pick = randomSong()

local tips = {
	"Pressing " .. TW.keyLabel("options", "Ctrl+O") .. " opens the options, where you can switch theme, skin and notes.",
	"Pressing " .. TW.keyLabel("keybinds", "Ctrl+K") .. " lists every useful key, and lets you change them.",
	"Your osu! collections and playlists are under Group by > Playlists on song select.",
	"Click the rate on song select to change it by 0.05x (right click to lower it).",
	"Etterna rates every chart with MSD, whichever game it came from.",
	"Type anywhere in a list to search it.",
	TW.keyLabel("mods", "F1") .. " opens the modifiers on song select.",
}

local t = Def.ActorFrame {
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(color("#000000")) end },
	Def.Sprite {
		InitCommand = function(self)
			local p = pick and pick:GetBackgroundPath()
			if p and p ~= "" then
				self:LoadBackground(p):scaletocover(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT):diffusealpha(0.22)
			end
		end
	},
	-- the logo
	QV.logo(M(64)) .. { InitCommand = function(self) self:xy(M(53), M(165)) end },
}

-- the card on the right: a song from your library, in the place of Quaver's news
local CX, CY, CW = R(1037), M(495), M(367)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(CX, CY) end,
	Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(CW, M(195)):diffuse(color("#000000")):diffusealpha(0.75) end },
	Def.Sprite {
		InitCommand = function(self)
			local p = pick and (pick:GetBannerPath() or pick:GetBackgroundPath())
			if p and p ~= "" then self:LoadBackground(p):align(0, 0):scaletoclipped(CW, M(92)) end
		end
	},
	QV.t(M(13), true, function(self) self:align(0, 0.5):xy(M(12), M(112))
		QV.fit(self, pick and (pick:GetDisplayArtist() .. " - " .. pick:GetDisplayMainTitle()) or "No songs yet", CW - M(24)) end),
	QV.t(M(12), true, function(self) self:align(0, 0.5):xy(M(12), M(137)):diffuse(QV.blue)
		QV.fit(self, pick and ("From " .. pick:GetGroupName()) or "", CW - M(24)) end),
	QV.t(M(11.5), false, function(self) self:align(0, 0):xy(M(12), M(152)):wrapwidthpixels((CW - M(24)) / self:GetZoom())
		self:settextf("You have %d songs from Etterna, Quaver, Qwilight and osu! on one wheel, all rated with Etterna's MSD.", SONGMAN:GetNumSongs()) end),
	Def.Quad { InitCommand = function(self) self:align(0, 0):y(M(194)):zoomto(CW, math.max(1, M(2))):diffusealpha(0.8) end },
	-- tip
	Def.Quad { InitCommand = function(self) self:align(0, 0):y(M(214)):zoomto(CW, M(40)):diffuse(color("#000000")):diffusealpha(0.75) end },
	Def.Quad { InitCommand = function(self) self:align(0, 0):y(M(252)):zoomto(CW, math.max(1, M(2))):diffusealpha(0.8) end },
	QV.t(M(12), true, function(self) self:align(0, 0.5):xy(M(12), M(233)):wrapwidthpixels((CW - M(24)) / self:GetZoom())
		self:settext("TIP:  " .. tips[math.random(1, #tips)]) end),
}
-- the image credit on the right edge, rotated like Quaver's
t[#t + 1] = QV.t(M(13), true, function(self)
	self:align(0, 0.5):xy(R(1418), M(720)):rotationz(-90):diffusealpha(0.5)
	QV.fit(self, pick and ("BACKGROUND: " .. pick:GetDisplayMainTitle()) or "", M(260))
end)

t[#t + 1] = QV.navbar()
t[#t + 1] = QV.bottombar(
	{ { "ETTERNA " .. GAMESTATE:GetEtternaVersion(), function() end, nil, 190 },
	  { "VSRG HUB", function() end, nil, 130 } },
	{ { "THEME", function() TW.openOptions() end }, { "OPTIONS", function() TW.toggleOptions() end } }
)
return t
