-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/Observatory.lua
-- - Dragon

Script.Load("lua/CommAbilities/Marine/Scan.lua")

Script.Load("lua/Mixins/ClientModelMixin.lua")
Script.Load("lua/LiveMixin.lua")
Script.Load("lua/PointGiverMixin.lua")
Script.Load("lua/AchievementGiverMixin.lua")
Script.Load("lua/GameEffectsMixin.lua")
Script.Load("lua/SelectableMixin.lua")
Script.Load("lua/FlinchMixin.lua")
Script.Load("lua/LOSMixin.lua")
Script.Load("lua/TeamMixin.lua")
Script.Load("lua/EntityChangeMixin.lua")
Script.Load("lua/CorrodeMixin.lua")
Script.Load("lua/ConstructMixin.lua")
Script.Load("lua/ResearchMixin.lua")
Script.Load("lua/RecycleMixin.lua")
Script.Load("lua/CombatMixin.lua")
Script.Load("lua/CommanderGlowMixin.lua")

Script.Load("lua/ScriptActor.lua")
Script.Load("lua/RagdollMixin.lua")
Script.Load("lua/DetectorMixin.lua")
Script.Load("lua/NanoShieldMixin.lua")
Script.Load("lua/ObstacleMixin.lua")
Script.Load("lua/WeldableMixin.lua")
Script.Load("lua/UnitStatusMixin.lua")
Script.Load("lua/DissolveMixin.lua")
Script.Load("lua/PowerConsumerMixin.lua")
Script.Load("lua/GhostStructureMixin.lua")
Script.Load("lua/MapBlipMixin.lua")
Script.Load("lua/InfestationTrackerMixin.lua")
Script.Load("lua/IdleMixin.lua")
Script.Load("lua/ParasiteMixin.lua")

class 'Observatory' (ScriptActor)

Observatory.kMapName = "observatory"

Observatory.kModelName = PrecacheAsset("models/marine/observatory/observatory.model")
Observatory.kCommanderScanSound = PrecacheAsset("sound/NS2.fev/marine/commander/scan_com")

local kDistressBeaconSoundMarine = PrecacheAsset("sound/NS2.fev/marine/common/distress_beacon_marine")

local kObservatoryTechButtons = { kTechId.Scan, kTechId.DistressBeacon, kTechId.Detector, kTechId.None,
                                   kTechId.PhaseTech, kTechId.None, kTechId.None, kTechId.None }

Observatory.kDistressBeaconTime = kDistressBeaconTime
Observatory.kDistressBeaconRange = kDistressBeaconRange
Observatory.kDetectionRange = 22 -- From NS1
Observatory.kRelevancyPortalRange = 40

local kAnimationGraph = PrecacheAsset("models/marine/observatory/observatory.animation_graph")

local networkVars = { }

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ClientModelMixin, networkVars)
AddMixinNetworkVars(LiveMixin, networkVars)
AddMixinNetworkVars(GameEffectsMixin, networkVars)
AddMixinNetworkVars(FlinchMixin, networkVars)
AddMixinNetworkVars(TeamMixin, networkVars)
AddMixinNetworkVars(LOSMixin, networkVars)
AddMixinNetworkVars(CorrodeMixin, networkVars)
AddMixinNetworkVars(ConstructMixin, networkVars)
AddMixinNetworkVars(ResearchMixin, networkVars)
AddMixinNetworkVars(RecycleMixin, networkVars)
AddMixinNetworkVars(CombatMixin, networkVars)
AddMixinNetworkVars(NanoShieldMixin, networkVars)
AddMixinNetworkVars(ObstacleMixin, networkVars)
AddMixinNetworkVars(DissolveMixin, networkVars)
AddMixinNetworkVars(PowerConsumerMixin, networkVars)
AddMixinNetworkVars(GhostStructureMixin, networkVars)
AddMixinNetworkVars(SelectableMixin, networkVars)
AddMixinNetworkVars(IdleMixin, networkVars)
AddMixinNetworkVars(ParasiteMixin, networkVars)

