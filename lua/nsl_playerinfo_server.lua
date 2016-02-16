-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\nsl_playerinfo_server.lua
-- - Dragon

local function UpdateFromNSLPlayerData(player, nsldata)
	if player then
		if player.playerInfo then
			player.playerInfo:SetupNSLData(nsldata) 
		end
	end
end

table.insert(gPlayerDataUpdatedFunctions, UpdateFromNSLPlayerData)