-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/customspawns/server.lua
-- - Dragon

local kSelectedMarineSpawn
local kSelectedAlienSpawn
local kCustomTechPointData
local kSpawnConfigModes = { }

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
	if table.contains(kSpawnConfigModes, "CustomSpawns") then
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
end

local function UpdateWithCustomSpawnLocations(techPoints, teamNumber)
	-- Apply our custom stuff to techpoint table
	if teamNumber == 1 and kCustomTechPointData then
		for _, tp in ipairs(techPoints) do
			local lowerLoc = string.lower(tp:GetLocationName())
			if kCustomTechPointData[lowerLoc] then
				tp.allowedTeamNumber = kCustomTechPointData[lowerLoc].allowedTeamNumber
				tp.chooseWeight = kCustomTechPointData[lowerLoc].chooseWeight
			else
				tp.allowedTeamNumber = 3
				tp.chooseWeight = 0
			end
		end
	end
	return techPoints
end

local function UpdateWithRemainingTechPoints(selectedTechPointLoc, techPoints, teamNumber)
	-- Apply our custom stuff to techpoint table
	if teamNumber == 1 and kCustomTechPointData then
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
		if not GetNSLModEnabled() then
			techPoint = originalNS2GRGetChooseTechPoint(self, techPoints, teamNumber)
		else

			if table.contains(kSpawnConfigModes, "UseFixedSpawnsWhenLoaded") then
				if teamNumber == kTeam1Index then
					techPoint = kSelectedMarineSpawn
				elseif teamNumber == kTeam2Index then
					techPoint = kSelectedAlienSpawn
				end
			end

			if not techPoint and table.contains(kSpawnConfigModes, "AliensChoose") then
				if teamNumber == kTeam1Index then
					techPoint = kSelectedMarineSpawn
				elseif teamNumber == kTeam2Index then
					techPoint = kSelectedAlienSpawn
				end
			end
			if not techPoint and table.contains(kSpawnConfigModes, "CustomSpawns") and kCustomTechPointData then
				techPoint = originalNS2GRGetChooseTechPoint(self, UpdateWithCustomSpawnLocations(techPoints, teamNumber), teamNumber)
				techPoints = UpdateWithRemainingTechPoints(string.lower(techPoint:GetLocationName()), techPoints, teamNumber)
			end
			if not techPoint then
				techPoint = originalNS2GRGetChooseTechPoint(self, techPoints, teamNumber)
			end
		end
		return techPoint
		
	end
)

local function OnGameEndClearSpawns(gamerules)
	if not table.contains(kSpawnConfigModes, "UseFixedSpawnsWhenLoaded") then
		kSelectedMarineSpawn = nil
		kSelectedAlienSpawn = nil
		GetGameInfoEntity():SetSpawnSelection(-1)
	end
end

table.insert(gGameEndFunctions, OnGameEndClearSpawns)

local function UpdateEnemySpawnData(tpTable, currentloc, enemyspawns, teamType)
	for _, e in ipairs(enemyspawns) do
		local loc
		if type(e) == "table" then
			loc = string.lower(e.name)
		else
			loc = string.lower(e)
		end
		table.insert(tpTable[currentloc].enemySpawns, loc)
	end
end

