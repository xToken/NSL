//NSL Configs

local configFileName = "NSLConfig.json"
local configUpdateURL = "https://raw.github.com/xToken/NSL/master/League%20Config.lua"
local configUpdateRequestSent = false
local configUpdateRetries = 0
local NSL_Mode = "PCW"
local NSL_League = "NSL"
local NSL_CachedScores = { }
local NSL_Scores = { }
local CachedScoresValidFor = 10 * 60

function GetNSLMode()
	return NSL_Mode
end

function GetNSLModEnabled()
	return NSL_Mode ~= "DISABLED"
end

function GetActiveLeague()
	return NSL_League
end

function GetRecentScores()
	return NSL_CachedScores
end

local function LoadConfig()
	local defaultConfig = { mode = "PCW", league = "NSL", recentgames = { } }
	WriteDefaultConfigFile(configFileName, defaultConfig)
	local config = LoadConfigFile(configFileName) or defaultConfig
	NSL_Mode = config.mode or "PCW"
	NSL_League = config.league or "NSL"
	local loadedScores = config.recentgames or { }
	local updated = false
	for t, s in pairs(loadedScores) do
		if type(s) == "table" and (Shared.GetSystemTime() - (s.scoretime or 0) < CachedScoresValidFor) and (s.score or 0) > 0 then
			NSL_CachedScores[t] = s.score or 0
		end
	end
end

LoadConfig()

local function SavePluginConfig()
	SaveConfigFile(configFileName, { mode = NSL_Mode, league = NSL_League, recentgames = NSL_Scores })
end

function SetNSLMode(state)
	if NSL_Mode ~= state then
		NSL_Mode = state
		SavePluginConfig()
		if NSL_Mode == "DISABLED" then
			GetGamerules():OnTournamentModeDisabled()
		else
			GetGamerules():OnTournamentModeEnabled()
		end
	end
end

function SetActiveLeague(state)
	if NSL_League ~= state then
		NSL_League = state
		SavePluginConfig()
	end
end

function UpdateNSLScores(team1name, team1score, team2name, team2score)
	NSL_Scores[team1name] = { score = team1score, scoretime = Shared.GetSystemTime() }
	NSL_Scores[team2name] = { score = team2score, scoretime = Shared.GetSystemTime() }
	SavePluginConfig()
end

local ENSLBaseConfig = {
LeagueName 							= "NSL",
PlayerDataURL 						= "http://www.ensl.org/plugin/user/",
PlayerDataFormat					= "ENSL",
PlayerRefLevel 						= 10,
AutomaticMapCycleDelay				= 180 * 60,
PauseEndDelay 						= 5,
PauseStartDelay 					= 1,
PauseMaxPauses 						= 3,
PausedReadyNotificationDelay 		= 30,
PauseEnabled 						= true,
Interp 								= 70,
MoveRate 							= 50,
ClientRate 							= 20,
FriendlyFireDamagePercentage 		= 0.33,
FriendlyFireEnabled			 		= true,
TournamentModeAlertDelay 			= 30,
TournamentModeGameStartDelay 		= 15,
PCW 								= {
										PausedMaxDuration 					= 300,
										TournamentModeForfeitClock			= 0,
										TournamentModeRestartDuration 		= 90,
										Limit6PlayerPerTeam 				= false,
										MercsRequireApproval 				= false,
									},
OFFICIAL							= {
										PausedMaxDuration 					= 300,
										TournamentModeForfeitClock			= 1200,
										TournamentModeRestartDuration 		= 30,
										Limit6PlayerPerTeam 				= true,
										MercsRequireApproval 				= true,
									},
REFS								= { 37983254, 2582259, 4204158, 3834993, 9821488, 1009560, 850663, 870339, 3834993, 220612, 
										33962486, 26400815, 4048968, 4288812, 44665807, 28798044, 40509515, 39359741, 64272164, 
										56472390, 42416427, 7862563, 3823437, 1080730, 221386, 42984531, 37996245, 49465,
										44778147, 10498798, 24256940, 22793, 80887771, 512557, 4288812, 12482757, 54867496, 
										711854, 6851233, 13901505, 19744894, 206793, 1561398, 8973, 50582634, 73397263, 45160820, 
										15901849,  38540300, 136317, 1592683, 7494, 20682781, 90227495, 42608442, 3023411, 81519, 
										3814554, 70496041, 12034125, 41851898, 35329790, 1207116, 69364649, 3490104, 115723837, 
										15097215, 100657023, 95816540, 599694, 131547597, 24995964, 7246681
									},
PLAYERDATA							= { },
}

local AUSNS2BaseConfig = {
LeagueName 							= "AusNS2",
PlayerDataURL 						= "http://ausns2.org/league-api.php?lookup=player&steamid=",
PlayerDataFormat					= "AUSNS",
PlayerRefLevel 						= 1,
AutomaticMapCycleDelay				= 180 * 60,
PauseEndDelay 						= 5,
PauseStartDelay 					= 1,
PauseMaxPauses 						= 3,
PausedReadyNotificationDelay 		= 30,
PauseEnabled 						= true,
Interp 								= 70,
MoveRate 							= 50,
ClientRate 							= 20,
FriendlyFireDamagePercentage 		= 0.33,
FriendlyFireEnabled			 		= true,
TournamentModeAlertDelay 			= 30,
TournamentModeGameStartDelay 		= 15,
PCW 								= {
										PausedMaxDuration 					= 120,
										TournamentModeForfeitClock			= 0,
										TournamentModeRestartDuration 		= 90,
										Limit6PlayerPerTeam 				= false,
										MercsRequireApproval 				= false,
									},
OFFICIAL							= {
										PausedMaxDuration 					= 90,
										TournamentModeForfeitClock			= 1200,
										TournamentModeRestartDuration 		= 30,
										Limit6PlayerPerTeam 				= true,
										MercsRequireApproval 				= true,
									},
REFS								= { },
PLAYERDATA							= { },
}

