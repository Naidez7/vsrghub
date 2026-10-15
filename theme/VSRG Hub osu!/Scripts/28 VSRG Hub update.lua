-- "A new VSRG Hub is out" on the main menu: VSRG Hub's program checks for a newer version when the
-- game starts and writes it to Save/VSRGHub/update.txt (removed when the game is up to date). The
-- note is read for a while after the menu comes up (the check takes a moment) and a click hides it.
local FILE = "Save/VSRGHub/update.txt"
local dismissed = false

local function newest()
	local ok, txt = pcall(function() return File.Read(FILE) end)
	if not ok or not txt then return nil end
	local v = txt:match("^%s*(%S+)")
	return v ~= "" and v or nil
end

function TW.updateNotice()
	local M = TW.M
	local H = M(38)
	return Def.ActorFrame {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_HEIGHT - M(26)):diffusealpha(0)
			local t0, shown = GetTimeSinceStart(), false
			-- (a clock in an update function, not a sleep: a long animation would hold the menu)
			self:SetUpdateFunction(function(s)
				if shown or dismissed then return end
				local v = newest()
				if v then
					shown = true
					s:playcommand("Show", { version = v })
				elseif GetTimeSinceStart() - t0 > 20 then
					shown = true
				end
			end):SetUpdateFunctionInterval(1)
		end,
		ShowCommand = function(self, p)
			local c = self:GetChildren()
			c.T:settext("VSRG Hub " .. p.version .. " is out: close the game and press Update in the launcher")
			local w = c.T:GetZoomedWidth() + M(64)
			TW.setBox(c.Bg, { w = w })
			TW.setBox(c.Ring, { w = w })
			c.X:x(w / 2 - M(18))
			c.Hit:zoomto(w, H):visible(true)
			self:stoptweening():decelerate(0.3):diffusealpha(1)
		end,
		TW.box { w = M(400), h = H, r = H / 2, ax = 0.5, ay = 0.5, col = { 0.10, 0.09, 0.15, 0.94 } } .. { Name = "Bg" },
		TW.box { w = M(400), h = H, r = H / 2, ax = 0.5, ay = 0.5, tex = "ring", stroke = M(1.5), col = TW.pink } .. { Name = "Ring" },
		TW.text(M(14), true, function(self) self:align(0.5, 0.5):x(-M(10)):shadowlength(1) end) .. { Name = "T" },
		TW.text(M(14), false, function(self) self:align(0.5, 0.5):settext("x"):diffusealpha(0.7) end) .. { Name = "X" },
		TW.button(M(400), H, function(self)
			if dismissed then return end
			dismissed = true
			self:visible(false)
			self:GetParent():stoptweening():linear(0.2):diffusealpha(0)
		end) .. { Name = "Hit",
			-- (TW.button's own Init, hidden: a hidden button takes no clicks; its On registers it)
			InitCommand = function(self) self:zoomto(M(400), H):diffusealpha(0):visible(false) end },
	}
end
