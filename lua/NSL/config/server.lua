-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/config/server.lua
-- - Dragon

--NSL Configs
local configFileName = "NSLConfig.json"
local leaguesConfigUpdateURL = "https://raw.githubusercontent.com/xToken/NSL/master/configs/nsl_leagues.json"
local leagueConfigUpdateURL = "https://raw.githubusercontent.com/xToken/NSL/master/configs/leagueconfigs/%s.json"
local perfConfigUpdateURL = "https://raw.githubusercontent.com/xToken/NSL/master/configs/nsl_perfconfig.json"
local defaultConfigFile = "configs/leagueconfigs/DEFAULT.json"
local configRequestTracking = { 
								leaguesConfigRequest = false, leaguesConfigRetries = 0, leaguesLocalConfig = "configs/nsl_leagues.json", leaguesExpectedVersion = 1.1, leaguesConfigComplete = false,
								leagueConfigRequest = false, leagueConfigRetries = 0, leagueLocalConfig = "configs/leagueconfigs/%s.json", leagueExpectedVersion = 3.6, leagueConfigComplete = false,
								perfConfigRequest = false, perfConfigRetries = 0, perfLocalConfig = "configs/nsl_perfconfig.json", perfExpectedVersion = 1.1, perfConfigComplete = false
							}
local NSL_Mode = kNSLPluginConfigs.DISABLED
local NSL_League = "DEFAULT"
local NSL_PerfLevel = "DEFAULT"
local NSL_CachedScores = { }
local NSL_Scores = { }
local NSL_ServerCommands = { }
local NSL_LeagueAdminsAccess = false
local NSL_PerfConfigsBlocked = false
local NSL_LeagueMapCycle = false
local NSL_DefaultPerfCaptured = false
local NSL_CaptainsPlayerLimit = 6
local NSL_PostErrors = true
local NSL_EnforceGatherBans = true
local kNSLMaxConfigRetries = 2
local cachedScoresValidFor = 10 * 60
local queryLeague = { "DEFAULT" }

function GetNSLMode()
	return NSL_Mode
end

function GetNSLModEnabled()
	return NSL_Mode ~= kNSLPluginConfigs.DISABLED
end

function GetActiveLeague()
	return NSL_League
end

function GetRecentScores()
	return NSL_CachedScores
end

function GetNSLPerfLevel()
	return NSL_PerfLevel
end

function GetNSLLeagueAdminsAccess()
	return NSL_LeagueAdminsAccess
end

function GetNSLPerfConfigsBlocked()
	return NSL_PerfConfigsBlocked
end

function GetNSLLeagueMapCycle()
	return NSL_LeagueMapCycle
end

function GetNSLCaptainsPlayerLimit()
	return NSL_CaptainsPlayerLimit
end

function GetNSLShouldPostErrors()
	return NSL_PostErrors
end

function GetNSLShouldEnforceGatherBans()
	return NSL_EnforceGatherBans
end

function RegisterNSLServerCommand(commandName)
	NSL_ServerCommands[string.gsub(commandName, "Console_", "")] = true
end

local function SavePluginConfig()
	SaveConfigFile(configFileName, { mode = NSL_Mode, league = NSL_League, perf = NSL_PerfLevel, recentgames = NSL_Scores, adminaccess = NSL_LeagueAdminsAccess, perfconfigsblocked = NSL_PerfConfigsBlocked, captainsplayerlimit = NSL_CaptainsPlayerLimit, mapcycle = NSL_LeagueMapCycle, post_errors = NSL_PostErrors, enforce_gather_bans = NSL_EnforceGatherBans })
end

local function LoadConfig()
	local defaultConfig = { mode = "PCW", league = "DEFAULT", perf = "DEFAULT", recentgames = { }, adminaccess = false, perfconfigsblocked = false, captainsplayerlimit = 6, mapcycle = false, post_errors = true, enforce_gather_bans = true }
	WriteDefaultConfigFile(configFileName, defaultConfig)
	local config = LoadConfigFile(configFileName) or defaultConfig
	NSL_Mode = type(config.mode) == "number" and config.mode or kNSLPluginConfigs.PCW
	NSL_League = config.league or "DEFAULT"
	NSL_PerfLevel = config.perf or "DEFAULT"
	NSL_LeagueAdminsAccess = config.adminaccess or false
	NSL_PerfConfigsBlocked = config.perfconfigsblocked or false
	NSL_LeagueMapCycle = config.mapcycle or false
	NSL_CaptainsPlayerLimit = config.captainsplayerlimit or 6
	NSL_PostErrors = config.post_errors or true
	NSL_EnforceGatherBans = config.enforce_gather_bans or true
	local loadedScores = config.recentgames or { }
	local updated = false
	for t, s in pairs(loadedScores) do
		if type(s) == "table" and (Shared.GetSystemTime() - (s.scoretime or 0) < cachedScoresValidFor) and (s.score or 0) > 0 then
			NSL_CachedScores[t] = s.score or 0
		end
	end