function Observatory:OnCreate()

    ScriptActor.OnCreate(self)
    
    if Server then
    
        self.distressBeaconSound = Server.CreateEntity(SoundEffect.kMapName)
        self.distressBeaconSound:SetAsset(kDistressBeaconSoundMarine)
        self.distressBeaconSound:SetRelevancyDistance(Math.infinity)
        
        self:AddTimedCallback(Observatory.RevealCysts, 0.4)
        
        self.beaconRelevancyPortal = -1
        
    end
    
    InitMixin(self, BaseModelMixin)
    InitMixin(self, ClientModelMixin)
    InitMixin(self, LiveMixin)
    InitMixin(self, GameEffectsMixin)
    InitMixin(self, FlinchMixin, { kPlayFlinchAnimations = true })
    InitMixin(self, TeamMixin)
    InitMixin(self, PointGiverMixin)
    InitMixin(self, AchievementGiverMixin)
    InitMixin(self, SelectableMixin)
    InitMixin(self, EntityChangeMixin)
    InitMixin(self, LOSMixin)
    InitMixin(self, CorrodeMixin)
    InitMixin(self, ConstructMixin)
    InitMixin(self, ResearchMixin)
    InitMixin(self, RecycleMixin)
    InitMixin(self, CombatMixin)
    InitMixin(self, RagdollMixin)
    InitMixin(self, DetectorMixin)
    InitMixin(self, ObstacleMixin)
    InitMixin(self, DissolveMixin)
    InitMixin(self, GhostStructureMixin)
    InitMixin(self, PowerConsumerMixin)
    InitMixin(self, ParasiteMixin)
    
    if Client then
        InitMixin(self, CommanderGlowMixin)
    end
    
    self:SetLagCompensated(false)
    self:SetPhysicsType(PhysicsType.Kinematic)
    self:SetPhysicsGroup(PhysicsGroup.MediumStructuresGroup)  
    
end

function Observatory:OnInitialized()

    ScriptActor.OnInitialized(self)
    
    InitMixin(self, WeldableMixin)
    InitMixin(self, NanoShieldMixin)
    
    self:SetModel(Observatory.kModelName, kAnimationGraph)
    
    if Server then
    
        -- This Mixin must be inited inside this OnInitialized() function.
        if not HasMixin(self, "MapBlip") then
            InitMixin(self, MapBlipMixin)
        end
        
        InitMixin(self, SleeperMixin)
        InitMixin(self, StaticTargetMixin)
        InitMixin(self, InfestationTrackerMixin)
    
    elseif Client then
    
        InitMixin(self, UnitStatusMixin)
        InitMixin(self, HiveVisionMixin)
        
    end
    
    InitMixin(self, IdleMixin)

end

local function DestroyRelevancyPortal(self)
    if self.beaconRelevancyPortal ~= -1 then
        Server.DestroyRelevancyPortal(self.beaconRelevancyPortal)
        self.beaconRelevancyPortal = -1
    end
end

function Observatory:OnDestroy()

    ScriptActor.OnDestroy(self)
    
    if Server then
    
        DestroyEntity(self.distressBeaconSound)
        self.distressBeaconSound = nil
        DestroyRelevancyPortal(self)
        
    end
    
end

function Observatory:GetTechButtons(techId)

    if techId == kTechId.RootMenu then
        return kObservatoryTechButtons
    end
    
    return nil
    
end

function Observatory:GetDetectionRange()

    if GetIsUnitActive(self) then
        return Observatory.kDetectionRange
    end
    
    return 0
    
end

function Observatory:GetRequiresPower()
    return true
end

function Observatory:GetReceivesStructuralDamage()
    return true
end

function Observatory:GetCanSleep()
    return self:GetIsBuilt() and not self:GetIsBeaconing()
end

function Observatory:GetDamagedAlertId()
    return kTechId.MarineAlertStructureUnderAttack
end

