-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/ClientModelMixin.lua
-- - Dragon

ClientModelMixin.networkVars = 
{
    serverAnimationSequence   = "compensated integer (-1 to " .. BaseModelMixin.kMaxAnimations .. ")",
}

local function ClientModelMixinOnUpdate(self)
    -- This can still be -1, i guess they init to 0 regardless, so -1 is always a change? meh
    if self.serverAnimationSequence > -1 then
        local state = self.animationState
        self.animationSequence = self.serverAnimationSequence
        AnimationGraphState.SetCurrentAnimation(state, 0, 0, self.animationSequence, 0, 1, 0)
    end
    return false
end

function ClientModelMixin:__initmixin()
    
    PROFILE("ClientModelMixin:__initmixin")
    
    self.limitedModel = true
    self.fullyUpdated = Client or Predict
    
    BaseModelMixin.InitializeFields(self)
    
    if Server then
        self.forceModelUpdateUntilTime = 0
        self.serverAnimationSequence = -1
    else
        -- Client models dont sync, so we need to cheat some anims otherwise stuff repeats the animation every time you enter relevancy
        -- Ideally we would set this during init, but it appears that netvars are not available at this point - so we need to do it before next update ideally
        if self.AddFieldWatcher then
            self:AddFieldWatcher("serverAnimationSequence", ClientModelMixinOnUpdate)
        end
    end

end

if Server then

    local oldClientModelMixinOnUpdate = ClientModelMixin.OnUpdate
    function ClientModelMixin:OnUpdate(_)
        oldClientModelMixinOnUpdate(self)
        self.serverAnimationSequence, _, _, _ = self.animationState:GetCurrentAnimation(0, 0)
    end

end