end

LoadConfig()

local function SetSeasonOnLoad()
	if GetNSLModEnabled() then
		Server.SetServerProperty(Seasons.kPropertyKey, Seasons.kNone)
	end
end

SetSeasonOnLoad()

function SetNSLMode(state)
	if NSL_Mode ~= state then
		NSL_Mode = state
		SavePluginConfig()
		for i = 1, #gPluginStateChange do
			gPluginStateChange[i](NSL_Mode)
		end
	end
end

function SetActiveLeague(state)
	if NSL_League ~= state then
		NSL_League = state
		SavePluginConfig()
		if GetNSLModEnabled() then
			EstablishConfigDependantSettings("reload")
		end
		for i = 1, #gLeagueChangeFunctions do
			gLeagueChangeFunctions[i](NSL_League)
		end
	end
end

function SetPerfLevel(state)
	if NSL_PerfLevel ~= state then
		NSL_PerfLevel = state
		SavePluginConfig()
		ApplyPerfDependantSettings()
	end
end

function SetNSLAdminAccess(state)
	if NSL_LeagueAdminsAccess ~= state then
		NSL_LeagueAdminsAccess = state
		SavePluginConfig()
	end
end

function SetNSLMapCycle(state)
	if NSL_LeagueMapCycle ~= state then
		NSL_LeagueMapCycle = state
		SavePluginConfig()
	end
	if NSL_LeagueMapCycle then
		UpdateNSLMapCycle()
	end
end

function SetNSLPerfConfigAccess(state)
	if NSL_PerfConfigsBlocked ~= state then
		NSL_PerfConfigsBlocked = state
		SavePluginConfig()
	end
	if NSL_PerfConfigsBlocked then
		SetPerfLevel("DEFAULT")
	end
end

function SetNSLCaptainsLimit(limit)
	if NSL_CaptainsPlayerLimit ~= limit then
		NSL_CaptainsPlayerLimit = limit
		SavePluginConfig()
	end
end

function SetNSLShouldPostErrors(enable)
	if NSL_PostErrors ~= enable then
		NSL_PostErrors = enable
		SavePluginConfig()
	end
end

function SetNSLEnforceGatherBans(enable)
	if NSL_EnforceGatherBans ~= enable then
		NSL_EnforceGatherBans = enable
		SavePluginConfig()
	end
end

function UpdateNSLScores(team1name, team1score, team2name, team2score)
	NSL_Scores[team1name] = { score = team1score, scoretime = Shared.GetSystemTime() }
	NSL_Scores[team2name] = { score = team2score, scoretime = Shared.GetSystemTime() }
	SavePluginConfig()
end

local Configs = { }
local PerfConfigs = { }

local function OnLoadLocalConfig(configFile)
	local config = { }
	local file = io.open(configFile, "r")
	if file then
		config = json.decode(file:read("*all"))
		file:close()
	end
	return config
end

local function ValidateResponse(response, request, additionalparam)
	local responseTable
	if response then
		responseTable = json.decode(response)
		if not responseTable or type(responseTable) ~= "table" or not responseTable.Version or not responseTable.EndOfTable then
			if configRequestTracking[request .. "ConfigRetries"] < kNSLMaxConfigRetries then
				configRequestTracking[request .. "ConfigRequest"] = false
				configRequestTracking[request .. "ConfigRetries"] = configRequestTracking[request .. "ConfigRetries"] + 1
				responseTable = nil
			else
				Shared.Message(string.format("NSL - Failed getting %s config from GitHub, using local copy.", (additionalparam and additionalparam.." " or "")..request))
				responseTable = OnLoadLocalConfig(string.format(configRequestTracking[request .. "LocalConfig"], additionalparam))
			end
		elseif responseTable.Version < configRequestTracking[request .. "ExpectedVersion"] then
			--Old version still on github, use local cache
			Shared.Message(string.format("NSL - Old copy of %s config on GitHub, using local copy.", (additionalparam and additionalparam.." " or "")..request))
			responseTable = OnLoadLocalConfig(string.format(configRequestTracking[request .. "LocalConfig"], additionalparam))
		end
		if responseTable then
			--GOOD DATA ITS AMAZING
			configRequestTracking[request .. "ConfigComplete"] = additionalparam == nil and true or false
		end
	end
	return responseTable
