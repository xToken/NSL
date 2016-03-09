-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\nsl_decalmanager_server.lua
-- - Dragon

local kOriginVec = Vector(0, 0, 0)
local kDefaultDecal = 1

local function LookupDecalLocations()
	local mapName = string.lower(Shared.GetMapName())
	local locations = GetNSLConfigValue("LogoLocations")
	if locations and locations[mapName] then
		return locations[mapName]
	end
	return nil
end

local function GetNSLDecalForTP(techPoints)
	local tpDecals = { }
	local logoNumbers = GetNSLConfigValue("TeamLogos")
	if logoNumbers then
		local t1name = GetActualTeamName(1)
		local t2name = GetActualTeamName(2)
		local team1decalnum = logoNumbers[string.format("materials/logos/%s.material", GetNSLBadgeNameFromTeamName(t1name) or string.lower(t1name))] or kDefaultDecal
		local team2decalnum = logoNumbers[string.format("materials/logos/%s.material", GetNSLBadgeNameFromTeamName(t2name) or string.lower(t2name))] or kDefaultDecal
		--Build transfer table of TP Locations to current Decal
		for _, techPoint in ipairs(techPoints) do
			if techPoint:GetAttached() then
				tpDecals[string.lower(techPoint:GetLocationName())] = techPoint.occupiedTeam == 1 and team1decalnum or team2decalnum
			end
		end
	end
	return tpDecals
end

local function GetNSLDecalLocations(techPoints)
	local locations = { }
	local maplocations = LookupDecalLocations()
	local tpDecals = GetNSLDecalForTP(techPoints)
	--Build full list of all decals, if we have them
	if maplocations then
		for loc, data in pairs(maplocations) do
			local decal = tpDecals[loc] or data.decal
			table.insert(locations, {data = data, decal = decal})
		end
	end
	return locations
end

local function ConvertTabletoOrigin(t)
	if t and type(t) == "table" and #t == 3 then
		return Vector(t[1], t[2], t[3])
	end
	return nil
end

local function SyncAllLogos(spec)
	if GetNSLMode() == "PCW" or GetNSLMode() == "OFFICIAL" then
		local techPoints = Shared.GetEntitiesWithClassname("TechPoint")
		local locations = GetNSLDecalLocations(EntityListToTable(techPoints))
		if locations then
			for i, loc in ipairs(locations) do
				--Only sync valid decal locations on a SyncAll
				if loc and loc.data and loc.decal then
					local origin = ConvertTabletoOrigin(loc.data.origin)
					if origin then
						Server.SendNetworkMessage(spec, "NSLDecal", { decalIndex = loc.decal, origin = origin, pitch = loc.data.pitch, yaw = loc.data.yaw, roll = loc.data.roll }, true)
					end
				end
			end
		end
	end
end

local function SyncNSLDecalsToPlayer(player, teamNumber)
	--Clear all decals
	Server.SendNetworkMessage(player, "NSLClearDecals", { origin = kOriginVec }, true)
	if teamNumber == kSpectatorIndex then
		SyncAllLogos(player)
	end
end

table.insert(gTeamJoinedFunctions, SyncNSLDecalsToPlayer)

local function UpdateAllNSLDecals()
	--Clear all decals for everyone.
	Server.SendNetworkMessage("NSLClearDecals", { origin = kOriginVec }, true)
	--Get All Specs
	for _, spec in ipairs(GetEntitiesForTeam("Spectator", kSpectatorIndex)) do
		SyncNSLDecalsToPlayer(spec, kSpectatorIndex)
	end	
end

table.insert(gTeamNamesUpdatedFunctions, UpdateAllNSLDecals)

--Detect TP Changes
local originalTechPointOnAttached
originalTechPointOnAttached = Class_ReplaceMethod("TechPoint", "OnAttached", 
	function(self, entity)
		originalTechPointOnAttached(self, entity)
		UpdateAllNSLDecals()
	end
)

local originalTechPointClearAttached
originalTechPointClearAttached = Class_ReplaceMethod("TechPoint", "ClearAttached", 
	function(self)
		originalTechPointClearAttached(self)
		UpdateAllNSLDecals()
	end
)