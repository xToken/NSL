-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/Shift.lua
-- - Dragon

if Server then

    -- SHIFT
    local UpdateShiftButtons = debug.getupvaluex(Shift.OnUpdate, "UpdateShiftButtons")
    if UpdateShiftButtons then
        local kEchoCooldown = 1

        local function OnShiftButtonsCallback(self)
            UpdateShiftButtons(self)
            self.echoActive = self.timeLastEcho + kEchoCooldown > Shared.GetTime()
            return self:GetIsAlive()
        end

        local originalShiftOnCreate = Shift.OnCreate
        function Shift:OnCreate()
            originalShiftOnCreate(self)
            self:AddTimedCallback(OnShiftButtonsCallback, 2)
        end

        local originalShiftOnInitialized = Shift.OnInitialized
        function Shift:OnInitialized()
            originalShiftOnInitialized(self)
            InitMixin(self, SleeperMixin)
        end
    end

    function Shift:GetCanSleep()
        return not self.moving and self:GetIsBuilt() and not self:GetHasOrder() and self:GetIsAlive() and not self.isRepositioning
    end

    function Shift:OnUpdate(deltaTime)

        PROFILE("Shift:OnUpdate")

        ScriptActor.OnUpdate(self, deltaTime)
        
        UpdateAlienStructureMove(self, deltaTime)

    end

    function Shift:OnOrderGiven(order)
        if order then
            self:WakeUp()
        end
    end
    -- END SHIFT

end