local DefaultConfig = {
AutomaticMapCycleDelay				= 180 * 60,
PauseEndDelay 						= 5,
PauseStartDelay 					= 1,
PauseMaxPauses 						= 3,
PausedReadyNotificationDelay 		= 30,
PauseEnabled 						= true,
Interp 								= 100,
MoveRate 							= 30,
ClientRate 							= 20,
FriendlyFireDamagePercentage 		= 0.33,
FriendlyFireEnabled			 		= false,
TournamentModeAlertDelay 			= 30,
TournamentModeGameStartDelay 		= 15,
PausedMaxDuration 					= 120,
TournamentModeForfeitClock			= 0,
TournamentModeRestartDuration 		= 90,
Limit6PlayerPerTeam 				= false,
MercsRequireApproval 				= false,
}

local Configs = { }

local function OnConfigResponse(response)
	if response then
		local responsetable = json.decode(response)
		if responsetable == nil or responsetable.Version == nil then
			//RIP
			//Retry?
			if configUpdateRetries < 3 then
				configUpdateRequestSent = false
				configUpdateRetries = configUpdateRetries + 1
			else
				Shared.Message("Failed getting latest config from GitHub.")
				Configs = { NSL = ENSLBaseConfig, AUSNS2 = AUSNS2BaseConfig }
			end
		else
			if responsetable.Version and responsetable.EndOfTable then
				for i, config in ipairs(responsetable.Configs) do
					if config.LeagueName ~= nil then
						//assume valid, update Configs table, always uppercase
						//Shared.Message("Loading config " .. config.LeagueName .. " from GitHub.")
						Configs[string.upper(config.LeagueName)] = config
					end
				end
			end
		end
	end
end

local function OnServerUpdated()
	if GetNSLModEnabled() and not configUpdateRequestSent then
		Shared.SendHTTPRequest(configUpdateURL, "GET", OnConfigResponse)
		configUpdateRequestSent = true
	end
end

Event.Hook("UpdateServer", OnServerUpdated)

function GetNSLConfigValue(value)
	//Check base config
	if Configs[NSL_League] ~= nil and Configs[NSL_League][value] ~= nil then
		return Configs[NSL_League][value]
	end
	//Check Mode Specific config
	if Configs[NSL_League] ~= nil and Configs[NSL_League][NSL_Mode] ~= nil and Configs[NSL_League][NSL_Mode][value] ~= nil then
		return Configs[NSL_League][NSL_Mode][value]
	end
	if DefaultConfig[value] ~= nil then
		return DefaultConfig[value]
	end
	return nil
end

function GetNSLLeagueValid(league)
	if Configs[league] ~= nil and Configs[league].LeagueName ~= nil then
		return true
	end
	return false
end

function GetIsNSLRef(ns2id)
	local ref = false
	if ns2id ~= nil then
		local cRefs = GetNSLConfigValue("REFS")
		if cRefs ~= nil then
			ref = table.contains(cRefs, ns2id)
		end
		local pData = GetNSLUserData(ns2id)
		if pData ~= nil and pData.NSL_Level ~= nil and tonumber(pData.NSL_Level) ~= nil and not ref then
			ref = tonumber(pData.NSL_Level) >= GetNSLConfigValue("PlayerRefLevel")
		end
	end
	return ref
end

local Messages = {
PauseResumeMessage 					= "Game Resumed.  %s have %s pauses remaining",
PausePausedMessage					= "Game Paused.",
PauseWarningMessage					= "Game will %s in %d seconds.",
PauseResumeWarningMessage 			= "Game will automatically resume in %d seconds.",
PausePlayerMessage					= "%s has paused the game.",
PauseTeamReadiedMessage				= "%s readied for %s, resuming game.",
PauseTeamReadyMessage				= "%s readied for %s, waiting for the %s.",
PauseTeamReadyPeriodicMessage		= "%s are ready, waiting for the %s.",
PauseNoTeamReadyMessage				= "No team is ready to resume, type unpause in console to ready for your team.",
PauseCancelledMessage				= "Game Pause Cancelled.",
PauseTooManyPausesMessage			= "Your team is out of pauses.",
TournamentModeTeamReadyAlert 		= "%s are ready, waiting on %s to start game.",
TournamentModeCountdown 			= "Game will start in %s seconds!",
TournamentModeReadyAlert 			= "Both teams need to ready for the game to start.",
TournamentModeTeamReady				= "%s has %s for %s.",
TournamentModeGameCancelled			= "Game start cancelled.",
TournamentModeForfeitWarning		= "%s have %d %s left to ready before forfeiting.",
TournamentModeGameForfeited			= "%s have forfeit the round due to not reading within %s seconds.",
TournamentModeReadyNoComm			= "Your team needs a commander to ready.",
TournamentModeStartedGameCancelled  = "%s un-readied for the %s, resetting game.",
UnstuckCancelled					= "You moved or were unable to be unstuck currently.",
Unstuck								= "Unstuck!",
UnstuckIn							= "You will be unstuck in %s seconds.",
UnstuckRecently						= "You have unstucked too recently, please wait %d seconds.",
UnstuckFailed						= "Unstuck Failed after %s attempts.",
MercApprovalNeeded					= "The opposite team will need to approve you as a merc.",
MercApproved 						= "%s has been approved as a merc for %s.",
MercsReset 							= "Merc approvals have been reset."
}

function GetNSLMessage(message)
	return Messages[message] or ""
end