-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/handicap/shared.lua
-- - Dragon

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
	
	--Attacker might be nil... duhhhhhh
	if attacker and attacker:isa("Player") then
		damage = damage * attacker:GetHandicap()
	end

	return origDamageMixinDoDamage( self, damage, ... ) 
end

Class_Reload( "Player", {handicap = "float (0 to 1 by 0.01)"} )