function Observatory:GetDistressOrigin()

    -- Respawn at nearest built command station
    local origin
    local nearest = GetNearest(self:GetOrigin(), "CommandStation", self:GetTeamNumber(), function(ent) return ent:GetIsBuilt() and ent:GetIsAlive() end)
    if nearest then
        -- Log("Nearest CC ID: %s", nearest:GetLocationId())
        origin = nearest:GetModelOrigin()
    end
    
    return origin
    
end

local function TriggerMarineBeaconEffects(self)

    for _, player in ipairs(GetEntitiesForTeam("Player", self:GetTeamNumber())) do
    
        if player:GetIsAlive() and (player:isa("Marine") or player:isa("Exo")) then
            player:TriggerEffects("player_beacon")
        end
    
    end

end

local function SetupBeaconRelevancyPortal(self, destination)
    
    DestroyRelevancyPortal(self)
    
    local source = Vector(Math.infinity, Math.infinity, Math.infinity)
    
    local mask = 0
    local teamNumber = self:GetTeamNumber()
    if teamNumber == 1 then
        mask = kRelevantToTeam1Unit
    elseif teamNumber == 2 then
        mask = kRelevantToTeam2Unit
    end
    
    if mask ~= 0 then
        self.beaconRelevancyPortal = Server.CreateRelevancyPortal(source, destination, mask, 0)
    end
    
end

function Observatory:TriggerDistressBeacon()

    local success = false
    
    if not self:GetIsBeaconing() then

        self.distressBeaconSound:Start()

        local origin = self:GetDistressOrigin()
        
        if origin then
        
            self.distressBeaconSound:SetOrigin(origin)

            -- Beam all faraway players back in a few seconds!
            self.distressBeaconTime = Shared.GetTime() + Observatory.kDistressBeaconTime
            self:WakeUp()
            
            if Server then
            
                TriggerMarineBeaconEffects(self)
                
                local location = GetLocationForPoint(self:GetDistressOrigin())
                local locationName = location and location:GetName() or ""
                local locationId = Shared.GetStringIndex(locationName)
                SendTeamMessage(self:GetTeam(), kTeamMessageTypes.Beacon, locationId)
                
                SetupBeaconRelevancyPortal(self, origin)
                
            end
            
            success = true
        
        end
    
    end
    
    return success, not success
    
end

function Observatory:CancelDistressBeacon()

    self.distressBeaconTime = nil
    self.distressBeaconSound:Stop()
    DestroyRelevancyPortal(self)

end

-- Check if both origins are in the location (game wise, not mapping wise since a "location" is composed of several mapping "location" entities)
local function GetIsSameLocation(CC_orig, player_orig)
    local loc1 = GetLocationForPoint(CC_orig)
    local loc2 = GetLocationForPoint(player_orig)

    if loc1 and loc2 then
        local location1_id = Shared.GetStringIndex(loc1:GetName())
        local location2_id = Shared.GetStringIndex(loc2:GetName())

        -- Log("Locations1: %s %s/%s", loc1, loc1:GetName(), location1_id)
        -- Log("Locations2: %s %s/%s", loc2, loc2:GetName(), location2_id)
        -- Log("Distance: %s", CC_orig:GetDistanceTo(player_orig))
        if location1_id == location2_id then
            return true
        end
    end

    return false
end

local function GetIsPlayerNearby(_, player, toOrigin)
    return (player:GetOrigin() - toOrigin):GetLength() < Observatory.kDistressBeaconRange
end

local function GetPlayersToBeacon(self, toOrigin)

    local players = { }
    
    for _, player in ipairs(self:GetTeam():GetPlayers()) do
    
        -- Don't affect Commanders or Heavies
        if player:isa("Marine") then
        
            -- Don't respawn players that are already nearby.
            -- Log("Player location id: %s", player:GetLocationId())
            local nearby = GetIsPlayerNearby(self, player, toOrigin)
            local inTheSameLocation = GetIsSameLocation(toOrigin, player:GetOrigin())
            if not nearby or not inTheSameLocation then
            
                if player:isa("Exo") then
                    table.insert(players, 1, player)
                else
                    table.insert(players, player)
                end
                
            end
            
        end
        
    end

    return players
    
end

