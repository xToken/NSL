// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_handicap_shared.lua
// - Dragon

local originalNS2PlayerOnCreate
originalNS2PlayerOnCreate = Class_ReplaceMethod("Player", "OnCreate", 
	function(self)
		originalNS2PlayerOnCreate(self)
		self.handicap = 1
	end
)

function Player:SetHandicap(value)
    self.handicap = Clamp(value, 0.1, 1)
end

function Player:GetHandicap()
    return self.handicap
end

if Server then

	function Player:GetName(realName)
		if self:GetHandicap() < 1 and not realName then
			return string.format("%s (%.0f%%)", self.name, ( 1 - self:GetHandicap() ) * 100)
		end
		return self.name
	end

end

local origDamageMixinDoDamage = DamageMixin.DoDamage
function DamageMixin:DoDamage( damage, ... )
	
	local attacker
	
    if self:isa("Player") then
        attacker = self
    else

        if self:GetParent() and self:GetParent():isa("Player") then
            attacker = self:GetParent()
        elseif HasMixin(self, "Owner") and self:GetOwner() and self:GetOwner():isa("Player") then
            attacker = self:GetOwner()
        end  

    end
	
	if attacker:isa("Player") then
		damage = damage * attacker:GetHandicap()
	end

	return origDamageMixinDoDamage( self, damage, ... ) 
end

local function OnClientHandicap( client, value )
	if not client or not value then return end
	value = tonumber(value)
	if value == nil or value > 1 or value < 0.1 then return end
	
	local player = client:GetControllingPlayer()
	if not player then return end
	
	player:SetHandicap(value)
	
	ServerAdminPrint(client, string.format("%s set handicap to (%.0f%%)", player:GetName(true), ( 1 - player:GetHandicap() ) * 100 ))
end

Event.Hook("Console_sv_nslhandicap", OnClientHandicap)

Class_Reload( "Player", {handicap = "float (0 to 1 by 0.01)"} )