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

-- SOUND EFFECTS
--[[
local function DestroySoundEffect(self)
    
    if self.soundEffectInstance then
    
        Client.DestroySoundEffect(self.soundEffectInstance)
        self.soundEffectInstance = nil
        
    end
    
end

local originalSoundEffectOnCreate
originalSoundEffectOnCreate = Class_ReplaceMethod("SoundEffect", "OnCreate",
    function(self)
        originalSoundEffectOnCreate(self)
        self:SetUpdates(false)
        self:AddFieldWatcher("assetIndex", SoundEffect.UpdateClientPlaybackState)
        self:AddFieldWatcher("playing", SoundEffect.UpdateClientPlaybackState)
        self:AddFieldWatcher("startTime", SoundEffect.UpdateClientPlaybackState)
        self:AddFieldWatcher("positional", SoundEffect.UpdateClientPlaybackState)
        self:AddFieldWatcher("volume", SoundEffect.UpdateClientPlaybackState)
    end
)

function SoundEffect:UpdateClientPlaybackEffects()

    if self.assetIndex ~= 0 then

        if self.clientAssetIndex ~= self.assetIndex then

            DestroySoundEffect(self)
    
            if self.assetIndex ~= 0 then
            
                self.soundEffectInstance = Client.CreateSoundEffect(self.assetIndex)
                self.soundEffectInstance:SetParent(self:GetId())
                
            end

            self.clientAssetIndex = self.assetIndex

        end

        if self.soundEffectInstance then
    
            if self.clientPlaying ~= self.playing or self.clientStartTime ~= self.startTime then
            
                self.clientPlaying = self.playing
                self.clientStartTime = self.startTime
                
                if self.playing then
                
                    self.soundEffectInstance:Start()
                    
                    if self.clientSetParameters then
                    
                        for c = 1, #self.clientSetParameters do
                        
                            local param = self.clientSetParameters[c]
                            self.soundEffectInstance:SetParameter(param.name, param.value, param.speed)
                            
                        end
                        self.clientSetParameters = nil
                        
                    end
                    
                else
                    self.soundEffectInstance:Stop()
                end
                
            end

            if self.clientVolume ~= self.volume then
                self.soundEffectInstance:SetVolume(self.volume)
                self.clientVolume = self.volume
            end

            if self.clientPositional ~= self.positional then
        
                self.soundEffectInstance:SetPositional(self.positional)
                self.clientPositional = self.positional
                
            end

        end

    end

end

function SoundEffect:UpdateClientPlaybackState()

    if self.predictorId ~= Entity.invalidId then

        -- If we are the predictor, we already know of this sound - dont play, now or ever
        local predictor = Shared.GetEntity(self.predictorId)
        if Client.GetLocalPlayer() == predictor and Client.GetIsControllingPlayer() then
            return false
        end
        
    end

    -- Update playback this tick - multiple fieldwatchers may trigger at the same time, dont want to update the sfx many times.
    -- Fieldwatchers trigger before OnUpdate, so we just update for 1 tick.
    self:SetUpdates(true)

    return true

end

function SoundEffect:OnUpdate()
    self:UpdateClientPlaybackEffects()
    self:SetUpdates(false)
end

-- Ideally these are no longer called?
function SoundEffect:OnProcessSpectate()
end

function SoundEffect:OnProcessMove()
end
-- END SOUND EFFECTS
--]]
Shared.Message("NS2Opti loaded!")