end

local function tablemerge(tab1, tab2)
	if tab1 and tab2 then
		for k, v in pairs(tab2) do
			if type(v) == "table" and type(tab1[k]) == "table" then
				tablemerge(tab1[k], tab2[k])
			else
				tab1[k] = v
			end
		end
	end
end

local function OnLoadLocalDefaultConfig()
	Configs["DEFAULT"] = { }
	tablemerge(Configs["DEFAULT"], OnLoadLocalConfig(defaultConfigFile))
end

OnLoadLocalDefaultConfig()
-- Load local copy.  While ideally not needed, best to have some config ready by default.  The updated copy will be gotten later anyways

local function OnConfigResponse(response, request, additionalparam)
	response = ValidateResponse(response, request, additionalparam)
	if response and request == "leagues" then
		for _, league in ipairs(response.Leagues) do
			Configs[string.upper(league)] = { }
			table.insert(queryLeague, league)
		end
	elseif response and request == "league" then
		if response.LeagueName and Configs[string.upper(response.LeagueName)] then
			--Assume valid, update Configs table, always uppercase
			--Shared.Message("NSL - Loading config for " .. response.LeagueName .. ".")
			tablemerge(Configs[string.upper(response.LeagueName)], response)
			-- Get ready for next league query
			table.remove(queryLeague, 1)
			configRequestTracking["leagueConfigRetries"] = 0
			configRequestTracking["leagueConfigRequest"] = false
		end
	elseif response and response.Configs and request == "perf" then
		for _, config in ipairs(response.Configs) do
			if config.PerfLevel then
				--Performance configs
				--Shared.Message("NSL - Loading perf config " .. config.PerfLevel .. ".")
				PerfConfigs[string.upper(config.PerfLevel)] = config
			end
		end
	end
end

local function OnServerUpdated()
	if not configRequestTracking["leaguesConfigRequest"] then
		Shared.SendHTTPRequest(leaguesConfigUpdateURL, "GET", function(response) OnConfigResponse(response, "leagues") end)
		configRequestTracking["leaguesConfigRequest"] = true
	end
	if not configRequestTracking["leagueConfigRequest"] and configRequestTracking["leaguesConfigComplete"] then
		-- Query all individual league configs
		if queryLeague[1] then
			Shared.SendHTTPRequest(string.format(leagueConfigUpdateURL, queryLeague[1]), "GET", function(response) OnConfigResponse(response, "league", queryLeague[1]) end)
			configRequestTracking["leagueConfigRequest"] = true
		else
			--Out of leagues to load, we are done!
			configRequestTracking["leagueConfigComplete"] = true
		end
	end
	if not configRequestTracking["perfConfigRequest"] and configRequestTracking["leagueConfigComplete"] then
		Shared.SendHTTPRequest(perfConfigUpdateURL, "GET", function(response) OnConfigResponse(response, "perf") end)
		configRequestTracking["perfConfigRequest"] = true
	end
	--Small grace period to allow other mods to adjust defaults and not mess with us.
	if not NSL_DefaultPerfCaptured and Shared.GetTime() > 2 then
		if Shared.GetServerPerformanceData():GetInterpMs() > 0 then
			--wait for this to be valid
			PerfConfigs["DEFAULT"] = {
				PerfLevel = "Default",
				Interp = Shared.GetServerPerformanceData():GetInterpMs(),
				MoveRate = Shared.GetServerPerformanceData():GetMoverate(),
				ClientRate = Server.GetSendrate(),
				TickRate = Server.GetTickrate(),
				MaxDataRate = math.ceil(Server.GetBwLimit() / 1024)
			}
			ApplyPerfDependantSettings()
			NSL_DefaultPerfCaptured = true
		end
	end
	if NSL_DefaultPerfCaptured and configRequestTracking["perfConfigComplete"] then
		EstablishConfigDependantSettings("complete")
		Event.RemoveHook("UpdateServer", OnServerUpdated)
	end
end

Event.Hook("UpdateServer", OnServerUpdated)

