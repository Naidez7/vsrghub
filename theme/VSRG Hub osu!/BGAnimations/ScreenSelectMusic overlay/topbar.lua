-- osu!'s song select, top: the skin's songselect-top with the beatmap info lines, Group / Sort and
-- the search bar at the top right. Etterna's MSD stands in for osu!'s star rating.
TW.useInterfaceSkin()
local M, R = TW.M, TW.R
local white = color("#FFFFFF")

local function fmtTime(s)
	s = math.max(0, math.floor(s))
	return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end
local function commas(n)
	local neg = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (neg and "-" or "") .. (out:gsub("^,", ""))
end
local skillNames = { "Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical" }

local function topSkill(steps)
	local best, name = 0, ""
	for i = 2, #skillNames do
		local v = TW.msd(steps, i)
		if v > best then best, name = v, skillNames[i] end
	end
	return name
end

local function info(self)
	local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
	local c = self:GetChildren()
	if not song then
		for _, n in ipairs({ "L1", "L2", "L3", "L4", "L5" }) do c[n]:settext("") end
		return
	end
	local rate = getCurRateValue()
	c.L1:settext(song:GetDisplayArtist() .. " - " .. song:GetDisplayMainTitle() .. (steps and (" [" .. TW.diffName(steps) .. "]") or ""))
	local by = TW.author(song)
	c.L2:settext("Mapped by " .. (by ~= "" and by or song:GetGroupName()))
	local bpms = song:GetDisplayBpms()
	local bpm = math.abs(bpms[1] - bpms[2]) < 0.5 and string.format("%d", bpms[1] * rate + 0.5)
		or string.format("%d-%d", bpms[1] * rate + 0.5, bpms[2] * rate + 0.5)
	local rv = steps and steps:GetRadarValues(PLAYER_1)
	local function radar(k) return rv and rv:GetValue(k) or 0 end
	local len = (steps and steps:GetLengthSeconds() or song:MusicLengthSeconds()) / rate
	c.L3:settextf("Length: %s BPM: %s Objects: %d", fmtTime(len), bpm, radar("RadarCategory_Notes") + radar("RadarCategory_Holds"))
	c.L4:settextf("Notes: %d Holds: %d Mines: %d", radar("RadarCategory_Notes"), radar("RadarCategory_Holds"), radar("RadarCategory_Mines"))
	local m = TW.msd(steps)
	local skill = steps and topSkill(steps) or ""
	c.L5:settextf("Keys:%d Rate:%s Pack:%s MSD: %.2f%s", TW.keys(steps), getCurRateDisplayString(true),
		song:GetGroupName(), m, skill ~= "" and (" (" .. skill .. ")") or "")
end

local t = Def.ActorFrame {
	-- (not while you browse the osu! stable list: the picked song stays shown)
	CurrentSongChangedMessageCommand = function(self) if not TW.browsingSkip() then self:playcommand("Info") end end,
	CurrentStepsChangedMessageCommand = function(self) if not TW.browsingSkip() then self:playcommand("Info") end end,
	CurrentRateChangedMessageCommand = function(self) self:playcommand("Info") end,
	OnCommand = function(self) self:playcommand("Info") end,
	CodeMessageCommand = function(self, params)
		if params.Name == "NextRate" or params.Name == "PrevRate" or params.Name == "NextScore" or params.Name == "PrevScore" then
			ChangeMusicRate(nil, params)
			MESSAGEMAN:Broadcast("CurrentRateChanged")
		end
	end,
}

-- osu! draws the tabs, Group / Sort and the search text first and the skin's top bar art over them
-- (songselect-top, and the mode-*-small icon some skins make a whole top bar of): a skin whose art
-- has its own words there hides osu!'s; other art lets them show through
local under = Def.ActorFrame {}
-- (the tabs and words under the art, and the art: default.lua puts these under the bottom buttons'
-- art, TW.stableTopArt, as osu! draws them: skins that make selection-mode a whole-screen frame draw
-- their search box over the top bar art)
local art = Def.ActorFrame {}
TW.stableTopArt = art

-- top bar art: the skin's, or osu!'s dark band fading into the picture with a thin line of the
-- interface colour under it
if TW.has("songselect_top") then
	-- (osu! scales it evenly to fit the screen, from the top left)
	art[#art + 1] = TW.sprite("songselect_top", function(self)
		local w, h = self:GetWidth(), self:GetHeight()
		if w > 0 and h > 0 then self:zoom(math.min(SCREEN_WIDTH / w, SCREEN_HEIGHT / h)) end
		self:align(0, 0)
	end)
