-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/server.lua
-- - Dragon

Script.Load("lua/NSL/optimizations/CloakableMixin.lua")
Script.Load("lua/NSL/optimizations/LOSMixin.lua")
Script.Load("lua/NSL/optimizations/RepositioningMixin.lua")

local InternalSleep = GetNSLUpValue(SleeperMixin.CheckAll, "InternalSleep")
local InternalWakeUp = GetNSLUpValue(SleeperMixin.CheckAll, "InternalWakeUp")
local InternalGetCanSleep = GetNSLUpValue(SleeperOnUpdateServer, "InternalGetCanSleep")

Event.RemoveHook("UpdateServer", SleeperOnUpdateServer)

function SleeperOnUpdateServer(deltaTime)

    PROFILE("SleeperMixin:OnUpdateServer")

    SleeperMixin.CheckDirtyTable()

    if SleeperMixin.timeLastCheckAll + 2 < Shared.GetTime() then
        SleeperMixin.CheckAll()
        SleeperMixin.timeLastCheckAll = Shared.GetTime()
    end
    
end

Event.Hook("UpdateServer", SleeperOnUpdateServer)

-- DEATH TRIGGER
local GetDamageOverTimeIsEnabled = GetNSLUpValue(DeathTrigger.OnInitialized, "GetDamageOverTimeIsEnabled")

local originalDeathTriggerOnInitialized
originalDeathTriggerOnInitialized = Class_ReplaceMethod("DeathTrigger", "OnInitialized",
	function(self)
		originalDeathTriggerOnInitialized(self)
		InitMixin(self, SleeperMixin)
	end
)

function DeathTrigger:GetCanSleep()
	return not GetDamageOverTimeIsEnabled(self) or #self.insideTriggerEntities == 0
end

local originalDeathTriggerOnTriggerEntered
originalDeathTriggerOnTriggerEntered = Class_ReplaceMethod("DeathTrigger", "OnTriggerEntered",
	function(self, enterEnt, triggerEnt)
		originalDeathTriggerOnTriggerEntered(self, enterEnt, triggerEnt)
		self:WakeUp()
	end
)
-- END DEATH TRIGGER

-- CRAG
local function OnCragHealCallback(self)
	if GetIsUnitActive(self) then
		self:PerformHealing()
		self.healingActive = self:GetIsHealingActive()
        self.healWaveActive = self:GetIsHealWaveActive()
	end
	return self:GetIsAlive()
end

local originalCragOnCreate
originalCragOnCreate = Class_ReplaceMethod("Crag", "OnCreate",
	function(self)
		originalCragOnCreate(self)
		self:AddTimedCallback(OnCragHealCallback, Crag.kHealInterval)
	end
)

function Crag:GetCanSleep()
    return not self.moving and self:GetIsBuilt() and not self:GetHasOrder() and self:GetIsAlive() and not self.isRepositioning
end

function Crag:OnUpdate(deltaTime)

    PROFILE("Crag:OnUpdate")

    ScriptActor.OnUpdate(self, deltaTime)
    
    UpdateAlienStructureMove(self, deltaTime)

end

function Crag:OnOrderGiven(order)
    if order and order:GetType() == kTechId.Move then
    	self:WakeUp()
    end
end
-- END CRAG

-- SHADE
local originalShadeOnInitialized
originalShadeOnInitialized = Class_ReplaceMethod("Shade", "OnInitialized",
	function(self)
		originalShadeOnInitialized(self)
		InitMixin(self, SleeperMixin)
	end
)

function Shade:GetCanSleep()
    return not self.moving and self:GetIsBuilt() and not self:GetHasOrder() and self:GetIsAlive() and not self.isRepositioning
end

function Shade:OnOrderGiven(order)
    if order and order:GetType() == kTechId.Move then
    	self:WakeUp()
    end
end
-- END SHADE

-- SHIFT
local UpdateShiftButtons = GetNSLUpValue(Shift.OnUpdate, "UpdateShiftButtons")
local kEchoCooldown = 1

