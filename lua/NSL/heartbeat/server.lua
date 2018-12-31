-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/heartbeat/server.lua
-- - Dragon

local kHeartbeatUpdateRate = 1
local lastHeartbeatUpdate = 60
local kClientHeartbeatIds = { }
local kClientHeartbeatCache = { }
local kHeartbeatWarn = 8
local kHeartbeatCritical = 12
local kHeartbeatDisconnect = 20

local function UpdateHeartbeatStates(deltatime)
	if GetNSLConfigValue("HeartbeatRequired") then
		if lastHeartbeatUpdate + kHeartbeatUpdateRate < Shared.GetTime(true) then
			for i = #kClientHeartbeatIds, 1, -1 do
				local id = kClientHeartbeatIds[i]
				local client = Server.GetClientById(id)
				if not client then
					table.remove(kClientHeartbeatIds, i)
					kClientHeartbeatCache[id] = nil
				elseif kClientHeartbeatCache[id].override == false then
					if kClientHeartbeatCache[id].lastTime + kHeartbeatWarn < Shared.GetTime(true) and kClientHeartbeatCache[id].warn == false then
						SendClientMessage(client, string.format(GetNSLMessage("HeartbeatWarn"), kHeartbeatWarn), true)
						kClientHeartbeatCache[id].warn = true
					elseif kClientHeartbeatCache[id].lastTime + kHeartbeatCritical < Shared.GetTime(true) and kClientHeartbeatCache[id].critical == false then
						SendClientMessage(client, string.format(GetNSLMessage("HeartbeatCritical"), kHeartbeatCritical, kHeartbeatDisconnect - kHeartbeatCritical), true)
						kClientHeartbeatCache[id].critical = true
					elseif kClientHeartbeatCache[id].lastTime + kHeartbeatDisconnect < Shared.GetTime(true) and kClientHeartbeatCache[id].disconnect == false then
						Server.DisconnectClient(client, string.format("Heartbeat not recieved in %s seconds.", kHeartbeatDisconnect))
						Shared.Message("Client ID " .. id .. " disconnected for missing heartbeat response for " .. kHeartbeatDisconnect .. " seconds.")
						table.remove(kClientHeartbeatIds, i)
						kClientHeartbeatCache[id] = nil
					end
				end
			end
			lastHeartbeatUpdate = Shared.GetTime(true)
		end
	end
end

Event.Hook("UpdateServer", UpdateHeartbeatStates)

local function CreateHeartbeatTable(id)
	table.insert(kClientHeartbeatIds, id)
	kClientHeartbeatCache[id] = { lastTime = 0, warn = false, critical = false, disconnect = false, override = false }
end

local function OnRecievedHeartbeat(client)
	if client then
		local id = client:GetId()
		if not kClientHeartbeatCache[id] then
			CreateHeartbeatTable(id)
		end
		kClientHeartbeatCache[id].lastTime = Shared.GetTime(true)
		kClientHeartbeatCache[id].warn = false
		kClientHeartbeatCache[id].critical = false
		kClientHeartbeatCache[id].disconnect = false
	end
	
end

Server.HookNetworkMessage("NSLHeartbeat", OnRecievedHeartbeat)

local function OnCommandOverrideHeartbeat(client)
	if client then
		local id = client:GetId()
		if not kClientHeartbeatCache[id] then
			CreateHeartbeatTable(id)
		end
		kClientHeartbeatCache[id].override = true
		SendClientMessage(client, GetNSLMessage("HeartbeatOverride"), true)
	end
end

Event.Hook("Console_heartbeat", OnCommandOverrideHeartbeat)
RegisterNSLHelpMessageForCommand("heartbeat: Disables heartbeat requirement for your client.  Only use if having connection problems!", false)

local function SetupServerConfig(config)
	if config == "all" or config == "league" then
		local gameInfo = GetGameInfoEntity()
		if gameInfo then
			gameInfo:SetHeartbeatRequired(GetNSLConfigValue("HeartbeatRequired"))
		end
	end
end

table.insert(gConfigLoadedFunctions, SetupServerConfig)

local function RemoveDisconnectedClient(client)
	if client then
		local id = client:GetId()
		table.removevalue(kClientHeartbeatIds, id)
		kClientHeartbeatCache[id] = nil
	end
end

table.insert(gDisconnectFunctions, RemoveDisconnectedClient)