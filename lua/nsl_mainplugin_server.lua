//NSL Main Plugin
//Reworked to function more as a 'league' plugin, not just a ENSL plugin.

Script.Load("lua/nsl_class.lua")
Script.Load("lua/nsl_mainplugin_shared.lua")
Script.Load("lua/nsl_eventhooks_server.lua")
Script.Load("lua/nsl_playerdata_server.lua")
Script.Load("lua/nsl_teammanager_server.lua")
local kCachedDataRate = 25
local kCachedMoveRate = 30
local kCachedInterp = 100

//Supposedly this still not syncronized.
local function SetupClientRates()
	//If non-default rates, send to clients.
	if GetNSLPerfValue("Interp") ~= 100 then
		Shared.ConsoleCommand(string.format("interp %f", (GetNSLPerfValue("Interp") / 1000)))
	end
	if GetNSLPerfValue("MoveRate") ~= 30 then
		Shared.ConsoleCommand(string.format("mr %f", GetNSLPerfValue("MoveRate")))
	end
end

local function SetupRates()
	
	if GetNSLPerfValue("TickRate") > Server.GetTickrate() then
		//Tickrate going up, increase it first.
		Shared.ConsoleCommand(string.format("tickrate %f", GetNSLPerfValue("TickRate")))
		if GetNSLPerfValue("ClientRate") ~= Server.GetSendrate() then
			Shared.ConsoleCommand(string.format("sendrate %f", GetNSLPerfValue("ClientRate")))
		end
	elseif GetNSLPerfValue("TickRate") <= Server.GetTickrate() then
		//Tickrate going down, set updaterate first.
		if GetNSLPerfValue("ClientRate") ~= Server.GetSendrate() then
			Shared.ConsoleCommand(string.format("sendrate %f", GetNSLPerfValue("ClientRate")))
		end
		Shared.ConsoleCommand(string.format("tickrate %f", GetNSLPerfValue("TickRate")))
	end
	if GetNSLPerfValue("MaxDataRate") ~= kCachedDataRate then
		Shared.ConsoleCommand(string.format("bwlimit %f", (GetNSLPerfValue("MaxDataRate") * 1024)))
		kCachedDataRate = GetNSLPerfValue("MaxDataRate")
	end
	if GetNSLPerfValue("Interp") ~= kCachedInterp then
		Shared.ConsoleCommand(string.format("interp %f", (GetNSLPerfValue("Interp") / 1000)))
		kCachedInterp = GetNSLPerfValue("Interp")
	end
	if GetNSLPerfValue("MoveRate") ~= kCachedMoveRate then
		Shared.ConsoleCommand(string.format("mr %f", GetNSLPerfValue("MoveRate")))
		kCachedMoveRate = GetNSLPerfValue("MoveRate")
	end
end

table.insert(gConnectFunctions, SetupClientRates)
table.insert(gConfigLoadedFunctions, SetupRates)