elseif TW.fallback("songselect_top") then
	art[#art + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):zoomto(SCREEN_WIDTH, M(98)):diffuse({ 0, 0, 0, 0.78 }):diffusebottomedge({ 0.02, 0.02, 0.04, 0.55 }) end }
	art[#art + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):y(M(98)):zoomto(SCREEN_WIDTH, M(26)):diffuse({ 0, 0, 0, 0.35 }):diffusebottomedge({ 0, 0, 0, 0 }) end }
	art[#art + 1] = Def.Quad { InitCommand = function(self) self:align(0, 0):y(M(97)):zoomto(SCREEN_WIDTH * 0.62, M(2)):diffuse(TW.pink):diffuserightedge({ TW.pink[1], TW.pink[2], TW.pink[3], 0 }) end }
end
-- osu!'s own parts of the top bar (Group / Sort, the tabs, "Search:") go over songselect-top (they
-- show bright over see-through art) but under the mode-*-small and selection-mode frames some skins
-- draw over the whole screen with their own words
art[#art + 1] = under
-- (osu! centres the skin's mode-*-small on the mode button at the bottom, whatever its size: some
-- skins draw their whole top bar into it)
-- (measured against osu!: a few pixels right of the mode button's middle)
-- (default.lua draws it right over the mode button's art, under the back button's: skins build on
-- that order, e.g. a selection-mode with dark shadows under a mode-*-small's white shapes, or a
-- menu-back that is a whole-screen frame)
TW.stableModeIcon = TW.sprite("mode_icon", function(self)
	self:xy(TW.U * 270.85, SCREEN_HEIGHT - TW.U * 56)
	-- (one as wide as half the screen is such a top bar)
	if self:GetZoomedWidth() > SCREEN_WIDTH * 0.5 then TW.stableOwnTopArt = true end
end) .. { OnCommand = function() MESSAGEMAN:Broadcast("TWTopArt") end }

-- beatmap info lines
t[#t + 1] = Def.ActorFrame {
	InfoCommand = function(self)
		local ok, err = pcall(info, self)
		if not ok then self:GetChild("L1"):settext("(info: " .. tostring(err) .. ")") end
	end,
	-- (osu!'s sizes and places, measured on osu! at 1080p: no outlines; the third line and the
	-- small last one bold)
	TW.text(M(17.4), false, function(self) self:align(0, 0.5):xy(M(41.7), M(9.5)):maxwidth(M(780) / self:GetZoom()):shadowlength(0) end) .. { Name = "L1" },
	TW.text(M(12), false, function(self) self:align(0, 0.5):xy(M(43.2), M(29.6)):maxwidth(M(760) / self:GetZoom()):shadowlength(0) end) .. { Name = "L2" },
	TW.text(M(12.1), true, function(self) self:align(0, 0.5):xy(M(3.5), M(50)):maxwidth(M(800) / self:GetZoom()):shadowlength(0) end) .. { Name = "L3" },
	TW.text(M(11.4), false, function(self) self:align(0, 0.5):xy(M(3.5), M(69.4)):maxwidth(M(800) / self:GetZoom()):shadowlength(0) end) .. { Name = "L4" },
	TW.text(M(7.4), true, function(self) self:align(0, 0.5):xy(M(3.5), M(88)):maxwidth(M(800) / self:GetZoom()):shadowlength(0) end) .. { Name = "L5" },
	-- a round badge with the key count where osu! has its mode icon
	Def.ActorFrame {
		InitCommand = function(self) self:xy(M(19.5), M(19)) end,
		TW.box { w = M(25), h = M(25), r = M(12.5), ax = 0.5, ay = 0.5, col = TW.pink },
		TW.text(M(9), true, function(self) self:align(0.5, 0.5):shadowlength(0) end) .. {
			InfoCommand = function(self) local st = GAMESTATE:GetCurrentSteps(); self:settext(st and (TW.keys(st) .. "K") or "") end,
		},
	},
}
-- ranked-status style mark in the corner: the skin's mode icon

-- Group / Sort, as in osu!: each opens its list below it. Etterna has one "sort order" that both
-- groups and orders the wheel, so both lists set it; Collections and Favourites filter the wheel.
local groupItems = {
	{ "No Grouping", "Ungrouped" }, { "By Artist", "Artist" }, { "By BPM", "BPM" }, { "By Creator", "Author" },
	{ "By Date Added", "DateAdded" }, { "By Difficulty", "Overall" }, { "By Genre", "Genre" }, { "By Length", "Length" },
	{ "By Pack", "Group" }, { "By Pattern", "@patterns" }, { "By Rank Achieved", "TopGrades" }, { "By Title", "Title" }, { "Collections", "@collections" },
	{ "Favourites", "Favorites" },
}
local sortItems = {
	{ "By Artist", "Artist" }, { "By BPM", "BPM" }, { "By Creator", "Author" }, { "By Date Added", "DateAdded" },
	{ "By Difficulty", "Overall" }, { "By Length", "Length" }, { "By Rank Achieved", "TopGrades" }, { "By Title", "Title" },
	{ "By Stream", "Stream" }, { "By Jumpstream", "Jumpstream" }, { "By Handstream", "Handstream" }, { "By Stamina", "Stamina" },
	{ "By Jackspeed", "JackSpeed" }, { "By Chordjack", "Chordjack" }, { "By Technical", "Technical" },
}
local function curSort() return ToEnumShortString(GAMESTATE:GetSortOrder() or "SortOrder_Group") end
local function setSort(name)
	if name == "@collections" then TW.openCollections() return end
	if name == "@patterns" then TW.openPatterns() return end
	local w = SCREENMAN:GetTopScreen():GetMusicWheel()
	if w then w:ChangeSort("SortOrder_" .. name) end
	MESSAGEMAN:Broadcast("TWSortChanged")
end
local function labelFor(list)
	local cur = curSort()
	for _, it in ipairs(list) do if it[2] == cur then return it[1] end end
	-- (grouped by pack, Etterna orders each pack's songs by title)
	return list == groupItems and "By Pack" or "By Title"
end
TW.dropOpen = nil
local function dropdown(name, label, x0, x1, list)
	local w = M(x1 - x0)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(R(x0), M(44)) end,
		-- (osu!'s: a dark box with a thin white frame)
		TW.box { w = w, h = M(24), r = M(5), ay = 0.5, col = { 0, 0, 0, 0.5 } } .. { Name = "Bg" },
		TW.box { w = w, h = M(24), r = M(5), ay = 0.5, tex = "ring", stroke = M(1.2), col = { 1, 1, 1, 0.9 } } .. { Name = "Edge" },
		TW.text(M(13.3), false, function(self) self:align(0, 0.5):x(M(5)):shadowlength(0) end) .. {
			OnCommand = function(self) self:playcommand("TWSortChanged") end,
			TWSortChangedMessageCommand = function(self) self:settext(labelFor(list)):maxwidth((w - M(34)) / self:GetZoom()) end
		},
		TW.icon("chevron-down", M(16), function(self) self:x(w - M(16)) end),
		TW.button(w, M(26), function()
			TW.dropOpen = TW.dropOpen ~= name and name or nil
			MESSAGEMAN:Broadcast("TWDrop", { name = TW.dropOpen })
		end, function(self, on) TW.setBox(self:GetParent():GetChild("Bg"), { col = on and { 0.2, 0.2, 0.2, 0.7 } or { 0, 0, 0, 0.5 } }) end) ..
			{ InitCommand = function(self) self:align(0, 0.5):zoomto(w, M(26)):diffusealpha(0) end }
	}
end
-- the open list, drawn last so it sits over the tabs and the search bar
local function dropList(name, x0, x1, list)
	local w, rowH = M(x1 - x0), M(22)
	local f = Def.ActorFrame {
		InitCommand = function(self) self:xy(R(x0), M(56)):visible(false):z(30) end,
		TWDropMessageCommand = function(self, p)
			self:visible(p.name == name)
			if p.name == name then self:playcommand("Fill") end
		end,
		-- a click anywhere else closes it
		TW.button(1, 1, function() TW.dropOpen = nil; MESSAGEMAN:Broadcast("TWDrop", {}) end) ..
			{ InitCommand = function(self) self:zoomto(SCREEN_WIDTH * 4, SCREEN_HEIGHT * 4) end },
		TW.shadow { w = w, h = #list * rowH + M(8), spread = M(12), alpha = 0.6 },
		TW.box { w = w, h = #list * rowH + M(8), r = M(6), col = { 0.10, 0.10, 0.14, 0.97 }, col2 = { 0.07, 0.07, 0.10, 0.97 } },
	}
	for i, it in ipairs(list) do
		f[#f + 1] = Def.ActorFrame {
			InitCommand = function(self) self:y(M(4) + (i - 0.5) * rowH):z(1) end,
			FillCommand = function(self)
				local on = it[2] == curSort() or (it[2] == "@collections" and TW.collection ~= nil and not TW.collection.pattern)
					or (it[2] == "@patterns" and TW.collection ~= nil and TW.collection.pattern ~= nil)
				self:GetChild("Text"):diffuse(on and TW.yellow or white)
			end,
			TW.box { w = w - M(8), h = rowH - M(2), r = M(4), ay = 0.5, col = TW.pink, init = function(self) self:x(M(4)):diffusealpha(0) end } .. { Name = "Hl" },
			TW.text(M(13), false, function(self) self:align(0, 0.5):x(M(12)):settext(it[1]) end) .. { Name = "Text" },
			TW.button(w, rowH, function()
				TW.dropOpen = nil
				MESSAGEMAN:Broadcast("TWDrop", {})
				setSort(it[2])
			end, function(self, on) self:GetParent():GetChild("Hl"):stoptweening():linear(0.08):diffusealpha(on and 0.45 or 0) end) ..
				{ InitCommand = function(self) self:align(0, 0.5):zoomto(w, rowH):diffusealpha(0) end },
		}
	end
	return f
end
t[#t + 1] = dropdown("group", "Group", 948, 1152, groupItems)
t[#t + 1] = dropdown("sort", "Sort", 1235, 1440, sortItems)
-- Group / Sort words left of their lists and the green "Search:": osu!'s own top bar has them; a
-- skin with top bar art of its own (songselect-top, or a mode-*-small made into a whole top bar)
-- has its own words there and osu! shows none
TW.stableOwnTopArt = TW.has("songselect_top")
-- (osu!'s: big, light, white with a faint blue edge)
local function bigWord(word, x)
	local f, z = TW.pickFont(TW.light or TW.font, M(19))
	return LoadFont(f) .. { Name = word .. "Word", InitCommand = function(self)
		self:zoom(z):align(1, 0.5):xy(R(x), M(42.8)):settext(word):diffuse(color("#FFFFFF"))
			:shadowlength(1):shadowcolor(TW.rgb(60, 120, 200, 0.6))
	end }
end
under[#under + 1] = bigWord("Group", 940)
under[#under + 1] = bigWord("Sort", 1228)
-- osu!'s quick tabs under them, words and all: the skin's selection-tab at its own size, tinted as
-- osu! tints it (crimson, the one in use white), or osu!'s own crimson tabs. They are under the top
-- bar art: skins that write their own tabs into it cover osu!'s, leaving holes for the tab art (a
-- heart, a diamond...), black where the skin blanks its selection-tab; see-through art shows them.
local CRIMSON = { 220 / 255, 20 / 255, 60 / 255, 1 }
local tabs = { { "Collections", 789, 123, "Collections" }, { "Recently Added", 915, 123, "DateAdded" }, { "By Artist", 1041, 123, "Artist" },
	{ "By Difficulty", 1168, 123, "Overall" }, { "No Grouping", 1294, 143, "Ungrouped" } }
local tabArt, tabBlank = TW.has("selection_tab"), TW.blank("selection_tab")
for _, tab in ipairs(tabs) do
	local tw, th = M(tab[3]), M(19)
	local function isOn() return (tab[4] == "Collections" and TW.collection ~= nil) or curSort() == tab[4] end
	under[#under + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(R(tab[2]), M(70)) end,
		OnCommand = function(self) self:playcommand("TWSortChanged"); self:playcommand("TWTopArt") end,
		TWCollectionChangedMessageCommand = function(self) self:playcommand("TWSortChanged") end,
		TWTopArtMessageCommand = function(self)
			local c = self:GetChildren()
			c.Hole:visible(TW.stableOwnTopArt == true and tabBlank)
		end,
		TWSortChangedMessageCommand = function(self)
			local on = isOn()
			local c = self:GetChildren()
			if c.Art then c.Art:diffuse(on and { 1, 1, 1, 1 } or CRIMSON) end
			if c.Tab then TW.setBox(c.Tab, { col = on and { 1, 1, 1, 1 } or CRIMSON }) end
			local word = tab[1]
			if tab[4] == "Collections" and TW.collection then word = (TW.collection.pattern and "Pattern: " or "Collection: ") .. TW.collection.name end
			c.Word:settext(word):maxwidth((tw - M(8)) / c.Word:GetZoom()):diffuse(on and TW.rgb(30, 30, 40) or white)
		end,
		Def.Quad { Name = "Hole", InitCommand = function(self) self:align(0, 0.5):zoomto(th * 1.1, th * 1.1):diffuse(color("#000000")):visible(false) end },
		tabArt and TW.sprite("selection_tab", function(self) self:align(0, 0.5) end) .. { Name = "Art" }
			or ((not tabBlank) and TW.box { w = tw, h = th * 1.12, r = th * 0.56, ay = 0.5, col = CRIMSON, init = function(self) self:x(M(7.5)) end } .. { Name = "Tab" } or Def.Actor { Name = "None" }),
		TW.text(M(9.1), true, function(self) self:align(0.5, 0.5):x(tw / 2 + ((tabArt or tabBlank) and 0 or M(7.5))):shadowlength(0) end) .. { Name = "Word" },
		TW.button(tw, th, function() if tab[4] == "Collections" then TW.openCollections() else setSort(tab[4]) end end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(tw, th):diffusealpha(0) end }
	}
end

-- search bar (under the skin's art too)
under[#under + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(R(1084), M(104)) end,
	-- (osu!'s: a dark band to the screen's edge, green "Search:" and the words in white)
	Def.Quad { Name = "Bg", InitCommand = function(self) self:align(0, 0.5):x(-M(16)):zoomto(SCREEN_WIDTH - R(1084) + M(16), M(46)):diffuse({ 0, 0, 0, 0.5 }):y(M(6)) end,
		TWTopArtMessageCommand = function(self) self:visible(not TW.stableOwnTopArt) end, OnCommand = function(self) self:playcommand("TWTopArt") end,
		TWSearchMessageCommand = function(self, p) self:diffusealpha(p.active and 0.7 or 0.5) end },
	-- (osu! writes it whatever the skin: art over it hides it)
	TW.text(M(13.5), true, function(self) self:align(0, 0.5):x(0):settext("Search:"):diffuse(TW.rgb(170, 255, 50)):shadowlength(0) end) .. { Name = "Label" },
}
-- (the words typed and the matches over the skin's art, as osu! writes them)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(R(1084), M(104)) end,
	-- (osu!'s: no outline, a little smaller than the info lines)
	TW.text(M(13.5), true, function(self) self:align(0, 0.5):x(M(70)):shadowlength(0):maxwidth((SCREEN_WIDTH - R(1156) - M(30)) / self:GetZoom()) end) .. {
		OnCommand = function(self)
			-- (osu! writes the words at the same place whatever the label)
			self:x(M(73))
			self:playcommand("TWSearch", { text = "", active = false })
		end,
		TWSearchMessageCommand = function(self, p)
			if p.text ~= "" then self:settext(p.text):diffuse(white)
			elseif p.active then self:settext(""):diffuse(white)
			else self:settext("Type to search!"):diffuse(white) end
		end
	},
	-- osu!'s "N matches found!" under the words while searching
	TW.text(M(8.5), true, function(self) self:align(0, 0.5):xy(-M(3), M(17)):shadowlength(0) end) .. {
		Name = "Matches",
		TWSearchMessageCommand = function(self, p) self.text = p.text; self:playcommand("Count") end,
		TWSearchResultsMessageCommand = function(self) self:playcommand("Count") end,
		CountCommand = function(self)
			if not self.text or self.text == "" then self:settext("") return end
			local n = 0
			pcall(function() n = #SCREENMAN:GetTopScreen():GetMusicWheel():GetSongs() end)
			self:settext(n == 0 and "No matches found. Hit ESC to reset." or (n == 1 and "1 match found!" or (n .. " matches found!")))
		end,
	},
	TW.button(SCREEN_WIDTH, M(28), function() MESSAGEMAN:Broadcast("TWStartSearch") end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(SCREEN_WIDTH, M(28)):diffusealpha(0) end }
}
-- Etterna's MSD for each pattern type in the selected chart, as one more line of the beatmap info
-- (each in its MSD colour), where osu! ends its info lines
local skillShort = { { "Stream", 2 }, { "JS", 3 }, { "HS", 4 }, { "Stamina", 5 }, { "Jack", 6 }, { "CJ", 7 }, { "Tech", 8 } }
local skills = Def.ActorFrame {
	InitCommand = function(self) self:xy(M(3.5), M(101)) end,
	CurrentStepsChangedMessageCommand = function(self) if not TW.browsingSkip() then self:stoptweening():queuecommand("Fill") end end,
	CurrentSongChangedMessageCommand = function(self) if not TW.browsingSkip() then self:stoptweening():queuecommand("Fill") end end,
	CurrentRateChangedMessageCommand = function(self) self:stoptweening():queuecommand("Fill") end,
	OnCommand = function(self) self:queuecommand("Fill") end,
	FillCommand = function(self)
		local steps = GAMESTATE:GetCurrentSteps()
		self:visible(steps ~= nil)
		if not steps then return end
		local x = 0
		for i, sk in ipairs(skillShort) do
			local v = TW.msd(steps, sk[2])
			local l, n = self:GetChild("L" .. i), self:GetChild("V" .. i)
			l:x(x)
			x = x + l:GetZoomedWidth() + M(1)
			n:settext(string.format("%.2f", v)):diffuse(byMSD(v)):x(x)
			x = x + n:GetZoomedWidth() + M(5)
		end
	end,
}
for i, sk in ipairs(skillShort) do
	skills[#skills + 1] = TW.text(M(7.4), true, function(self) self:align(0, 0.5):settext(sk[1] .. ":"):shadowlength(0) end) .. { Name = "L" .. i }
	skills[#skills + 1] = TW.text(M(7.4), true, function(self) self:align(0, 0.5):shadowlength(0) end) .. { Name = "V" .. i }
end
t[#t + 1] = skills

local leftModes = { { "Ranking", "local" }, { "Ranking", "hub" }, { "Ranking", "online" }, { "Preview" } }
function TW.osuLeftStep(d)
	local cur = 1
	if TW.osuLeft == "Preview" then cur = 4 elseif TW.rankSource == "hub" then cur = 2 elseif TW.rankSource == "online" then cur = 3 end
	local m = leftModes[(cur - 1 + d) % #leftModes + 1]
	TW.osuLeft = m[1]
	if m[2] and m[2] ~= TW.rankSource and TW.setRankSource then TW.setRankSource(m[2]) end
	MESSAGEMAN:Broadcast("TWOsuLeft")
end
-- osu!'s ranking box under the top bar (the skin's button art when it has some), with the rate
-- button where osu! has its round button: left click -0.05x, right click +0.05x, as in Etterna
local RW, RH = M(328), M(25)
-- (osu! draws this box itself, like the Group / Sort lists, whatever the skin)
local function rankBox()
	return Def.ActorFrame {
		Name = "Box",
		TW.box { w = RW, h = RH, r = M(4), ay = 0.5, col = { 0, 0, 0, 0.55 } },
		TW.box { w = RW, h = RH, r = M(4), ay = 0.5, tex = "ring", stroke = M(1.2), col = { 1, 1, 1, 0.9 } },
	}
end
t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(M(7.5), M(137.6)) end,
		rankBox(),
		Def.Quad { Name = "Hover", InitCommand = function(self) self:align(0, 0.5):zoomto(RW, RH):diffuse({ 1, 1, 1, 0 }) end },
		-- osu!'s ranking type box; here it switches the left side between your local ranking, the online
		-- one and a preview of the chart (as Quaver's View Map: click its graph to jump, Tab to play
		-- from there)
		TW.text(M(13.3), false, function(self) self:align(0, 0.5):x(M(5)):shadowlength(0) end) .. {
			OnCommand = function(self) self:playcommand("TWOsuLeft") end,
			TWOsuLeftMessageCommand = function(self)
				self:settext(TW.osuLeft == "Preview" and "Map Preview" or (TW.rankSource == "online" and "EtternaOnline Ranking"
				or (TW.rankSource == "hub" and "Global Ranking (VSRG Hub)" or "Local Ranking")))
			end,
			TWRankSourceMessageCommand = function(self) self:playcommand("TWOsuLeft") end,
		},
		TW.icon("chevron-down", M(14), function(self) self:x(RW - M(20)) end),
		-- click: Local Ranking > Global Ranking (VSRG Hub's) > EtternaOnline's > Map Preview; right click goes back
		TW.button(RW, RH, function() TW.osuLeftStep(1) end, function(self, on)
			self:GetParent():GetChild("Hover"):stoptweening():linear(0.1):diffusealpha(on and 0.08 or 0)
		end, function() TW.osuLeftStep(-1) end) .. { InitCommand = function(self) self:align(0, 0.5):zoomto(RW, RH):diffusealpha(0) end },
		-- the rate, on osu!'s round button right of the box. Skins with their own top bar art draw
		-- that button into it (a heart, a ring...): then the rate isn't drawn over it, the button
		-- still changes it, and the rate shows under it for a moment while it changes or while the
		-- mouse is over it (it is always in the info lines above too)
		Def.ActorFrame {
			InitCommand = function(self) self:x(RW + M(6)) end,
			OnCommand = function(self) self:playcommand("TWTopArt") end,
			TWTopArtMessageCommand = function(self) self:GetChild("Pill"):visible(not TW.stableOwnTopArt) end,
			Def.ActorFrame {
				Name = "Pill",
				TW.box { w = M(56), h = RH, r = RH / 2, ay = 0.5, col = { 0, 0, 0, 0.55 } } .. { Name = "Bg" },
				TW.box { w = M(56), h = RH, r = RH / 2, ay = 0.5, tex = "ring", stroke = M(1.5), col = { 1, 1, 1, 0.9 } },
				TW.text(M(13), true, function(self) self:align(0.5, 0.5):x(M(28)) end) .. {
					OnCommand = function(self) self:playcommand("Rate") end,
					CurrentRateChangedMessageCommand = function(self) self:playcommand("Rate") end,
					RateCommand = function(self) self:settext(getCurRateDisplayString(true)) end
				},
			},
			-- (the skin's button: a small tag under it)
			Def.ActorFrame {
				Name = "Tip",
				InitCommand = function(self) self:xy(M(12), RH / 2 + M(12)):diffusealpha(0) end,
				TW.box { w = M(48), h = M(18), r = M(9), ax = 0.5, ay = 0.5, col = { 0, 0, 0, 0.75 } },
				TW.text(M(10), true, function(self) self:align(0.5, 0.5):shadowlength(0) end) .. {
					OnCommand = function(self) self:playcommand("Rate") end,
					CurrentRateChangedMessageCommand = function(self) self:playcommand("Rate") end,
					RateCommand = function(self) self:settext(getCurRateDisplayString(true)) end
				},
				ShowCommand = function(self)
					if not TW.stableOwnTopArt then return end
					self:stoptweening():linear(0.1):diffusealpha(1)
					if not self.hover then self:sleep(1.2):linear(0.3):diffusealpha(0) end
				end,
				CurrentRateChangedMessageCommand = function(self) self:playcommand("Show") end,
			},
			UIElements.QuadButton(1, 1) .. {
				InitCommand = function(self) self:align(0, 0.5):zoomto(M(56), RH):diffusealpha(0) end,
				MouseOverCommand = function(self)
					local p = self:GetParent()
					TW.setBox(p:GetChild("Pill"):GetChild("Bg"), { col = { 0.25, 0.25, 0.3, 0.7 } })
					local tip = p:GetChild("Tip"); tip.hover = true; tip:playcommand("Show")
				end,
				MouseOutCommand = function(self)
					local p = self:GetParent()
					TW.setBox(p:GetChild("Pill"):GetChild("Bg"), { col = { 0, 0, 0, 0.55 } })
					local tip = p:GetChild("Tip"); tip.hover = false; tip:stoptweening():linear(0.2):diffusealpha(0)
				end,
				MouseDownCommand = function(self, params)
					if params.event == "DeviceButton_left mouse button" then
						ChangeMusicRate(nil, { Name = "PrevRate" })
					elseif params.event == "DeviceButton_right mouse button" then
						ChangeMusicRate(nil, { Name = "NextRate" })
					end
				end
			}
		}
	}
t[#t + 1] = dropList("group", 948, 1152, groupItems)
t[#t + 1] = dropList("sort", 1235, 1440, sortItems)
return t
