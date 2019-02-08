-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/ResearchMixin.lua
-- - Dragon

ResearchMixin = CreateMixin(ResearchMixin)
ResearchMixin.type = "Research"

ResearchMixin.networkVars =
{
    -- Tech id of research this building is currently researching
    researchingId           = "enum kTechId",
    -- 0 to 1 scalar of progress
    researchProgress        = "float (0 to 1 by 0.01)",
}

ResearchMixin.expectedMixins =
{
    --TechAction = "Required to display buttons."
}

ResearchMixin.expectedCallbacks = 
{
}

ResearchMixin.optionalCallbacks = 
{
    GetCanResearchOverride = "Return custom conditions when researching should be allowed.",
    OnResearch = "Called whenever a research is triggered.",
    OverrideCreateManufactureEntity = "Custom creation method",
    OnManufactured = "Called after successful creation" 
}

local function RemoveResearchSupply(self, researchId)

    local team = self:GetTeam()    
    if self.addedResearchSupply and team and team.RemoveSupplyUsed then
        
        self.addedResearchSupply = false
        team:RemoveSupplyUsed(LookupTechData(researchId, kTechDataSupply, 0))
    
    end

end

function ResearchMixin:__initmixin()
    
    PROFILE("ResearchMixin:__initmixin")
    
    self.researchingId = kTechId.None
    self.researchProgress = 0
    self.timeResearchStarted = 0
    self.researchingPlayerId = Entity.invalidId
    
end

function ResearchMixin:GetShouldUpdateResearch()
    return self.researchingId ~= kTechId.None and ( GetIsUnitActive(self) or 
        ( HasMixin(self, "Recycle") and self.researchingId == kTechId.Recycle ) or 
        ( HasMixin(self, "Consume") and self.researchingId == kTechId.Consume ) )
end

function ResearchMixin:UpdateResearch(deltaTime)

    local researchNode = self:GetTeam():GetTechTree():GetTechNode(self.researchingId)
    if researchNode and self:GetShouldUpdateResearch() then
    
        local researchDuration = LookupTechData(researchNode:GetTechId(), kTechDataResearchTimeKey, 0.01)
        
        if GetGamerules():GetAutobuild() then
            researchDuration = math.min(0.5, researchDuration)
        end
        
        researchDuration = researchDuration * kResearchMod
        
        -- avoid division with 0
        researchDuration = math.max(researchDuration, 0.01)
        
        local progress = self.researchProgress + deltaTime / researchDuration
        progress = math.min(progress, 1)

        if progress ~= self.researchProgress then
        
            self.researchProgress = progress

            researchNode:SetResearchProgress(self.researchProgress)
            
            local techTree = self:GetTeam():GetTechTree()
            techTree:SetTechNodeChanged(researchNode, string.format("researchProgress = %.2f", self.researchProgress))
            
            -- Update research progress
            if self.researchProgress == 1 then

                -- Mark this tech node as researched
                researchNode:SetResearched(true)
                
                techTree:QueueOnResearchComplete(self.researchingId, self)
                
            end
        
        end
        
    end

    return self.researchingId ~= kTechId.None

end

ResearchMixin.OnUpdate = nil
ResearchMixin.OnProcessMove = nil

function ResearchMixin:GetResearchingId()
    return self.researchingId
end

function ResearchMixin:GetResearchProgress()
    return self.researchProgress
end

function ResearchMixin:GetResearchTechAllowed(techNode)

    -- Return false if we're researching, or if tech is being researched
    return not (self.researchingId ~= kTechId.None or techNode.researched or techNode.researching)
    
end

local function AbortResearch(self, refundCost)

    if self.researchProgress > 0 then
    
        local team = self:GetTeam()
        -- Team is not always available due to order of destruction during map change.
        if team then
        
            local researchNode = team:GetTechTree():GetTechNode(self.researchingId)
            if researchNode ~= nil then
            
                -- Give money back if refundCost is true.
                if refundCost then
                    team:AddTeamResources(researchNode:GetCost())
                end
                
                ASSERT(researchNode:GetResearching() or researchNode:GetIsUpgrade())
                
                researchNode:ClearResearching()
                
                if self.OnResearchCancel then
                    self:OnResearchCancel(self.researchingId)
                end
                
                self:ClearResearch()
                
                team:GetTechTree():SetTechNodeChanged(researchNode)
                team:GetTechTree():SetTechChanged()
                
            end
            
        end
        
    end
    
end

function ResearchMixin:OnKill()
    AbortResearch(self)
end 

function ResearchMixin:ClearResearch()

    RemoveResearchSupply(self, self.researchingId)
    self.researchingId = kTechId.None
    self.researchingPlayerId = Entity.invalidId
    self.researchTime = 0
    self.timeResearchStarted = 0
    self.timeResearchComplete = 0
    self.researchProgress = 0
    