local function OnShiftButtonsCallback(self)
	UpdateShiftButtons(self)
	self.echoActive = self.timeLastEcho + kEchoCooldown > Shared.GetTime()
	return self:GetIsAlive()
end

local originalShiftOnCreate
originalShiftOnCreate = Class_ReplaceMethod("Shift", "OnCreate",
	function(self)
		originalShiftOnCreate(self)
        InitMixin(self, SleeperMixin)
		self:AddTimedCallback(OnShiftButtonsCallback, 2)
	end
)

function Shift:GetCanSleep()
    return not self.moving and self:GetIsBuilt() and not self:GetHasOrder() and self:GetIsAlive() and not self.isRepositioning
end

function Shift:OnUpdate(deltaTime)

    PROFILE("Shift:OnUpdate")

    ScriptActor.OnUpdate(self, deltaTime)
    
    UpdateAlienStructureMove(self, deltaTime)

end

function Shift:OnOrderGiven(order)
    if order and order:GetType() == kTechId.Move then
    	self:WakeUp()
    end
end
-- END SHIFT

-- RESOURCE TOWERS
local function OnCollectResourcesCallback(self)
	if self:GetIsCollecting() then
		self:CollectResources()
	end
	return self:GetIsAlive()
end

local originalResourceTowerOnCreate
originalResourceTowerOnCreate = Class_ReplaceMethod("ResourceTower", "OnCreate",
	function(self)
		originalResourceTowerOnCreate(self)
		self:AddTimedCallback(OnCollectResourcesCallback, kResourceTowerResourceInterval)
	end
)

local originalResourceTowerGetCanSleep
originalResourceTowerGetCanSleep = Class_ReplaceMethod("ResourceTower", "GetCanSleep",
    function(self)
        return self:GetIsBuilt()
    end
)

local originalResourceTowerOnUpdate
originalResourceTowerOnUpdate = Class_ReplaceMethod("ResourceTower", "OnUpdate",
    function(self, deltaTime)
        ScriptActor.OnUpdate(self, deltaTime)
    end
)
-- END RESOURCE TOWERS

-- ARC
function ARC:GetCanSleep()
    return self.mode == ARC.kMode.Stationary and not self:GetHasPossibleTarget() and not self.isRepositioning
end

function ARC:GetHasPossibleTarget()
    return self.targetSelector.possibleTargets == true
end

local originalARCOnOrderGiven
originalARCOnOrderGiven = Class_ReplaceMethod("ARC", "OnOrderGiven",
	function(self, order)
		originalARCOnOrderGiven(self, order)
		self:WakeUp()
	end
)
-- END ARC

-- CYST
function Cyst:GetCanSleep()
    return self:GetIsActuallyConnected() and self:GetIsAlive() and self:GetIsBuilt()
end

function Cyst:OnEntityChange(entityId, newEntityId)
    
    if self.parentId == entityId then
        self.parentId = newEntityId or Entity.invalidId
        if self.parentId == Entity.invalidId then
        	-- Wakeup if parent is gone
        	self:WakeUp()
        end
    end

end
-- END CYST

-- DRIFTER
local kDetectInterval = 0.5
local kDrifterSelfOrderTime = 2

local ScanForNearbyEnemy = GetNSLUpValue(Drifter.OnUpdate, "ScanForNearbyEnemy")
local UpdateTasks = GetNSLUpValue(Drifter.OnUpdate, "UpdateTasks")
local FindTask = GetNSLUpValue(UpdateTasks, "FindTask")
local kDrifterSelfOrderRange = GetNSLUpValue(FindTask, "kDrifterSelfOrderRange")

local function FindTask2(self)
    if not self:GetCurrentOrder() then
        FindTask(self)
    end
    return self:GetIsAlive()
end

local function ScanForNearbyEnemy2(self)
    if self:GetIsCloaked() then
        ScanForNearbyEnemy(self)
    end
    return self:GetIsAlive()
end

