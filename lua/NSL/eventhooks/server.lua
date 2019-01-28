-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\eventhooks\server.lua
-- - Dragon

--Functions for chat commands
gChatCommands = { }
--Chat functions which could use additional arguments
gArgumentedChatCommands = { }
--Functions on connect
gConnectFunctions = { }
--Functions on disconnect
gDisconnectFunctions = { }
--Plugin Activation Functions
gPluginStateChange = { }
--Game End Functions
gGameEndFunctions = { }
--Config Loaded Functions
gConfigLoadedFunctions = { }
--LeagueChanged Functions
gLeagueChangeFunctions = { }
--PlayerData Updated Functions
gPlayerDataUpdatedFunctions = { }
--TeamNames Updated Functions
gTeamNamesUpdatedFunctions = { }
--CanJoinTeam Functions
gCanJoinTeamFunctions = { }
--TeamJoin Functions
gTeamJoinedFunctions = { }
--Perf Values Loaded Functions
gPerfLoadedFunctions = { }
--NSL Help Messages (sv_nslhelp)
gNSLHelpMessages = { }
--NSL Console Commands
gNSLConsoleCommands = { }
-- Captains Phase change
gCaptainsStateChange = { }

local function OnClientConnected(client)
	if GetNSLModEnabled() then
		for i = #gConnectFunctions, 1, -1 do
			gConnectFunctions[i](client)
		end
	end
end

Event.Hook("ClientConnect", OnClientConnected)

local function OnClientDisconnect(client)    
    if GetNSLModEnabled() then
		for i = #gDisconnectFunctions, 1, -1 do
			gDisconnectFunctions[i](client)
		end
	end 
end

Event.Hook("ClientDisconnect", OnClientDisconnect)

local originalNS2GameRulesEndGame
originalNS2GameRulesEndGame = Class_ReplaceMethod("NS2Gamerules", "EndGame", 
	function(self, winningTeam)
		originalNS2GameRulesEndGame(self, winningTeam)
		for i = #gGameEndFunctions, 1, -1 do
			gGameEndFunctions[i](self, winningTeam)
		end
	end
)

local originalNS2GRJoinTeam
originalNS2GRJoinTeam = Class_ReplaceMethod("NS2Gamerules", "JoinTeam", 
	function(self, player, newTeamNumber, force)
		local success, newPlayer = originalNS2GRJoinTeam(self, player, newTeamNumber, force)
		if success then
			for i = #gTeamJoinedFunctions, 1, -1 do
				gTeamJoinedFunctions[i](self, newPlayer, newTeamNumber)
			end
		end
		return success, newPlayer
	end
)

local originalNS2GameRulesGetCanJoinTeamNumber
originalNS2GameRulesGetCanJoinTeamNumber = Class_ReplaceMethod("NS2Gamerules", "GetCanJoinTeamNumber", 
	function(self, player, teamNumber)
		for i = #gCanJoinTeamFunctions, 1, -1 do
			if not gCanJoinTeamFunctions[i](self, player, teamNumber) then return false end
		end
		return originalNS2GameRulesGetCanJoinTeamNumber(self, player, teamNumber)
	end
)

function ProcessSayCommand(player, command)

	if GetNSLModEnabled() then
		local client = Server.GetOwner(player)
		for validCommand, func in pairs(gChatCommands) do
			if string.lower(validCommand) == string.lower(command) then
				func(client)
			end
		end
		for validCommand, func in pairs(gArgumentedChatCommands) do
			if string.lower(string.sub(command, 1, string.len(validCommand))) == string.lower(validCommand) then
				func(client, string.sub(command, string.len(validCommand) + 2))
			end
		end
	end

end

function EstablishConfigDependantSettings(configLoaded)
	for i = #gConfigLoadedFunctions, 1, -1 do
		gConfigLoadedFunctions[i](configLoaded)
	end
end

function ApplyPerfDependantSettings()
	for i = #gPerfLoadedFunctions, 1, -1 do
		gPerfLoadedFunctions[i]()
	end
end

local function UpdateNSLEntityCFG(newState)
	local gameInfo = GetGameInfoEntity()
	if gameInfo then
		gameInfo:SetNSLConfig(newState)
	end
end

table.insert(gPluginStateChange, UpdateNSLEntityCFG)

local function UpdateNSLEntityTeams(teamData, teamScore)
	local gameInfo = GetGameInfoEntity()
	if gameInfo then
		gameInfo:SetTeam1Name(teamData[1].name)
		gameInfo:SetTeam2Name(teamData[2].name)
		gameInfo:SetTeam1Score(teamScore[teamData[1].name])
		gameInfo:SetTeam2Score(teamScore[teamData[2].name])
		gameInfo:SetTeamsUpdated()
	end
end

table.insert(gTeamNamesUpdatedFunctions, UpdateNSLEntityTeams)

function RegisterNSLHelpMessageForCommand(message, refOnly)
	if message then
		table.insert(gNSLHelpMessages, {message = message, refOnly = (refOnly == true)})
	end
end

function RegisterNSLConsoleCommand(command, callback, helper, allPlayers)
	if command and callback then
		table.insert(gNSLConsoleCommands, {command = command, callback = callback, helper = helper, open = allPlayers == true})
	end
end

local function OnUpdateLeagueName(_)
	-- Grab 'friendly' league name from config
	local gameInfo = GetGameInfoEntity()
	if gameInfo then
		gameInfo:SetLeagueName(GetNSLConfigValue("LeagueName"))
	end
end

table.insert(gLeagueChangeFunctions, OnUpdateLeagueName)
table.insert(gConfigLoadedFunctions, OnUpdateLeagueName)

local function OnUpdateCaptainsState(newState)
	local gameInfo = GetGameInfoEntity()
	if gameInfo then
		gameInfo:SetNSLCaptainsState(newState)
	end
end

table.insert(gCaptainsStateChange, OnUpdateCaptainsState)

local function FinalizeNSLConsoleCommands()
	-- Only run if stuff to register
	if #gNSLConsoleCommands > 0 then
		local HookTable = debug.getregistry()["Event.HookTable"]
		for i = #gNSLConsoleCommands, 1, -1 do
			local cc = gNSLConsoleCommands[i]
			local command = "Console_"..cc.command
			if not rawget(HookTable, command) then
				RegisterNSLServerCommand(command, cc.callback, string.gsub(GetNSLMessageDefaultText(cc.helper), command..": ", ""), cc.open)
			else
				--Print(string.format("Skipping already registered event %s!",cc.command))
			end
			table.remove(gNSLConsoleCommands, i)
		end
	end
end

table.insert(gConfigLoadedFunctions, FinalizeNSLConsoleCommands)