end

function ResearchMixin:GetIsResearching()

    local researchProgress = self:GetResearchProgress()
    -- Note: We need to treat 1 as "not researching" as there
    -- is a delay in the tech tree code that means the entity will
    -- have a researchProgress of 1 for longer than we would expect.
    -- This delay allows the player to cancel research before the
    -- tech tree updates and get a free research.
    return researchProgress > 0 and researchProgress < 1
    
end

function ResearchMixin:GetIsManufacturing()

    if self:GetIsResearching() then
    
        local researchNode = GetTechTree(self:GetTeamNumber()):GetTechNode(self.researchingId)
        return researchNode ~= nil and (researchNode:GetIsManufacture() or researchNode:GetIsEnergyManufacture() or researchNode:GetIsPlasmaManufacture())
    
    end
    
    return false

end

function ResearchMixin:GetIsUpgrading()

    if self:GetIsResearching() then
    
        local researchNode = GetTechTree(self:GetTeamNumber()):GetTechNode(self.researchingId)
        return researchNode ~= nil and researchNode:GetIsUpgrade()
    
    end
    
    return false
    
end

-- Could be for research or upgrade
function ResearchMixin:SetResearching(techNode, player)

    self.researchingId = techNode.techId
    assert(self.researchingId ~= 0)
    self.researchTime = techNode.time
    self.researchingPlayerId = player:GetId()
    
    self.timeResearchStarted = Shared.GetTime()
    self.timeResearchComplete = techNode.time
    self.researchProgress = 0
    
    if self.OnResearch then
        self:OnResearch(self.researchingId)
    end

    self:AddTimedCallback(ResearchMixin.UpdateResearch, 0.1)
    
end

function ResearchMixin:OnResearch(researchId)

    local team = self:GetTeam()
    if team and team.AddSupplyUsed then
        self.addedResearchSupply = true
        team:AddSupplyUsed(LookupTechData(researchId, kTechDataSupply, 0))
    end

end

function ResearchMixin:OnUpdateAnimationInput(modelMixin)

    PROFILE("ResearchMixin:OnUpdateAnimationInput")
    modelMixin:SetAnimationInput("researching", self:GetIsResearching())
    
end

function ResearchMixin:PerformAction(techNode, _)

    -- Process Cancel of research or upgrade.
    if techNode.techId == kTechId.Cancel then
    
        if self:GetIsResearching() then
            AbortResearch(self, true)
        end
        
    end
    
end

function ResearchMixin:OnEntityChange(oldId, newId)

    if oldId == self.researchingPlayerId and self.researchingPlayerId ~= Entity.invalidId then
        self.researchingPlayerId = newId
    end
    
end

function ResearchMixin:GetCanResearch(techId)

    if self:GetIsResearching() then
        return false
    end    

    if techId == kTechId.Recycle and HasMixin(self, "Recycle") then
        return true
    end

    if self.GetCanResearchOverride then
        return self:GetCanResearchOverride(techId)
    end

    return GetIsUnitActive(self)
    
end

function ResearchMixin:GetIssuedCommander()

    local issuedCommander = Shared.GetEntity(self.researchingPlayerId)
    
    if not issuedCommander then
        local commanders = GetEntitiesForTeam("Commander", self:GetTeamNumber())
        issuedCommander = commanders[1]
    end
    
    return issuedCommander
    
end

function ResearchMixin:CreateManufactureEntity(techId)

    local entity

    if self.OverrideCreateManufactureEntity then
        entity = self:OverrideCreateManufactureEntity(techId)
    else

        local mapName = LookupTechData(techId, kTechDataMapName)
        entity = CreateEntity(mapName, self:GetOrigin(), self:GetTeamNumber())
        entity:SetOwner(self:GetIssuedCommander())
        
        if entity.ProcessRallyOrder then
            entity:ProcessRallyOrder(self)
        end
        
    end    

    if entity and self.OnManufactured then
        self:OnManufactured(entity)
    end
    
    return entity

end

function ResearchMixin:TechResearched(structure, researchId)

    if structure and structure:GetId() == self:GetId() then
    
        RemoveResearchSupply(self, researchId)
        
        local researchNode = self:GetTeam():GetTechTree():GetTechNode(researchId)
        if researchNode and (researchNode:GetIsEnergyManufacture() or researchNode:GetIsManufacture() or researchNode:GetIsPlasmaManufacture()) then
        
            -- Handle manufacture actions
            self:CreateManufactureEntity(researchId)
            
        elseif self.OnResearchComplete then
            self:OnResearchComplete(researchId)
        end
        
        self:ClearResearch()
        
    end
    
end

function ResearchMixin:OnPowerOff()

    if self:GetIsResearching() and self:GetResearchingId() ~= kTechId.Recycle then        
        AbortResearch(self, true)
    end

end