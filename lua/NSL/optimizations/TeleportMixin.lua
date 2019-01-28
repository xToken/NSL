-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/TeleportMixin.lua
-- - Dragon

TeleportMixin = CreateMixin(TeleportMixin)
TeleportMixin.type = "TeleportAble"

TeleportMixin.kDefaultDelay = 3
TeleportMixin.kMaxRange = 4.5
TeleportMixin.kMinRange = 1
TeleportMixin.kAttachRange = 15
TeleportMixin.kDefaultSinkin = 1.4

TeleportMixin.optionalCallbacks = {

    OnTeleport = "Called when teleport is triggered.",
    OnTeleportEnd = "Called when teleport is done.",
    GetCanTeleportOverride = "Return true/false to allow/prevent teleporting."
    
}

TeleportMixin.networkVars = {
 
    isTeleporting = "boolean",
    teleportDelay = "float"
    
}

function TeleportMixin:__initmixin()
    
    PROFILE("TeleportMixin:__initmixin")
    
    self.maxCatalystStacks = TeleportMixin.kDefaultStacks

    if Client then
    
        self.clientIsTeleporting = false
        
    elseif Server then
    
        self.isTeleporting = false
        self.destinationEntityId = Entity.invalidId
        self.timeUntilPort = 0
        self.teleportDelay = 0
        
    end
    
end

function TeleportMixin:GetTeleportSinkIn()

    if self.OverrideGetTeleportSinkin then
        return self:OverrideGetTeleportSinkin()
    end
    
    if HasMixin(self, "Extents") then
        return self:GetExtents().y * 2.5
    end    
    
    return TeleportMixin.kDefaultSinkin
    
end   

function TeleportMixin:GetIsTeleporting()
    return self.isTeleporting
end

function TeleportMixin:GetCanTeleport()

    local canTeleport = true
    if self.GetCanTeleportOverride then
        canTeleport = self:GetCanTeleportOverride()
    end
    
    return canTeleport and not self.isTeleporting
    
end

--
-- Forbid the update of model coordinates while we teleport(?)
--
function TeleportMixin:GetForbidModelCoordsUpdate()
    return self.isTeleporting
end

function TeleportMixin:UpdateTeleportClientEffects(deltaTime)

    if self.clientIsTeleporting ~= self.isTeleporting then
    
        self:TriggerEffects("teleport_start", { effecthostcoords = self:GetCoords(), classname = self:GetClassName() })
        self.clientIsTeleporting = self.isTeleporting
        self.clientTimeUntilPort = self.teleportDelay
        
    end
    
    local renderModel = self:GetRenderModel()
    
    if renderModel then
    
        self.clientTimeUntilPort = math.max(0, self.clientTimeUntilPort - deltaTime)

        local sinkCoords = self:GetCoords()
        local teleportFraction = 1 - (self.clientTimeUntilPort / self.teleportDelay)

        sinkCoords.origin = sinkCoords.origin - teleportFraction * self:GetTeleportSinkIn() * sinkCoords.yAxis
        renderModel:SetCoords(sinkCoords)

    end

end

local function GetAttachDestination(self, attachTo, destinationOrigin)

    local attachEntities = GetEntitiesWithinRange(attachTo, destinationOrigin, TeleportMixin.kAttachRange)
    
    for i=1,#attachEntities do
        local ent = attachEntities[i]
        if not ent:GetAttached() and GetInfestationRequirementsMet(self:GetTechId(), ent:GetOrigin()) then
            
            -- free up old attached entity and attach to new
            local attached = self:GetAttached()
            if attached then
                attached:ClearAttached()
            end
            self:ClearAttached()
            
            self:SetAttached(ent)
            
            local attachCoords = ent:GetCoords()
            attachCoords.origin.y = attachCoords.origin.y + LookupTechData(self:GetTechId(), kTechDataSpawnHeightOffset, 0)
            
            return attachCoords
            
        end
    end

end

