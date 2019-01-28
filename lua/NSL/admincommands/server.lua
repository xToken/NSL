-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/admincommands/server.lua
-- - Dragon

-- Simple functions to make sending messages easier.
local function BuildAdminMessage(message, teamname, client, changesound, param1, param2, param3)
	local t = { }
	t.messageid = GetNSLMessageID(message)
	t.messageparam1 = string.sub(param1 or "", 1, 25)
	t.messageparam2 = string.sub(param2 or "", 1, 25)
	t.messageparam3 = string.sub(param3 or "", 1, 25)
	t.header = client and 2 or teamname and 1 or 0
	t.color = GetNSLConfigValue("MessageColor")
    t.changesound = changesound
	return t
end

function SendAllClientsMessage(message, changesound, ...)
	Server.SendNetworkMessage("NSLSystemMessage", BuildAdminMessage(message, nil, nil, changesound, ...), true)
end

function SendClientMessage(client, message, changesound, ...)
	if client then
		Server.SendNetworkMessage(client, "NSLSystemMessage", BuildAdminMessage(message, nil, client, changesound, ...), true)
	end
end

function NSLSendTeamMessage(teamnum, message, changesound, ...)
	local chatmessage = BuildAdminMessage(message, GetActualTeamName(teamnum), nil, changesound, ...)
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

local function BuildNSLServerAdminMessage(message, param1, param2, param3)
	local t = { }
	t.messageid = GetNSLMessageID(message)
	t.messageparam1 = string.sub(param1 or "", 1, 25)
	t.messageparam2 = string.sub(param2 or "", 1, 25)
	t.messageparam3 = string.sub(param3 or "", 1, 25)
	return t
end

function SendClientServerAdminMessage(client, message, ...)
	if client then
		Server.SendNetworkMessage(client, "NSLServerAdminPrint", BuildNSLServerAdminMessage(message, ...), true)
	end
end

local function OnClientCommandNSLHelp(client)
	if client then
		local NS2ID = client:GetUserId()
		local ref = GetIsNSLRef(NS2ID)
		for _, t in ipairs(gNSLHelpMessages) do
			if t.refOnly and ref then
				SendClientServerAdminMessage(client, t.message)
			elseif not t.refOnly then
				SendClientServerAdminMessage(client, t.message)
			end
		end
	end
end

Event.Hook("Console_sv_nslhelp", OnClientCommandNSLHelp)

local function UpdateNSLMode(client, mode)
	mode = mode or ""
	local currentMode = GetNSLMode()
	if string.lower(mode) == "gather" and currentMode ~= kNSLPluginConfigs.GATHER then
		SetNSLMode(kNSLPluginConfigs.GATHER)
	elseif string.lower(mode) == "pcw" and currentMode ~= kNSLPluginConfigs.PCW then
		SetNSLMode(kNSLPluginConfigs.PCW)
	elseif string.lower(mode) == "official" and currentMode ~= kNSLPluginConfigs.OFFICIAL then
		SetNSLMode(kNSLPluginConfigs.OFFICIAL)
	--elseif string.lower(mode) == "captains" and currentMode ~= kNSLPluginConfigs.CAPTAINS then
		--SetNSLMode(kNSLPluginConfigs.CAPTAINS)
	elseif string.lower(mode) == "disabled" and currentMode ~= kNSLPluginConfigs.DISABLED then
		SetNSLMode(kNSLPluginConfigs.DISABLED)
	else
		SendClientServerAdminMessage(client, "NSL_MODE_CURRENT", EnumToString(kNSLPluginConfigs, GetNSLMode()))
		return
	end
	SendClientServerAdminMessage(client, "NSL_MODE_UPDATED", EnumToString(kNSLPluginConfigs, GetNSLMode()))
	SendClientServerAdminMessage(client, "NSL_MODE_UPDATED_SEASONS_NOTE")
end

local function UpdateNSLLeague(client, league)
	league = string.upper(league or "")
	if GetNSLLeagueValid(league) then
		SetActiveLeague(league)
		SendClientServerAdminMessage(client, "NSL_LEAGUE_CONFIG_UPDATED", GetActiveLeague())
	else
		SendClientServerAdminMessage(client, "NSL_LEAGUE_CONFIG_CURRENT", GetActiveLeague())
	end
end

local function UpdateNSLPerfConfig(client, perfcfg)
	perfcfg = string.upper(perfcfg or "")
	if GetPerfLevelValid(perfcfg) and not GetNSLPerfConfigsBlocked() then
		SetPerfLevel(perfcfg)
		SendClientServerAdminMessage(client, "NSL_PERF_CONFIG_UPDATED", GetNSLPerfLevel())
	else
		SendClientServerAdminMessage(client, "NSL_PERF_CONFIG_CURRENT", GetNSLPerfLevel())
	end
end

