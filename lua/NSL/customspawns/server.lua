-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/customspawns/server.lua
-- - Dragon

local kSelectedMarineSpawn
local kSelectedAlienSpawn
local kCustomTechPointData = { }
local kValidCustomSpawnData = false
local kCustomTechPointTeams = { }
local kMapLocations

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

--Need this to re-apply team values.
local function UpdateTechPointTeamsAfterReset(techPoints)
	for index, currentTechPoint in pairs(techPoints) do
		for k, v in pairs(kCustomTechPointTeams) do
			if (string.lower(k) == string.lower(currentTechPoint:GetLocationName())) then		
				currentTechPoint.allowedTeamNumber = v
			end
		end
	end
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
				if teamNumber == kTeam1Index then
					UpdateTechPointTeamsAfterReset(kCustomTechPointData)
					techPoint = originalNS2GRGetChooseTechPoint(self, kCustomTechPointData, teamNumber)
					--Add back in this TP cause yea
					table.insert(kCustomTechPointData, techPoint)
					--If getting team1 spawn location, build alien spawns for next check
					local ValidAlienSpawns = { }
					for index, currentTechPoint in pairs(kCustomTechPointData) do
						local teamNum = kCustomTechPointTeams[currentTechPoint:GetLocationName()]
						if (techPoint.enemyspawns ~= nil and (teamNum == 0 or teamNum == 2)) then
							for i,v in pairs(techPoint.enemyspawns) do
								if (string.lower(v) == string.lower(currentTechPoint:GetLocationName())) then
									table.insert(ValidAlienSpawns, currentTechPoint)
								end
							end
						end
					end
					local randomTechPointIndex = self.techPointRandomizer:random(1, #ValidAlienSpawns)
					kSelectedAlienSpawn = ValidAlienSpawns[randomTechPointIndex]
					assert(kSelectedAlienSpawn ~= nil)
				elseif teamNumber == kTeam2Index then
					techPoint = kSelectedAlienSpawn
				end
			else
				--Blehhhhh
				techPoint = originalNS2GRGetChooseTechPoint(self, techPoints, teamNumber)
			end
		end
		return techPoint
		
	end
)

