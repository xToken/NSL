-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/Crag.lua
-- - Dragon

-- CRAG
if Server then

    local function OnCragHealCallback(self)
    	if GetIsUnitActive(self) then
    		self:PerformHealing()
    		self.healingActive = self:GetIsHealingActive()
            self.healWaveActive = self:GetIsHealWaveActive()
    	end
    	return self:GetIsAlive()
    end

    local originalCragOnCreate = Crag.OnCreate
    function Crag:OnCreate()
		originalCragOnCreate(self)
		self:AddTimedCallback(OnCragHealCallback, Crag.kHealInterval)
	end

    function Crag:GetCanSleep()
        return not self.moving and self:GetIsBuilt() and not self:GetHasOrder() and self:GetIsAlive() and not self.isRepositioning
    end

    function Crag:OnUpdate(deltaTime)

        PROFILE("Crag:OnUpdate")

        ScriptActor.OnUpdate(self, deltaTime)
        
        UpdateAlienStructureMove(self, deltaTime)

    end

    function Crag:OnOrderGiven(order)
        if order then
        	self:WakeUp()
        end
    end

end
-- END CRAG