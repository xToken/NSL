-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/statesave/server.lua
-- - Dragon

local NSL_VirtualClients = { }
local NSL_DisconnectedIDs = { }
local NSL_VirtualClientCount = 0
local NSLPauseDisconnectOverride = false
local NSLDontGenPlayerOnConnect = false
local kDisconnectTag = "[D/C]"

local function StoreDisconnectedTeamPlayer(gameRules, client)
	local player = client:GetControllingPlayer()
	--If we kicked already cached player, just assume something might have gone wrong, and dont save again.
	if player and not player.isCached and GetNSLConfigValue("SavePlayerStates") then
		local teamNumber = player:GetTeamNumber()
		if teamNumber == kMarineTeamType or teamNumber == kAlienTeamType then
			--Valid team, player, config opt.  Check gamestate.
			if gameRules:GetGameStarted() then
				--Do things
				--Okay, so we are going to SAVE this player ent.  Then make a fake one to pass for the rest of the code.
				local id = client:GetUserId()
				local name = player:GetName()
				local tempplayer = CreateEntity(Skulk.kMapName, Vector(0, 0, 0), teamNumber)
				NSLDontGenPlayerOnConnect = true
				local newclient = Server.AddVirtualClient() 
				--Fake client to prevent death of retarded amount of NS2 codebase that is reliant on valid clients without ANY checks if not.
				NSLDontGenPlayerOnConnect = false
				player:RemoveSpectators(nil)
				player:SetControllerClient(newclient)
				tempplayer:SetControllerClient(client)
				--Block things
				player.isCached = true
				player:SetName(kDisconnectTag .. name)
				--Player ENT should be disjoined, cache to table.
				NSL_VirtualClients[id] = newclient
				NSL_DisconnectedIDs[name] = id
				NSL_VirtualClientCount = NSL_VirtualClientCount + 1
				--Force Pause
				--Will consume a pause for the team, but will always pause even if out.
				--During crash, team may pause before, so check.
				if not GetIsGamePaused() and (GetNSLConfigValue("PauseOnDisconnect") or NSLPauseDisconnectOverride) then
					TriggerDisconnectNSLPause(name, teamNumber, 1, true)
				end
			end
		end
	end
end

local originalGamerulesOnClientConnect
originalGamerulesOnClientConnect = Class_ReplaceMethod("Gamerules", "OnClientConnect", 
	function(self, client)
		--Already exists, and is cached so maybeh?  Atleast basic safety to ensure only bot clients.
		if NSLDontGenPlayerOnConnect and client:GetIsVirtual() then
			return
		end
		return originalGamerulesOnClientConnect(self, client)
	end
)

function CleanupVirtualClient(client)
	for k, v in pairs(NSL_VirtualClients) do
		if NSL_VirtualClients[k] and NSL_VirtualClients[k] == client then
			NSL_VirtualClients[k] = nil
		end
	end
end

local oldNS2GamerulesOnClientDisconnect = NS2Gamerules.OnClientDisconnect
function NS2Gamerules:OnClientDisconnect(client)
	if GetNSLModEnabled() and client and not client:GetIsVirtual() then
		StoreDisconnectedTeamPlayer(self, client)
	elseif client and client:GetIsVirtual() then
		CleanupVirtualClient(client)
	end
	oldNS2GamerulesOnClientDisconnect(self, client)
end

function CleanupCachedPlayers()
	--Delete ents if still valid
	for k, v in pairs(NSL_VirtualClients) do
		if NSL_VirtualClients[k] then
			Server.DisconnectClient(NSL_VirtualClients[k])
		end
	end
	--Clear ref table
	NSL_DisconnectedIDs = { }
	--Clear this too
	NSL_VirtualClients = { }
	--No virtual clients here dawg
	NSL_VirtualClientCount = 0
end

local oldNS2GamerulesResetGame = NS2Gamerules.ResetGame
function NS2Gamerules:ResetGame()
	oldNS2GamerulesResetGame(self)
	CleanupCachedPlayers()
end

--Hook into this shiz
local oldRagdollMixinOnTag = RagdollMixin.OnTag
function RagdollMixin:OnTag(tagName)
	if not (self.isCached and tagName == "destroy") then
		oldRagdollMixinOnTag(self, tagName)
	end
end

--Block the vanilla bot controller from kicking the bot the moment we add it :<
local oldBotTeamControllerUpdateBotsForTeam = BotTeamController.UpdateBotsForTeam
local oldBotTeamControllerUpdateBots = BotTeamController.UpdateBots

function BotTeamController:UpdateBotsForTeam(teamNumber)
	if GetNSLModEnabled() and GetNSLConfigValue("SavePlayerStates") then
		return
	end
	oldBotTeamControllerUpdateBotsForTeam(self, teamNumber)
end

function BotTeamController:UpdateBots()
	if not GetNSLModEnabled() and GetNSLConfigValue("SavePlayerStates") then
		return
	end
	oldBotTeamControllerUpdateBots(self)
end

function Player:GetDestructionAllowed(destructionAllowedTable)
    destructionAllowedTable.allowed = destructionAllowedTable.allowed and not self.isCached
end

local function CleanupIDTable(ns2ID)
	for k, v in pairs(NSL_DisconnectedIDs) do
		if v == ns2ID then
			NSL_DisconnectedIDs[k] = nil
		end
	end
end

local function RemoveCachedFlag(self)
	self.isCached = false
	return false
end

