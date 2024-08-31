-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/misc/server.lua
-- - Dragon

local kNSLTag = "nsl"

-- Supposedly this still not syncronized.
local function SetupClientRatesandConfig(client)
	-- Confirm we scanned the defaults already
	if GetNSLDefaultPerfValue("Interp") then
		--If non-default rates, send to clients.
		if GetNSLDefaultPerfValue("Interp") ~= Shared.GetServerPerformanceData():GetInterpMs() then
			if Server.SetInterpolationDelay then
				Server.SetInterpolationDelay(GetNSLPerfValue("Interp") / 1000)
			else
				Shared.ConsoleCommand(string.format("interp %f", (GetNSLPerfValue("Interp") / 1000)))
			end
		end
		if GetNSLDefaultPerfValue("MoveRate") ~= Shared.GetServerPerformanceData():GetMoverate() then
			if Server.SetMoveRate then
				Server.SetMoveRate(GetNSLPerfValue("MoveRate"))
			else
				Shared.ConsoleCommand(string.format("mr %f", (GetNSLPerfValue("MoveRate"))))
			end
		end
	end
end

local function SetupNSLTag()
	Server.RemoveTag(kNSLTag)
	if GetNSLModEnabled() then
		Server.AddTag(kNSLTag)
	end
end

local function SetupRates()
	
	if Server.GetTickrate and Server.SetTickRate and GetNSLPerfValue("TickRate") > Server.GetTickrate() then
		-- Tickrate going up, increase it first.
		Server.SetTickRate(GetNSLPerfValue("TickRate"))
		
		if GetNSLPerfValue("ClientRate") ~= Server.GetSendrate() then
			Server.SetSendRate(GetNSLPerfValue("ClientRate"))
		end
	elseif Server.GetTickrate and Server.SetTickRate and GetNSLPerfValue("TickRate") <= Server.GetTickrate() then
		-- Tickrate going down, set updaterate first.
		if GetNSLPerfValue("ClientRate") ~= Server.GetSendrate() then
			Server.SetSendRate(GetNSLPerfValue("ClientRate"))
		end
		if GetNSLPerfValue("TickRate") ~= Server.GetTickrate() then
			Server.SetTickRate(GetNSLPerfValue("TickRate"))
		end
	end
	
	if GetNSLPerfValue("MaxDataRate") ~= math.ceil(Server.GetBwLimit() / 1024) then
		Shared.ConsoleCommand(string.format("bwlimit %f", (GetNSLPerfValue("MaxDataRate") * 1024)))
	end
	
	if GetNSLPerfValue("Interp") ~= Shared.GetServerPerformanceData():GetInterpMs() then
		if Server.SetInterpolationDelay then
			Server.SetInterpolationDelay(GetNSLPerfValue("Interp") / 1000)
		else
			Shared.ConsoleCommand(string.format("interp %f", (GetNSLPerfValue("Interp") / 1000)))
		end
	end
	
	if GetNSLPerfValue("MoveRate") ~= Shared.GetServerPerformanceData():GetMoverate() then
		if Server.SetMoveRate then
			Server.SetMoveRate(GetNSLPerfValue("MoveRate"))
		else
			Shared.ConsoleCommand(string.format("mr %f", (GetNSLPerfValue("MoveRate"))))
		end
	end
	
	SetupNSLTag()

	-- If we are not changing this anymore, just completely disable
	-- Server.SetNetworkFieldTruncationControl(GetNSLConfigValue("NetworkTruncation"))
	-- Shared.Message(string.format("Network Truncation set to %s.", GetNSLConfigValue("NetworkTruncation")))
end

table.insert(gConnectFunctions, SetupClientRatesandConfig)

table.insert(gPerfLoadedFunctions, SetupRates)

local originalPlayerOnJoinTeam
-- Maintain original PlayerOnJoinTeam
originalPlayerOnJoinTeam = Class_ReplaceMethod("Player", "OnJoinTeam", 
	function(self)
		originalPlayerOnJoinTeam(self)
		--This is new, to prevent players joining midgame and getting pRes.
		local gamerules = GetGamerules()
		if gamerules and gamerules:GetGameStarted() and GetNSLModEnabled() then
			--Set pres to 0.
			local team = self:GetTeam()
			local startingpres = kPlayerInitialIndivRes
			if kAlienInitialIndivRes and kMarineInitialIndivRes and team then
				startingpres = ConditionalValue(team.GetIsAlienTeam and team:GetIsAlienTeam(), kAlienInitialIndivRes, kMarineInitialIndivRes)
			end
			if self:GetResources() == startingpres then
				self:SetResources(0)
			end
		end
	end
)

local originalNS2GRGetFriendlyFire
-- Override friendly fire function checks
originalNS2GRGetFriendlyFire = Class_ReplaceMethod("NS2Gamerules", "GetFriendlyFire", 
	function(self)
		return GetNSLConfigValue("FriendlyFireEnabled") and GetNSLModEnabled()
	end
)

-- Override friendly fire function checks
function GetFriendlyFire()
	return GetNSLConfigValue("FriendlyFireEnabled") and GetNSLModEnabled()
end

