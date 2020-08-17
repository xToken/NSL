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
	if not client then return end
	local NS2ID = client:GetUserId()
	local ref = GetIsNSLRef(NS2ID)
	for _, t in ipairs(gNSLHelpMessages) do
		if t.refOnly and ref then
			SendClientServerAdminMessage(client, t.message, t.command..": ")
		elseif not t.refOnly then
			SendClientServerAdminMessage(client, t.message, t.command..": ")
		end
	end
	--Hardcode this for now :<
	SendClientServerAdminMessage(client, "NSL_OPPONENT_MUTE_TOGGLE", "toggleopponentmute: ")
end

RegisterNSLConsoleCommand("sv_nslhelp", OnClientCommandNSLHelp, "SV_NSLHELP", true)

local function UpdateNSLMode(client, mode)
	if not GetIsClientNSLRef(client) then return end
	mode = mode or ""
	local currentMode = GetNSLMode()
	if string.lower(mode) == "gather" and currentMode ~= kNSLPluginConfigs.GATHER then
		SetNSLMode(kNSLPluginConfigs.GATHER)
	elseif string.lower(mode) == "pcw" and currentMode ~= kNSLPluginConfigs.PCW then
		SetNSLMode(kNSLPluginConfigs.PCW)
	elseif string.lower(mode) == "official" and currentMode ~= kNSLPluginConfigs.OFFICIAL then
		SetNSLMode(kNSLPluginConfigs.OFFICIAL)
	elseif string.lower(mode) == "captains" and currentMode ~= kNSLPluginConfigs.CAPTAINS then
		SetNSLMode(kNSLPluginConfigs.CAPTAINS)
	elseif string.lower(mode) == "disabled" and currentMode ~= kNSLPluginConfigs.DISABLED then
		SetNSLMode(kNSLPluginConfigs.DISABLED)
	else
		SendClientServerAdminMessage(client, "NSL_MODE_CURRENT", EnumToString(kNSLPluginConfigs, GetNSLMode()))
		return
	end
	SendClientServerAdminMessage(client, "NSL_MODE_UPDATED", EnumToString(kNSLPluginConfigs, GetNSLMode()))
	if currentMode == kNSLPluginConfigs.DISABLED or GetNSLMode() == kNSLPluginConfigs.DISABLED then
		SendClientServerAdminMessage(client, "NSL_MODE_UPDATED_NOTE")
	end
end

RegisterNSLConsoleCommand("sv_nslcfg", UpdateNSLMode, "SV_NSLCFG", false, {{ Type = "string", Optional = true}})
--CreateServerAdminCommand("Console_sv_nslcfg", OnAdminCommandSetMode, "<state> - disabled,gather,pcw,official,captains - Changes the configuration mode of the NSL plugin.")

local function UpdateNSLLeague(client, league)
	if not client then return end
	league = string.upper(league or "")
	if GetNSLLeagueValid(league) then
		SetActiveLeague(league)
		SendClientServerAdminMessage(client, "NSL_LEAGUE_CONFIG_UPDATED", GetActiveLeague())
	else
		SendClientServerAdminMessage(client, "NSL_LEAGUE_CONFIG_CURRENT", GetActiveLeague())
	end
end

CreateNSLServerAdminCommand("sv_nslconfig", UpdateNSLLeague, "SV_NSLCONFIG", {{ Type = "string", Optional = true}})
--RegisterNSLConsoleCommand("sv_nslconfig", OnClientCommandSetLeague, "SV_NSLCONFIG")

local function UpdateNSLPerfConfig(client, perfcfg)
	if not GetIsClientNSLRef(client) then return end
	perfcfg = string.upper(perfcfg or "")
	if GetPerfLevelValid(perfcfg) and not GetNSLPerfConfigsBlocked() then
		SetPerfLevel(perfcfg)
		SendClientServerAdminMessage(client, "NSL_PERF_CONFIG_UPDATED", GetNSLPerfLevel())
	else
		SendClientServerAdminMessage(client, "NSL_PERF_CONFIG_CURRENT", GetNSLPerfLevel())
	end
end

RegisterNSLConsoleCommand("sv_nslperfconfig", UpdateNSLPerfConfig, "SV_NSLPERFCONFIG", false, {{ Type = "string", Optional = true}})
--CreateServerAdminCommand("Console_sv_nslperfconfig", OnAdminCommandSetPerfConfig, "<config> - Changes the performance configuration used by the NSL mod.")

