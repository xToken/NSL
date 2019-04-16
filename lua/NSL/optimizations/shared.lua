-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/shared.lua
-- - Dragon

Shared.Message("Loading NSL Optimizations.")

-- NILS
EffectsMixin.OnProcessMove = nil
EffectsMixin.OnUpdate = nil

ScoringMixin.OnUpdate = nil

CelerityMixin.OnProcessMove = nil

function CelerityMixin:ModifyMaxSpeed(maxSpeedTable)
	local celeritySpeedScalar = GetHasCelerityUpgrade(self) and Clamp(self:GetSpurLevel() / 3, 0, 1) or 0
    local celerityBonus = celeritySpeedScalar * kCelerityAddSpeed
    if self.ModifyCelerityBonus then
        celerityBonus = self:ModifyCelerityBonus( celerityBonus )
    end
    maxSpeedTable.maxSpeed = maxSpeedTable.maxSpeed + celerityBonus
end

-- NETVAR OPTIMIZATIONS
--[[
Shared.LinkClassToMap("AlienSpectator", AlienSpectator.kMapName, { autoSpawnTime = "private time" })

AttackOrderMixin.networkVars =
{
    timeOfLastAttackOrder = "time"
}

CelerityMixin.networkVars =
{
}
--]]