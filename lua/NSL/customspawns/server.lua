-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/customspawns/server.lua
-- - Dragon

local kSelectedMarineSpawn
local kSelectedAlienSpawn
local kCustomTechPointData = { }
local kValidCustomSpawnData = false

local kFriendlySpawnHelpers = {
	ns2_biodome = {
		top = "atmosphere exchange", right = "hydroponics", bottom = "reception",
		left = "platform", middle = "falls", center = "falls" },

	ns2_descent = {
		top = "fabrication", right = "monorail", bottom = "drone bay", left = "launch control",
		middle = "hydroanalysis", center = "hydroanalysis" },

	ns2_jambi = {
		["top left"] = "pipeworks", top = {"pipeworks", "waste recycling"}, ["top right"] = "waste recycling",
		right = "waste recycling", bottom = "docking bay", left = "electrical core", middle = "gravity", center = "gravity" },

	ns2_mineral = {
		["top left"] = "drill site", top = {"drill site", "mineral processing"}, ["top right"] = "mineral processing",
		right = "production", bottom = "surface" },

	ns2_nexus = {
		top = "silo", right = "receiving", bottom = "relay", left = "extraction" },

	ns2_summit = {
		top = "atrium", right = "data core", bottom = "sub access", left = "flight control",
		middle = "crossroads", center = "crossroads" },

	ns2_tram = {
		["top left"] = "warehouse", top = {"warehouse", "server room"}, ["top right"] = "server room",
		right = "elevator transfer", bottom = "shipping", left = "repair room" },

	ns2_veil = {
		top = "control", right = "pipeline", ["bottom right"] = "pipeline", bottom = "cargo",
		middle = "cargo", ["bottom left"] = "sub-sector", left = "sub-sector" }
}

local function GetMapSpecificSpawns()
	local customSpawnData = GetNSLConfigValue("CustomSpawns")
	if customSpawnData then
		local now = os.time()
		local mapname = Shared.GetMapName()
		if customSpawnData[mapname] then
			local mapSpawnData = customSpawnData[mapname]
			for _, tpData in pairs(mapSpawnData) do
				if (tpData.effectiveDate and os.time(tpData.effectiveDate) <= now) and (tpData.expiryDate and os.time(tpData.expiryDate) >= now) then
					return tpData.spawnData
				end
			end
		end
	end
end

local function UpdateWithCustomSpawnLocations(techPoints, teamNumber)
	-- Apply our custom stuff to techpoint table
	if teamNumber == 1 then
		for _, tp in ipairs(techPoints) do
			local lowerLoc = string.lower(tp:GetLocationName())
			if kCustomTechPointData[lowerLoc] then
				tp.allowedTeamNumber = kCustomTechPointData[lowerLoc].allowedTeamNumber
				tp.chooseWeight = kCustomTechPointData[lowerLoc].chooseWeight
			else
				tp.allowedTeamNumber = 0
				tp.chooseWeight = 0
			end
		end
	end
	return techPoints
end

local function UpdateWithRemainingTechPoints(selectedTechPointLoc, techPoints, teamNumber)
	-- Apply our custom stuff to techpoint table
	if teamNumber == 1 then
		for i = #techPoints, 1, -1 do
			if not table.contains(kCustomTechPointData[selectedTechPointLoc].enemySpawns, string.lower(techPoints[i]:GetLocationName())) then
				table.remove(techPoints, i)
			end
		end
	end
	return techPoints
end

local originalNS2GRGetChooseTechPoint
--Override default tech point choosing function to something that supports using the caches	
originalNS2GRGetChooseTechPoint = Class_ReplaceMethod("NS2Gamerules", "ChooseTechPoint", 
	function(self, techPoints, teamNumber)
		
		local techPoint
		if not GetNSLModEnabled() or not GetNSLConfigValue("UseCustomSpawnConfigs") then
			techPoint = originalNS2GRGetChooseTechPoint(self, techPoints, teamNumber)
		else
			if GetNSLConfigValue("UseFixedSpawnsWhenLoaded") then
				if teamNumber == kTeam1Index then
					techPoint = kSelectedMarineSpawn
				elseif teamNumber == kTeam2Index then
					techPoint = kSelectedAlienSpawn
				end
			elseif kValidCustomSpawnData then
				techPoint = originalNS2GRGetChooseTechPoint(self, UpdateWithCustomSpawnLocations(techPoints, teamNumber), teamNumber)
				techPoints = UpdateWithRemainingTechPoints(string.lower(techPoint:GetLocationName()), techPoints, teamNumber)
			else
				--Blehhhhh
				techPoint = originalNS2GRGetChooseTechPoint(self, techPoints, teamNumber)
			end
		end
		return techPoint
		
	end
)

local function UpdateEnemySpawnData(currentloc, enemyspawns, teamType)
	for _, e in ipairs(enemyspawns) do
		local loc
		local weight = 1
		if type(e) == "table" then
			loc = string.lower(e.name)
			weight = e.weight
		else
			loc = string.lower(e)
		end
		if kCustomTechPointData[loc] then
			kCustomTechPointData[loc].allowedTeamNumber = teamType
			kCustomTechPointData[loc].chooseWeight = weight
		end
		table.insert(kCustomTechPointData[currentloc].enemySpawns, loc)
	end
end

