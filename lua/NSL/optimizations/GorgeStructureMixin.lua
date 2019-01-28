-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/GorgeStructureMixin.lua
-- - Dragon

GorgeStructureMixin = CreateMixin(GorgeStructureMixin)
GorgeStructureMixin.type = "GorgeStructure"

GorgeStructureMixin.kStarveDelay = 60
GorgeStructureMixin.kDieImmediatelyOnStarve = true

GorgeStructureMixin.networkVars =
{
}

GorgeStructureMixin.expectedMixins =
{
    Owner = "For tracking gorge owner."
}

GorgeStructureMixin.expectedCallbacks = 
{
}

GorgeStructureMixin.optionalCallbacks = 
{
}

function GorgeStructureMixin:__initmixin()
    
    PROFILE("GorgeStructureMixin:__initmixin")
    
    assert(Server)
    self.timeStarveBegin = 0
    self.hasGorgeOwner = true
    self.isStarving = false
    
end

function GorgeStructureMixin:OnStarve()
end

function GorgeStructureMixin:OnStarveEnd()
end

function GorgeStructureMixin:SetOwner(owner)

    local hasGorgeOwner = owner and ( owner:isa("Gorge") or (owner:isa("Commander") and owner.previousMapName == Gorge.kMapName) )
    
    if hasGorgeOwner ~= self.hasGorgeOwner then
    
        self.hasGorgeOwner = hasGorgeOwner
    
        if self.hasGorgeOwner then
            self:OnStarveEnd()
        else
            self:OnStarve()
            self.timeStarveBegin = Shared.GetTime()
            self:AddTimedCallback(GorgeStructureMixin.OnStarveTimeUp, GorgeStructureMixin.kStarveDelay)
        end
    
    end
    
end

function GorgeStructureMixin:GetIsStarving()
    return self.isStarving
end

function GorgeStructureMixin:OnStarveTimeUp()
    -- Check the time, if we gorged again after this started, but then died again.. we will wait for next callback.
    if not self.hasGorgeOwner and GorgeStructureMixin.kDieImmediatelyOnStarve and self.timeStarveBegin + GorgeStructureMixin.kStarveDelay < Shared.GetTime() then
        -- time is up, time to die
        self:Kill()
    end
    return false
end

GorgeStructureMixin.OnUpdate = nil
GorgeStructureMixin.OnProcessMove = nil