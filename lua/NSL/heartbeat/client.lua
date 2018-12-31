-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/heartbeat/client.lua
-- - Dragon

local kLastHeartbeatTime = 0
local kHeartbeatRate = 2.5
local gameInfo

local function OnUpdateClientHeartbeat(deltaTime)

	PROFILE("OnUpdateClientHeartbeat")
	
	if not gameInfo then
		gameInfo = GetGameInfoEntity()
	elseif gameInfo:GetHeartbeatRequired() and kLastHeartbeatTime + kHeartbeatRate < Shared.GetTime(true) then
		Client.SendNetworkMessage("NSLHeartbeat", { }, true)
		kLastHeartbeatTime = Shared.GetTime(true)
	end

end

Event.Hook("UpdateClient", OnUpdateClientHeartbeat)