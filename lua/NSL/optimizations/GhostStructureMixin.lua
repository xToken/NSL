-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/GhostStructureMixin.lua
-- - Dragon

GhostStructureMixin = CreateMixin(GhostStructureMixin)
GhostStructureMixin.type = "GhostStructure"

GhostStructureMixin.kGhostStructureCancelRange = 3
GhostStructureMixin.kGhostStructureCancelRefundScalar = 1

GhostStructureMixin.expectedMixins =
{
    Construct = "Makes no sense to use this mixin for non constructable units.",
    Team = "Required to identify enemies and to cancel ghost mode by onuse from friendly players"
}

GhostStructureMixin.networkVars =
{
    isGhostStructure = "boolean"
}

local kGhoststructureMaterial = PrecacheAsset("cinematics/vfx_materials/ghoststructure.material") 

if Client then
    PrecacheAsset("cinematics/vfx_materials/ghoststructure.surface_shader")
end

local function SetupTriggerBody(self)
        -- This is almost a mixin within a mixin.. ugh
    local coords = self:GetCoords()

    self.triggerBody = Shared.CreatePhysicsSphereBody(false, GhostStructureMixin.kGhostStructureCancelRange, 0, coords)
    self.triggerBody:SetGroup(PhysicsGroup.TriggerGroup)
    self.triggerBody:SetGroupFilterMask(PhysicsMask.AllButTriggers)
    self.triggerBody:SetTriggerEnabled(true)
    self.triggerBody:SetCollisionEnabled(true)        
    self.triggerBody:SetEntity(self)

    return false
end

function GhostStructureMixin:__initmixin()

    PROFILE("GhostStructureMixin:__initmixin")

    -- init the entity in ghost structure mode
    if Server then
        self.isGhostStructure = true
    end

    if Client then
        --Set this to false, hopefully triggers fieldwatcher then?
        self.isGhostStructure = false
        self:AddFieldWatcher("isGhostStructure", GhostStructureMixin.OnUpdateGhostEffects)

    end

    self:AddTimedCallback(SetupTriggerBody, 0)

end

function GhostStructureMixin:GetIsGhostStructure()
    return self.isGhostStructure
end

local function ClearGhostStructure(self, refundScalar)

    if Server then

        self.isGhostStructure = false

        self:TriggerEffects("ghoststructure_destroy")
        local cost = math.round(LookupTechData(self:GetTechId(), kTechDataCostKey, 0) * refundScalar)
        self:GetTeam():AddTeamResources(cost)
        self:GetTeam():PrintWorldTextForTeamInRange(kWorldTextMessageType.Resources, cost, self:GetOrigin() + kWorldMessageResourceOffset, kResourceMessageRange)

        if self.triggerBody then
        
            Shared.DestroyCollisionObject(self.triggerBody)
            self.triggerBody = nil

        end

        DestroyEntity(self)

    end

    if Client then
        -- Allow some grace for prediction of entity being poofed?
        self:SetModel(nil)
    end
    
end

function GhostStructureMixin:PerformAction(techNode, _)

    if techNode.techId == kTechId.Cancel and self:GetIsGhostStructure() then
    
        -- give back only 75% of resources to avoid abusing the mechanic
        ClearGhostStructure(self, kRecyclePaybackScalar)

    end
    
end

if Server then

    local function CheckGhostState(self, doer)

        if self:GetIsGhostStructure() and GetAreFriends(self, doer) then
            self.isGhostStructure = false

            -- Cleanup trigger
            if self.triggerBody then

                Shared.DestroyCollisionObject(self.triggerBody)
                self.triggerBody = nil

            end
        end

    end
    
    function GhostStructureMixin:OnTakeDamage()

        if self:GetIsGhostStructure() and self:GetHealthFraction() < 0.25 then        
            ClearGhostStructure(self, GhostStructureMixin.kGhostStructureCancelRefundScalar)
        end

    end
    
    -- If we start constructing, make us no longer a ghost
    function GhostStructureMixin:OnConstruct(builder, _)
        CheckGhostState(self, builder)
    end
    
    function GhostStructureMixin:OnConstructionComplete()
        self.isGhostStructure = false

        -- Cleanup trigger
        if self.triggerBody then

            Shared.DestroyCollisionObject(self.triggerBody)
            self.triggerBody = nil

        end

    end

    function GhostStructureMixin:OnTouchInfestation()

        if self:GetIsGhostStructure() and LookupTechData(self:GetTechId(), kTechDataNotOnInfestation, false) then
            ClearGhostStructure(self, GhostStructureMixin.kGhostStructureCancelRefundScalar)
        end

    end

end

function GhostStructureMixin:OnTriggerEntered(enterEntity)

    if self:GetIsGhostStructure() and HasMixin(enterEntity, "Team") and GetAreEnemies(self, enterEntity) then
        ClearGhostStructure(self, GhostStructureMixin.kGhostStructureCancelRefundScalar)
    end

end

if Client then
    
    function GhostStructureMixin:OnUpdateGhostEffects()

        local model
        if HasMixin(self, "Model") then
            model = self:GetRenderModel()
        end
        
        if model then

            if self:GetIsGhostStructure() then
            
                self:SetOpacity(0, "ghostStructure")
            
                if not self.ghostStructureMaterial then
                    self.ghostStructureMaterial = AddMaterial(model, kGhoststructureMaterial)
                end
        
            else
            
                self:SetOpacity(1, "ghostStructure")
            
                if RemoveMaterial(model, self.ghostStructureMaterial) then
                    self.ghostStructureMaterial = nil
                end

            end
            
        end

        return self:GetIsGhostStructure()
        
    end
    
end

--
-- Do not allow nano shield on ghost structures.
--
function GhostStructureMixin:GetCanBeNanoShieldedOverride(resultTable)
    resultTable.shieldedAllowed = resultTable.shieldedAllowed and not self.isGhostStructure
end

GhostStructureMixin.OnUpdate = nil
GhostStructureMixin.OnProcessMove = nil