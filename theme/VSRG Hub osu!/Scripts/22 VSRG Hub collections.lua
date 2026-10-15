-- osu! collections on song select (shared by every VSRG Hub theme).
-- osu! collections (read from osu!'s collection.db at launch): picking one filters the wheel to
-- the songs that have its maps
TW.collection = TW.collection -- kept while the game runs
local function collectionKeys(c)
	local want = {}
	for _, ch in ipairs(c.charts) do
		want[ch[1]] = want[ch[1]] or {}
		table.insert(want[ch[1]], (ch[2] or ""):lower())
	end
	local keys = {}
	for _, song in ipairs(SONGMAN:GetAllSongs()) do
		local dir = (song:GetSongDir() or ""):gsub("\\", "/"):gsub("/+$", "")
		local a, b = dir:match("([^/]+)/([^/]+)$")
		local diffs = a and want[(a .. "/" .. b):lower()]
		if diffs then
			local hit = false
			for _, st in ipairs(song:GetAllSteps()) do
				local dn = TW.diffName(st):lower()
				for _, d in ipairs(diffs) do
					if d == "" or dn == d or dn:find(d, 1, true) then
						keys[#keys + 1] = st:GetChartKey(); hit = true; break
					end
				end
			end
			if not hit then for _, st in ipairs(song:GetAllSteps()) do keys[#keys + 1] = st:GetChartKey() end end
		end
	end
	return keys
end
-- Patterns: a chart belongs to every pattern type whose MSD is close to its highest one (within
-- 10%), so a long chordjack map counts as Chordjack and Stamina, not only the larger of the two.
TW.patternNames = { [2] = "Stream", [3] = "Jumpstream", [4] = "Handstream", [5] = "Stamina",
	[6] = "JackSpeed", [7] = "Chordjack", [8] = "Technical" }
local patternCache = {}
function TW.patternKeys()
	local rate = getCurRateValue()
	local cacheKey = TW.gameName() .. "@" .. rate
	if patternCache[cacheKey] then return patternCache[cacheKey] end
	local out = {}
	for i = 2, 8 do out[i] = {} end
	for _, song in ipairs(SONGMAN:GetAllSongs()) do
		for _, st in ipairs(TW.playable(song)) do
			local vals, top = {}, 0
			for i = 2, 8 do
				local ok, v = pcall(function() return st:GetMSD(rate, i) end)
				vals[i] = ok and v or 0
				if vals[i] > top then top = vals[i] end
			end
			if top > 0 then
				local key = st:GetChartKey()
				for i = 2, 8 do if vals[i] >= top * 0.9 then table.insert(out[i], key) end end
			end
		end
	end
	patternCache[cacheKey] = out
	return out
end
function TW.openPatterns(title)
	local all = TW.patternKeys()
	local items = { { label = "All songs", value = "", sub = "no pattern filter" } }
	for i = 2, 8 do
		local n = #all[i]
		items[#items + 1] = { label = TW.patternNames[i], value = tostring(i), sub = n .. (n == 1 and " chart" or " charts") }
	end
	local cur = TW.collection and TW.collection.pattern and tostring(TW.collection.pattern) or ""
	TW.openList { title = title or "Group by pattern", items = items, current = cur, onPick = function(v)
		local i = tonumber(v)
		TW.applyCollection(i and { name = TW.patternNames[i], pattern = i } or nil)
	end }
end
-- c: an osu! collection (from TW_COLLECTIONS), { name = ..., playlist = <Etterna playlist name> }
-- or { name = ..., pattern = <skillset number> }
local function keysFor(c)
	if c.pattern then return TW.patternKeys()[c.pattern] or {} end
	if c.playlist then
		for _, pl in ipairs(SONGMAN:GetPlaylists() or {}) do
			if pl:GetName() == c.playlist then return pl:GetChartkeys() or {} end
		end
		return {}
	end
	return collectionKeys(c)
end
function TW.applyCollection(c)
	local w = SCREENMAN:GetTopScreen():GetMusicWheel()
	if not w then return end
	TW.collection = c
	-- an Etterna playlist picked here is also where "Add to playlist" puts charts
	if c and c.playlist then pcall(function() SONGMAN:SetActivePlaylist(c.playlist) end) end
	if c then
		local keys = keysFor(c)
		if #keys == 0 then
			TW.collection = nil
			SCREENMAN:SystemMessage("No songs from \"" .. c.name .. "\" are in VSRG Hub")
			w:FilterByStepKeys({})
		else
			w:FilterByStepKeys(keys)
		end
	else
		w:FilterByStepKeys({})
	end
	MESSAGEMAN:Broadcast("TWSortChanged")
	MESSAGEMAN:Broadcast("TWCollectionChanged")
end
-- every list a song can be picked from: osu! collections and Etterna playlists
function TW.collectionItems()
	local items = { { label = "All songs", value = "", sub = "no collection" } }
	TW.collectionByKey = {}
	for i, c in ipairs(TW_COLLECTIONS or {}) do
		local k = "osu:" .. i
		TW.collectionByKey[k] = c
		items[#items + 1] = { label = c.name, value = k, sub = "osu! collection, " .. c.maps .. (c.maps == 1 and " map" or " maps") }
	end
	local ok, pls = pcall(function() return SONGMAN:GetPlaylists() end)
	for _, pl in ipairs(ok and pls or {}) do
		local k = "pl:" .. pl:GetName()
		TW.collectionByKey[k] = { name = pl:GetName(), playlist = pl:GetName() }
		local n = pl:GetNumCharts()
		items[#items + 1] = { label = pl:GetName(), value = k, sub = "playlist, " .. n .. (n == 1 and " chart" or " charts") }
	end
	return items
end
function TW.currentCollectionKey()
	local c = TW.collection
	if not c then return "" end
	if c.playlist then return "pl:" .. c.playlist end
	for i, cc in ipairs(TW_COLLECTIONS or {}) do if cc == c then return "osu:" .. i end end
	return ""
end
function TW.pickCollection(k) TW.applyCollection(k ~= "" and TW.collectionByKey[k] or nil) end
function TW.openCollections(title)
	local items = TW.collectionItems()
	if #items == 1 then items[1].sub = "no osu! collections or playlists yet" end
	TW.openList { title = title or "Collections", items = items, current = TW.currentCollectionKey(), onPick = TW.pickCollection }
end
