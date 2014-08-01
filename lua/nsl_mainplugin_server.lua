//NSL Main Plugin
//Reworked to function more as a 'league' plugin, not just a ENSL plugin.

Script.Load("lua/nsl_class.lua")
Script.Load("lua/nsl_mainplugin_shared.lua")
Script.Load("lua/nsl_eventhooks_server.lua")
Script.Load("lua/nsl_playerdata_server.lua")
Script.Load("lua/nsl_teammanager_server.lua")

local function SetupRates()
	if GetNSLConfigValue("Interp") ~= 100 then
		Shared.ConsoleCommand(string.format("interp %f", (GetNSLConfigValue("Interp")/1000)))
	end
	if GetNSLConfigValue("ClientRate") ~= 20 then
		//Shared.ConsoleCommand(string.format("cr %f", GetNSLConfigValue("ClientRate")))
	end
	if GetNSLConfigValue("MoveRate") ~= 30 then
		Shared.ConsoleCommand(string.format("mr %f", GetNSLConfigValue("MoveRate")))
	end
	if GetNSLConfigValue("TickRate") ~= 30 then
		Shared.ConsoleCommand(string.format("tr %f", GetNSLConfigValue("TickRate")))
	end
	if GetNSLConfigValue("MaxDataRate") ~= 25600 then
		Shared.ConsoleCommand(string.format("dr %f", GetNSLConfigValue("MaxDataRate")))
	end
end

table.insert(gConfigLoadedFunctions, SetupRates)

function Player:OnJoinTeam()
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

local originalAlienOnJoinTeam
//Maintain original AlienOnJoinTeam
originalAlienOnJoinTeam = Class_ReplaceMethod("Alien", "OnJoinTeam", 
	function(self)
		originalAlienOnJoinTeam(self)
		Player.OnJoinTeam(self)
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
	if client ~= nil then
		Server.SendNetworkMessage(client, "Chat", BuildChatMessage(false, GetNSLConfigValue("LeagueName"), -1, kTeamReadyRoom, kNeutralTeamType, message), true)
	end
end

function SendTeamMessage(teamnum, message)
	local chatmessage = BuildChatMessage(false, GetNSLConfigValue("LeagueName"), -1, kTeamReadyRoom, kNeutralTeamType, message)
	if tonumber(teamnum) ~= nil then
		local playerRecords = GetEntitiesForTeam("Player", teamnum)
		for _, player in ipairs(playerRecords) do
			
			local client = Server.GetOwner(player)
			if client ~= nil then
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
			ServerAdminPrint(client, "sv_nslapprovemercs" .. ": " .. "<team, opt. player> - Forces approval of teams mercs, '1' approving for marines which allows alien mercs.")
			ServerAdminPrint(client, "sv_nslclearmercs" .. ": " .. "<team> - 1,2 - Clears approval of teams mercs, '1' clearing any alien mercs.")
			ServerAdminPrint(client, "sv_nslpause" .. ": " .. "Will pause/unpause game using standard delays.  Does not consume teams allowed pauses.")
			ServerAdminPrint(client, "sv_nslsetpauses" .. ": " .. "<team, pauses> - Sets the number of pauses remaining for a team.")
			ServerAdminPrint(client, "sv_nslforcestart" .. ": " .. "Will force the countdown to start regardless of teams ready status, still requires commanders.")
			ServerAdminPrint(client, "sv_nslcancelstart" .. ": " .. "Will cancel a game start countdown currently in progress.")
			ServerAdminPrint(client, "sv_nslsetteamnames" .. ": " .. "<team1name, team2name> Will set the team names manually, will prevent automatic team name updates.")
			ServerAdminPrint(client, "sv_nslswitchteams" .. ": " .. "Will switch team names (best used if setting team names manually).")
			ServerAdminPrint(client, "sv_nslsetteamscores" .. ": " .. "<t1score, t2score> Will set the team scores manually.")
		end
		ServerAdminPrint(client, "sv_nslinfo" .. ": " .. "<team> - marines,aliens,specs,other,all - Will return the player details from the corresponding league site.")
		ServerAdminPrint(client, "sv_nslmerchelp" .. ": " .. "Displays specific help information pertaining to approving and clearing mercs.")
	end
end

Event.Hook("Console_sv_nslhelp",               OnClientCommandNSLHelp)

local function UpdateNSLMode(client, mode)
	if string.lower(mode) == "pcw" then
		SetNSLMode("PCW")
	elseif string.lower(mode) == "official" then
		SetNSLMode("OFFICIAL")
	elseif string.lower(mode) == "disabled" then
		SetNSLMode("DISABLED")
	end
	ServerAdminPrint(client, string.format("NSL Plugin now running in %s config.", GetNSLMode()))
end

local function OnClientSVCommandSetMode(client, mode)
	local isRef = false
	if client then
		local NS2ID = client:GetUserId()
		isRef = GetIsNSLRef(NS2ID)
	end
	if (not isRef or not GetNSLModEnabled()) and mode ~= nil then
		UpdateNSLMode(client, mode)
	end
end

local function OnClientCommandSetMode(client, mode)
	local isRef = false
	if client then
		local NS2ID = client:GetUserId()
		isRef = GetIsNSLRef(NS2ID)
	end
	if isRef and mode ~= nil then
		UpdateNSLMode(client, mode)
	else
		ServerAdminPrint(client, string.format("NSL Plugin currently running in %s config.", GetNSLMode()))
	end
end

Event.Hook("Console_sv_nslcfg",               OnClientCommandSetMode)
CreateServerAdminCommand("Console_sv_nslcfg", OnClientSVCommandSetMode, "<state> - disabled,pcw,official - Changes the configuration mode of the NSL plugin.")

local function UpdateNSLLeague(client, league)
	league = string.upper(league)
	if GetNSLLeagueValid(league) then
		SetActiveLeague(league)
		ServerAdminPrint(client, string.format("NSL Plugin now using %s league config.", GetActiveLeague()))
	else
		ServerAdminPrint(client, string.format("NSL Plugin currently using %s league config.", GetActiveLeague()))
	end
end

local function OnClientSVCommandSetLeague(client, league)
	local isRef = false
	if client then
		local NS2ID = client:GetUserId()
		isRef = GetIsNSLRef(NS2ID)
	end
	if not isRef and league ~= nil then
		UpdateNSLLeague(client, league)
	end
end

local function OnClientCommandSetLeague(client, league)
	local isRef = false
	if client then
		local NS2ID = client:GetUserId()
		isRef = GetIsNSLRef(NS2ID)
	end
	if isRef and league ~= nil then
		UpdateNSLLeague(client, league)
	else
		ServerAdminPrint(client, string.format("NSL Plugin currently using %s league config.", GetActiveLeague()))
	end
end

Event.Hook("Console_sv_nslconfig",               OnClientCommandSetLeague)
CreateServerAdminCommand("Console_sv_nslconfig", OnClientSVCommandSetLeague, "<league> - Changes the league configuration used by the NSL mod.")

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