local function LoadCustomTechPointData(config)
		
	if (config == "complete" or config == "reload") and GetNSLModEnabled() then
		--Cache once configs are loaded.
		local customSpawnData = GetMapSpecificSpawns()
		local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
		if customSpawnData then
			for _, tp in ipairs(techPoints) do
				kCustomTechPointData[string.lower(tp:GetLocationName())] = {location = string.lower(tp:GetLocationName())}
			end
			for _, currentTechPoint in ipairs(techPoints) do
				local lowerLoc = string.lower(currentTechPoint:GetLocationName())
				for _, v in ipairs(customSpawnData) do
					if string.lower(v.name) == lowerLoc then						
						--Modify the teams allowed to spawn here
						if (string.lower(v.team) == "marines") then
							kCustomTechPointData[lowerLoc].allowedTeamNumber = 1
							kCustomTechPointData[lowerLoc].chooseWeight = v.chooseWeight or 1
							kCustomTechPointData[lowerLoc].enemySpawns = { }
							UpdateEnemySpawnData(lowerLoc, v.enemyspawns, 2)
						elseif (string.lower(v.team) == "aliens") then
							kCustomTechPointData[lowerLoc].allowedTeamNumber = 2
							kCustomTechPointData[lowerLoc].chooseWeight = v.chooseWeight or 1
							kCustomTechPointData[lowerLoc].enemySpawns = { }
							UpdateEnemySpawnData(lowerLoc, v.enemyspawns, 1)
						elseif (string.lower(v.team) == "both") then
							kCustomTechPointData[lowerLoc].allowedTeamNumber = 0
							kCustomTechPointData[lowerLoc].chooseWeight = v.chooseWeight or 1
							kCustomTechPointData[lowerLoc].enemySpawns = { }
							UpdateEnemySpawnData(lowerLoc, v.enemyspawns, 0)
						else
							-- We dont know what this is, blacklist
							kCustomTechPointData[lowerLoc].allowedTeamNumber = 3
							kCustomTechPointData[lowerLoc].chooseWeight = v.chooseWeight or 0
							kCustomTechPointData[lowerLoc].enemySpawns = { }
						end
						kValidCustomSpawnData = true
						Server.spawnSelectionOverrides = nil
					end
				end
			end
		end
		
		if GetNSLConfigValue("UseFixedSpawnsWhenLoaded") then
			--Setup spawns now, reset game
			-- Apply our updates, if any
			UpdateWithCustomSpawnLocations(techPoints)
			local gamerules = GetGamerules()
				
			kSelectedMarineSpawn = originalNS2GRGetChooseTechPoint(gamerules, techPoints, 1)
			assert(kSelectedMarineSpawn ~= nil)
			kSelectedAlienSpawn =  originalNS2GRGetChooseTechPoint(gamerules, techPoints, 2)
			assert(kSelectedAlienSpawn ~= nil)
			
			--Prevent Map Specific spawn overrides from being used
			Server.spawnSelectionOverrides = nil
			
			gamerules:ResetGame()

		elseif kValidCustomSpawnData then

			GetGamerules():ResetGame()

		end

	end
	
end

table.insert(gConfigLoadedFunctions, LoadCustomTechPointData)

local function UpdateSpawnForMapSpecificSetups(teamSpawn)
	local mapname = Shared.GetMapName()
	if teamSpawn then
		teamSpawn = string.lower(teamSpawn)
		if kFriendlySpawnHelpers[mapname] and kFriendlySpawnHelpers[mapname][teamSpawn] then
			teamSpawn = kFriendlySpawnHelpers[mapname][teamSpawn]
			if type(teamSpawn) == "table" then
				teamSpawn = teamSpawn[math.random(1,#teamSpawn)]
			end
  		end
	end
	return teamSpawn
end

local function SetTeamSpawns(client, ...)

	if client then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			local args = StringConcatArgs(...)
			if args then
				local spawns = StringSplit(args, ",")
				local team1Spawn = spawns[1]
				local team2Spawn = spawns[2]
					
				if string.find(ToString(spawns), ",") and team2Spawn and team2Spawn ~= "" then
					team2Spawn = StringTrim(team2Spawn)
				end
				
				team1Spawn = UpdateSpawnForMapSpecificSetups(team1Spawn)
				team2Spawn = UpdateSpawnForMapSpecificSetups(team2Spawn)
				
				Server.teamSpawnOverride = { }
				if team1Spawn and team1Spawn ~= "" and team2Spawn and team2Spawn ~= "" and team1Spawn ~= team2Spawn and not GetGamerules():GetGameStarted() then
					table.insert(Server.teamSpawnOverride, { marineSpawn = string.lower(team1Spawn), alienSpawn = string.lower(team2Spawn) }) 
					SendClientServerAdminMessage(client, "NSL_SPAWNS_UPDATED", team1Spawn, team2Spawn)
					GetGamerules():ResetGame()
				else
					SendClientServerAdminMessage(client, "NSL_SPAWNS_INVALID_UPDATE")
				end
			else
				SendClientServerAdminMessage(client, "NSL_SPAWNS_INVALID_UPDATE")
			end
		end
	end
	
end

RegisterNSLConsoleCommand("sv_nslsetteamspawns", SetTeamSpawns, "SV_NSLSETTEAMSPAWNS")
RegisterNSLHelpMessageForCommand("SV_NSLSETTEAMSPAWNS", true)