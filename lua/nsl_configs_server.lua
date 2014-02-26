//NSL Configs

local configFileName = "NSLConfig.json"
local NSL_Mode = "PCW"
local FF_Enabled = true

function GetNSLMode()
	return NSL_Mode
end

function GetNSLModEnabled()
	return NSL_Mode ~= "DISABLED"
end

function GetFFEnabled()
	return FF_Enabled
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

function SetFFState(state)
	if FF_Enabled ~= state then
		FF_Enabled = state
		SavePluginConfig()
	end
end

local function LoadConfig()
	local defaultConfig = { mode = "PCW", friendlyfire = true }
	WriteDefaultConfigFile(configFileName, defaultConfig)
	local config = LoadConfigFile(configFileName) or defaultConfig
	NSL_Mode = config.mode or "PCW"
	FF_Enabled = config.friendlyfire or true
end

LoadConfig()

function SavePluginConfig()
	SaveConfigFile(configFileName, { mode = GetNSLMode(), friendlyfire = GetFFEnabled() })
end

local PCWConfig = {
kPauseEndDelay 						= 5,
kPauseStartDelay 					= 1,
kPauseMaxPauses 					= 3,
kPausedReadyNotificationDelay 		= 30,
kPausedMaxDuration 					= 120,
kInterp 							= 70,
kMoveRate 							= 50,
kClientRate 						= 20,
kFriendlyFireDamagePercentage 		= 0.33,
kTournamentModeAlertDelay 			= 30,
kTournamentModeForfeitClock			= 0,
kTournamentModeRestartDuration 		= 90,
kTournamentModeGameStartDelay 		= 15,
kLimit6PlayerPerTeam 				= false,
kMercsRequireApproval 				= false,
}

local OfficalsConfig = {
kPauseEndDelay 						= 5,
kPauseStartDelay 					= 1,
kPauseMaxPauses 					= 3,
kPausedReadyNotificationDelay 		= 30,
kPausedMaxDuration 					= 90,
kInterp 							= 70,
kMoveRate 							= 50,
kClientRate 						= 20,
kFriendlyFireDamagePercentage 		= 0.33,
kTournamentModeAlertDelay 			= 30,
kTournamentModeForfeitClock			= 1200,
kTournamentModeRestartDuration 		= 30,
kTournamentModeGameStartDelay 		= 15,
kLimit6PlayerPerTeam 				= true,
kMercsRequireApproval 				= true,
}

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
TournamentModeStartedGameCancelled  = "%s un-readied for the %s, cancelling game start.",
UnstuckCancelled					= "You moved or were unable to be unstuck currently.",
Unstuck								= "Unstuck!",
UnstuckIn							= "You will be unstuck in %s seconds.",
UnstuckRecently						= "You have unstucked too recently, please wait %d seconds.",
MercApprovalNeeded					= "The opposite team will need to approve you as a merc.",
MercApproved 						= "%s has been approved as a merc for %s.",
MercsReset 							= "Merc approvals have been reset."
}

local ApprovedRefs = { 	37983254, 2582259, 4204158, 3834993, 9821488, 1009560, 850663, 870339, 3834993, 220612, 
						33962486, 26400815, 4048968, 4288812, 44665807, 28798044, 40509515, 39359741, 64272164, 
						56472390, 42416427, 7862563, 3823437, 1080730, 221386, 42984531, 37996245, 49465,
						44778147, 10498798, 24256940, 22793, 80887771, 512557, 4288812, 12482757, 54867496, 
						711854, 6851233, 13901505, 19744894, 206793, 1561398, 8973, 50582634, 73397263, 45160820, 
						15901849,  38540300, 136317, 1592683, 7494, 20682781, 90227495, 42608442, 5176141 }

function GetNSLConfig()
	if GetNSLMode() == "OFFICIAL" then
		return OfficalsConfig
	else
		return PCWConfig
	end
end

function GetNSLMessages()
	return Messages
end

function GetNSLRefs()
	return ApprovedRefs
end