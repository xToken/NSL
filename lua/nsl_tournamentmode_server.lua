//NS2 Tournament Mod Server side script

Script.Load("lua/nsl_class.lua")

local TournamentModeSettings = { 
countdownstarted = false, 
countdownstarttime = 0, 
countdownstartcount = 0, 
lastmessage = 0,  
roundstarted = 0
}

function TournamentModeOnGameEnd()
	GetGamerules():SetTeamsReady(false)
end

local originalNS2GROnCreate
originalNS2GROnCreate = Class_ReplaceMethod("NS2Gamerules", "OnCreate", 
	function(self)
		originalNS2GROnCreate(self)
		if GetNSLModEnabled() then
			GetGamerules():OnTournamentModeEnabled()
		end
	end
)

local originalNS2GRSetGameState
originalNS2GRSetGameState = Class_ReplaceMethod("NS2Gamerules", "SetGameState", 
	function(self, state)
		if self.gameState ~= kGameState.Started and state == kGameState.Started then
			GetGamerules():SetTeamsReady(false)
		end
		originalNS2GRSetGameState(self, state)
	end
)

//Allow imbalanced teams, but also dont allow more than 6 players per team in an in-progress game.
local function CheckTournamentModeTeamJoin(self, teamNumber)
	if teamNumber == 1 or teamNumber == 2 and GetNSLModEnabled() and GetNSLConfig().kLimit6PlayerPerTeam then
		if self:GetGameState() == kGameState.Started then
			local team1Players = self.team1:GetNumPlayers()
			local team2Players = self.team2:GetNumPlayers()
			if (teamNumber == 1 and team1Players >= 6) or (teamNumber == 2 and team2Players >= 6) then
				return false
			end
		end
	end
	return true
end

table.insert(gCanJoinTeamFunctions, CheckTournamentModeTeamJoin)

local function ClearTournamentModeState()
	TournamentModeSettings[1] = {ready = false, lastready = 0}
	TournamentModeSettings[2] = {ready = false, lastready = 0}
	TournamentModeSettings.countdownstarted = false
	TournamentModeSettings.countdownstarttime = 0
	TournamentModeSettings.countdownstartcount = 0
	TournamentModeSettings.lastmessage = 0
end

ClearTournamentModeState()

local function CheckCancelGameStart()
	if TournamentModeSettings.countdownstarttime ~= 0 then
		SendAllClientsMessage(GetNSLMessages().TournamentModeGameCancelled)
		ClearTournamentModeState()
	end
end

local originalNS2OnCommanderLogOut = OnCommanderLogOut
function OnCommanderLogOut(commander)
	originalNS2OnCommanderLogOut(commander)
	if commander and GetNSLModEnabled() then
		local teamnum = commander:GetTeamNumber()
		if TournamentModeSettings[teamnum].ready and (GetGamerules():GetGameState() == kGameState.NotStarted or GetGamerules():GetGameState() == kGameState.PreGame) then
			TournamentModeSettings[teamnum].ready = false
			CheckCancelGameStart()
			SendTeamMessage(teamnum, GetNSLMessages().TournamentModeReadyNoComm)
		end
	end
end

local function CheckGameStart()
	if TournamentModeSettings.countdownstarttime < Shared.GetTime() + 0.9 then
		GetGamerules():SetTeamsReady(true)
		ClearTournamentModeState()
		TournamentModeSettings.roundstarted = Shared.GetTime()
	end
end

local function AnnounceTournamentModeCountDown()

	if TournamentModeSettings.countdownstarted and TournamentModeSettings.countdownstarttime - TournamentModeSettings.countdownstartcount < Shared.GetTime() and TournamentModeSettings.countdownstartcount ~= 0 then
		if (math.fmod(TournamentModeSettings.countdownstartcount, 5) == 0 or TournamentModeSettings.countdownstartcount <= 5) then
			SendAllClientsMessage(string.format(GetNSLMessages().TournamentModeCountdown, TournamentModeSettings.countdownstartcount))
		end
		TournamentModeSettings.countdownstartcount = TournamentModeSettings.countdownstartcount - 1
	end
	
end

