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
--Plugin Activation Functions
gPluginStateChange = { }
--Game End Functions
gGameEndFunctions = { }
--Config Loaded Functions
gConfigLoadedFunctions = { }
--PlayerData Updated Functions
gPlayerDataUpdatedFunctions = { }
--TeamNames Updated Functions
gTeamNamesUpdatedFunctions = { }
--TeamJoin Functions
gTeamJoinedFunctions = { }
--Perf Values Loaded Functions
gPerfLoadedFunctions = { }

local function OnClientConnected(client)
	if GetNSLModEnabled() then
		for i = 1, #gConnectFunctions do
			gConnectFunctions[i](client)
		end
	end
end

Event.Hook("ClientConnect", OnClientConnected)

local originalNS2GameRulesEndGame
originalNS2GameRulesEndGame = Class_ReplaceMethod("NS2Gamerules", "EndGame", 
	function(self, winningTeam)
		originalNS2GameRulesEndGame(self, winningTeam)
		for i = 1, #gGameEndFunctions do
			gGameEndFunctions[i](self, winningTeam)
		end
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
	for i = 1, #gConfigLoadedFunctions do
		gConfigLoadedFunctions[i](configLoaded)
	end
end

function ApplyPerfDependantSettings()
	for i = 1, #gPerfLoadedFunctions do
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