local originalDrifterOnCreate
originalDrifterOnCreate = Class_ReplaceMethod("Drifter", "OnCreate",
    function(self)
        originalDrifterOnCreate(self)
        self:AddTimedCallback(ScanForNearbyEnemy2, kDetectInterval)
        self:AddTimedCallback(FindTask2, kDrifterSelfOrderTime)
    end
)

ReplaceLocals(Drifter.OnUpdate, {ScanForNearbyEnemy = (function() end)})
ReplaceLocals(UpdateTasks, {FindTask = (function() end)})

function Drifter:OnOrderGiven(order)
    if order then
    	self:WakeUp()
    end
end

function Drifter:GetCanSleep()
    return not self:GetHasOrder() and not self.isRepositioning
end
-- END DRIFTER

-- HALLU
function Hallucination:OnOrderGiven(order)
    if order then
        self:WakeUp()
    end
end

function Hallucination:GetCanSleep()
    return not self:GetHasOrder() and not self.isRepositioning
end
-- END HALLU

-- HYDRA
function Hydra:GetCanSleep()
    return not self.alerting and not self.attacking and not self:GetHasPossibleTarget() and (self.doneFalling or self.fallWaiting == nil)
end

function Hydra:GetHasPossibleTarget()
    return self.targetSelector.possibleTargets == true
end
-- END HYDRA

-- MAC
local originalMACOnOrderGiven
originalMACOnOrderGiven = Class_ReplaceMethod("MAC", "OnOrderGiven",
	function(self, order)
		originalMACOnOrderGiven(self, order)
		self:WakeUp()
	end
)

function MAC:GetCanSleep()
    return not self:GetHasOrder() and not self.isRepositioning
end
-- END MAC

-- SENTRY
function Sentry:GetCanSleep()
    return false -- For now....
end
-- END SENTRY

-- TUNNELS
function TunnelEntrance:GetCanSleep()
    return false -- For now...
end
-- END TUNNELS

-- WHIP
function Whip:GetCanSleep()
    return not self.moving and self:GetIsBuilt() and not self:GetHasOrder() and self:GetIsAlive() and not self:GetHasPossibleTarget() and not self.isRepositioning
end

function Whip:OnOrderGiven(order)
    if order then
    	self:WakeUp()
    end
end

function Whip:GetHasPossibleTarget()
    return self.slapTargetSelector.possibleTargets == true or self.bombardTargetSelector.possibleTargets == true
end
-- END WHIP

-- ARMSLAB
local originalArmsLabOnInitialized
originalArmsLabOnInitialized = Class_ReplaceMethod("ArmsLab", "OnInitialized",
	function(self)
		originalArmsLabOnInitialized(self)
		InitMixin(self, SleeperMixin)
	end
)

function ArmsLab:GetCanSleep()
	return true
end
-- END ARMSLAB

-- WEAPON
local originalWeaponOnInitialized
originalWeaponOnInitialized = Class_ReplaceMethod("Weapon", "OnInitialized",
	function(self)
		originalWeaponOnInitialized(self)
		InitMixin(self, SleeperMixin)
	end
)

function Weapon:GetCanSleep()
	return self:GetWeaponWorldState()
end

local originalWeaponSetWeaponWorldState
originalWeaponSetWeaponWorldState = Class_ReplaceMethod("Weapon", "SetWeaponWorldState",
	function(self, state, preventExpiration)
		originalWeaponSetWeaponWorldState(self, state, preventExpiration)
		if state and self.WakeUp then
			self:WakeUp()
		end
	end
)
-- END WEAPON

-- NUTRIENT MIST
function NutrientMist:Perform()

    self.success = false

    self:TriggerEffects("comm_nutrient_mist")

    local entities = GetEntitiesWithMixinForTeamWithinRange("Catalyst", self:GetTeamNumber(), self:GetOrigin(), NutrientMist.kSearchRange)
    
    for index, entity in ipairs(entities) do
        
        entity:TriggerCatalyst(2, self:RequestHealing(entity:GetId()))
        
    end

end

