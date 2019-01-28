-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/skinsblocker/server.lua
-- - Dragon

-- This seems stupid, but gender models are also considered 'variants'.  Allow for marines BUT force 'default' variant
function MarineVariantMixin:GetVariantModel()
	if GetNSLConfigValue("UseDefaultSkins") then
		return MarineVariantMixin.kModelNames[ self:GetGenderString() ][ kMarineVariant.green ]
	end
    return MarineVariantMixin.kModelNames[ self:GetGenderString() ][ self.variant ]
end

-- Weapon Skin Update call would be skipped when default skins is enabled
local originalPlayerOnClientUpdated
originalPlayerOnClientUpdated = Class_ReplaceMethod("Player", "OnClientUpdated",
	function(self, client)
		originalPlayerOnClientUpdated(self, client)
		if GetNSLConfigValue("UseDefaultSkins") then
			self:UpdateWeaponSkin(client)
		end
	end
)

function ExoVariantMixin:OnClientUpdated(client)
	Player.OnClientUpdated(self, client)
end

function Alien:GetIgnoreVariantModels()
    return GetNSLConfigValue("UseDefaultSkins")
end

function GameInfo:SetTeamSkin( teamIndex, skinIndex )
	if not GetNSLConfigValue("UseDefaultSkins") then
	    if teamIndex == kTeam1Index then
	        self.team1Skin = skinIndex
	    elseif teamIndex == kTeam2Index then
	        self.team2Skin = skinIndex
	    end
	end
end