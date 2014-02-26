local kLoadedSpawnFile = false
local kValidAlienSpawn = nil
gCustomTechPoints = { }

//Load this file on server startup, cache table
local function LoadCustomTechPointData()

	local file = io.open("maps/" .. Shared.GetMapName() .. ".txt", "r")
	local validfile = false
	if file then
		local t = json.decode(file:read("*all"), 1, nil)
		local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
		file:close()
		if t then
			for i,v in pairs(t) do
				for index, currentTechPoint in pairs(techPoints) do
					if (string.lower(v.name) == string.lower(currentTechPoint:GetLocationName())) then						
						// Modify the teams allowed to spawn here
						if (string.lower(v.team) == "marines") then
							currentTechPoint.allowedTeamNumber = 1
						elseif (string.lower(v.team) == "aliens") then
							currentTechPoint.allowedTeamNumber = 2
						elseif (string.lower(v.team) == "both") then
							currentTechPoint.allowedTeamNumber = 0
						// If we don't understand the team, no teams can spawn here
						else
							currentTechPoint.allowedTeamNumber = 3
						end
						
						// Assign the valid enemy spawns to the tech point
						if (v.enemyspawns ~= nil) then
							currentTechPoint.enemyspawns = v.enemyspawns
						end
						
						// Reset the weight parameter (will be customizable in the file later)
						currentTechPoint.chooseWeight = 1
						
						table.insert(gCustomTechPoints, currentTechPoint)
						validfile = true
					end
				end
			end
		end
	end

	if not validfile then
		gCustomTechPoints = nil
	end
	
	if validfile then
		//Prevent Map Specific spawn overrides from being used
		Server.spawnSelectionOverrides = nil
	end
	kLoadedSpawnFile = true
	
end

local originalNS2GRGetChooseTechPoint
//Override default tech point choosing function to something that supports using the caches	
originalNS2GRGetChooseTechPoint = Class_ReplaceMethod("NS2Gamerules", "ChooseTechPoint", 
	function(self, techPoints, teamNumber)
		
		local techPoint
		if not kLoadedSpawnFile then
			LoadCustomTechPointData()
		end
		if gCustomTechPoints == nil then
			techPoint = originalNS2GRGetChooseTechPoint(self, techPoints, teamNumber)
		else
			if teamNumber == kTeam1Index then
				techPoint = originalNS2GRGetChooseTechPoint(self, gCustomTechPoints, teamNumber)
				//Add back in this TP cause yea
				table.insert(gCustomTechPoints, techPoint)
				//If getting team1 spawn location, build alien spawns for next check
				local ValidAlienSpawns = { }
				for index, currentTechPoint in pairs(gCustomTechPoints) do
					local teamNum = currentTechPoint:GetTeamNumberAllowed()
					if (techPoint.enemyspawns ~= nil and (teamNum == 0 or teamNum == 2)) then
						for i,v in pairs(techPoint.enemyspawns) do
							if (v == currentTechPoint:GetLocationName()) then
								table.insert(ValidAlienSpawns, currentTechPoint)
							end
						end
					end
				end
				local randomTechPointIndex = self.techPointRandomizer:random(1, #ValidAlienSpawns)
				kValidAlienSpawn = ValidAlienSpawns[randomTechPointIndex]
			elseif teamNumber == kTeam2Index then
				techPoint = kValidAlienSpawn
			end
		end
		return techPoint
		
	end
)