local function BeaconGetMarineSpawnPoints(orig, number)
    local techId = kTechId.Marine
    local mapName = Marine.kMapName
    local entities = {}
    local extents = LookupTechData(kTechId.Marine, kTechDataMaxExtents)
    local capsuleHeight, capsuleRadius = GetTraceCapsuleFromExtents(extents)
    local range = Observatory.kDistressBeaconRange
    local position = nil

    number = number or 1
    for i = 1, number do

        local success = false
        -- Persistence is the path to victory.
        for index = 1, 150 do

            teamNumber = 1
            position = GetRandomSpawnForCapsule(capsuleHeight, capsuleRadius, orig, 2, range, EntityFilterAll())
            if position then
                success = true

                local CCLocation = GetLocationForPoint(orig)
                local marineLocation = GetLocationForPoint(position)
                local inTheSameLocation = GetIsSameLocation(orig, position)

                -- Check if we are in the same location room
                if (not inTheSameLocation)
                then
                    success = false
                    Log("Beaconing a marine to the wrong location (%s instead of %s), let's retry", marineLocation:GetName(), CCLocation:GetName())
                end

                if (success) then
                    -- Log("Location found in %s for a marine", marineLocation and marineLocation:GetName() or "")
                    table.insert(entities, position)
                    break
                end
            end

        end

        -- if not success then
        --    Print("Create %s: Couldn't find space for entity", EnumToString(kTechId, techId))
        -- end
    end

    return entities
end

-- Spawn players at nearest Command Station to Observatory - not initial marine start like in NS1. Allows relocations and more versatile tactics.
local function RespawnPlayer(_, player, distressOrigin)

    -- Always marine capsule (player could be dead/spectator)
    local extents = HasMixin(player, "Extents") and player:GetExtents() or LookupTechData(kTechId.Marine, kTechDataMaxExtents)
    local capsuleHeight, capsuleRadius = GetTraceCapsuleFromExtents(extents)
    local range = Observatory.kDistressBeaconRange
    local spawnPoints = BeaconGetMarineSpawnPoints(distressOrigin, 1)
    local spawnPoint = #spawnPoints > 0 and spawnPoints[1] or nil
    
    if spawnPoint then
        
        -- Obsolete Jan. 2, 2018, w/ relevancy portals.
        --if HasMixin(player, "SmoothedRelevancy") then
            --player:StartSmoothedRelevancy(spawnPoint)
        --end
        
        player:SetOrigin(spawnPoint)
        if player.TriggerBeaconEffects then
            player:TriggerBeaconEffects()
        end

    end
    
    return spawnPoint ~= nil, spawnPoint
    
end

