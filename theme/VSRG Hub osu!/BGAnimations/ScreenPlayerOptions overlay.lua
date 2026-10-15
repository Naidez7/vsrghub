-- Til Death's player options overlay (Etterna, MIT licence), with VSRG Hub's noteskin preview at the end.
local t = Def.ActorFrame {}
local topFrameHeight = 35
local bottomFrameHeight = 54
local borderWidth = 4

local widescreen = GetScreenAspectRatio() > 1.7

local t =
	Def.ActorFrame {
	Name = "PlayerAvatar"
}

local profileP1

local profileNameP1 = THEME:GetString("GeneralInfo", "NoProfile")
local playCountP1 = 0
local playTimeP1 = 0
local noteCountP1 = 0

local AvatarXP1 = 5
local AvatarYP1 = 44

local bpms = {}
if GAMESTATE:GetCurrentSong() then
	bpms = GAMESTATE:GetCurrentSong():GetDisplayBpms(true)
	bpms[1] = math.round(bpms[1])
	bpms[2] = math.round(bpms[2])
end

-- P1 Avatar
t[#t + 1] =
	TW.box { w = 250, h = 40, r = 8, col = { 0.11, 0.11, 0.15, 0.9 }, col2 = { 0.07, 0.07, 0.1, 0.9 }, init = function(self) self:xy(AvatarXP1 - 15, AvatarYP1 - 5) end }

t[#t + 1] =
	Def.Actor {
	BeginCommand = function(self)
		self:queuecommand("Set")
	end,
	SetCommand = function(self)
		if GAMESTATE:IsPlayerEnabled() then
			profileP1 = GetPlayerOrMachineProfile(PLAYER_1)
			if profileP1 ~= nil then
				profileNameP1 = profileP1:GetDisplayName()
				playCountP1 = profileP1:GetTotalNumSongsPlayed()
				playTimeP1 = profileP1:GetTotalSessionSeconds()
				noteCountP1 = profileP1:GetTotalTapsAndHolds()
			else
				profileNameP1 = THEME:GetString("GeneralInfo", "NoProfile")
				playCountP1 = 0
				playTimeP1 = 0
				noteCountP1 = 0
			end
		else
			profileNameP1 = THEME:GetString("GeneralInfo", "NoProfile")
			playCountP1 = 0
			playTimeP1 = 0
			noteCountP1 = 0
		end
	end
}

t[#t + 1] =
	Def.ActorFrame {
	Name = "Avatar" .. PLAYER_1,
	BeginCommand = function(self)
		self:queuecommand("Set")
	end,
	SetCommand = function(self)
		if profileP1 == nil then
			self:visible(false)
		else
			self:visible(true)
		end
	end,
	Def.Sprite {
		Name = "Image",
		InitCommand = function(self)
			self:visible(true):halign(0):valign(0):xy(AvatarXP1, AvatarYP1)
		end,
		BeginCommand = function(self)
			self:queuecommand("ModifyAvatar")
		end,
		ModifyAvatarCommand = function(self)
			self:finishtweening()
			self:Load(getAvatarPath(PLAYER_1))
			self:zoomto(30, 30)
		end
	},
	LoadFont("Common Normal") ..
		{
			InitCommand = function(self)
				self:xy(AvatarXP1 + 33, AvatarYP1 + 9):halign(0):zoom(0.45)
			end,
			BeginCommand = function(self)
				self:queuecommand("Set")
			end,
			SetCommand = function(self)
				self:settextf("%s%s", profileNameP1, THEME:GetString("ScreenPlayerOptions", "ScrollSpeed"))
			end
		},
	LoadFont("Common Normal") ..
		{
			InitCommand = function(self)
				self:xy(AvatarXP1 + 33, AvatarYP1 + 20):halign(0):zoom(0.40)
			end,
			BeginCommand = function(self)
				local speed, mode = GetSpeedModeAndValueFromPoptions(PLAYER_1)
				self:playcommand("SpeedChoiceChanged", {pn = PLAYER_1, mode = mode, speed = speed})
			end,
			RateListOptionChangedMessageCommand = function(self, params)
				self:finishtweening():sleep(0.01):queuecommand("DelayedThing")
			end,
			RateListOptionSavedMessageCommand = function(self, params)
				self:finishtweening():sleep(0.01):queuecommand("DelayedThing")
			end,
			DelayedThingCommand = function(self)
				self:playcommand("SpeedChoiceChanged", {pn = PLAYER_1, mode = self.mode, speed = self.speed})
			end,
			SpeedChoiceChangedMessageCommand = function(self, param)
				self.mode = param.mode
				self.speed = param.speed
				if param.pn == PLAYER_1 then
					local text = ""
					if param.mode == "x" then
						if not bpms[1] then
							text = "??? - ???"
						elseif bpms[1] == bpms[2] then
							text = math.round(bpms[1] * getCurRateValue() * param.speed / 100)
						else
							text = string.format("%d - %d", math.round(bpms[1] * getCurRateValue() * param.speed / 100), math.round(bpms[2] * getCurRateValue() * param.speed / 100))
						end
					elseif param.mode == "C" then
						text = param.speed
					else
						if not bpms[1] then
							text = "??? - " .. param.speed
						elseif bpms[1] == bpms[2] then
							text = param.speed
						else
							local factor = param.speed / bpms[2]
							text = string.format("%d - %d", math.round(bpms[1] * factor), param.speed)
						end
					end
					self:settext(text)
				end
			end
		}
}

--Frames
t[#t + 1] =
	Def.Quad {
	InitCommand = function(self)
		self:xy(0, 0):halign(0):valign(0):zoomto(SCREEN_WIDTH, topFrameHeight):diffuse({ 0.05, 0.05, 0.08, 0.95 }):diffusebottomedge({ 0.1, 0.1, 0.14, 0.92 })
	end
}
t[#t + 1] =
	Def.Quad {
	InitCommand = function(self)
		self:xy(0, topFrameHeight):halign(0):valign(1):zoomto(SCREEN_WIDTH, 2):diffuse(TW.pink)
	end
}

t[#t + 1] =
	TW.text(20, true, function(self)
		self:xy(10, topFrameHeight / 2):halign(0):valign(0.5)
		self:settext(THEME:GetString("ScreenPlayerOptions", "Title"))
	end)

-- VSRG Hub: the noteskin preview is a small playfield left of the option names, with every column
-- of the game (4K or 7K), each note and receptor shrunk to fit its column, so wide skins (big osu!
-- 7K notes) stay inside it instead of running over the options.
local OptionRowHeight = 35
local NSPreviewY = 125
local NoteskinRow = 0
local cols = GivenGameToFullNSkinElements(PREFSMAN:GetPreference("CurrentGame")) or GameToNSkinElements()
local BoxX = 6
local BoxW = math.max(90, SCREEN_CENTER_X - 222 - SCREEN_WIDTH * 0.06 - 14)
local Span = BoxW / #cols
local RowGap = math.min(40, math.max(Span * 1.15, 22))

local function skinWidth(name)
	local info = TW and TW.noteskinInfo and TW.noteskinInfo(name)
	return info and info.width or 64
end
-- the noteskin picked in the NoteSkins row (or the player's)
local function pickedSkin()
	local top = SCREENMAN:GetTopScreen()
	local names = NOTESKIN:GetNoteSkinNames()
	local ok, name = pcall(function()
		for i = 0, top:GetNumRows() - 1 do
			local r = top:GetOptionRow(i)
			if r and r:GetName() == "NoteSkins" then return names[r:GetChoiceInRowWithFocus(PLAYER_1) + 1] end
		end
	end)
	if ok and name then return name end
	return GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin()
end

local field = Def.ActorFrame {
	Name = "Field",
	FitCommand = function(self)
		local z = math.min(0.5, Span * 0.92 / math.max(1, skinWidth(pickedSkin())))
		for i = 1, #cols do
			local c = self:GetChild("C" .. i)
			if c then c:zoom(z) end
		end
	end,
}
for i = 1, #cols do
	field[#field + 1] = Def.ActorFrame {
		Name = "C" .. i,
		InitCommand = function(self) self:x(BoxX + Span * (i - 0.5)) end,
		Def.ActorFrame { Name = "R", InitCommand = function(self) self:y(-RowGap / 2) end, LoadNSkinPreview("Get", cols[i], "Receptor", PLAYER_1) .. { Name = "P" } },
		Def.ActorFrame { Name = "T", InitCommand = function(self) self:y(RowGap / 2) end, LoadNSkinPreview("Get", cols[i], "Tap Note", PLAYER_1) .. { Name = "P" } },
	}
end

t[#t + 1] =
	Def.ActorFrame {
	OnCommand = function(self)
		self:x(0)
		for i = 0, SCREENMAN:GetTopScreen():GetNumRows() - 1 do
			if SCREENMAN:GetTopScreen():GetOptionRow(i) and SCREENMAN:GetTopScreen():GetOptionRow(i):GetName() == "NoteSkins" then
				NoteskinRow = i
			end
		end
		local field = self:GetChild("Field")
		-- (Etterna's preview shows the noteskin only after the first key press: shown at once here)
		local cur = GAMESTATE:GetPlayerState():GetPlayerOptions("ModsLevel_Preferred"):NoteSkin():lower()
		for k, n in ipairs(NOTESKIN:GetNoteSkinNames()) do
			if n:lower() == cur then
				for i = 1, #cols do
					for _, part in ipairs({ "R", "T" }) do
						local pv = field:GetChild("C" .. i):GetChild(part):GetChild("P")
						local nk = pv and pv:GetChild("N" .. k)
						if nk then nk:playcommand("Activate") end
					end
				end
			end
		end
		field:playcommand("Fit")
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			-- (after the preview's own input callbacks have switched the skin)
			field:stoptweening():sleep(0.02):queuecommand("Fit")
		end)
		self:SetUpdateFunction(
			function(self)
				local row = SCREENMAN:GetTopScreen():GetCurrentRowIndex(PLAYER_1)
				local pos = 0
				if row > 4 then
					pos = NSPreviewY + NoteskinRow * OptionRowHeight - (row - 4) * OptionRowHeight
				else
					pos = NSPreviewY + NoteskinRow * OptionRowHeight
				end
				self:y(pos - RowGap / 2)
				self:visible(NoteskinRow - row > -5 and NoteskinRow - row < 7)
			end
		)
	end,
	-- the playfield: a dark see-through box behind the receptors and notes
	Def.Quad { InitCommand = function(self)
		self:align(0, 0.5):x(BoxX):zoomto(BoxW, RowGap * 2.1):diffuse({ 0.06, 0.06, 0.09, 0.8 })
	end },
	field,
}
return t
