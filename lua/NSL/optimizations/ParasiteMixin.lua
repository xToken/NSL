-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/ParasiteMixin.lua
-- - Dragon

ParasiteMixin = CreateMixin( ParasiteMixin )
ParasiteMixin.type = "ParasiteAble"

PrecacheAsset("cinematics/vfx_materials/parasited.surface_shader")
local kParasitedMaterial = PrecacheAsset("cinematics/vfx_materials/parasited.material")

ParasiteMixin.expectedMixins =
{
    Live = "ParasiteMixin makes only sense if this entity can take damage (has LiveMixin).",
}

ParasiteMixin.optionalCallbacks =
{
    GetCanBeParasitedOverride = "Return true or false if the entity has some specific conditions under which nano shield is allowed."
}

ParasiteMixin.networkVars =
{
    parasited = "boolean",
    timeParasited = "private time",
    parasiteDuration = "private float (0 to 999 by 0.1)" --TODO Move to MAX global var?
}

function ParasiteMixin:__initmixin()
    
    PROFILE("ParasiteMixin:__initmixin")
    
    self.timeParasited = 0
    self.parasiteDuration = 0
    self.parasited = false

    if Client then

        self:AddFieldWatcher("parasited", ParasiteMixin.UpdateClientEffect)

    end
    
end

function ParasiteMixin:OnTakeDamage(_, attacker, doer, _, _)

    if doer and doer:isa("Parasite") and GetAreEnemies(self, attacker) then
        self:SetParasited(attacker)
    end

end

function ParasiteMixin:GetParasitePercentageRemaining()

    local percentLeft = 0
    
    if self.parasited and self.parasiteDuration > 0 then
        percentLeft = Clamp( math.abs( (self.timeParasited + self.parasiteDuration) - Shared.GetTime() ) / self.parasiteDuration, 0.0, 1.0 )
    end
    
    return percentLeft

end

function ParasiteMixin:SetParasited( fromPlayer, durationOverride )

    if Server then

        if not self.GetCanBeParasitedOverride or self:GetCanBeParasitedOverride() then
        
            if not self.parasited and self.OnParasited then
            
                self:OnParasited()
                
                if fromPlayer and HasMixin(fromPlayer, "Scoring") and self:isa("Player") then
                    fromPlayer:AddScore(kParasitePlayerPointValue)
                end
                
            end
            
            local parasiteTimeChanged = false
            
            if durationOverride ~= nil and type(durationOverride) == "number" then
                
                durationOverride = Clamp( durationOverride, 0, kParasiteDuration )
                
                if self.parasited and self.timeParasited + durationOverride >= self.parasiteDuration + self.timeParasited then
                    
                    self.parasiteDuration = durationOverride
                    parasiteTimeChanged = true
                    
                elseif not self.parasited then
                    
                    self.parasiteDuration = durationOverride
                    parasiteTimeChanged = true
                    
                end
                
            else
                
                self.parasiteDuration = kParasiteDuration
                parasiteTimeChanged = true
                
            end
            
            if parasiteTimeChanged then
                self.timeParasited = Shared.GetTime()
            end
            
            self.parasited = true

            self:AddTimedCallback(ParasiteMixin.UpdateParasiteState, self.parasiteDuration)
            
        end
    
    end

end

function ParasiteMixin:TransferParasite(from)
    
    self.parasiteDuration = from.parasiteDuration
    self.timeParasited = from.timeParasited
    self.parasited = from.parasited
    
    if self.OnParasited and not self.parasited then
        self:OnParasited()
    end
    
end

function ParasiteMixin:OnDestroy()

    if Client then
        self:_RemoveParasiteEffect()
    end
    
end

if Server then

    function ParasiteMixin:OnKill()
        self:RemoveParasite()
    end

end

function ParasiteMixin:GetIsParasited()
    return self.parasited
end

function ParasiteMixin:RemoveParasite()
    self.parasited = false