local function LoadCustomTechPointData(configLoaded)
		
	if (configLoaded == "all" or configLoaded == "spawn") and GetNSLModEnabled() then
		--Cache once configs are loaded.
		kMapLocations = GetNSLConfigValue("FriendlySpawns")
		local customSpawnData = GetMapSpecificSpawns()
		local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
		if customSpawnData then
			for index, currentTechPoint in pairs(techPoints) do
				for _, v in pairs(customSpawnData) do
					if (string.lower(v.name) == string.lower(currentTechPoint:GetLocationName())) then						
						--Modify the teams allowed to spawn here
						if (string.lower(v.team) == "marines") then
							currentTechPoint.allowedTeamNumber = 1
						elseif (string.lower(v.team) == "aliens") then
							currentTechPoint.allowedTeamNumber = 2
						elseif (string.lower(v.team) == "both") then
							currentTechPoint.allowedTeamNumber = 0
						--If we don't understand the team, no teams can spawn here
						else
							currentTechPoint.allowedTeamNumber = 3
						end
						
						--Assign the valid enemy spawns to the tech point
						if (v.enemyspawns ~= nil) then
							currentTechPoint.enemyspawns = v.enemyspawns
						end
						
						--Reset the weight parameter (will be customizable in the file later)
						currentTechPoint.chooseWeight = 1
						
						kValidCustomSpawnData = true
						table.insert(kCustomTechPointData, currentTechPoint)
						kCustomTechPointTeams[currentTechPoint:GetLocationName()] = currentTechPoint.allowedTeamNumber
					end
				end
			end
		end
		
		if #kCustomTechPointData < 2 and kValidCustomSpawnData then
			--NOT valid data
			kValidCustomSpawnData = false
			Shared.Message("NSL - Error configuring custom spawns, invalid response or incorrectly configured weekly config!")
			kCustomTechPointData = nil
		end
		
		if kValidCustomSpawnData then
			--Prevent Map Specific spawn overrides from being used
			Server.spawnSelectionOverrides = nil
		end
		
		if GetNSLConfigValue("UseFixedSpawnsWhenLoaded") then
			--Setup spawns now, reset game
			local gamerules = GetGamerules()
			
			if not kValidCustomSpawnData then
				kSelectedMarineSpawn = originalNS2GRGetChooseTechPoint(gamerules, techPoints, 1)
				assert(kSelectedMarineSpawn ~= nil)
				kSelectedAlienSpawn = originalNS2GRGetChooseTechPoint(gamerules, techPoints, 2)
				assert(kSelectedAlienSpawn ~= nil)
			else
				kSelectedMarineSpawn = originalNS2GRGetChooseTechPoint(gamerules, kCustomTechPointData, 1)
				assert(kSelectedMarineSpawn ~= nil)
				--Add back in this TP cause yea
				table.insert(kCustomTechPointData, kSelectedMarineSpawn)
				--If getting team1 spawn location, build alien spawns for next check
				local ValidAlienSpawns = { }
				for index, currentTechPoint in pairs(kCustomTechPointData) do
					local teamNum = kCustomTechPointTeams[currentTechPoint:GetLocationName()]
					if (kSelectedMarineSpawn.enemyspawns ~= nil and (teamNum == 0 or teamNum == 2)) then
						for i,v in pairs(kSelectedMarineSpawn.enemyspawns) do
							if (string.lower(v) == string.lower(currentTechPoint:GetLocationName())) then
								table.insert(ValidAlienSpawns, currentTechPoint)
							end
						end
					end
				end
				local randomTechPointIndex = gamerules.techPointRandomizer:random(1, #ValidAlienSpawns)
				kSelectedAlienSpawn = ValidAlienSpawns[randomTechPointIndex]
				assert(kSelectedAlienSpawn ~= nil)
			end
			
			--Prevent Map Specific spawn overrides from being used
			Server.spawnSelectionOverrides = nil
			
			gamerules:ResetGame()
		end
	end
	
end

table.insert(gConfigLoadedFunctions, LoadCustomTechPointData)

local function UpdateSpawnForMapSpecificSetups(teamSpawn)
	local mapname = Shared.GetMapName()
	if teamSpawn then
		teamSpawn = string.lower(teamSpawn)
		if kMapLocations and kMapLocations[mapname] and kMapLocations[mapname][teamSpawn] then
			teamSpawn = kMapLocations[mapname][teamSpawn]
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
					
				if string.find(ToString(spawns), ",") then
					team2Spawn = StringTrim(team2Spawn)
				end
				
				team1Spawn = UpdateSpawnForMapSpecificSetups(team1Spawn)
				team2Spawn = UpdateSpawnForMapSpecificSetups(team2Spawn)
				
				Server.teamSpawnOverride = { }
				if team1Spawn and team1Spawn ~= "" and team2Spawn and team2Spawn ~= "" and team1Spawn ~= team2Spawn and not GetGamerules():GetGameStarted() then
					table.insert(Server.teamSpawnOverride, { marineSpawn = string.lower(team1Spawn), alienSpawn = string.lower(team2Spawn) }) 
					ServerAdminPrint(client, string.format("Setting spawns to %s for marines and %s for aliens.", team1Spawn, team2Spawn))
					GetGamerules():ResetGame()
				else
					ServerAdminPrint(client, "Invalid usage. Usage: <marine spawn location>, <alien spawn location>")
				end
			else
				ServerAdminPrint(client, "Invalid usage. Usage: <marine spawn location>, <alien spawn location>")
			end
		end
	end
	
end

Event.Hook("Console_sv_nslsetteamspawns", SetTeamSpawns)
RegisterNSLHelpMessageForCommand("sv_nslsetteamspawns: marinespawnname, alienspawnname, Spawns teams at specified locations. Locations must be exact", true)