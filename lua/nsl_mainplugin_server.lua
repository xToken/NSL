-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\nsl_mainplugin_server.lua
-- - Dragon

--NSL Main Plugin
--Reworked to function more as a 'league' plugin, not just a ENSL plugin.
local kCachedDataRate, kCachedMoveRate, kCachedInterp, kCachedSendRate
local kCachedTickRate = Server.GetTickrate()
local kNSLTag = "nsl"

--Supposedly this still not syncronized.
local function SetupClientRatesandConfig(client)
	--If non-default rates, send to clients.
	if GetNSLPerfValue("Interp") ~= 100 then
		Shared.ConsoleCommand(string.format("interp %f", (GetNSLPerfValue("Interp") / 1000)))
	end
	if GetNSLPerfValue("MoveRate") ~= 30 then
		Shared.ConsoleCommand(string.format("mr %f", GetNSLPerfValue("MoveRate")))
	end
	Server.SendNetworkMessage(client, "NSLPluginConfig", {config = kNSLPluginConfigs[GetNSLMode()], league = GetActiveLeague()}, true)
end

local function SetupNSLTag()
	Server.RemoveTag(kNSLTag)
	if GetNSLModEnabled() then
		Server.AddTag(kNSLTag)
	end
end

local function SetupRates(configLoaded)
	
	if configLoaded == "perf" or configLoaded == "all" then
		if GetNSLPerfValue("TickRate") > kCachedTickRate then
			--Tickrate going up, increase it first.
			Shared.ConsoleCommand(string.format("tickrate %f", GetNSLPerfValue("TickRate")))
			kCachedTickRate = GetNSLPerfValue("TickRate")
			if GetNSLPerfValue("ClientRate") ~= kCachedSendRate then
				Shared.ConsoleCommand(string.format("sendrate %f", GetNSLPerfValue("ClientRate")))
				kCachedSendRate = GetNSLPerfValue("ClientRate")
			end
		elseif GetNSLPerfValue("TickRate") <= kCachedTickRate then
			--Tickrate going down, set updaterate first.
			if GetNSLPerfValue("ClientRate") ~= kCachedSendRate then
				Shared.ConsoleCommand(string.format("sendrate %f", GetNSLPerfValue("ClientRate")))
				kCachedSendRate = GetNSLPerfValue("ClientRate")
			end
			if GetNSLPerfValue("TickRate") ~= kCachedTickRate then
				Shared.ConsoleCommand(string.format("tickrate %f", GetNSLPerfValue("TickRate")))
				kCachedTickRate = GetNSLPerfValue("TickRate")
			end
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
		SetupNSLTag()
	end
	if configLoaded == "league" or configLoaded == "all" then
		Server.SetNetworkFieldTruncationControl(GetNSLConfigValue("NetworkTruncation"))
		Shared.Message(string.format("Network Truncation set to %s.", GetNSLConfigValue("NetworkTruncation")))
	end
end

table.insert(gConnectFunctions, SetupClientRatesandConfig)
table.insert(gConfigLoadedFunctions, SetupRates)

local function SendClientUpdatedMode(newState)
	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	for p = 1, #playerList do
		local playerClient = Server.GetOwner(playerList[p])
		if playerClient then
			Server.SendNetworkMessage(playerClient, "NSLPluginConfig", {config = kNSLPluginConfigs[newState], league = GetActiveLeague()}, true)
		end
	end
	SetupNSLTag()
end

table.insert(gPluginStateChange, SendClientUpdatedMode)