end

function ParasiteMixin:UpdateParasiteState()

    if not self.parasited then
        return
    end
    
    -- See if parsited time is over
    if self.parasiteDuration > 0 and self.timeParasited + self.parasiteDuration < Shared.GetTime() then
        
        self.parasited = false
        self.parasiteDuration = 0
        
        if self.OnParasiteRemoved then
            self:OnParasiteRemoved()
        end
        
    end

    return false

end

ParasiteMixin.OnUpdate = nil
ParasiteMixin.OnProcessMove = nil

if Client then

    function ParasiteMixin:UpdateClientEffect()

        if self:GetIsParasited() and self:GetIsAlive() and self:isa("Player") and not self:isa("Commander") then
            self:_CreateParasiteEffect()
        else
            self:_RemoveParasiteEffect() 
        end

        return true

    end

    -- Adds the material effect to the entity and all child entities (hat have a Model mixin)
    local function AddEffect(entity, material, viewMaterial, entities)
    
        -- local numChildren = entity:GetNumChildren()
        
        if HasMixin(entity, "Model") then
            local model = entity._renderModel
            if model ~= nil then
                if model:GetZone() == RenderScene.Zone_ViewModel then
                
                    if viewMaterial then                
                        model:AddMaterial(viewMaterial)
                    end
                    
                else
                    model:AddMaterial(material)
                end
                table.insert(entities, entity:GetId())
            end
        end
        
        for i = 1, entity:GetNumChildren() do
            local child = entity:GetChildAtIndex(i - 1)
            if child ~= nil then
                AddEffect(child, material, viewMaterial, entities)
            end
        end
    
    end
    
    local function RemoveEffect(entities, material, viewMaterial)
    
        for i =1, #entities do
            local entity = Shared.GetEntity( entities[i] )
            if entity ~= nil and HasMixin(entity, "Model") then
                local model = entity._renderModel
                if model ~= nil then
                    if model:GetZone() == RenderScene.Zone_ViewModel then
                        
                        if viewMaterial then                    
                            model:RemoveMaterial(viewMaterial)
                        end
                        
                    else
                        model:RemoveMaterial(material)
                    end
                end                    
            end
        end
        
    end
    
    function ParasiteMixin:OnModelChanged(_)
        self:_RemoveParasiteEffect()
    end

    function ParasiteMixin:_CreateParasiteEffect()
   
        if not self.parasiteMaterial then
        
            local material = Client.CreateRenderMaterial()
            material:SetMaterial(kParasitedMaterial)

            local showViewMaterial = not self.GetShowParasiteView or self:GetShowParasiteView()
            local viewMaterial

            if showViewMaterial then

                viewMaterial = Client.CreateRenderMaterial()
                viewMaterial:SetMaterial(kParasitedMaterial)
            
            end
            
            self.parasiteEntities = {}
            self.parasiteMaterial = material
            self.parasiteViewMaterial = viewMaterial
            AddEffect(self, material, viewMaterial, self.parasiteEntities)
            
        end    
        
    end

    function ParasiteMixin:_RemoveParasiteEffect()

        if self.parasiteMaterial then
        
            RemoveEffect(self.parasiteEntities, self.parasiteMaterial, self.parasiteViewMaterial)
            Client.DestroyRenderMaterial(self.parasiteMaterial)
            self.parasiteMaterial = nil
            self.parasiteEntities = nil
            
        end

        if self.parasiteViewMaterial then
            
            Client.DestroyRenderMaterial(self.parasiteViewMaterial)
            self.parasiteViewMaterial = nil
            
        end        

    end

end

---------------------------------------

Event.Hook("Console_debugparasite",
    function()
        if Shared.GetCheatsEnabled() or Shared.GetTestsEnabled() then
            --TODO Get entity of local client
            --TODO check for ParasiteMixin (or fields?)
            --TODO Dump data about parasite-state
        end
    end
)