local function LoadCustomTechPointData(config)
		
	if (config == "complete" or config == "reload") and GetNSLModEnabled() then
		kSpawnConfigModes = GetNSLConfigValue("CustomSpawnModes")
		--Cache once configs are loaded.
		local customSpawnData = GetMapSpecificSpawns()
		local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
		if customSpawnData and table.contains(kSpawnConfigModes, "CustomSpawns") then
			local tpTable = { }
			for _, tp in ipairs(techPoints) do
				tpTable[string.lower(tp:GetLocationName())] = 
				{ 
					allowedTeamNumber = 3,
					chooseWeight = 0,
					enemySpawns = { }
				}
			end
			local vA, vM, vB
			vB = 0
			for _, currentTechPoint in ipairs(techPoints) do
				local lowerLoc = string.lower(currentTechPoint:GetLocationName())
				for _, v in ipairs(customSpawnData) do
					if string.lower(v.name) == lowerLoc then						
						--Modify the teams allowed to spawn here
						if (string.lower(v.team) == "marines") then
							tpTable[lowerLoc].allowedTeamNumber = 1
							tpTable[lowerLoc].chooseWeight = v.chooseWeight or 1
							tpTable[lowerLoc].enemySpawns = { }
							UpdateEnemySpawnData(tpTable, lowerLoc, v.enemyspawns, 2)
							vM = true
						elseif (string.lower(v.team) == "aliens") then
							tpTable[lowerLoc].allowedTeamNumber = 2
							tpTable[lowerLoc].chooseWeight = v.chooseWeight or 1
							tpTable[lowerLoc].enemySpawns = { }
							UpdateEnemySpawnData(tpTable, lowerLoc, v.enemyspawns, 1)
							vA = true
						elseif (string.lower(v.team) == "both") then
							tpTable[lowerLoc].allowedTeamNumber = 0
							tpTable[lowerLoc].chooseWeight = v.chooseWeight or 1
							tpTable[lowerLoc].enemySpawns = { }
							UpdateEnemySpawnData(tpTable, lowerLoc, v.enemyspawns, 0)
							--vB = vB + 1
							if vB >= 2 then
								vA = true
								vM = true
							end
						end
					end
				end
			end
			if vM and vA or (vM and vB >= 1) or (vA and vB >= 1) then
				-- Its actually valid!
				kCustomTechPointData = tpTable
				Server.spawnSelectionOverrides = nil
			else
				Shared.Message("Invalid custom spawn data!")
			end
		end
		
		if table.contains(kSpawnConfigModes, "UseFixedSpawnsWhenLoaded") then
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

		else

			if table.contains(kSpawnConfigModes, "AliensChoose") then

				if Server.spawnSelectionOverrides and not kCustomTechPointData then

	    		    local validSpawns = { }
	    		    local spawnKey = { }
	    		    local teamSpawns = { }
	    		    local enemySpawns = { }

		            for t = 1, #Server.spawnSelectionOverrides do
		            	local selectedSpawn = Server.spawnSelectionOverrides[t]
		            	local lowerMarine = string.lower(selectedSpawn.marineSpawn)
		            	local lowerAlien = string.lower(selectedSpawn.alienSpawn)

		            	if table.contains(validSpawns, lowerMarine) then
		            		if teamSpawns[spawnKey[lowerMarine]] == 2 or teamSpawns[spawnKey[lowerMarine]] == 0 then
		            			teamSpawns[spawnKey[lowerMarine]] = 0
		            		else
		            			teamSpawns[spawnKey[lowerMarine]] = 1
		            		end
		            		if not table.contains(enemySpawns[spawnKey[lowerMarine]], lowerAlien) then
		            			table.insert(enemySpawns[spawnKey[lowerMarine]], lowerAlien)
		            		end		            		
		            	else
		            		table.insert(validSpawns, lowerMarine)
		            		spawnKey[lowerMarine] = #validSpawns
		            		teamSpawns[spawnKey[lowerMarine]] = 1
		            		enemySpawns[spawnKey[lowerMarine]] = { lowerAlien }
		            	end
		                if table.contains(validSpawns, lowerAlien) then
		            		if teamSpawns[spawnKey[lowerAlien]] == 1 or teamSpawns[spawnKey[lowerAlien]] == 0 then
		            			teamSpawns[spawnKey[lowerAlien]] = 0
		            		else
		            			teamSpawns[spawnKey[lowerAlien]] = 2
		            		end
		            		if not table.contains(enemySpawns[spawnKey[lowerAlien]], lowerMarine) then
		            			table.insert(enemySpawns[spawnKey[lowerAlien]], lowerMarine)
		            		end
		            	else
		            		table.insert(validSpawns, lowerAlien)
		            		spawnKey[lowerAlien] = #validSpawns
		            		teamSpawns[spawnKey[lowerAlien]] = 2
		            		enemySpawns[spawnKey[lowerAlien]] = { lowerMarine }
		            	end

		            end

		            if #validSpawns > 0 then

		            	kCustomTechPointData = { }

		            	for _, currentTechPoint in ipairs(techPoints) do
							kCustomTechPointData[string.lower(currentTechPoint:GetLocationName())] = 
								{
									allowedTeamNumber = 3,
									chooseWeight = 0,
									enemySpawns = { }
								}
						end

			            for i = 1, #validSpawns do

			            	kCustomTechPointData[validSpawns[i]] = 
							{ 
								allowedTeamNumber = teamSpawns[i],
								chooseWeight = 1,
								enemySpawns = enemySpawns[i]
							}
			            end

			        end

				end

				if kCustomTechPointData then

					for _, tp in ipairs(techPoints) do

						local lowerLoc = string.lower(tp:GetLocationName())
						if kCustomTechPointData[lowerLoc] then
							tp.allowedTeamNumber = kCustomTechPointData[lowerLoc].allowedTeamNumber
							tp.chooseWeight = kCustomTechPointData[lowerLoc].chooseWeight
						else
							tp.allowedTeamNumber = 3
							tp.chooseWeight = 0
						end

					end

				end

				GetGamerules():ResetGame()

				--Prevent Map Specific spawn overrides from being used
				Server.spawnSelectionOverrides = nil

			elseif kCustomTechPointData then

				GetGamerules():ResetGame()
			end

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

