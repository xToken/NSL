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
local kHeartbeatEventRegistered = false

local function UpdateHeartbeatStates(deltatime)
	if lastHeartbeatUpdate + kHeartbeatUpdateRate < Shared.GetTime(true) then
		for i = #kClientHeartbeatIds, 1, -1 do
			local id = kClientHeartbeatIds[i]
			local client = Server.GetClientById(id)
			if not client then
				table.remove(kClientHeartbeatIds, i)
				kClientHeartbeatCache[id] = nil
			elseif kClientHeartbeatCache[id].override == false and not client:GetIsVirtual() then
				if kClientHeartbeatCache[id].lastTime + kHeartbeatWarn < Shared.GetTime(true) and kClientHeartbeatCache[id].warn == false then
					SendClientMessage(client, "NSL_HEARTBEAT_WARN", true, kHeartbeatWarn)
					kClientHeartbeatCache[id].warn = true
				elseif kClientHeartbeatCache[id].lastTime + kHeartbeatCritical < Shared.GetTime(true) and kClientHeartbeatCache[id].critical == false then
					SendClientMessage(client, "NSL_HEARTBEAT_CRITICAL", true, kHeartbeatCritical, kHeartbeatDisconnect - kHeartbeatCritical)
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
		SendClientMessage(client, "NSL_HEARTBEAT_OVERRIDE", true)
	end
end

RegisterNSLConsoleCommand("heartbeat", OnCommandOverrideHeartbeat, "CMD_HEARTBEAT", true)

local function SetupServerConfig(config)
	if (config == "complete" or config == "reload") and GetNSLModEnabled() then
		local gameInfo = GetGameInfoEntity()
		if gameInfo then
			gameInfo:SetHeartbeatRequired(GetNSLConfigValue("HeartbeatRequired"))
		end
		if not kHeartbeatEventRegistered then
			Event.Hook("UpdateServer", UpdateHeartbeatStates)
			kHeartbeatEventRegistered = true
		end
	elseif kHeartbeatEventRegistered then
		Event.RemoveHook("UpdateServer", UpdateHeartbeatStates)
		kHeartbeatEventRegistered = false
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