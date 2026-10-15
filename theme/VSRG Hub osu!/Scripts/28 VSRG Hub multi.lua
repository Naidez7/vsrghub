-- Multiplayer from the main menu. Etterna asks for the EtternaOnline name and password on its own
-- text entry screen, which took no typing under VSRG Hub's looks (stuck on "Enter username"): the
-- name and password are asked here instead, with VSRG Hub's own input box, and Etterna is signed in
-- before its multiplayer screens open (they then skip their own login).
--   TW.startMulti(go)  go: what the menu's Multi did (Etterna's multiplayer screens)
--   TW.multiStatus()   the "Signing in..." line and the poller (put it on each look's main menu)
local wait = nil -- { user, t0, go } while signing in

local function online() return IsNetSMOnline ~= nil and IsNetSMOnline() end
local function loggedIn() return IsSMOnlineLoggedIn ~= nil and IsSMOnlineLoggedIn() end

local function say(text, bad)
	MESSAGEMAN:Broadcast("TWMultiStatus", { text = text, bad = bad })
end

function TW.startMulti(go)
	-- not connected to a multiplayer server: Etterna's screens connect first; already signed in:
	-- straight in
	if not online() or loggedIn() then go() return end
	TW.openInput { title = "Multiplayer: your EtternaOnline name", value = (TW.settings and TW.settings.mpUser) or "",
		hint = "The account from etternaonline.com.",
		onDone = function(user)
			user = (user or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if user == "" then return end
			TW.openInput { title = "Password for " .. user, value = "", secret = true,
				hint = "Not kept by VSRG Hub.",
				onDone = function(pass)
					if (pass or "") == "" then return end
					pcall(function() TW.saveSetting("mpUser", user) end)
					wait = { user = user, t0 = GetTimeSinceStart(), go = go }
					say("Signing in to multiplayer as " .. user .. "...")
					local ok = pcall(function() NSMAN:Login(user, pass) end)
					if not ok then wait = nil; say("Multiplayer isn't available right now.", true) end
				end }
		end }
end

function TW.multiStatus()
	local M = TW.M
	return Def.ActorFrame {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_HEIGHT - M(70)):diffusealpha(0)
			self:SetUpdateFunction(function()
				if not wait then return end
				if loggedIn() then
					local go = wait.go
					wait = nil
					say("")
					go()
				elseif GetTimeSinceStart() - wait.t0 > 10 then
					wait = nil
					say("Couldn't sign in: check your EtternaOnline name and password.", true)
				end
			end):SetUpdateFunctionInterval(0.1)
		end,
		OffCommand = function() wait = nil end,
		TWMultiStatusMessageCommand = function(self, p)
			local c = self:GetChildren()
			c.T:settext(p.text or ""):diffuse(p.bad and TW.rgb(255, 120, 140) or { 1, 1, 1, 1 })
			TW.setBox(c.Bg, { w = c.T:GetZoomedWidth() + M(40) })
			self:stoptweening():linear(0.15):diffusealpha((p.text or "") ~= "" and 1 or 0)
		end,
		TW.box { w = M(300), h = M(40), r = M(20), ax = 0.5, ay = 0.5, col = { 0.08, 0.07, 0.12, 0.9 } } .. { Name = "Bg" },
		TW.text(M(15), true, function(self) self:align(0.5, 0.5) end) .. { Name = "T" },
	}
end