function GetNSLConfigValue(value)
	--Check League config
	local NSL_Mode_Value = EnumToString(kNSLPluginConfigs, NSL_Mode)
	if Configs[NSL_League] then
		--Check League/Mode Specific config
		if Configs[NSL_League][NSL_Mode_Value] and Configs[NSL_League][NSL_Mode_Value][value] then
			return Configs[NSL_League][NSL_Mode_Value][value]
		end
		--Check League Specific config
		if Configs[NSL_League][value] then
			return Configs[NSL_League][value]
		end
	end
	--Base Config
	if Configs["DEFAULT"][value] then
		return Configs["DEFAULT"][value]
	end
	return nil
end

function GetNSLPerfValue(value)
	--Check base config
	if PerfConfigs[NSL_PerfLevel] and PerfConfigs[NSL_PerfLevel][value] then
		return PerfConfigs[NSL_PerfLevel][value]
	end
	return GetNSLDefaultPerfValue(value)
end

function GetNSLDefaultPerfValue(value)
	if PerfConfigs["DEFAULT"] and PerfConfigs["DEFAULT"][value] then
		return PerfConfigs["DEFAULT"][value]
	end
	return nil
end

function GetNSLLeagueValid(league)
	if Configs[league] and Configs[league].LeagueName then
		return true
	end
	return false
end

function GetPerfLevelValid(level)
	if PerfConfigs[level] and PerfConfigs[level].PerfLevel then
		return true
	end
	return false
end

function GetIsNSLRef(ns2id)
	if ns2id then
		local pData = GetNSLUserData(ns2id)
		if pData and pData.NSL_Level then
			return pData.NSL_Level >= GetNSLConfigValue("PlayerRefLevel")
		end
	end
	return false
end

function GetIsClientNSLRef(client)
	if not client then return false end
	return GetIsNSLRef(client:GetUserId())
end

local function GetGroupCanRunCommand(groupData, commandName)
    
	local existsInList = false
	local commands = groupData.commands
	
	if commands then
		for c = 1, #groupData.commands do
			if groupData.commands[c] == commandName then
				existsInList = true
				break
			end
		end
	end
	
	if groupData.type == "allowed" then
		return existsInList
	elseif groupData.type == "disallowed" then
		return not existsInList
	else
		--Invalid structure
		return false
	end
	
end

function GetCanRunCommandviaNSL(ns2id, commandName)
	-- Check for access to NSL commands
	if NSL_ServerCommands[commandName] and GetNSLModEnabled() and GetIsNSLRef(ns2id) then
		return true
	end
	-- Check for access to vanilla/shine style commands
	if NSL_LeagueAdminsAccess and GetIsNSLRef(ns2id) then
		local pData = GetNSLUserData(ns2id)
		if pData and pData.NSL_Level then
			local level = tostring(pData.NSL_Level)
			local groupData = GetNSLConfigValue("AdminGroups")
			if groupData and groupData[level] then
				return GetGroupCanRunCommand(groupData[level], commandName)
			end
		end		
	end
	return false
end

--NSL Server Admin Hooks
local oldGetClientCanRunCommand = GetClientCanRunCommand
function GetClientCanRunCommand(client, commandName, printWarning)

	if not client then return end
	local NS2ID = client:GetUserId()
	local canRun = GetCanRunCommandviaNSL(NS2ID, commandName)
	if not canRun then
		return oldGetClientCanRunCommand(client, commandName, printWarning)
	end
	return canRun
	
end

local Shine = Shine
if Shine then
    -- Adds the graphical AdminMenu button to Shine's VoteMenu
    -- for NSL admins who can use sh_adminmenu
    local oldHasAccess = Shine.HasAccess
    function Shine:HasAccess(client, commandName, AllowByDefault)
        if not client then return true end

        local _, ns2id = Shine:GetUserData(client)
        local oldAccess = oldHasAccess(self, client, commandName, AllowByDefault)
        local newAccess = GetCanRunCommandviaNSL(ns2id, commandName)

        return oldAccess or newAccess
    end

    -- Gives NSL admins access to their group's Shine commands
    local oldGetPermission = Shine.GetPermission
    function Shine:GetPermission(client, commandName)
        if not client then return true end

        local _, ns2id = Shine:GetUserData(client)
        local oldPerm = oldGetPermission(self, client, commandName)
        local newPerm = GetCanRunCommandviaNSL(ns2id, commandName)

        return oldPerm or newPerm
    end
end