local function NeedsHealing(ent)
    return ent.AmountDamaged and ent:AmountDamaged() > 0
end

function NutrientMist:RequestHealing(requestorId)
    
    local requestor = Shared.GetEntity(requestorId)
    if not requestor then
        return false
    end

    if not NeedsHealing(requestor) or not requestor.GetCanCatalyzeHeal or not requestor:GetCanCatalyzeHeal() then
        return false
    end

    -- clean table, removing entities that no longer exist or no longer need healing
    for i = #self.healTargets, 1, -1 do
        local ent = Shared.GetEntity(self.healTargets[i])
        if (not ent) or (not NeedsHealing(ent)) then
            table.remove(self.healTargets, i)
            self.numHealTargets = self.numHealTargets - 1
        end
    end

    -- see if there is room for another entity to be healed
    if self.numHealTargets < CatalystMixin.kMaxHealTargets then
        table.insert(self.healTargets, requestorId)
        self.numHealTargets = self.numHealTargets + 1
        return true
    end
    
    return false -- no room with this mist for another entity.
    -- requestor will either have to wait, or find healing with a different mist.
    
end
-- END NUTRIENT MIST

-- CLOG FALL NONSENSE
local oldClogFallMixin_AllChildFalling = ClogFallMixin_AllChildFalling
function ClogFallMixin_AllChildFalling(self)
    for _, childId in ipairs(self.connectedClogs) do
    	local child = Shared.GetEntity(childId)
        if child and child.WakeUp then
        	child:WakeUp()
        end
    end
    oldClogFallMixin_AllChildFalling(self)
end
-- END CLOGFALL

-- TARGETSELECTORS
local _TargetSelectorCache = { }
local _EntityToTargetSelectors = { }
local _TargetSelectorUpdateRate = 0.25

local oldTargetSelectorInit = TargetSelector.Init
function TargetSelector:Init(attacker, range, visibilityRequired, targetTypeList, filters, prioritizers)
	oldTargetSelectorInit(self, attacker, range, visibilityRequired, targetTypeList, filters, prioritizers)
	self.lastPeriodicUpdateCheck = Shared.GetTime()
	table.insert(_TargetSelectorCache, self)
	if not _EntityToTargetSelectors[attacker:GetId()] then
		_EntityToTargetSelectors[attacker:GetId()] = { }
	end
	table.insert(_EntityToTargetSelectors[attacker:GetId()], self)
	return self
end

local oldTargetCacheMixinOnDestroy = TargetCacheMixin.OnDestroy
function TargetCacheMixin:OnDestroy()
	if _EntityToTargetSelectors[self:GetId()] then
	    for _, ts in ipairs(_EntityToTargetSelectors[self:GetId()]) do
	        table.removevalue(_TargetSelectorCache, ts)
	    end
	    _EntityToTargetSelectors[self:GetId()] = nil
	end
    oldTargetCacheMixinOnDestroy(self)
end

local function TargetSelectorServerUpdate()

    PROFILE("TargetSelectorServerUpdate")

    for _, ts in ipairs(_TargetSelectorCache) do
    	if ts and ts.attacker then
    		-- Periodically check to see if there are possible things we MIGHT attack
    		if ts.lastPeriodicUpdateCheck + _TargetSelectorUpdateRate > Shared.GetTime() then
	    		local hasPossibleTargets = ts.possibleTargets
	    		ts.possibleTargets = ts:AcquireTarget() ~= nil
	    		if not hasPossibleTargets and ts.possibleTargets then
	    			-- We now have a possible target, wakeup if needed
	    			if ts.attacker.WakeUp then
	    				ts.attacker:WakeUp()
	    			end
	    		end
	    		ts.lastPeriodicUpdateCheck = Shared.GetTime()
	    	end
    	end
    end

end

Event.Hook("UpdateServer", TargetSelectorServerUpdate)

----- MIXIN HELL BELOW-----

-- EFFECTSMIXIN
local function UpdateSpawnEffect(self)
	self:TriggerEffects("spawn", { ismarine = GetIsMarineUnit(self), isalien = GetIsAlienUnit(self) })
    return false
