// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_statesave_server.lua
// - Dragon

Script.Load("lua/nsl_class.lua")
local NSL_DisconnectedPlayers = { }
local NSL_DisconnectedIDs = { }
local NSLPauseDisconnectOverride = false

local function StoreDisconnectedTeamPlayer(self, client)
	local player = client:GetControllingPlayer()
	if player and (GetNSLConfigValue("PauseOnDisconnect") or NSLPauseDisconnectOverride) then
		local teamNumber = player:GetTeamNumber()
		if teamNumber == kMarineTeamType or teamNumber == kAlienTeamType then
			//Valid team, player, config opt.  Check gamestate.
			if self:GetGameStarted() then
				//Do things
				//Okay, so we are going to SAVE this player ent.  Then make a fake one to pass for the rest of the code.
				local id = client:GetUserId()
				local name = player:GetName()
				local tempplayer = CreateEntity(Skulk.kMapName, Vector(0, 0, 0), teamNumber)
				player.client = nil
				player:RemoveSpectators(tempplayer)
				tempplayer:SetControllerClient(client)
				//Just delete this NOW
				if player.playerInfo then
					DestroyEntity(player.playerInfo)
					player.playerInfo = nil
				end
				//Block ragdoll destruction
				player.blockRagdollDestruction = true
				//Player ENT should be disjoined, cache to table.
				NSL_DisconnectedPlayers[id] = player
				NSL_DisconnectedIDs[name] = id
				//Force Pause
				//Will consume a pause for the team, but will always pause even if out.
				//During crash, team may pause before, so check.
				if not GetIsGamePaused() then
					TriggerDisconnectNSLPause(name, teamNumber, 1, true)
				end
			end
		end
	end
end

local oldNS2GamerulesOnClientDisconnect = NS2Gamerules.OnClientDisconnect
function NS2Gamerules:OnClientDisconnect(client)
	StoreDisconnectedTeamPlayer(self, client)
	oldNS2GamerulesOnClientDisconnect(self, client)
end

function CleanupCachedPlayers()
	//Delete ents if still valid
	for k, v in pairs(NSL_DisconnectedPlayers) do
		if NSL_DisconnectedPlayers[k] then
			DestroyEntity(NSL_DisconnectedPlayers[k])
		end
		NSL_DisconnectedPlayers[k] = nil
	end
	//Clear ref table
	NSL_DisconnectedIDs = { }
end

local oldNS2GamerulesResetGame = NS2Gamerules.ResetGame
function NS2Gamerules:ResetGame()
	oldNS2GamerulesResetGame(self)
	CleanupCachedPlayers()
end

//Hook into this shiz
local oldRagdollMixinOnTag= RagdollMixin.OnTag
function RagdollMixin:OnTag(tagName)
	if not self.blockRagdollDestruction then
		oldRagdollMixinOnTag(self, tagName)
	end
end

function Player:GetDestructionAllowed(destructionAllowedTable)
    destructionAllowedTable.allowed = destructionAllowedTable.allowed and not self.blockRagdollDestruction
end

local function CleanupIDTable(ns2ID)
	for k, v in pairs(NSL_DisconnectedIDs) do
		if v == ns2ID then
			NSL_DisconnectedIDs[k] = nil
		end
	end
end

local function RemoveRagdollBlock(self)
	self.blockRagdollDestruction = false
	return false
end

function MoveClientToStoredPlayer(client, ns2ID)
	//So we found a stored player, and we are still paused
	local player = client:GetControllingPlayer()
	local success = false
	local name = player:GetName()
	local newplayer = NSL_DisconnectedPlayers[ns2ID]
	//Dont want to stick them back into a ragdoll, as funny as it would be :D - anddddd thats now what we do cause its fun :D:D
	if newplayer then
		player.client = nil
		newplayer:SetControllerClient(client)
		newplayer:SetPlayerInfo(player.playerInfo)
		player.playerInfo = nil
		DestroyEntity(player)
		newplayer:SetName(name)
		//Need to send tech tree to player
		newplayer.sendTechTreeBase = true
		newplayer:AddTimedCallback(RemoveRagdollBlock, 0.1)
		success = true
	end
	NSL_DisconnectedPlayers[ns2ID] = nil
	CleanupIDTable(ns2ID)
	return success
end

local function OnClientConnected(client)
	if client and (GetNSLConfigValue("PauseOnDisconnect") or NSLPauseDisconnectOverride) then
		local NS2ID = client:GetUserId()
		if NSL_DisconnectedPlayers[NS2ID] and GetIsGamePaused() then
			//So we found a stored player, and we are still paused
			MoveClientToStoredPlayer(client, NS2ID)
		end
	end
end

table.insert(gConnectFunctions, OnClientConnected)

local function OnClientCommandEnablePauseTesting(client, team)
	if client then
		local NS2ID = client:GetUserId()	
		if GetIsNSLRef(NS2ID) then
			NSLPauseDisconnectOverride = not NSLPauseDisconnectOverride
			ServerAdminPrint(client, "NSL Pause on Disconnect " .. ConditionalValue(NSLPauseDisconnectOverride, "enabled.", "disabled."))
		end
	end
end

Event.Hook("Console_sv_nslpausedisconnect", OnClientCommandEnablePauseTesting)

local function OnClientCommandForceReplacement(client, newPlayer, oldPlayer)
	if client then
		local NS2ID = client:GetUserId()	
		if GetIsNSLRef(NS2ID) then
			local replacePlayer = GetPlayerMatching(newPlayer)
			if replacePlayer then
				local replaceClient = Server.GetOwner(replacePlayer)
				//Found new replacement, find cached player
				local id = tonumber(oldPlayer)
				if NSL_DisconnectedIDs[oldPlayer] then
					//Name
					id = tonumber(NSL_DisconnectedIDs[oldPlayer])
				end
				if replaceClient and id and NSL_DisconnectedPlayers[id] then
					//it worked, holy shit
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

local function OnClientCommandListCachedPlayers(client, team)
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

Class_Reload( "Player" )