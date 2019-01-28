-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/StormCloudMixin.lua
-- - Dragon

StormCloudMixin = CreateMixin( StormCloudMixin )
StormCloudMixin.type = "Storm"

kStormCloudSpeed = 1.8

StormCloudMixin.networkVars =
{
    stormCloudSpeed = "private boolean",
}

function StormCloudMixin:__initmixin()
    
    PROFILE("StormCloudMixin:__initmixin")
    
    self.timeUntilStormCloud = 0
    self.stormCloudSpeed = false
    
end

function StormCloudMixin:ModifyMaxSpeed(maxSpeedTable)

    if self.stormCloudSpeed then
        maxSpeedTable.maxSpeed = maxSpeedTable.maxSpeed + kStormCloudSpeed
    end
    
end

if Server then

    function StormCloudMixin:CheckEndStormCloudBoost()

        self.stormCloudSpeed = self.timeUntilStormCloud > Shared.GetTime()
        return false
        
    end

    function StormCloudMixin:SetSpeedBoostDuration(duration)
        
        self.timeUntilStormCloud = Shared.GetTime() + duration
        self.stormCloudSpeed = true

        self:AddTimedCallback(StormCloudMixin.CheckEndStormCloudBoost, duration)
        
    end

    StormCloudMixin.OnProcessMove = nil
    StormCloudMixin.OnUpdate = nil 
    
end