local function GetRandomSpawn(self, destinationOrigin)

    local extents = self:GetExtents()
    local randomSpawn
    local requiresInfestation = LookupTechData(self:GetTechId(), kTechDataRequiresInfestation, false)
    
    for i = 1, 25 do
    
        randomSpawn = GetRandomSpawnForCapsule(extents.y, extents.x, destinationOrigin, TeleportMixin.kMinRange, TeleportMixin.kMaxRange)
        if randomSpawn and GetInfestationRequirementsMet(self:GetTechId(), randomSpawn) then
            randomSpawn = GetGroundAtPosition(randomSpawn, nil, PhysicsMask.CommanderBuild) --, self:GetExtents())
            return Coords.GetTranslation(randomSpawn)
        end
        
    end

end

local function AddObstacle(self)

    if self.obstacleId == -1 then
        self:AddToMesh()
    end    
       
    return false
 
end

local function PerformTeleport(self)

    local destinationEntity = Shared.GetEntity(self.destinationEntityId)
    
    if destinationEntity then

        local destinationCoords
        local attachTo = LookupTechData(self:GetTechId(), kStructureAttachClass, nil)
        
        -- find a free attach entity
        if attachTo then
            destinationCoords = GetAttachDestination(self, attachTo, self.destinationPos)
        else
            destinationCoords = Coords.GetTranslation(self.destinationPos)
        end
        
        if destinationCoords then

            if HasMixin(self, "Obstacle") then
                self:RemoveFromMesh()
            end
        
            self:SetCoords(destinationCoords)

            if HasMixin(self, "Obstacle") then
                -- this needs to be delayed, otherwise the obstacle is created too early and stacked up structures would not be able to push each other away
                self:AddTimedCallback(AddObstacle, 3)
            end
            
            local location = GetLocationForPoint(self:GetOrigin())
            local locationName = location and location:GetName() or ""
            
            self:SetLocationName(locationName, true)
            
            self:TriggerEffects("teleport_end", { classname = self:GetClassName() })
            
            if self.OnTeleportEnd then
                self:OnTeleportEnd(destinationEntity)
            end

            if self.WakeUp then
                self:WakeUp()
            end
            
            if HasMixin(self, "StaticTarget") then
                self:StaticTargetMoved()
            end

        else
            -- teleport has failed, give back resources to shift

            if destinationEntity then
                destinationEntity:GetTeam():AddTeamResources(self.teleportCost)
            end
        
        end
    
    end
    
    self.destinationEntityId = Entity.invalidId
    self.isTeleporting = false
    self.timeUntilPort = 0
    self.teleportDelay = 0

end

function TeleportMixin:PerformFinalTeleport()

    if self.isTeleporting and self:GetIsAlive() then 
  
        PerformTeleport(self)
        
    end
    return false

end

if Client then

    local function SharedUpdate(self, deltaTime)

        if self.isTeleporting then        
            self:UpdateTeleportClientEffects(deltaTime)
         
        elseif self.clientIsTeleporting then        
            self.clientIsTeleporting = false            
        end
        
    end

    function TeleportMixin:OnUpdate(deltaTime)
        PROFILE("TeleportMixin:OnUpdate")
        SharedUpdate(self, deltaTime)
    end

end

function TeleportMixin:TriggerTeleport(delay, destinationEntityId, destinationPos, cost)

    if Server then
    
        self.teleportDelay = ConditionalValue(delay, delay, TeleportMixin.kDefaultDelay)
        self.timeUntilPort = ConditionalValue(delay, delay, TeleportMixin.kDefaultDelay)
        self.destinationEntityId = destinationEntityId
        self.destinationPos = destinationPos
        self.isTeleporting = true
        self.teleportCost = cost
        
        --Print("%s:TriggerTeleport ", self:GetClassName())
        
        if self.OnTeleport then
            self:OnTeleport()
        end 

        self:AddTimedCallback(TeleportMixin.PerformFinalTeleport, self.teleportDelay)  
        
    end
    
end

function TeleportMixin:OnUpdateAnimationInput(modelMixin)

    modelMixin:SetAnimationInput("isTeleporting", self.isTeleporting)

end