local function DisplayReadiedTeamAlertMessages(ReadiedTeamNum)
	local notreadyteamname = GetActualTeamName((ReadiedTeamNum == 2 and 1) or 2)
	local readyteamname = GetActualTeamName(ReadiedTeamNum)
	SendAllClientsMessage(string.format(GetNSLMessages().TournamentModeTeamReadyAlert, readyteamname, notreadyteamname))
	if GetNSLConfig().kTournamentModeForfeitClock > 0 then
		if Shared.GetTime() - (TournamentModeSettings[ReadiedTeamNum].lastready + GetNSLConfig().kTournamentModeForfeitClock) > 0 then
			SendAllClientsMessage(string.format(GetNSLMessages().TournamentModeGameForfeited, notreadyteamname, GetNSLConfig().kTournamentModeForfeitClock))
			TournamentModeSettings[ReadiedTeamNum].ready = false
			TournamentModeSettings[ReadiedTeamNum].lastready = Shared.GetTime()
		else
			local timeremaining = (TournamentModeSettings[ReadiedTeamNum].lastready + GetNSLConfig().kTournamentModeForfeitClock) - Shared.GetTime()
			local unit = "seconds"
			if (timeremaining / 60) > 1 then
				timeremaining = (timeremaining / 60)
				unit = "minutes"
			end
			SendAllClientsMessage(string.format(GetNSLMessages().TournamentModeForfeitWarning, notreadyteamname, timeremaining, unit))
		end
	end
end

local function MonitorCountDown()

	if not TournamentModeSettings.countdownstarted then
		if TournamentModeSettings.lastmessage + GetNSLConfig().kTournamentModeAlertDelay < Shared.GetTime() then
			if TournamentModeSettings[1].ready or TournamentModeSettings[2].ready then
				if TournamentModeSettings[1].ready then
					DisplayReadiedTeamAlertMessages(1)
				else
					DisplayReadiedTeamAlertMessages(2)
				end
			else
				SendAllClientsMessage(GetNSLMessages().TournamentModeReadyAlert)
			end
			TournamentModeSettings.lastmessage = Shared.GetTime()
		end
	else
		AnnounceTournamentModeCountDown()
		CheckGameStart()
	end
	
end

local originalNS2GamerulesUpdatePregame
originalNS2GamerulesUpdatePregame = Class_ReplaceMethod("NS2Gamerules", "UpdatePregame", 
	function(self, timePassed)
		if (self:GetGameState() == kGameState.PreGame or self:GetGameState() == kGameState.NotStarted) and not self.teamsReady and GetNSLModEnabled() then
			MonitorCountDown()
		else
			originalNS2GamerulesUpdatePregame(self, timePassed)
		end
	end
)

local function TournamentModeOnDisconnect(client)
	if TournamentModeSettings.countdownstarted then
		CheckCancelGameStart()
	end
end

Event.Hook("ClientDisconnect", TournamentModeOnDisconnect)

local function CheckGameCountdownStart()
	if TournamentModeSettings[1].ready and TournamentModeSettings[2].ready then
		TournamentModeSettings.countdownstarted = true
		TournamentModeSettings.countdownstarttime = Shared.GetTime() + GetNSLConfig().kTournamentModeGameStartDelay
		TournamentModeSettings.countdownstartcount = GetNSLConfig().kTournamentModeGameStartDelay
	end
end

local function OnCommandForceStartRound(client)
	local NS2ID = client:GetUserId()
	if ValidateNSLUsersAccessLevel(NS2ID) then
		ClearTournamentModeState()
		TournamentModeSettings[1].ready = true
		TournamentModeSettings[2].ready = true
		CheckGameCountdownStart()
		ServerAdminPrint(client, "Forcing game start.")
	end
end

Event.Hook("Console_sv_nslforcestart",               OnCommandForceStartRound)

local function OnCommandCancelRoundStart(client)
	local NS2ID = client:GetUserId()
	if ValidateNSLUsersAccessLevel(NS2ID) then
		CheckCancelGameStart()
		ClearTournamentModeState()
		ServerAdminPrint(client, "Cancelling countdown in progress.")
	end
end

Event.Hook("Console_sv_nslcancelstart",               OnCommandCancelRoundStart)

