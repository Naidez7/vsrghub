-- The VIDEO and AUDIO parts of VSRG Hub's options (both looks): what any game lets you set
-- without digging through Etterna's menus. All of them are Etterna's own preferences, kept in its
-- Preferences.ini.
--
-- Some apply at once (FPS limits, what happens when the game isn't focused, the FPS counter,
-- background dim, volumes, audio offset). Display mode, resolution and VSync need Etterna to set up
-- the screen again: they are kept until "Apply display settings", which reloads the look (the song
-- you had selected stays selected).

local function pref(name, default)
	local ok, v = pcall(function() return PREFSMAN:GetPreference(name) end)
	if ok and v ~= nil then return v end
	return default
end
local function setPref(name, v)
	pcall(function() PREFSMAN:SetPreference(name, v) end)
	pcall(function() PREFSMAN:SavePreferences() end)
end
local function cycle(list, cur, d)
	local i = 1
	for k, v in ipairs(list) do if v == cur then i = k end end
	return list[(i - 1 + d) % #list + 1]
end

-- display settings waiting for "Apply display settings"
TW.pendingDisplay = TW.pendingDisplay or nil
local function display()
	local p = TW.pendingDisplay
	local mode = "windowed"
	if not pref("Windowed", true) then mode = "fullscreen" end
	if pref("FullscreenIsBorderlessWindow", false) then mode = "borderless" end
	local cur = { mode = mode, w = pref("DisplayWidth", 1280), h = pref("DisplayHeight", 720), vsync = pref("Vsync", false) == true }
	if not p then return cur end
	for k, v in pairs(p) do cur[k] = v end
	return cur
end
local function setPending(k, v)
	TW.pendingDisplay = TW.pendingDisplay or {}
	TW.pendingDisplay[k] = v
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
end
function TW.applyDisplay()
	local d = display()
	setPref("Windowed", d.mode == "windowed")
	setPref("FullscreenIsBorderlessWindow", d.mode == "borderless")
	setPref("DisplayWidth", d.w)
	setPref("DisplayHeight", d.h)
	if d.h > 0 then setPref("DisplayAspectRatio", d.w / d.h) end
	setPref("Vsync", d.vsync)
	TW.pendingDisplay = nil
	-- Etterna sets the screen up again when it loads a theme: the look is loaded again
	if TW.rememberSelection then TW.rememberSelection() end
	if TW.closeOptions then TW.closeOptions() end
	THEME:SetTheme(THEME:GetCurThemeName())
end

local MODE_LABEL = { windowed = "Windowed", fullscreen = "Fullscreen", borderless = "Borderless window" }
local function resolutions()
	local out, seen = {}, {}
	pcall(function()
		local specs = DISPLAY:GetDisplaySpecs()
		for i = 1, #specs do
			local s = specs[i]
			if not s:IsVirtual() then
				for _, m in ipairs(s:GetSupportedModes() or {}) do
					local w, h = m:GetWidth(), m:GetHeight()
					local key = w .. "x" .. h
					if not seen[key] and w >= 640 and h >= 480 then
						seen[key] = true
						out[#out + 1] = { w = w, h = h }
					end
				end
			end
		end
	end)
	if #out == 0 then
		for _, r in ipairs({ { 1280, 720 }, { 1366, 768 }, { 1600, 900 }, { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 } }) do
			out[#out + 1] = { w = r[1], h = r[2] }
		end
	end
	table.sort(out, function(a, b) if a.w ~= b.w then return a.w > b.w end return a.h > b.h end)
	return out
end
local function ratioName(w, h)
	local r = w / h
	for _, c in ipairs({ { 16 / 9, "16:9" }, { 16 / 10, "16:10" }, { 4 / 3, "4:3" }, { 5 / 4, "5:4" }, { 21 / 9, "21:9" }, { 32 / 9, "32:9" } }) do
		if math.abs(r - c[1]) < 0.02 then return c[2] end
	end
	return ""
end
local function resolutionList()
	local d = display()
	local items = {}
	for _, r in ipairs(resolutions()) do
		items[#items + 1] = { label = r.w .. " x " .. r.h, value = r.w .. "x" .. r.h, sub = ratioName(r.w, r.h) }
	end
	TW.openList { title = "Resolution", items = items, current = d.w .. "x" .. d.h, onPick = function(v)
		local w, h = v:match("(%d+)x(%d+)")
		TW.pendingDisplay = TW.pendingDisplay or {}
		TW.pendingDisplay.w, TW.pendingDisplay.h = tonumber(w), tonumber(h)
	end }
end

-- Etterna's renderer (VideoRenderers: the first one that starts is used). Only OpenGL can draw the
-- osu! look's frosted glass (TW.canFrost). Takes effect the next time the game starts.
local function wantsOpenGL()
	local v = tostring(pref("VideoRenderers", "") or ""):lower():gsub("%s", "")
	if v == "" then return TW.canFrost() end
	return v:sub(1, 6) == "opengl"
end
local function rendererLabel()
	local name = wantsOpenGL() and "OpenGL" or "Direct3D"
	if wantsOpenGL() ~= TW.canFrost() then return name .. " (after a restart)" end
	return name
end
local function pickRenderer(gl)
	setPref("VideoRenderers", gl and "opengl,d3d" or "d3d,opengl")
	MESSAGEMAN:Broadcast("TWOptionsRefresh")
end

local FPS = { 0, 60, 75, 120, 144, 165, 240, 360, 500, 1000 }
local function fpsLabel(v) return (v or 0) <= 0 and "Unlimited" or (v .. " FPS") end
local function fpsList(prefName, title)
	local items = {}
	for _, v in ipairs(FPS) do items[#items + 1] = { label = fpsLabel(v), value = tostring(v) } end
	TW.openList { title = title, items = items, current = tostring(pref(prefName, 0)),
		onPick = function(v) setPref(prefName, tonumber(v)) end }
end
-- Etterna sleeps this long each frame while another window is in front
local UNFOCUSED = { { 0, "Keep full speed" }, { 10, "Lower (a little)" }, { 30, "About 30 FPS" }, { 100, "About 10 FPS" } }
local function unfocusedLabel()
	local v = pref("UnfocusedSleepMilliseconds", 10)
	for _, u in ipairs(UNFOCUSED) do if u[1] == v then return u[2] end end
	return v .. " ms per frame"
end

local function pct(v) return string.format("%d%%", math.floor((v or 0) * 100 + 0.5)) end
local function nudge(name, d, lo, hi, default)
	local v = (pref(name, default) or default) + d
	v = math.max(lo, math.min(hi, math.floor(v * 100 + 0.5) / 100))
	setPref(name, v)
	return v
end

function TW.videoRows()
	local rows = {
		{ kind = "head", text = "VIDEO" },
		{ label = "Display mode", value = function() return MODE_LABEL[display().mode] end,
		  change = function(dd) setPending("mode", cycle({ "windowed", "fullscreen", "borderless" }, display().mode, dd)) end,
		  activate = function()
			  local items = {}
			  for _, m in ipairs({ "windowed", "fullscreen", "borderless" }) do items[#items + 1] = { label = MODE_LABEL[m], value = m } end
			  TW.openList { title = "Display mode", items = items, current = display().mode,
				  onPick = function(v) TW.pendingDisplay = TW.pendingDisplay or {}; TW.pendingDisplay.mode = v end }
		  end },
		{ label = "Resolution", value = function() local x = display(); return x.w .. " x " .. x.h end, activate = resolutionList,
		  change = function() resolutionList() end },
		{ label = "VSync", value = function() return display().vsync and "On" or "Off" end,
		  check = function() return display().vsync end, checkLabel = "VSync",
		  change = function() setPending("vsync", not display().vsync) end,
		  activate = function() setPending("vsync", not display().vsync) end },
		{ label = "Apply display settings", button = true, hide = TW.pendingDisplay == nil, value = function() return "apply" end,
		  activate = TW.applyDisplay },
		{ label = "Renderer", value = rendererLabel, change = function() pickRenderer(not wantsOpenGL()) end,
		  activate = function()
			  TW.openList { title = "Renderer", current = wantsOpenGL() and "opengl" or "d3d",
				  items = { { label = "OpenGL", value = "opengl", sub = "frosted glass in the osu! look" },
					  { label = "Direct3D", value = "d3d", sub = "plain see-through grey" } },
				  onPick = function(v) pickRenderer(v == "opengl") end }
		  end },
		{ label = "Show FPS", value = function() return pref("ShowStats", false) and "On" or "Off" end,
		  check = function() return pref("ShowStats", false) == true end, checkLabel = "Show FPS",
		  change = function() setPref("ShowStats", not pref("ShowStats", false)) end,
		  activate = function() setPref("ShowStats", not pref("ShowStats", false)) end },
		{ label = "Background dim", value = function() return pct(1 - pref("BGBrightness", 0.2)) end,
		  change = function(dd) nudge("BGBrightness", -dd * 0.05, 0, 1, 0.2) end },
		{ kind = "head", text = "PERFORMANCE" },
		{ label = "FPS limit (menus)", value = function() return fpsLabel(pref("FrameLimit", 0)) end,
		  change = function(dd) setPref("FrameLimit", cycle(FPS, pref("FrameLimit", 0), dd)) end,
		  activate = function() fpsList("FrameLimit", "FPS limit (menus)") end },
		{ label = "FPS limit (playing)", value = function() return fpsLabel(pref("FrameLimitGameplay", 0)) end,
		  change = function(dd) setPref("FrameLimitGameplay", cycle(FPS, pref("FrameLimitGameplay", 0), dd)) end,
		  activate = function() fpsList("FrameLimitGameplay", "FPS limit (playing)") end },
		{ label = "FPS limit mode", value = function() return pref("PredictiveFrameLimit", false) and "Predictive (less input lag)" or "Exact" end,
		  change = function() setPref("PredictiveFrameLimit", not pref("PredictiveFrameLimit", false)) end,
		  activate = function() setPref("PredictiveFrameLimit", not pref("PredictiveFrameLimit", false)) end },
		{ label = "When not focused", value = unfocusedLabel,
		  change = function(dd)
			  local vals = {}
			  for _, u in ipairs(UNFOCUSED) do vals[#vals + 1] = u[1] end
			  setPref("UnfocusedSleepMilliseconds", cycle(vals, pref("UnfocusedSleepMilliseconds", 10), dd))
		  end,
		  activate = function()
			  local items = {}
			  for _, u in ipairs(UNFOCUSED) do items[#items + 1] = { label = u[2], value = tostring(u[1]) } end
			  TW.openList { title = "When not focused", items = items, current = tostring(pref("UnfocusedSleepMilliseconds", 10)),
				  onPick = function(v) setPref("UnfocusedSleepMilliseconds", tonumber(v)) end }
		  end },
		{ kind = "head", text = "AUDIO" },
		{ label = "Master volume", value = function() return pct(pref("SoundVolumeMaster", 0.5)) end,
		  change = function(dd) SOUND:SetVolume(nudge("SoundVolumeMaster", dd * 0.05, 0, 1, 0.5)) end },
		{ label = "Menu music volume", value = function() return pct(pref("SoundVolumeBGM", 0.4)) end,
		  change = function(dd) local v = nudge("SoundVolumeBGM", dd * 0.05, 0, 1, 0.4); pcall(function() SOUND:SetBGMVolume(v) end) end },
		{ label = "Effects volume", value = function() return pct(pref("SoundVolumeActions", 1)) end,
		  change = function(dd) local v = nudge("SoundVolumeActions", dd * 0.05, 0, 1, 1); pcall(function() SOUND:SetActionsVolume(v) end) end },
		{ label = "Audio offset", value = function() return string.format("%+d ms", math.floor(pref("GlobalOffsetSeconds", 0) * 1000 + 0.5)) end,
		  change = function(dd) setPref("GlobalOffsetSeconds", math.floor(pref("GlobalOffsetSeconds", 0) * 1000 + 0.5 + dd) / 1000) end,
		  activate = function()
			  TW.openInput { title = "Audio offset (ms)", value = tostring(math.floor(pref("GlobalOffsetSeconds", 0) * 1000 + 0.5)),
				  hint = "Etterna's global offset, in milliseconds.",
				  onDone = function(t) local v = tonumber(t); if v then setPref("GlobalOffsetSeconds", math.max(-1000, math.min(1000, v)) / 1000) end end }
		  end },
	}
	for i = #rows, 1, -1 do if rows[i].hide then table.remove(rows, i) end end
	return rows
end
