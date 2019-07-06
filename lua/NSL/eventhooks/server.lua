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
--NSL Server Admin Commands
gNSLServerAdminCommands = { }
-- Captains Phase change
gCaptainsStateChange = { }
-- Ready chat/console command callbacks
gReadyCommandFunctions = { }
-- NotReady chat/console command callbacks
gNotReadyCommandFunctions = { }

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
	function(self, winningTeam, autoConceded)
		originalNS2GameRulesEndGame(self, winningTeam, autoConceded)
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

function RegisterNSLConsoleCommand(command, callback, helper, allPlayers, params)
	if command and callback then
		table.insert(gNSLConsoleCommands, {command = command, callback = callback, helper = helper, open = (allPlayers == true), params = params})
		table.insert(gNSLHelpMessages, {command = command, message = helper, refOnly = (allPlayers == true)})
	end
end

function CreateNSLServerAdminCommand(command, callback, helper, params)
	if command and callback then
		table.insert(gNSLServerAdminCommands, {command = command, callback = callback, helper = helper, params = params})
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

local function OnUpdateSpawnConfig(_)
	local gameInfo = GetGameInfoEntity()
	if gameInfo then
		gameInfo:SetSpawnSelectionMode(GetNSLConfigValue("CustomSpawnModes"))
	end
end

table.insert(gConfigLoadedFunctions, OnUpdateSpawnConfig)

local function OnUpdateCaptainsState(newState)
	local gameInfo = GetGameInfoEntity()
	if gameInfo then
		gameInfo:SetNSLCaptainsState(newState)
	end
end

table.insert(gCaptainsStateChange, OnUpdateCaptainsState)

local function FinalizeNSLConsoleCommands(configloaded)
	-- Only run if its part of final config load
	if configloaded == "complete" then
		-- Only run if stuff to register
		local nslPlugin
		if Shine then
			nslPlugin = Shine.Plugins["nsl"]
		end
		if #gNSLConsoleCommands > 0 then
			local HookTable = debug.getregistry()["Event.HookTable"]
			for i = #gNSLConsoleCommands, 1, -1 do
				local cc = gNSLConsoleCommands[i]
				local command = "Console_"..cc.command
				if not rawget(HookTable, command) then
					if cc.open then
						-- If its a command for everyone, we dont need to check if shine is present
						RegisterNSLServerCommand(command)
						CreateServerAdminCommand(command, cc.callback, GetNSLMessageDefaultText(cc.helper), cc.open)
					else
						-- This command requires perms.
						if nslPlugin then
							-- Register with shine
							-- NSL mod built to work with vanilla admin command system, so most params are just strings - NSL mod handles the processing already
							RegisterNSLServerCommand(command)
							nslPlugin:CreateCommand({Command = cc.command, Callback = cc.callback, Params = cc.params, Help = GetNSLMessageDefaultText(cc.helper)})
						else
							RegisterNSLServerCommand(command)
							CreateServerAdminCommand(command, cc.callback, GetNSLMessageDefaultText(cc.helper))
						end
					end
				else
					--Print(string.format("Skipping already registered event %s!",cc.command))
				end
				table.remove(gNSLConsoleCommands, i)
			end
		end
		if #gNSLServerAdminCommands > 0 then
			for i = #gNSLServerAdminCommands, 1, -1 do
				local cc = gNSLServerAdminCommands[i]
				if nslPlugin then
					-- Register with shine
					-- NSL mod built to work with vanilla admin command system, so most params are just strings - NSL mod handles the processing already
					nslPlugin:CreateCommand({Command = cc.command, Callback = cc.callback, Params = cc.params, Help = GetNSLMessageDefaultText(cc.helper)})
				else
					CreateServerAdminCommand("Console_"..cc.command, cc.callback, GetNSLMessageDefaultText(cc.helper))
				end
			end
		end
	end
end

table.insert(gConfigLoadedFunctions, FinalizeNSLConsoleCommands)

local function OnCommandReady(client)
	for i = #gReadyCommandFunctions, 1, -1 do
		if gReadyCommandFunctions[i](client) then return end
	end
end

RegisterNSLConsoleCommand("ready", OnCommandReady, "CMD_READY", true)
gChatCommands["ready"] = OnCommandReady
gChatCommands["!ready"] = OnCommandReady
gChatCommands["rdy"] = OnCommandReady

local function OnCommandNotReady(client)
	for i = #gNotReadyCommandFunctions, 1, -1 do
		if gNotReadyCommandFunctions[i](client) then return end
	end
end

RegisterNSLConsoleCommand("notready", OnCommandNotReady, "CMD_NOTREADY", true)
gChatCommands["notready"] = OnCommandNotReady
gChatCommands["!notready"] = OnCommandNotReady
gChatCommands["notrdy"] = OnCommandNotReady