local function ApplyNSLMapcycle(client)
	if not client then return end
	SetNSLMapCycle(not GetNSLLeagueMapCycle())
	if GetNSLLeagueMapCycle() then
		SendClientServerAdminMessage(client, "NSL_LEAGUE_MAPCYCLE_APPLIED")
	else
		SendClientServerAdminMessage(client, "NSL_LEAGUE_MAPCYCLE_REMOVED")
	end
end

CreateNSLServerAdminCommand("sv_nslleaguemapcycle", ApplyNSLMapcycle, "SV_NSLLEAGUEMAPCYCLE")

local function UpdateNSLLeagueAccess(client)
	if not client then return end
	SetNSLAdminAccess(not GetNSLLeagueAdminsAccess())
	if GetNSLLeagueAdminsAccess() then
		SendClientServerAdminMessage(client, "NSL_LEAGUE_ADMIN_ACCESS_ALLOWED")
	else
		SendClientServerAdminMessage(client, "NSL_LEAGUE_ADMIN_ACCESS_DISALLOWED")
	end
end

CreateNSLServerAdminCommand("sv_nslleagueadmins", UpdateNSLLeagueAccess, "SV_NSLLEAGUEADMINS")

local function UpdateNSLPerfConfigAccess(client)
	if not client then return end
	SetNSLPerfConfigAccess(not GetNSLPerfConfigsBlocked())
	if GetNSLPerfConfigsBlocked() then
		SendClientServerAdminMessage(client, "NSL_PERF_CONFIGS_DISALLOWED")
	else
		SendClientServerAdminMessage(client, "NSL_PERF_CONFIGS_ALLOWED")
	end
end

CreateNSLServerAdminCommand("sv_nslallowperfconfigs", UpdateNSLPerfConfigAccess, "SV_NSLLEAGUEPERACCESS")

local function UpdateNSLCaptainsLimit(client, limit)
	if not GetIsClientNSLRef(client) then return end
	limit = tonumber(limit)
	if limit and limit >= 5 and limit <= 12 then
		SetNSLCaptainsLimit(limit)
		SendClientServerAdminMessage(client, "NSL_CAPTAINS_LIMIT_UPDATED", GetNSLCaptainsPlayerLimit())
	else
		SendClientServerAdminMessage(client, "NSL_CAPTAINS_LIMIT_CURRENT", GetNSLCaptainsPlayerLimit())
	end
end

--RegisterNSLConsoleCommand("sv_nslcaptainslimit", UpdateNSLCaptainsLimit, "SV_NSLCAPTAINSLIMIT", false, {{ Type = "string", Optional = true}})
CreateServerAdminCommand("Console_sv_nslcaptainslimit", UpdateNSLCaptainsLimit, "SV_NSLCAPTAINSLIMIT", {{ Type = "string", Optional = true}})

local function OnCommandNSLPassword(client, password)
	if not GetIsClientNSLRef(client) then return end
	Server.SetPassword(password or "")
	SendClientServerAdminMessage(client, "NSL_SET_PASSWORD", password and string.rep("*", string.len(password)) or "nothing")
end

RegisterNSLConsoleCommand("sv_nslpassword", OnCommandNSLPassword, "SV_NSLPASSWORD", false, {{ Type = "string", Optional = true}})

local function UpdateNSLErrorReporter(client)
	if not client then return end
	SetNSLShouldPostErrors(not GetNSLShouldPostErrors())
	if GetNSLShouldPostErrors() then
		SendClientServerAdminMessage(client, "NSL_ERRORREPORTER_ENABLED")
	else
		SendClientServerAdminMessage(client, "NSL_ERRORREPORTER_DISABLED")
	end
end

CreateNSLServerAdminCommand("sv_nslerrorreporter", UpdateNSLErrorReporter, "SV_NSLERRORREPORTER")

local function UpdateNSLEnforceGatherBans(client)
	if not client then return end
	SetNSLEnforceGatherBans(not GetNSLShouldEnforceGatherBans())
	if GetNSLShouldEnforceGatherBans() then
		SendClientServerAdminMessage(client, "NSL_ENFORCEGATHERBANS_ENABLED")
	else
		SendClientServerAdminMessage(client, "NSL_ENFORCEGATHERBANS_DISABLED")
	end
end

CreateNSLServerAdminCommand("sv_nslenforcegatherbans", UpdateNSLEnforceGatherBans, "SV_NSLENFORCEGATHERBANS")