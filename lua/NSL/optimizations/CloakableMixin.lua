-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/CloakableMixin.lua
-- - Dragon

local kCloakUpdateRate = 0.1
local UpdateCloakState = GetNSLUpValue(CloakableMixin.OnUpdate, "UpdateCloakState")

function CloakableMixin:__initmixin()
    
    PROFILE("CloakableMixin:__initmixin")
    
    if Server then
        self.cloakingDesired = false
        self.fullyCloaked = false
    end
    
    self.desiredCloakFraction = 0
    self.timeCloaked = 0
    self.timeUncloaked = 0    
    
    -- when entity is created on client consider fully cloaked, so units wont show up for a short moment when going through a phasegate for example
    self.cloakFraction = self.fullyCloaked and 1 or 0
    self.speedScalar = 0

    self:AddTimedCallback(CloakableMixin.OnTimedUpdate, kCloakUpdateRate)
    
end

function CloakableMixin:OnTimedUpdate(deltaTime)
    UpdateCloakState(self, deltaTime)
    return self:GetIsAlive()
end

-- Support for CompMod S15
function CloakableMixin:OnUpdate(deltaTime)
    if false then
        UpdateCloakState(self, deltaTime)
    end
end

-- CloakableMixin.OnUpdate = nil
CloakableMixin.OnProcessMove = nil
CloakableMixin.OnProcessSpectate = nil