function MoveClientToStoredPlayer(client, ns2ID)
	--So we found a stored player
	local player = client:GetControllingPlayer()
	local gamerules = GetGamerules()
	local success = false
	local virtualClient = NSL_VirtualClients[ns2ID]
	--Dont want to stick them back into a ragdoll, as funny as it would be :D - anddddd thats now what we do cause its fun :D:D
	if virtualClient and player and gamerules then
		local name = player:GetName()
		local oldplayer = virtualClient:GetControllingPlayer()
		if oldplayer then
			local oldname = string.gsub(oldplayer:GetName(), kDisconnectTag, "")
			-- Make the client ACTUALLY JOIN the team... cause.. lol
			success, player = gamerules:JoinTeam(player, oldplayer:GetTeamNumber(), true)
			if success then
				oldplayer:SetControllerClient(client)
				player:SetControllerClient(virtualClient)
				--Set this flag so they get removed as expected
				player.isCached = true
				if virtualClient then
					Server.DisconnectClient(virtualClient)
				end
				oldplayer:SetName(name)
				--Need to send tech tree to player
				oldplayer.sendTechTreeBase = true
				oldplayer:AddTimedCallback(RemoveCachedFlag, 0.1)
				--oldplayer is actually the 'newplayer' lol.. but its the OLDPlayer entity that was disconnected.. so that.
				Server.SendNetworkMessage(oldplayer, "NSLSystemMessage", {color = GetNSLConfigValue("MessageColor"), message = string.format(" %s Player Restored.", name), header = "NSL: "}, true )
			end
		end
	end
	NSL_VirtualClients[ns2ID] = nil
	NSL_VirtualClientCount = math.max(NSL_VirtualClientCount - 1, 0)
	CleanupIDTable(ns2ID)
	return success
end

local function OnClientConnected(client)
	if client and GetNSLConfigValue("SavePlayerStates") then
		local NS2ID = client:GetUserId()
		if NSL_VirtualClients[NS2ID] then
			--So we found a stored player
			MoveClientToStoredPlayer(client, NS2ID)
		end
	end
end

table.insert(gConnectFunctions, OnClientConnected)

local function OnClientCommandEnablePauseTesting(client)
	if client then
		local NS2ID = client:GetUserId()	
		if GetIsNSLRef(NS2ID) then
			NSLPauseDisconnectOverride = not NSLPauseDisconnectOverride
			ServerAdminPrint(client, "NSL Pause on Disconnect " .. ConditionalValue(NSLPauseDisconnectOverride, "enabled.", "disabled."))
		end
	end
end

Event.Hook("Console_sv_nslpausedisconnect", OnClientCommandEnablePauseTesting)
RegisterNSLHelpMessageForCommand("sv_nslpausedisconnect: Enables automatic pausing on client disconnect.", true)

local function OnClientCommandForceReplacement(client, newPlayer, oldPlayer)
	if client then
		local NS2ID = client:GetUserId()	
		if GetIsNSLRef(NS2ID) then
			local replacePlayer = GetPlayerMatching(newPlayer)
			if replacePlayer then
				local replaceClient = Server.GetOwner(replacePlayer)
				--Found new replacement, find cached player
				local id = tonumber(oldPlayer)
				if NSL_DisconnectedIDs[oldPlayer] then
					--Name
					id = tonumber(NSL_DisconnectedIDs[oldPlayer])
				end
				if replaceClient and id and NSL_VirtualClients[id] then
					--it worked, holy shit
					if MoveClientToStoredPlayer(replaceClient, id) then
						ServerAdminPrint(client, "Set " .. tostring(newPlayer) .. " as replacement for " .. tostring(oldPlayer) .. ".")
					else
						ServerAdminPrint(client, "Something went wrong when caching the player :(.")
					end
				else
					ServerAdminPrint(client, "Couldn't find cached player " .. tostring(oldPlayer) .. ".")
				end
			else
				ServerAdminPrint(client, "Couldn't find replacement player " .. tostring(newPlayer) .. ".")
			end
		end
	end
end

Event.Hook("Console_sv_nslreplaceplayer", OnClientCommandForceReplacement)
RegisterNSLHelpMessageForCommand("sv_nslreplaceplayer: <newPlayer, oldPlayer> Will force different player to take crashed/disconnect players place.", true)

local function OnClientCommandListCachedPlayers(client)
	if client then
		local NS2ID = client:GetUserId()	
		if GetIsNSLRef(NS2ID) then
			ServerAdminPrint(client, "Cached Players listed below.")
			for k, v in pairs(NSL_DisconnectedIDs) do
				ServerAdminPrint(client, string.format("Cached Player - Name - %s, ID - %s", k, v))
			end
		end
	end
end

Event.Hook("Console_sv_nsllistcachedplayers", OnClientCommandListCachedPlayers)
RegisterNSLHelpMessageForCommand("sv_nsllistcachedplayers: Will list currently cached players names and steamIDs, for sv_nslreplaceplayer cmd.", true)

Class_Reload( "Player" )

Event.RemoveHook("VirtualClientMove", OnVirtualClientMove)

local oldOnVirtualClientMove = OnVirtualClientMove
function OnVirtualClientMove(client)
	for k, v in pairs(NSL_VirtualClients) do
		if NSL_VirtualClients[k] and NSL_VirtualClients[k] == client then
			return Move()
		end
	end
	return oldOnVirtualClientMove(client)
end

Event.Hook("VirtualClientMove", OnVirtualClientMove)