local originalNS2GRGetWarmUpPlayerLimit
-- Override warmup mode player limit
originalNS2GRGetWarmUpPlayerLimit = Class_ReplaceMethod("NS2Gamerules", "GetWarmUpPlayerLimit", 
	function(self)
		return GetNSLModEnabled() and 100 or originalNS2GRGetWarmUpPlayerLimit(self)
	end
)

local oldGetCanTakeDamage = LiveMixin.GetCanTakeDamage
-- Prevent damage to players in warmup mode
function LiveMixin:GetCanTakeDamage()
	-- WarmUp func is part of newer builds 'pregame', only active if that exists in gamestate enum
	if table.contains(kGameState, "WarmUp") and GetNSLModEnabled() and GetGameInfoEntity():GetState() == kGameState.WarmUp then
		return false
	end

	return oldGetCanTakeDamage(self)
end

local originalNS2GRKillEnemiesNearCommandStructureInPreGame
-- Shrink the pregame damage area to just near the command structure
originalNS2GRKillEnemiesNearCommandStructureInPreGame = Class_ReplaceMethod("NS2Gamerules", "KillEnemiesNearCommandStructureInPreGame",
	function(self, timePassed)
		if GetNSLModEnabled() then
			if self:GetGameState() < kGameState.Countdown then

				local commandStations = Shared.GetEntitiesWithClassname("CommandStructure")
				for _, ent in ientitylist(commandStations) do

					local enemyPlayers = GetEntitiesForTeam("Player", GetEnemyTeamNumber(ent:GetTeamNumber()))
					for e = 1, #enemyPlayers do

						local enemy = enemyPlayers[e]
						if enemy:GetDistance(ent) <= 5 then
							enemy:TakeDamage(25 * timePassed, nil, nil, nil, nil, 0, 25 * timePassed, kDamageType.Normal)
						end
					end
				end
			end
		else
			originalNS2GRKillEnemiesNearCommandStructureInPreGame(self, timePassed)
		end
	end
)

local oldMapCycle_CycleMap = MapCycle_CycleMap
function MapCycle_CycleMap()
	-- Override to prevent automatic mapcycle from lazy server admins
end

-- Keep vanilla behavior when a map change fails
local function NewOnMapChangeFailed(mapName)
    Log("Failed to load map '%s', cycling...", mapName);
    oldMapCycle_CycleMap(mapName)
end

Event.RemoveHook("MapChangeFailed", OnMapChangeFailed)
Event.Hook("MapChangeFailed", NewOnMapChangeFailed)

local function NewServerAgeCheck(self)
	if GetNSLModEnabled() then
		if self.gameState ~= kGameState.Started and Shared.GetTime() > GetNSLConfigValue("AutomaticMapCycleDelay") and Server.GetNumPlayers() == 0 then
			oldMapCycle_CycleMap()
		end
	else
		if self.gameState ~= kGameState.Started and Shared.GetTime() > 36000 and Server.GetNumPlayers() == 0 then
			oldMapCycle_CycleMap()
		end
	end
end

-- Setup Periodic MapCycle to prevent some animation craziness.
ReplaceLocals(NS2Gamerules.OnUpdate, { ServerAgeCheck = NewServerAgeCheck })

-- Set friendly fire percentage
local function SetupServerConfig(config)
	if (config == "complete" or config == "reload") then

		if GetNSLModEnabled() then
			kFriendlyFireScalar = GetNSLConfigValue("FriendlyFireDamagePercentage")
			-- Block AFK, AutoConcede, AutoTeamBalance and other server cfg stuff
			Server.SetConfigSetting("rookie_friendly", false)
			Server.SetConfigSetting("force_even_teams_on_join", false)
			Server.SetConfigSetting("auto_team_balance", {enabled_after_seconds = 0, enabled = false, enabled_on_unbalance_amount = 2})
			Server.SetConfigSetting("end_round_on_team_unbalance", nil)
			Server.SetConfigSetting("end_round_on_team_unbalance_check_after_time", nil)
			Server.SetConfigSetting("end_round_on_team_unbalance_after_warning_time", nil)
			Server.SetConfigSetting("auto_kick_afk_time", nil)
			Server.SetConfigSetting("auto_kick_afk_capacity", nil)
			Server.SetConfigSetting("quickplay_ready", false)
			Server.SetConfigSetting("auto_vote_add_commander_bots", false)
			--Server.SetVariableTableCommandsAllowed(not GetNSLMode() == kNSLPluginConfigs.OFFICIAL)
		end

	end

end

table.insert(gConfigLoadedFunctions, SetupServerConfig)

local function SetupServerRanking()
	if not GetNSLModEnabled() or not GetNSLConfigValue("RankingDisabled") then
		gRankingDisabled = false
		Shared.Message(string.format("Server Ranking Enabled."))
		
		--Call function to request whitelisting check for ranking enablement - called as part of consistency check in vanilla.
		local ok = Server.EnableServerRanking()
		Print("Requesting server ranking be enabled, request success: %s", ok)
	else
		gRankingDisabled = true
		Shared.Message(string.format("Server Ranking Disabled."))
	end
end

table.insert(gConfigLoadedFunctions, SetupServerRanking)
table.insert(gPluginStateChange, SetupServerRanking)
