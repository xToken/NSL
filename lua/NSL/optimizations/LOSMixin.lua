-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/LOSMixin.lua
-- - Dragon

if Server then

    local UpdateLOS = GetNSLUpValue(LOSMixin.__initmixin, "UpdateLOS")
    local SharedUpdate = GetNSLUpValue(LOSMixin.OnUpdate, "SharedUpdate")
    local MarkNearbyDirty = GetNSLUpValue(SharedUpdate, "MarkNearbyDirty")
    local UpdateSelfSighted = GetNSLUpValue(SharedUpdate, "UpdateSelfSighted")
    local LookForEnemies = GetNSLUpValue(SharedUpdate, "LookForEnemies")
    local kLOSTimeout = GetNSLUpValue(SharedUpdate, "kLOSTimeout")

    function LOSMixin:__initmixin()
        
        PROFILE("LOSMixin:__initmixin")
        
        if Server then
        
            self.sighted = false
            self.lastTimeLookedForEnemies = 0
            self.updateLOS = true
            self.timeLastLOSUpdate = 0
            self.dirtyLOS = true
            self.timeLastLOSDirty = 0
            self.prevLOSorigin = Vector(0,0,0)
        
            self:SetIsSighted(false)
            UpdateLOS(self)
            self.oldSighted = true
            self.lastViewerId = Entity.invalidId

            if self.AddTimedCallback then
                self:AddTimedCallback(LOSMixin.PeriodicUpdate, 0.2)
            end
            
        end
        
    end

    function LOSMixin:PeriodicUpdate()
        self:SharedUpdate()
        return self:GetIsAlive()
    end

    function LOSMixin:SharedUpdate()

        PROFILE("LOSMixin:SharedUpdate")
        
        local now = Shared.GetTime()
        if self.dirtyLOS and self.timeLastLOSDirty + 0.2 < now then
        
            MarkNearbyDirty(self)
            self.dirtyLOS = false
            self.timeLastLOSDirty = now
            
        end
        
        if self.updateLOS and self.timeLastLOSUpdate + 0.2 < now then
        
            UpdateSelfSighted(self)
            LookForEnemies(self)
            
            self.updateLOS = false
            self.timeLastLOSUpdate = now
            
        end
        
        if self.oldSighted ~= self.sighted then
        
            if self.sighted then
            
                UpdateLOS(self)
                self.timeUpdateLOS = nil
                
            else
                self.timeUpdateLOS = Shared.GetTime() + kLOSTimeout
            end
            
            self.oldSighted = self.sighted
            
        end
        
        if self.timeUpdateLOS and self.timeUpdateLOS < Shared.GetTime() then
        
            UpdateLOS(self)
            self.timeUpdateLOS = nil
            
        end

        return false
        
    end

    LOSMixin.OnUpdate = nil
    LOSMixin.OnProcessMove = nil

    function LOSMixin:SetIsSighted(sighted, viewer)

        PROFILE("LOSMixin:SetIsSighted")
        
        self.sighted = sighted
        
        if viewer then
        
            if not HasMixin(viewer, "LOS") then
                error(string.format("%s: %s added as a viewer without having LOS mixin", ToString(self), ToString(viewer)))
            end
            
            self.lastViewerId = viewer:GetId()
            
        end

        -- Run update immediately after
        if self.AddTimedCallback then
            self:AddTimedCallback(LOSMixin.SharedUpdate, 0)
        end
        
    end

end