function Observatory:PerformDistressBeacon()

    self.distressBeaconSound:Stop()
    
    local anyPlayerWasBeaconed = false
    local successfullPositions = {}
    local successfullExoPositions = {}
    local failedPlayers = {}
    
    local distressOrigin = self:GetDistressOrigin()
    if distressOrigin then
    
        for _, player in ipairs(GetPlayersToBeacon(self, distressOrigin)) do
            
            -- Notify LOS mixin of the impending move (to prevent aliens scouted by this
            -- player from getting stuck scouted).
            if Server and HasMixin(player, "LOS") then
                player:MarkNearbyDirtyImmediately()
            end
            
            if Server and player.OnPreBeacon then
                player:OnPreBeacon()
            end
            
            local success, respawnPoint = RespawnPlayer(self, player, distressOrigin)
            if success then
            
                anyPlayerWasBeaconed = true
                if player:isa("Exo") then
                    table.insert(successfullExoPositions, respawnPoint)
                end
                    
                table.insert(successfullPositions, respawnPoint)
                
            else
                table.insert(failedPlayers, player)
            end
            
        end
        
        -- Also respawn players that are spawning in at infantry portals near command station (use a little extra range to account for vertical difference)
        for _, ip in ipairs(GetEntitiesForTeamWithinRange("InfantryPortal", self:GetTeamNumber(), distressOrigin, kInfantryPortalAttachRange + 1)) do
        
            ip:FinishSpawn()
            local spawnPoint = ip:GetAttachPointOrigin("spawn_point")
            table.insert(successfullPositions, spawnPoint)
            
        end
        
    end
    
    local usePositionIndex = 1
    local numPosition = #successfullPositions

    for i = 1, #failedPlayers do
    
        local player = failedPlayers[i]  
    
        if player:isa("Exo") then        
            player:SetOrigin(successfullExoPositions[math.random(1, #successfullExoPositions)])        
        else
              
            player:SetOrigin(successfullPositions[usePositionIndex])
            if player.TriggerBeaconEffects then
                player:TriggerBeaconEffects()
            end
            
            usePositionIndex = Math.Wrap(usePositionIndex + 1, 1, numPosition)
            
        end    
    
    end

    if anyPlayerWasBeaconed then
        self:TriggerEffects("distress_beacon_complete")
    end
    
end

function Observatory:OnPowerOff()    
    
    -- Cancel distress beacon on power down
    if self:GetIsBeaconing() then
        self:CancelDistressBeacon()        
    end

end

function Observatory:RevealCysts()

    for _, cyst in ipairs(GetEntitiesForTeamWithinRange("Cyst", GetEnemyTeamNumber(self:GetTeamNumber()), self:GetOrigin(), Observatory.kDetectionRange)) do
        if self:GetIsBuilt() and self:GetIsPowered() then
            cyst:SetIsSighted(true)
        end
    end

    return self:GetIsAlive()

end

function Observatory:OnUpdate(deltaTime)

    ScriptActor.OnUpdate(self, deltaTime)
    
    if self:GetIsBeaconing() and (Shared.GetTime() >= self.distressBeaconTime) then
        
        self:PerformDistressBeacon()
        DestroyRelevancyPortal(self)
        
        self.distressBeaconTime = nil
        
    end
    
    if self.beaconRelevancyPortal ~= -1 and self.distressBeaconTime then
        local rangeFrac = 1.0 - math.min(math.max(self.distressBeaconTime - Shared.GetTime(), 0) / self.kDistressBeaconTime, 1.0)
        local range = self.kRelevancyPortalRange * rangeFrac
        Server.SetRelevancyPortalRange(self.beaconRelevancyPortal, range)
    end
    
end

function Observatory:PerformActivation(techId, position, normal, commander)

    -- local success = false
    
    if GetIsUnitActive(self) then
    
        if techId == kTechId.DistressBeacon then
            return self:TriggerDistressBeacon()
        end
        
    end
    
    return ScriptActor.PerformActivation(self, techId, position, normal, commander)
    
end

function Observatory:GetIsBeaconing()
    return self.distressBeaconTime ~= nil
end

if Server then

    function Observatory:OnKill(killer, doer, point, direction)

        if self:GetIsBeaconing() then
            self:CancelDistressBeacon()
        end
        
        ScriptActor.OnKill(self, killer, doer, point, direction)
        
    end
    
end

function Observatory:OverrideVisionRadius()
    return Observatory.kDetectionRange
end

if Server then

    local function OnConsoleDistress()
    
        if Shared.GetCheatsEnabled() or Shared.GetDevMode() then
            local beacons = Shared.GetEntitiesWithClassname("Observatory")
            for _, beacon in ientitylist(beacons) do
                beacon:TriggerDistressBeacon()
                return -- don't beacon more than one at a time.
            end
        end
        
    end
    
    Event.Hook("Console_distress", OnConsoleDistress)
    
end

if Server then

    function Observatory:OnConstructionComplete()

        if self.phaseTechResearched then

            local techTree = GetTechTree(self:GetTeamNumber())
            if techTree then
                local researchNode = techTree:GetTechNode(kTechId.PhaseTech)
                researchNode:SetResearched(true)
                techTree:QueueOnResearchComplete(kTechId.PhaseTech, self)
            end    
            
        end

    end
    
end    

function Observatory:GetHealthbarOffset()
    return 0.9
end 


Shared.LinkClassToMap("Observatory", Observatory.kMapName, networkVars)