local function UpdateNSLLeagueAccess(client)
	SetNSLAdminAccess(not GetNSLLeagueAdminsAccess())
	if GetNSLLeagueAdminsAccess() then
		SendClientServerAdminMessage(client, "NSL_LEAGUE_ADMIN_ACCESS_ALLOWED")
	else
		SendClientServerAdminMessage(client, "NSL_LEAGUE_ADMIN_ACCESS_DISALLOWED")
	end
end

local function UpdateNSLPerfConfigAccess(client)
	SetNSLPerfConfigAccess(not GetNSLPerfConfigsBlocked())
	if GetNSLPerfConfigsBlocked() then
		SendClientServerAdminMessage(client, "NSL_PERF_CONFIGS_DISALLOWED")
	else
		SendClientServerAdminMessage(client, "NSL_PERF_CONFIGS_ALLOWED")
	end
end

local function UpdateNSLCaptainsLimit(client, limit)
	limit = tonumber(limit)
	if limit and limit >= 5 and limit <= 12 then
		SetNSLCaptainsLimit(limit)
		SendClientServerAdminMessage(client, "NSL_CAPTAINS_LIMIT_UPDATED", GetNSLCaptainsPlayerLimit())
	else
		SendClientServerAdminMessage(client, "NSL_CAPTAINS_LIMIT_CURRENT", GetNSLCaptainsPlayerLimit())
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
CreateServerAdminCommand("Console_sv_nslcfg", OnAdminCommandSetMode, "<state> - disabled,gather,pcw,official,captains - Changes the configuration mode of the NSL plugin.")
RegisterNSLHelpMessageForCommand("SV_NSLCFG", true)

local function OnAdminCommandSetLeague(client, league)
	ServerAdminOrNSLRefCommand(client, league, UpdateNSLLeague, true)
end

local function OnClientCommandSetLeague(client, league)
	ServerAdminOrNSLRefCommand(client, league, UpdateNSLLeague, false)
end

Event.Hook("Console_sv_nslconfig", OnClientCommandSetLeague)
CreateServerAdminCommand("Console_sv_nslconfig", OnAdminCommandSetLeague, "<league> - Changes the league configuration used by the NSL mod.")
RegisterNSLHelpMessageForCommand("SV_NSLCONFIG", true)

local function OnAdminCommandSetPerfConfig(client, perfcfg)
	ServerAdminOrNSLRefCommand(client, perfcfg, UpdateNSLPerfConfig, true)
end

local function OnClientCommandSetPerfConfig(client, perfcfg)
	ServerAdminOrNSLRefCommand(client, perfcfg, UpdateNSLPerfConfig, false)
end

Event.Hook("Console_sv_nslperfconfig", OnClientCommandSetPerfConfig)
CreateServerAdminCommand("Console_sv_nslperfconfig", OnAdminCommandSetPerfConfig, "<config> - Changes the performance configuration used by the NSL mod.")
RegisterNSLHelpMessageForCommand("SV_NSLPERFCONFIG", true)

local function OnAdminCommandSetLeagueAccess(client)
	ServerAdminOrNSLRefCommand(client, nil, UpdateNSLLeagueAccess, true)
end

CreateServerAdminCommand("Console_sv_nslleagueadmins", OnAdminCommandSetLeagueAccess, "Toggles league staff having access to administrative commands on server.")

local function OnAdminCommandSetPerfConfigAccess(client)
	ServerAdminOrNSLRefCommand(client, nil, UpdateNSLPerfConfigAccess, true)
end

CreateServerAdminCommand("Console_sv_nslallowperfconfigs", OnAdminCommandSetPerfConfigAccess, "Toggles league staff having access set performance configs.")

local function OnCommandNSLPassword(client, password)
	if not client then return end
	local NS2ID = client:GetUserId()
	if GetIsNSLRef(NS2ID) then
		Server.SetPassword(password or "")
		SendClientServerAdminMessage(client, "NSL_SET_PASSWORD", password and string.rep("*", string.len(password)) or "nothing")
	end
end

Event.Hook("Console_sv_nslpassword", OnCommandNSLPassword)
RegisterNSLHelpMessageForCommand("SV_NSLPASSWORD", true)

local function OnAdminCommandSetCaptainsLimit(client, limit)
	ServerAdminOrNSLRefCommand(client, limit, UpdateNSLCaptainsLimit, true)
end

local function OnClientCommandSetCaptainsLimit(client, limit)
	ServerAdminOrNSLRefCommand(client, limit, UpdateNSLCaptainsLimit, false)
end

Event.Hook("Console_sv_nslcaptainslimit", OnClientCommandSetCaptainsLimit)
CreateServerAdminCommand("Console_sv_nslcaptainslimit", OnAdminCommandSetCaptainsLimit, "<limit> - Changes the player limit for each team in Captains mode.")
RegisterNSLHelpMessageForCommand("SV_NSLCAPTAINSLIMIT", true)