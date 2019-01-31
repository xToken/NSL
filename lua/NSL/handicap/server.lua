-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/handicap/server.lua
-- - Dragon

function Player:GetName(realName)
	if self:GetHandicap() < 1 and not realName then
		return string.format("%s (%.0f%%)", self.name, ( 1 - self:GetHandicap() ) * 100)
	end
	return self.name
end

local originalNS2PlayerCopyPlayerDataFrom
originalNS2PlayerCopyPlayerDataFrom = Class_ReplaceMethod("Player", "CopyPlayerDataFrom", 
	function(self, player)
		originalNS2PlayerCopyPlayerDataFrom(self, player)
		self.handicap = player.handicap
	end
)

local function OnClientHandicap( client, value )
	if not client or not value then return end
	value = tonumber(value)
	if value == nil or value > 1 or value < 0.1 then return end
	
	local player = client:GetControllingPlayer()
	if not player then return end
	
	player:SetHandicap(value)
	
	SendClientServerAdminMessage(client, "NSL_HANDICAP_SET", player:GetName(true), ( 1 - player:GetHandicap() ) * 100 )
end

RegisterNSLConsoleCommand("sv_nslhandicap", OnClientHandicap, "SV_NSLHANDICAP", true)