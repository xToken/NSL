-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/client.lua
-- - Dragon

-- CRAG
local originalCragOnCreate
originalCragOnCreate = Class_ReplaceMethod("Crag", "OnCreate",
	function(self)
		originalCragOnCreate(self)
		self:AddTimedCallback(Crag.TriggerClientSideHealingEffects, Crag.kHealEffectInterval)
	end
)

function Crag:TriggerClientSideHealingEffects()

	if (self.healWaveActive or self.healingActive) and self:GetIsAlive() then
         
        local localPlayer = Client.GetLocalPlayer()
        local showHeal = not HasMixin(self, "Cloakable") or not self:GetIsCloaked() or not GetAreEnemies(self, localPlayer)

        if showHeal then
        
            if self.healWaveActive then
                self:TriggerEffects("crag_heal_wave")
            elseif self.healingActive then
                self:TriggerEffects("crag_heal")
            end
            
        end
        
    end

    return self:GetIsAlive()

end

function Crag:OnUpdate(deltaTime)

    PROFILE("Crag:OnUpdate")

    ScriptActor.OnUpdate(self, deltaTime)
    
    UpdateAlienStructureMove(self, deltaTime)

end
-- END CRAG

-- HARVESTER
function Harvester:OnUpdateRender()
    
    PROFILE("Harvester:OnUpdateRender")

    local model = self:GetRenderModel()
    if model then
    	if self:GetIsBuilt() and self.glowIntensity < 3 then
    		self.glowIntensity = math.min(3, self.glowIntensity + (Shared.GetTime() - (self.glowIntensityTime and self.glowIntensityTime or Shared.GetTime())))
    		self.glowIntensityTime = Shared.GetTime()
    	end
        model:SetMaterialParameter("glowIntensity", self.glowIntensity)
    end
    
end
-- END HARVESTER

-- GAMEINFO
local function OnUpdateTeamSkins(self, mixin, teamNumber)
    for _, entity in ipairs(GetEntitiesWithMixinForTeam(mixin, teamNumber)) do
        entity.structureVariant = self:GetTeamSkin(teamNumber)    
    end
end

local function OnUpdateTeam1Skins(self)
    OnUpdateTeamSkins(self, "MarineStructureVariant", 1)
    return true
end

local function OnUpdateTeam2Skins(self)
    OnUpdateTeamSkins(self, "AlienStructureVariant", 2)
    return true
end

local originalGameInfoOnCreate
originalGameInfoOnCreate = Class_ReplaceMethod("GameInfo", "OnCreate",
    function(self)
        originalGameInfoOnCreate(self)

        if Client then

            self:AddFieldWatcher("team1Skin", OnUpdateTeam1Skins)
            self:AddFieldWatcher("team2Skin", OnUpdateTeam2Skins)

        end

    end
)
-- END GAMEINFO

-- ARMORY
local originalArmoryOnInitialized
originalArmoryOnInitialized = Class_ReplaceMethod("Armory", "OnInitialized",
    function(self)
        originalArmoryOnInitialized(self)
        self.lastArmoryAnimUpdate = Client.GetTime()
    end
)

local UpdateArmoryAnim = GetNSLUpValue(Armory.OnUpdate, "UpdateArmoryAnim")

function Armory:OnUpdateClientAnims(deltaTime)

    self:UpdateArmoryWarmUp()

    if GetIsUnitActive(self) and self.deployed then

        -- Set pose parameters according to if we're logged in or not
        UpdateArmoryAnim(self, "e", self.loggedInEast, self.timeScannedEast, deltaTime)
        UpdateArmoryAnim(self, "n", self.loggedInNorth, self.timeScannedNorth, deltaTime)
        UpdateArmoryAnim(self, "w", self.loggedInWest, self.timeScannedWest, deltaTime)
        UpdateArmoryAnim(self, "s", self.loggedInSouth, self.timeScannedSouth, deltaTime)

    end

end

Armory.OnUpdate = nil

local originalArmoryOnUpdateRender
originalArmoryOnUpdateRender = Class_ReplaceMethod("Armory", "OnUpdateRender",
    function(self)
        originalArmoryOnUpdateRender(self)
        self:OnUpdateClientAnims(Clamp(Client.GetTime() - self.lastArmoryAnimUpdate, 0, 0.25))
        self.lastArmoryAnimUpdate = Client.GetTime()
    end
)
-- END ARMORY