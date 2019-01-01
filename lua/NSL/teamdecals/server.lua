-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/teamdecals/server.lua
-- - Dragon

local decalEntities = { }

local function LookupDecalLocations()
	local mapName = string.lower(Shared.GetMapName())
	local locations = GetNSLConfigValue("LogoLocations")
	if locations and locations[mapName] then
		return locations[mapName]
	end
	return nil
end

local function UpdateNonTechPointDecalData(techPoints, decalLocations)
	local techPointLocations = { }
	for _, techPoint in ipairs(techPoints) do
		table.insert(techPointLocations, string.lower(techPoint:GetLocationName()))
	end
	for loc, data in pairs(decalLocations) do
		if loc and data then
			if not table.contains(techPointLocations, loc) then
				if not data.decal then
					data.decal = GetNSLConfigValue("LeagueDecal")
				end
				if not data.angles then
					data.angles = Angles(0,0,0)
				end
			end
		end
	end
end

local function UpdateTechPointDecalData(techPoints, decalLocations)
	local team1decal = GetDecalNameforTeamId(GetNSLTeamID(1)) and GetNSLTeamID(1) or GetNSLConfigValue("LeagueDecal")
	local team2decal = GetDecalNameforTeamId(GetNSLTeamID(2)) and GetNSLTeamID(2) or GetNSLConfigValue("LeagueDecal")
	--Build transfer table of TP Locations to current Decal
	for _, techPoint in ipairs(techPoints) do
		if techPoint:GetAttached() then
			if decalLocations[string.lower(techPoint:GetLocationName())] then
				decalLocations[string.lower(techPoint:GetLocationName())].decal = techPoint.occupiedTeam == 1 and team1decal or team2decal
				decalLocations[string.lower(techPoint:GetLocationName())].active = true
			end
		else
			if decalLocations[string.lower(techPoint:GetLocationName())] then
				decalLocations[string.lower(techPoint:GetLocationName())].decal = GetNSLConfigValue("LeagueDecal")
				decalLocations[string.lower(techPoint:GetLocationName())].active = false
			end
		end
	end
end

local function GetNSLDecalLocations()
	local decalLocations = LookupDecalLocations()
	if decalLocations then
		-- Map has decal location data
		local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
		UpdateTechPointDecalData(techPoints, decalLocations)
		UpdateNonTechPointDecalData(techPoints, decalLocations)
	end
	return decalLocations
end

local function ConvertTabletoOrigin(t)
	if t and type(t) == "table" and #t == 3 then
		return Vector(t[1], t[2], t[3])
	end
	return nil
end

local function ConvertTabletoAngles(t)
	if t and type(t) == "table" and #t == 3 then
		return Angles((t[1] / 180) * math.pi, (t[2] / 180) * math.pi , (t[3] / 180) * math.pi)
	end
	return nil
end


local function UpdateOrCreateAllNSLDecals()
	local override = (GetNSLMode() == "PCW" or GetNSLMode() == "OFFICIAL")
	local decalLocations = GetNSLDecalLocations()
	if decalLocations then
		for loc, data in pairs(decalLocations) do
			if loc and data then
				local origin = ConvertTabletoOrigin(data.origin)
				local angles = ConvertTabletoAngles(data.angles)
				if origin then
					if decalEntities[loc] then
						decalEntities[loc]:SetDecal(data.decal)
						decalEntities[loc]:SetActive(data.active and override)
					else
						decalEntities[loc] = Server.CreateEntity("nsldecal", {origin = origin, angles = angles})
						decalEntities[loc]:SetDecal(data.decal)
						decalEntities[loc]:SetActive(data.active and override)
					end
				end
			end
		end
	end
end

local function UpdateAllNSLDecals(teamData, teamScore)
	UpdateOrCreateAllNSLDecals()
end

table.insert(gTeamNamesUpdatedFunctions, UpdateAllNSLDecals)

local function OnDecalConfigLoaded(config)
	if config == "all" or config == "decal" then
		UpdateOrCreateAllNSLDecals()
	end
end

table.insert(gConfigLoadedFunctions, OnDecalConfigLoaded)

--Detect TP Changes
local originalTechPointOnAttached
originalTechPointOnAttached = Class_ReplaceMethod("TechPoint", "OnAttached", 
	function(self, entity)
		originalTechPointOnAttached(self, entity)
		if Shared.GetTime() > 5 then
			UpdateOrCreateAllNSLDecals()
		end
	end
)

local originalTechPointClearAttached
originalTechPointClearAttached = Class_ReplaceMethod("TechPoint", "ClearAttached", 
	function(self)
		originalTechPointClearAttached(self)
		if Shared.GetTime() > 5 then
			UpdateOrCreateAllNSLDecals()
		end
	end
)