-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/EnergizeMixin.lua
-- - Dragon

EnergizeMixin = CreateMixin(EnergizeMixin)
EnergizeMixin.type = "Energize"

EnergizeMixin.expectedMixins =
{
    GameEffects = "Required to track energize state",
}

EnergizeMixin.networkVars =
{
    energized = "private boolean"
}

local function UpdateEnergizedState(self)

    local energizeAllowed = not self.GetIsEnergizeAllowed or self:GetIsEnergizeAllowed()
    
    local removeGiver = {}
    for _, giverId in ipairs(self.energizeGivers) do
        
        if not energizeAllowed or self.energizeGiverTime[giverId] + 1 < Shared.GetTime() then
            self.energizeGiverTime[giverId] = nil
            table.insert(removeGiver, giverId)
        end
        
    end
    
    -- removed timed out
    for _, removeId in ipairs(removeGiver) do
        table.removevalue(self.energizeGivers, removeId)
    end
    
    self.energized = #self.energizeGivers > 0
    self:SetGameEffectMask(kGameEffect.Energize, self.energized)
    
    if self.energized then

        local energy = ConditionalValue(self:isa("Player"), kPlayerEnergyPerEnergize, kStructureEnergyPerEnergize)
        self:AddEnergy(energy)

    end

    return self.energized

end

function EnergizeMixin:__initmixin()
    
    PROFILE("EnergizeMixin:__initmixin")
    
    self.energized = false

    if Server then
        
        self.energizeGivers = {}
        self.energizeGiverTime = {}
        self.timeLastEnergizeUpdate = 0
        
    end

end

if Server then

    function EnergizeMixin:Energize(giver)
    
        local energizeAllowed = not self.GetIsEnergizeAllowed or self:GetIsEnergizeAllowed()
        
        if energizeAllowed then
        
            table.insertunique(self.energizeGivers, giver:GetId())
            self.energizeGiverTime[giver:GetId()] = Shared.GetTime()

            if not self.energized then
                self:AddTimedCallback(UpdateEnergizedState, kEnergizeUpdateRate)
            end
        
        end
    
    end

end

EnergizeMixin.OnUpdate = nil
EnergizeMixin.OnProcessMove = nil

function EnergizeMixin:GetEnergized()
    return self.energized
end

-- Maintain compat with original implmentation
function EnergizeMixin:GetEnergizeLevel()
    return self.energized and 1 or 0
end