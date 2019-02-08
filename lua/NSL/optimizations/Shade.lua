-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/Shade.lua
-- - Dragon

if Server then

    -- SHADE
    local originalShadeOnInitialized = Shade.OnInitialized
    function Shade:OnInitialized()
        originalShadeOnInitialized(self)
        InitMixin(self, SleeperMixin)
    end

    function Shade:GetCanSleep()
        return not self.moving and self:GetIsBuilt() and not self:GetHasOrder() and self:GetIsAlive() and not self.isRepositioning
    end

    function Shade:OnOrderGiven(order)
        if order then
            self:WakeUp()
        end
    end
    -- END SHADE

end