local originalPlayerOnJoinTeam
--Maintain original PlayerOnJoinTeam
originalPlayerOnJoinTeam = Class_ReplaceMethod("Player", "OnJoinTeam", 
	function(self)
		originalPlayerOnJoinTeam(self)
		--This is new, to prevent players joining midgame and getting pRes.
		local gamerules = GetGamerules()
		if gamerules and gamerules:GetGameStarted() then
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
--Override friendly fire function checks
originalNS2GRGetFriendlyFire = Class_ReplaceMethod("NS2Gamerules", "GetFriendlyFire", 
	function(self)
		return GetNSLConfigValue("FriendlyFireEnabled") and GetNSLModEnabled()
	end
)

--Override friendly fire function checks
function GetFriendlyFire()
	return GetNSLConfigValue("FriendlyFireEnabled") and GetNSLModEnabled()
end

local originalNS2GRGetWarmUpPlayerLimit
--Override warmup mode player limit
originalNS2GRGetWarmUpPlayerLimit = Class_ReplaceMethod("NS2Gamerules", "GetWarmUpPlayerLimit", 
	function(self)
		return GetNSLModEnabled() and 100 or originalNS2GRGetWarmUpPlayerLimit(self)
	end
)

local oldGetCanTakeDamage = LiveMixin.GetCanTakeDamage
-- Prevent damage to players in warmup mode
function LiveMixin:GetCanTakeDamage()
	if GetNSLModEnabled() and GetGameInfoEntity():GetState() == kGameState.WarmUp then
		return false
	end

	return oldGetCanTakeDamage(self)
end

local originalNS2GRKillEnemiesNearCommandStructureInPreGame
--Shrink the pregame damage area to just near the command structure
originalNS2GRKillEnemiesNearCommandStructureInPreGame = Class_ReplaceMethod("NS2Gamerules", "KillEnemiesNearCommandStructureInPreGame",
	function(self, timePassed)
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
	end
)

local oldMapCycle_CycleMap = MapCycle_CycleMap
function MapCycle_CycleMap()
	--Override to prevent automatic mapcycle from lazy server admins
end

--Keep vanilla behavior when a map change fails
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
		if self.gameState ~= kGameState.Started and Shared.GetTime() > 360000 and Server.GetNumPlayers() == 0 then
			oldMapCycle_CycleMap()
		end
	end
end

--Setup Periodic MapCycle to prevent some animation craziness.
ReplaceLocals(NS2Gamerules.OnUpdate, { ServerAgeCheck = NewServerAgeCheck })

--Set friendly fire percentage
kFriendlyFireScalar = GetNSLConfigValue("FriendlyFireDamagePercentage")

--Simple functions to make sending messages easier.
local function BuildAdminMessage(message, teamname, client, changesound)
	local t = { }
	local mod
	t.message = string.sub(message, 1, 250)
	if client then
		local player = client:GetControllingPlayer()
        if player then
			mod = player:GetName()
		end
	else
		mod = teamname
	end
	t.header = string.format(mod and "(%s)(%s):" or "(%s):", GetNSLConfigValue("LeagueName"), mod)
	t.color = GetNSLConfigValue("MessageColor")
    t.changesound = changesound
	return t
end

function SendAllClientsMessage(message, changesound)
	Server.SendNetworkMessage("NSLSystemMessage", BuildAdminMessage(message, nil, nil, changesound), true)
end

function SendClientMessage(client, message)
	if client then
		Server.SendNetworkMessage(client, "NSLSystemMessage", BuildAdminMessage(message, nil, client), true)
	end
end

function SendTeamMessage(teamnum, message)
	local chatmessage = BuildAdminMessage(message, GetActualTeamName(teamnum))
	if tonumber(teamnum) then
		local playerRecords = GetEntitiesForTeam("Player", teamnum)
		for _, player in ipairs(playerRecords) do
			local client = Server.GetOwner(player)
			if client then
				Server.SendNetworkMessage(client, "NSLSystemMessage", chatmessage, true)
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
			ServerAdminPrint(client, "sv_nslcfg" .. ": " .. "<state> - disabled,gather,pcw,official - Changes the configuration mode of the NSL plugin.")
			ServerAdminPrint(client, "sv_nslconfig" .. ": " .. "<league> - Changes the league settings used by the NSL plugin.")
			ServerAdminPrint(client, "sv_nslperfconfig" .. ": " .. "<config> - Changes the performance config used by the NSL plugin.")
			ServerAdminPrint(client, "sv_nslapprovemercs" .. ": " .. "<team, opt. player> - Forces approval of teams mercs, '1' approving for marines which allows alien mercs.")
			ServerAdminPrint(client, "sv_nslclearmercs" .. ": " .. "<team> - 1,2 - Clears approval of teams mercs, '1' clearing any alien mercs.")
			ServerAdminPrint(client, "sv_nslpause" .. ": " .. "Will pause/unpause game using standard delays.  Does not consume teams allowed pauses.")
			ServerAdminPrint(client, "sv_nslsetpauses" .. ": " .. "<team, pauses> - Sets the number of pauses remaining for a team.")
			ServerAdminPrint(client, "sv_nslforcestart" .. ": " .. "<seconds> - Will force the game start countdown to start in the provided amount of seconds, or 15 if blank.")
			ServerAdminPrint(client, "sv_nslcancelstart" .. ": " .. "Will cancel a game start countdown currently in progress.")
			ServerAdminPrint(client, "sv_nslsetteamnames" .. ": " .. "<team1name, team2name> Will set the team names manually, will prevent automatic team name updates.")
			ServerAdminPrint(client, "sv_nslswitchteams" .. ": " .. "Will switch team names (best used if setting team names manually).")
			ServerAdminPrint(client, "sv_nslsetteamscores" .. ": " .. "<t1score, t2score> Will set the team scores manually.")
			ServerAdminPrint(client, "sv_nslsetteamspawns" .. ": " .. "marinespawnname, alienspawnname, Spawns teams at specified locations. Locations must be exact")
			ServerAdminPrint(client, "sv_nslpassword" .. ": " .. "Sets a password on the server, works like sv_password.")
			ServerAdminPrint(client, "sv_nslleagueadmins" .. ": " .. "Toggles league staff having access to administrative commands on server.")
			ServerAdminPrint(client, "sv_nslreplaceplayer" .. ": " .. "<newPlayer, oldPlayer> Will force different player to take crashed/disconnect players place.")
			ServerAdminPrint(client, "sv_nsllistcachedplayers" .. ": " .. "Will list currently cached players names and steamIDs, for sv_nslreplaceplayer cmd.")
		end
		ServerAdminPrint(client, "sv_nslinfo" .. ": " .. "<team> - marines,aliens,specs,other,all - Will return the player details from the corresponding league site.")
		ServerAdminPrint(client, "sv_nslhandicap" .. ": " .. "<0.1 - 1> Lowers your damage to the specified percentage.")
		ServerAdminPrint(client, "sv_nslmerchelp" .. ": " .. "Displays specific help information pertaining to approving and clearing mercs.")
	end
end

Event.Hook("Console_sv_nslhelp", OnClientCommandNSLHelp)

local function UpdateNSLMode(client, mode)
	mode = mode or ""
	if string.lower(mode) == "gather" then
		SetNSLMode("GATHER")
	elseif string.lower(mode) == "pcw" then
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
	ServerAdminPrint(client, "NOTE: If NSL Mod was Enabled or Disabled, map will need to change for seasonal content to work as expected.")
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
	if GetPerfLevelValid(perfcfg) and not GetNSLPerfConfigsBlocked() then
		SetPerfLevel(perfcfg)
		ServerAdminPrint(client, string.format("NSL Plugin now using %s performance config.", GetNSLPerfLevel()))
	else
		ServerAdminPrint(client, string.format("NSL Plugin currently using %s performance config.", GetNSLPerfLevel()))
	end
end

local function UpdateNSLLeagueAccess(client)
	SetNSLAdminAccess(not GetNSLLeagueAdminsAccess())
	if GetNSLLeagueAdminsAccess() then
		ServerAdminPrint(client,"NSL Plugin now allowing access to server admin commands.")
	else
		ServerAdminPrint(client, "NSL Plugin now dis-allowing access to server admin commands.")
	end
end

local function UpdateNSLPerfConfigAccess(client)
	SetNSLPerfConfigAccess(not GetNSLPerfConfigsBlocked())
	if GetNSLPerfConfigsBlocked() then
		ServerAdminPrint(client, "NSL Plugin now dis-allowing access to set performance configs.")
	else
		ServerAdminPrint(client,"NSL Plugin now allowing access to set performance configs.")
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

Event.Hook("Console_sv_nslcfg", OnClientCommandSetMode)
CreateServerAdminCommand("Console_sv_nslcfg", OnAdminCommandSetMode, "<state> - disabled,gather,pcw,official - Changes the configuration mode of the NSL plugin.")

local function OnAdminCommandSetLeague(client, league)
	ServerAdminOrNSLRefCommand(client, league, UpdateNSLLeague, true)
end

local function OnClientCommandSetLeague(client, league)
	ServerAdminOrNSLRefCommand(client, league, UpdateNSLLeague, false)
end

Event.Hook("Console_sv_nslconfig", OnClientCommandSetLeague)
CreateServerAdminCommand("Console_sv_nslconfig", OnAdminCommandSetLeague, "<league> - Changes the league configuration used by the NSL mod.")

local function OnAdminCommandSetPerfConfig(client, perfcfg)
	ServerAdminOrNSLRefCommand(client, perfcfg, UpdateNSLPerfConfig, true)
end

local function OnClientCommandSetPerfConfig(client, perfcfg)
	ServerAdminOrNSLRefCommand(client, perfcfg, UpdateNSLPerfConfig, false)
end

Event.Hook("Console_sv_nslperfconfig", OnClientCommandSetPerfConfig)
CreateServerAdminCommand("Console_sv_nslperfconfig", OnAdminCommandSetPerfConfig, "<config> - Changes the performance configuration used by the NSL mod.")

local function OnAdminCommandSetLeagueAccess(client)
	ServerAdminOrNSLRefCommand(client, nil, UpdateNSLLeagueAccess, true)
end

CreateServerAdminCommand("Console_sv_nslleagueadmins", OnAdminCommandSetLeagueAccess, "Toggles league staff having access to administrative commands on server.")

local function OnAdminCommandSetPerfConfigAccess(client)
	ServerAdminOrNSLRefCommand(client, nil, UpdateNSLPerfConfigAccess, true)
end

CreateServerAdminCommand("Console_sv_nslallowperfconfigs", OnAdminCommandSetPerfConfigAccess, "Toggles league staff having access set performance configs.")

local function SetupServerConfig()
	--Block AFK, AutoConcede, AutoTeamBalance and other server cfg stuff
	Server.SetConfigSetting("rookie_friendly", false)
	Server.SetConfigSetting("force_even_teams_on_join", false)
	Server.SetConfigSetting("auto_team_balance", {enabled_after_seconds = 0, enabled = false, enabled_on_unbalance_amount = 2})
	Server.SetConfigSetting("end_round_on_team_unbalance", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance_check_after_time", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance_after_warning_time", nil)
	Server.SetConfigSetting("auto_kick_afk_time", nil)
	Server.SetConfigSetting("auto_kick_afk_capacity", nil)
end

table.insert(gConfigLoadedFunctions, SetupServerConfig)

--This seems stupid, but gender models are also considered 'variants'.  Allow for marines BUT force 'default' variant
function MarineVariantMixin:GetVariantModel()
	if GetNSLConfigValue("UseDefaultSkins") then
		return MarineVariantMixin.kModelNames[ self:GetGenderString() ][ kMarineVariant.green ]
	end
    return MarineVariantMixin.kModelNames[ self:GetGenderString() ][ self.variant ]
end

--Weapon Skin Update call would be skipped when default skins is enabled
local originalPlayerOnClientUpdated
originalPlayerOnClientUpdated = Class_ReplaceMethod("Player", "OnClientUpdated",
	function(self, client)
		originalPlayerOnClientUpdated(self, client)
		if GetNSLConfigValue("UseDefaultSkins") then
			self:UpdateWeaponSkin(client)
		end
	end
)

function ExoVariantMixin:OnClientUpdated(client)
	Player.OnClientUpdated(self, client)
end

function Alien:GetIgnoreVariantModels()
    return GetNSLConfigValue("UseDefaultSkins")
end

local function OnCommandNSLPassword(client, password)
	if not client then return end
	local NS2ID = client:GetUserId()
	if GetIsNSLRef(NS2ID) then
		Server.SetPassword(password or "")
		ServerAdminPrint(client, string.format("Setting server password to %s.", password and string.rep("*", string.len(password)) or "nothing"))
	end
end

Event.Hook("Console_sv_nslpassword", OnCommandNSLPassword)