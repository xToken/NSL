-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/playerdata/client.lua
-- - Dragon

function NSLGetPlayerInfoEntityForPlayer(clientId)
    for _, pie in ientitylist(Shared.GetEntitiesWithClassname("PlayerInfoEntity")) do
    	if clientId == pie.clientId then
    		return pie
    	end
    end
    return nil
end

local function OnNSLPlayerInfoMessage(message)
	local msg = ReturnNSLMessage("NSL_PLAYER_INFO_MESSAGE")
	local pie = NSLGetPlayerInfoEntityForPlayer(message.clientId)
	if pie then
		local player = Shared.GetEntity(pie.playerId)
		local handicap = (1 - (player and player:GetHandicap() or 1)) * 100
		local ns2id = pie.steamId
		local steamid =  "0:" .. (ns2id % 2) .. ":" .. math.floor(ns2id / 2)
		if pie:GetNSLID() == 0 then
			-- No league data/invalid data
			msg = string.format(ReturnNSLMessage("NSL_PLAYER_INFO_MESSAGE_INVALID"), pie.playerName, steamid, ns2id, message.gameId, handicap)
		else
			-- we have a user ID
			msg = string.format(msg, pie.playerName, steamid, ns2id, message.gameId, handicap, pie:GetNSLName(), pie:GetNSLTeam(), pie:GetNSLID())
		end
	    Shared.Message(msg)
	end
end
Client.HookNetworkMessage("NSLPlayerInfoMessage", OnNSLPlayerInfoMessage)