local originalPlayerOnJoinTeam
//Maintain original PlayerOnJoinTeam
originalPlayerOnJoinTeam = Class_ReplaceMethod("Player", "OnJoinTeam", 
	function(self)
		originalPlayerOnJoinTeam(self)
		//This is new, to prevent players joining midgame and getting pRes.
		local gamerules = GetGamerules()
		if gamerules and gamerules:GetGameStarted() then
			//Set pres to 0.
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
//Override friendly fire function checks
originalNS2GRGetFriendlyFire = Class_ReplaceMethod("NS2Gamerules", "GetFriendlyFire", 
	function(self)
		return GetNSLConfigValue("FriendlyFireEnabled") and GetNSLModEnabled()
	end
)

//Override friendly fire function checks
function GetFriendlyFire()
	return GetNSLConfigValue("FriendlyFireEnabled") and GetNSLModEnabled()
end

local oldMapCycle_CycleMap = MapCycle_CycleMap
function MapCycle_CycleMap()
	//Override to prevent automatic mapcycle from lazy server admins
end

local function NewServerAgeCheck(self)
	if GetNSLModEnabled() then
		if self.gameState ~= kGameState.Started and Shared.GetTime() > GetNSLConfigValue("AutomaticMapCycleDelay") and Server.GetNumPlayers() == 0 then
			oldMapCycle_CycleMap()
		end
	else
		if self.gameState ~= kGameState.Started and Shared.GetTime() > 360000 and Server.GetNumPlayers() == 0 then
			oldMapCycle_CycleMap()
		end
	end
end

//Setup Periodic MapCycle to prevent some animation craziness.
ReplaceLocals(NS2Gamerules.OnUpdate, { ServerAgeCheck = NewServerAgeCheck })

//Set friendly fire percentage
kFriendlyFireScalar = GetNSLConfigValue("FriendlyFireDamagePercentage")

//Simple functions to make sending messages easier.
function SendAllClientsMessage(message)
	Server.SendNetworkMessage("Chat", BuildChatMessage(false, GetNSLConfigValue("LeagueName"), -1, kTeamReadyRoom, kNeutralTeamType, message), true)
end

function SendClientMessage(client, message)
	if client then
		Server.SendNetworkMessage(client, "Chat", BuildChatMessage(false, GetNSLConfigValue("LeagueName"), -1, kTeamReadyRoom, kNeutralTeamType, message), true)
	end
end

function SendTeamMessage(teamnum, message)
	local chatmessage = BuildChatMessage(false, GetNSLConfigValue("LeagueName"), -1, kTeamReadyRoom, kNeutralTeamType, message)
	if tonumber(teamnum) then
		local playerRecords = GetEntitiesForTeam("Player", teamnum)
		for _, player in ipairs(playerRecords) do
			
			local client = Server.GetOwner(player)
			if client then
				Server.SendNetworkMessage(client, "Chat", chatmessage, true)
			end
		
		end
	end
end

local function OnClientCommandNSLHelp(client)
	if client then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			ServerAdminPrint(client, "sv_nslsay" .. ": " .. "<message> - Will send a message to all connected players that displays in yellow.")
			ServerAdminPrint(client, "sv_nsltsay" .. ": " .. "<team, message> - Will send a message to all players on the team provided that displays in yellow.")
			ServerAdminPrint(client, "sv_nslpsay" .. ": " .. "<player, message> - Will send a message to the provided player that displays in yellow.")
			ServerAdminPrint(client, "sv_nslcfg" .. ": " .. "<state> - disabled,pcw,official - Changes the configuration mode of the NSL plugin.")
			ServerAdminPrint(client, "sv_nslconfig" .. ": " .. "<league> - Changes the league settings used by the NSL plugin.")
			ServerAdminPrint(client, "sv_nslperfconfig" .. ": " .. "<config> - Changes the performance config used by the NSL plugin.")
			ServerAdminPrint(client, "sv_nslapprovemercs" .. ": " .. "<team, opt. player> - Forces approval of teams mercs, '1' approving for marines which allows alien mercs.")
			ServerAdminPrint(client, "sv_nslclearmercs" .. ": " .. "<team> - 1,2 - Clears approval of teams mercs, '1' clearing any alien mercs.")
			ServerAdminPrint(client, "sv_nslpause" .. ": " .. "Will pause/unpause game using standard delays.  Does not consume teams allowed pauses.")
			ServerAdminPrint(client, "sv_nslsetpauses" .. ": " .. "<team, pauses> - Sets the number of pauses remaining for a team.")
			ServerAdminPrint(client, "sv_nslforcestart" .. ": " .. "Will force the countdown to start regardless of teams ready status, still requires commanders.")
			ServerAdminPrint(client, "sv_nslcancelstart" .. ": " .. "Will cancel a game start countdown currently in progress.")
			ServerAdminPrint(client, "sv_nslsetteamnames" .. ": " .. "<team1name, team2name> Will set the team names manually, will prevent automatic team name updates.")
			ServerAdminPrint(client, "sv_nslswitchteams" .. ": " .. "Will switch team names (best used if setting team names manually).")
			ServerAdminPrint(client, "sv_nslsetteamscores" .. ": " .. "<t1score, t2score> Will set the team scores manually.")
			ServerAdminPrint(client, "sv_nslsetteamspawns" .. ": " .. "marinespawnname, alienspawnname, Spawns teams at specified locations. Locations must be exact")
		end
		ServerAdminPrint(client, "sv_nslinfo" .. ": " .. "<team> - marines,aliens,specs,other,all - Will return the player details from the corresponding league site.")
		ServerAdminPrint(client, "sv_nslmerchelp" .. ": " .. "Displays specific help information pertaining to approving and clearing mercs.")
	end
end

Event.Hook("Console_sv_nslhelp",               OnClientCommandNSLHelp)

local function UpdateNSLMode(client, mode)
	mode = mode or ""
	if string.lower(mode) == "pcw" then
		SetNSLMode("PCW")
	elseif string.lower(mode) == "official" then
		SetNSLMode("OFFICIAL")
	elseif string.lower(mode) == "disabled" then
		SetNSLMode("DISABLED")
	else
		ServerAdminPrint(client, string.format("NSL Plugin currently running in %s config.", GetNSLMode()))
		return
	end
	ServerAdminPrint(client, string.format("NSL Plugin now running in %s config.", GetNSLMode()))
end

local function UpdateNSLLeague(client, league)
	league = string.upper(league or "")
	if GetNSLLeagueValid(league) then
		SetActiveLeague(league)
		ServerAdminPrint(client, string.format("NSL Plugin now using %s league config.", GetActiveLeague()))
	else
		ServerAdminPrint(client, string.format("NSL Plugin currently using %s league config.", GetActiveLeague()))
	end
end

local function UpdateNSLPerfConfig(client, perfcfg)
	perfcfg = string.upper(perfcfg or "")
	if GetPerfLevelValid(perfcfg) then
		SetPerfLevel(perfcfg)
		ServerAdminPrint(client, string.format("NSL Plugin now using %s performance config.", GetNSLPerfLevel()))
	else
		ServerAdminPrint(client, string.format("NSL Plugin currently using %s performance config.", GetNSLPerfLevel()))
	end
end

local function ServerAdminOrNSLRefCommand(client, parameter, functor, admin)
	local isRef
	if client then
		local NS2ID = client:GetUserId()
		isRef = GetIsNSLRef(NS2ID)
	end
	if isRef or admin then
		functor(client, parameter)
	end
end

local function OnAdminCommandSetMode(client, mode)
	ServerAdminOrNSLRefCommand(client, mode, UpdateNSLMode, true)
end

local function OnClientCommandSetMode(client, mode)
	ServerAdminOrNSLRefCommand(client, mode, UpdateNSLMode, false)
end

Event.Hook("Console_sv_nslcfg",               OnClientCommandSetMode)
CreateServerAdminCommand("Console_sv_nslcfg", OnAdminCommandSetMode, "<state> - disabled,pcw,official - Changes the configuration mode of the NSL plugin.")

local function OnAdminCommandSetLeague(client, league)
	ServerAdminOrNSLRefCommand(client, league, UpdateNSLLeague, true)
end

local function OnClientCommandSetLeague(client, league)
	ServerAdminOrNSLRefCommand(client, league, UpdateNSLLeague, false)
end

Event.Hook("Console_sv_nslconfig",               OnClientCommandSetLeague)
CreateServerAdminCommand("Console_sv_nslconfig", OnAdminCommandSetLeague, "<league> - Changes the league configuration used by the NSL mod.")

local function OnAdminCommandSetPerfConfig(client, perfcfg)
	ServerAdminOrNSLRefCommand(client, perfcfg, UpdateNSLPerfConfig, true)
end

local function OnClientCommandSetPerfConfig(client, perfcfg)
	ServerAdminOrNSLRefCommand(client, perfcfg, UpdateNSLPerfConfig, false)
end

Event.Hook("Console_sv_nslperfconfig",               OnClientCommandSetPerfConfig)
CreateServerAdminCommand("Console_sv_nslperfconfig", OnAdminCommandSetPerfConfig, "<config> - Changes the performance configuration used by the NSL mod.")

local function SetupServerConfig()
	//Block AFK, AutoConcede, AutoTeamBalance and other server cfg stuff
	Server.SetConfigSetting("rookie_friendly", false)
	Server.SetConfigSetting("force_even_teams_on_join", false)
	Server.SetConfigSetting("auto_team_balance", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance_check_after_time", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance_after_warning_time", nil)
	Server.SetConfigSetting("auto_kick_afk_time", nil)
	Server.SetConfigSetting("auto_kick_afk_capacity", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance", nil)
end

table.insert(gConfigLoadedFunctions, SetupServerConfig)

local oldGetHasDLC = GetHasDLC
function GetHasDLC(productId, client)
	if GetNSLConfigValue("UseDefaultSkins")
		return productId == nil or productId == 0
	else
		return oldGetHasDLC(productId, client)
	end
end