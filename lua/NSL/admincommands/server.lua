-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/admincommands/server.lua
-- - Dragon

-- Simple functions to make sending messages easier.
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

function SendClientMessage(client, message, changesound)
	if client then
		Server.SendNetworkMessage(client, "NSLSystemMessage", BuildAdminMessage(message, nil, client, changesound), true)
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

local ExecutionCache = { }
local function ServerAdminOrNSLRefCommand(client, parameter, functor, admin)
	local isRef
	local NS2ID = 0
	if client then
		NS2ID = client:GetUserId()
		isRef = GetIsNSLRef(NS2ID)
	end
	if isRef or admin then
		if not ExecutionCache[NS2ID] then
			ExecutionCache[NS2ID] = { }
		end
		if (ExecutionCache[NS2ID][functor] and ExecutionCache[NS2ID][functor] or 0) < Shared.GetTime() then
			functor(client, parameter)
			ExecutionCache[NS2ID][functor] = Shared.GetTime() + 0.03
		end
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
	-- Block AFK, AutoConcede, AutoTeamBalance and other server cfg stuff
	Server.SetConfigSetting("rookie_friendly", false)
	Server.SetConfigSetting("force_even_teams_on_join", false)
	Server.SetConfigSetting("auto_team_balance", {enabled_after_seconds = 0, enabled = false, enabled_on_unbalance_amount = 2})
	Server.SetConfigSetting("end_round_on_team_unbalance", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance_check_after_time", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance_after_warning_time", nil)
	Server.SetConfigSetting("auto_kick_afk_time", nil)
	Server.SetConfigSetting("auto_kick_afk_capacity", nil)
	Server.SetVariableTableCommandsAllowed(GetNSLMode() ~= "OFFICIAL")
end

table.insert(gConfigLoadedFunctions, SetupServerConfig)

local function OnCommandNSLPassword(client, password)
	if not client then return end
	local NS2ID = client:GetUserId()
	if GetIsNSLRef(NS2ID) then
		Server.SetPassword(password or "")
		ServerAdminPrint(client, string.format("Setting server password to %s.", password and string.rep("*", string.len(password)) or "nothing"))
	end
end

Event.Hook("Console_sv_nslpassword", OnCommandNSLPassword)