RegisterNSLConsoleCommand("sv_nslsetteamspawns", SetTeamSpawns, "SV_NSLSETTEAMSPAWNS", false,
	{{ Type = "string", Error = "Please provide location name for marine spawn."},
	{ Type = "string", TakeRestOfLine = true, Error = "Please provide location name for alien spawn."}})

local function onSpawnSelectionMessage(client, message)

    local player = client:GetControllingPlayer()
    if player and message then

        -- This only works for comms on the alien team.
        if player:GetIsCommander() and player:GetTeamNumber() == kTeam2Index then

        	kSelectedAlienSpawn = nil

        	local tp = Shared.GetEntity(message.techPointId)
        	if tp and tp:isa("TechPoint") and (tp:GetTeamNumberAllowed() == 0 or tp:GetTeamNumberAllowed() == 2) then
        		kSelectedAlienSpawn = tp
        		GetGameInfoEntity():SetSpawnSelection(tp:GetId())
        	end

        	if kSelectedAlienSpawn then
        		-- Now figure out marine spawn
        		local alienTechPointName = string.lower(kSelectedAlienSpawn:GetLocationName())
        		local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))

        		NSLSendTeamMessage(kTeam2Index, "NSL_TEAM_CHOOSE_SPAWN", false, kSelectedAlienSpawn:GetLocationName())

        		local marineTechPointNames = { }

        		if kCustomTechPointData then

        			for _, currentTechPoint in ipairs(techPoints) do
        				local lowerloc = string.lower(currentTechPoint:GetLocationName())
        				if kCustomTechPointData[lowerloc] then
	        				local enemySpawns = kCustomTechPointData[lowerloc].enemySpawns
	        				if enemySpawns and table.contains(enemySpawns, alienTechPointName) then
	        					table.insertunique(marineTechPointNames, lowerloc)
	        				end
	        			end
        			end

        		end

		        if marineTechPointNames and #marineTechPointNames > 0 then

		        	local selectedName
		        	if #marineTechPointNames == 1 then
		        		selectedName = marineTechPointNames[1]
		        	else
		        		selectedName = marineTechPointNames[math.random(1, #marineTechPointNames)]
		        	end
		        	for _, currentTechPoint in ipairs(techPoints) do
				    	if selectedName == string.lower(currentTechPoint:GetLocationName()) then
				    		kSelectedMarineSpawn = currentTechPoint
				    		break
				    	end
				    end

		        end

		        if not kSelectedMarineSpawn then

		        	-- Um?
		        	local validTechPoints = { }
				    local totalTechPointWeight = 0
				    local gameRules = GetGamerules()

				    for _, currentTechPoint in ipairs(techPoints) do
				    
				        local teamNum = currentTechPoint:GetTeamNumberAllowed()
				        if (teamNum == 0 or teamNum == 1) and teamNum ~= 3 then
				        
				            table.insert(validTechPoints, currentTechPoint)
				            totalTechPointWeight = totalTechPointWeight + currentTechPoint:GetChooseWeight()
				            
				        end
				        
				    end
				    
				    local chosenTechPointWeight = gameRules.techPointRandomizer:random(0, totalTechPointWeight)
				    for _, currentTechPoint in ipairs(validTechPoints) do
				    
				        chosenTechPointWeight = chosenTechPointWeight - currentTechPoint:GetChooseWeight()
				        if chosenTechPointWeight >= 0 then
				        
				            kSelectedMarineSpawn = currentTechPoint
				            break
				            
				        end
				        
				    end

		        end

		    else

		    	NSLSendTeamMessage(kTeam2Index, "NSL_TEAM_CHOOSE_RANDOM_SPAWN", false)
		    	kSelectedMarineSpawn = nil
		    	kSelectedAlienSpawn = nil

        	end
        end
        
    end
    
end

Server.HookNetworkMessage("NSLSelectSpawn", onSpawnSelectionMessage)