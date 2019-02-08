-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/PrototypeLab.lua
-- - Dragon

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
Script.Load("lua/ScriptActor.lua")
Script.Load("lua/RagdollMixin.lua")
Script.Load("lua/NanoShieldMixin.lua")
Script.Load("lua/ObstacleMixin.lua")
Script.Load("lua/WeldableMixin.lua")
Script.Load("lua/UnitStatusMixin.lua")
Script.Load("lua/DissolveMixin.lua")
Script.Load("lua/PowerConsumerMixin.lua")
Script.Load("lua/GhostStructureMixin.lua")
Script.Load("lua/MapBlipMixin.lua")
Script.Load("lua/CommanderGlowMixin.lua")
Script.Load("lua/InfestationTrackerMixin.lua")
Script.Load("lua/ParasiteMixin.lua")

local kAnimationGraph = PrecacheAsset("models/marine/prototype_lab/prototype_lab.animation_graph")

class 'PrototypeLab' (ScriptActor)

PrototypeLab.kMapName = "prototypelab"

local kUpdateLoginTime = 0.3
-- Players can use menu and be supplied by PrototypeLab inside this range
PrototypeLab.kResupplyUseRange = 2.5

PrototypeLab.kModelName = PrecacheAsset("models/marine/prototype_lab/prototype_lab.model")

if Server then
    Script.Load("lua/PrototypeLab_Server.lua")
elseif Client then
    Script.Load("lua/PrototypeLab_Client.lua")
end    

local networkVars =
{
    -- How far out the arms are for animation (0-1)
    loggedInEast = "boolean",
    loggedInNorth = "boolean",
    loggedInSouth = "boolean",
    loggedInWest = "boolean",
    deployed = "boolean"
}

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
AddMixinNetworkVars(ParasiteMixin, networkVars)

function PrototypeLab:OnCreate()

    ScriptActor.OnCreate(self)
    
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
    self:SetPhysicsGroup(PhysicsGroup.BigStructuresGroup)
    
    self.loginEastAmount = 0
    self.loginNorthAmount = 0
    self.loginWestAmount = 0
    self.loginSouthAmount = 0
    
    self.timeScannedEast = 0
    self.timeScannedNorth = 0
    self.timeScannedWest = 0
    self.timeScannedSouth = 0

    self.loginNorthAmount = 0
    self.loginEastAmount = 0
    self.loginSouthAmount = 0
    self.loginWestAmount = 0
    
    self.deployed = false
    
end

function PrototypeLab:OnInitialized()

    ScriptActor.OnInitialized(self)
    
    self:SetModel(PrototypeLab.kModelName, kAnimationGraph)
    
    InitMixin(self, WeldableMixin)
    InitMixin(self, NanoShieldMixin)
    
    if Server then
    
        self.loggedInArray = {false, false, false, false}
        self:AddTimedCallback(PrototypeLab.UpdateLoggedIn, kUpdateLoginTime)
        
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

        self.lastPrototypeAnimUpdate = Client.GetTime()
        
    end
    
end

function PrototypeLab:GetTechButtons(techId)
    return { kTechId.JetpackTech, kTechId.None, kTechId.None, kTechId.None, 
             kTechId.ExosuitTech, kTechId.None, kTechId.None, kTechId.None } -- kTechId.DualRailgunTech
end

function PrototypeLab:GetRequiresPower()
    return true
end
--[[ -- dont allow jp marines to use the prototype lab
function PrototypeLab:GetCanBeUsed(player, useSuccessTable)

    if (not self:GetIsBuilt() and player:isa("Exo")) or (player:isa("Exo") and player:GetHasDualGuns()) or (player:isa("JetpackMarine") and self:GetIsBuilt()) then
        useSuccessTable.useSuccess = false
    end
    
end
--]]

function PrototypeLab:GetCanBeUsed(player, useSuccessTable)

    if (not self:GetIsBuilt() and player:isa("Exo")) or (player:isa("Exo") and player:GetHasDualGuns()) then
        useSuccessTable.useSuccess = false
    end
    
end

function PrototypeLab:GetCanSleep()
    return self.deployed
end

function PrototypeLab:GetCanBeUsedConstructed()
    return true
end 

local function UpdatePrototypeLabAnim(self, extension, loggedIn, scanTime, timePassed)

    local loggedInName = "log_" .. extension
    local loggedInParamValue = ConditionalValue(loggedIn, 1, 0)
    
    if extension == "n" then
    
        self.loginNorthAmount = Clamp(Slerp(self.loginNorthAmount, loggedInParamValue, timePassed*2), 0, 1)
        self:SetPoseParam(loggedInName, self.loginNorthAmount)
        
    elseif extension == "s" then
    
        self.loginSouthAmount = Clamp(Slerp(self.loginSouthAmount, loggedInParamValue, timePassed*2), 0, 1)
        self:SetPoseParam(loggedInName, self.loginSouthAmount)
        
    elseif extension == "e" then
    
        self.loginEastAmount = Clamp(Slerp(self.loginEastAmount, loggedInParamValue, timePassed*2), 0, 1)
        self:SetPoseParam(loggedInName, self.loginEastAmount)
        
    elseif extension == "w" then
    
        self.loginWestAmount = Clamp(Slerp(self.loginWestAmount, loggedInParamValue, timePassed*2), 0, 1)
        self:SetPoseParam(loggedInName, self.loginWestAmount)
        
    end
    
    local scannedName = "scan_" .. extension
    local scannedParamValue = ConditionalValue(scanTime == 0 or (Shared.GetTime() > scanTime + 3), 0, 1)
    self:SetPoseParam(scannedName, scannedParamValue)
    
end

function PrototypeLab:GetDamagedAlertId()
    return kTechId.MarineAlertStructureUnderAttack
end

function PrototypeLab:OnUpdateClientAnims(deltaTime)

    self:UpdatePrototypeLabWarmUp()
    
    if GetIsUnitActive(self) and self.deployed then
    
        -- Set pose parameters according to if we're logged in or not
        UpdatePrototypeLabAnim(self, "e", self.loggedInEast, self.timeScannedEast, deltaTime)
        UpdatePrototypeLabAnim(self, "n", self.loggedInNorth, self.timeScannedNorth, deltaTime)
        UpdatePrototypeLabAnim(self, "w", self.loggedInWest, self.timeScannedWest, deltaTime)
        UpdatePrototypeLabAnim(self, "s", self.loggedInSouth, self.timeScannedSouth, deltaTime)
        
    end
    
end

function PrototypeLab:OnUpdateRender()
    self:OnUpdateClientAnims(Clamp(Client.GetTime() - self.lastPrototypeAnimUpdate, 0, 0.25))
    self.lastPrototypeAnimUpdate = Client.GetTime()
end

function PrototypeLab:GetItemList(forPlayer)

    return { kTechId.Jetpack, kTechId.DualMinigunExosuit, kTechId.DualRailgunExosuit, }
    
end

function PrototypeLab:GetReceivesStructuralDamage()
    return true
end

Shared.LinkClassToMap("PrototypeLab", PrototypeLab.kMapName, networkVars)