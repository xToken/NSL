// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_eventhooks_server.lua
// - Dragon

//Functions for chat commands
gChatCommands = { }
//Chat functions which could use additional arguments
gArgumentedChatCommands = { }
//Functions on connect
gConnectFunctions = { }
//Plugin Activation Functions
gPluginStateChange = { }
//Game End Functions
gGameEndFunctions = { }
//Config Loaded Functions
gConfigLoadedFunctions = { }
//PlayerData Updated Functions
gPlayerDataUpdatedFunctions = { }
//TeamNames Updated Functions
gTeamNamesUpdatedFunctions = { }
//TeamJoin Functions
gTeamJoinedFunctions = { }

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