local function ClientReady(client)

	local player = client:GetControllingPlayer()
	local playername = player:GetName()
	local teamnum = player:GetTeamNumber()
	if teamnum == 1 or teamnum == 2 then
		local gamerules = GetGamerules()
		local team1Commander = gamerules.team1:GetCommander()
        local team2Commander = gamerules.team2:GetCommander()
		if (not team1Commander and teamnum == 1) or (not team2Commander and teamnum == 2) then
			SendTeamMessage(teamnum, GetNSLMessages().TournamentModeReadyNoComm)
		elseif TournamentModeSettings[teamnum].lastready + 2 < Shared.GetTime() then
			TournamentModeSettings[teamnum].ready = not TournamentModeSettings[teamnum].ready
			TournamentModeSettings[teamnum].lastready = Shared.GetTime()
			SendAllClientsMessage(string.format(GetNSLMessages().TournamentModeTeamReady, playername, ConditionalValue(TournamentModeSettings[teamnum].ready, "readied", "unreadied"), GetActualTeamName(teamnum)))
			CheckGameCountdownStart()
		end	
	end
	if TournamentModeSettings[1].ready == false or TournamentModeSettings[2].ready == false then
		CheckCancelGameStart()
	end
	
end

local function OnCommandReady(client)
	local gamerules = GetGamerules()
	if gamerules ~= nil and client ~= nil and GetNSLModEnabled() then
		if gamerules:GetGameState() == kGameState.NotStarted or gamerules:GetGameState() == kGameState.PreGame or (TournamentModeSettings.roundstarted ~= 0 and TournamentModeSettings.roundstarted + GetNSLConfig().kTournamentModeRestartDuration > Shared.GetTime()) then
			if gamerules:GetGameState() == kGameState.Started then
				local player = client:GetControllingPlayer()
				local playername = player:GetName()
				local teamnum = player:GetTeamNumber()
				gamerules:SetTeamsReady(false)
				SendAllClientsMessage(string.format(GetNSLMessages().TournamentModeStartedGameCancelled, playername, GetActualTeamName(teamnum)))
			end
			//gamerules:SetGameState(kGameState.PreGame)
			ClientReady(client)
		end
	end
end

Event.Hook("Console_ready",                 OnCommandReady)
gChatCommands["ready"] = OnCommandReady
gChatCommands["rdy"] = OnCommandReady

local function ClientNotReady(client)

	local player = client:GetControllingPlayer()
	local playername = player:GetName()
	local teamnum = player:GetTeamNumber()
	if (teamnum == 1 or teamnum == 2) and TournamentModeSettings[teamnum].ready then
		TournamentModeSettings[teamnum].ready = false
		TournamentModeSettings[teamnum].lastready = Shared.GetTime()
		SendAllClientsMessage(string.format(GetNSLMessages().TournamentModeTeamReady, playername, "unreadied", GetActualTeamName(teamnum)))
	end
	if TournamentModeSettings[1].ready == false or TournamentModeSettings[2].ready == false then
		CheckCancelGameStart()
	end
	
end

local function OnCommandNotReady(client)
	local gamerules = GetGamerules()
	if gamerules ~= nil and client ~= nil and GetNSLModEnabled() then
		if gamerules:GetGameState() == kGameState.NotStarted or gamerules:GetGameState() == kGameState.PreGame or (TournamentModeSettings.roundstarted ~= 0 and TournamentModeSettings.roundstarted + GetNSLConfig().kTournamentModeRestartDuration > Shared.GetTime()) then
			if gamerules:GetGameState() == kGameState.Started then
				local player = client:GetControllingPlayer()
				local playername = player:GetName()
				local teamnum = player:GetTeamNumber()
				gamerules:SetTeamsReady(false)
				SendAllClientsMessage(string.format(GetNSLMessages().TournamentModeStartedGameCancelled, playername, GetActualTeamName(teamnum)))
			end
			//gamerules:SetGameState(kGameState.PreGame)
			ClientNotReady(client)
		end
	end
end

Event.Hook("Console_notready",                 OnCommandNotReady)
gChatCommands["notready"] = OnCommandNotReady
gChatCommands["notrdy"] = OnCommandNotReady