end

function EffectsMixin:OnInitialized()

    -- delay triggering of spawn effect to be independant of mixin initialization order
    -- effects inherit the relevancy of the triggering entity, so this needs to be set first, otherwise players
    -- could miss an effect which they were intended to so
    self:AddTimedCallback(UpdateSpawnEffect, 0.05)
    
end
-- END EFFECTSMIXIN

-- PowerConsumerMixin
function PowerConsumerMixin:SetPowerSurgeDuration(duration)
    
    if self:GetIsPowered() then
        CreateEntity( EMPBlast.kMapName, self:GetOrigin(), self:GetTeamNumber() )
    end

    self.timePowerSurgeEnds = Shared.GetTime() + duration
    self.powerSurge = true

    --Make sure to call this after setting up the powersurge parameters!
    if self.OnPowerOn then
        self:OnPowerOn()
    end

    self:AddTimedCallback(PowerConsumerMixin.OnUpdatePowerSurge, duration)
    
end

function PowerConsumerMixin:OnUpdatePowerSurge()

    PROFILE("PowerConsumerMixin:OnUpdatePowerSurge")
    
    if self.powerSurge then
    
        local endSurge = self.timePowerSurgeEnds < Shared.GetTime() 
        
        if endSurge then
            
            self.powerSurge = false
            
            if self.OnPowerOff then
                self:OnPowerOff()
            end
            
        end
        
    end

    return false
    
end
-- END PowerConsumerMixin

-- ScoringMixin
function ScoringMixin:__initmixin()
    
    PROFILE("ScoringMixin:__initmixin")
    
    self.score = 0
    -- Some types of points are added continuously. These are tracked here.
    self.continuousScores = { }
    
    self.serverJoinTime = Shared.GetTime()

    self.playerLevel = -1
    self.totalXP = -1
    self.playerSkill = -1
    self.adagradSum = 0
    
    self.weightedEntranceTimes = {}
    self.weightedEntranceTimes[kTeam1Index] = {}
    self.weightedEntranceTimes[kTeam2Index] = {}
    
    self.weightedExitTimes = {}
    self.weightedExitTimes[kTeam1Index] = {}
    self.weightedExitTimes[kTeam2Index] = {}

    self:AddTimedCallback(ScoringMixin.OnUpdateTimes, 1)
    
end

function ScoringMixin:OnUpdateTimes(deltaTime)

    if not self.commanderTime then
        self.commanderTime = 0
    end
    
    if not self.playTime then
        self.playTime = 0
    end
    
    if not self.marineTime then
        self.marineTime = 0
    end
    
    if not self.alienTime then
        self.alienTime = 0
    end    
    
    if self:GetIsPlaying() then
    
        if self:isa("Commander") then
            self.commanderTime = self.commanderTime + deltaTime
        end
        
        self.playTime = self.playTime + deltaTime
        
        if self:GetTeamType() == kMarineTeamType then
            self.marineTime = self.marineTime + deltaTime
        end
        
        if self:GetTeamType() == kAlienTeamType then
            self.alienTime = self.alienTime + deltaTime
        end
    
    end

    return true

end
-- END ScoringMixin

-- TODOS:
--[[
----------------------------
Structures:
----------------------------
Armory
InfantryPortal
Observatory
PrototypeLab
Tunnel
TunnelEntrance
Web
-----------------------------
OTHERS:
-----------------------------
DOTMarker
Effect
ObjectiveInfo
DropPack
ParticleEffect
Pheromone
ResourcePoint
SoundEffect
SpawnBlocker
TechPoint
TimedEmitter
Tracer
PulseEffect
----------------------------
Figure out:
----------------------------
-- NOT REQUIRED ATM, these structures dont sleep
MinimapConnectionMixin

-- PLAYER MIXINS, not important ATM
PickupableMixin
PickupableWeaponMixin
SprintMixin
StunMixin
TunnelUserMixin
WebableMixin
--]]