-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/NanoShieldMixin.lua
-- - Dragon

NanoShieldMixin = CreateMixin( NanoShieldMixin )
NanoShieldMixin.type = "NanoShieldAble"

PrecacheAsset("cinematics/vfx_materials/nanoshield.surface_shader")
PrecacheAsset("cinematics/vfx_materials/nanoshield_view.surface_shader")
PrecacheAsset("cinematics/vfx_materials/nanoshield_exoview.surface_shader")

local kNanoShieldStartSound = PrecacheAsset("sound/NS2.fev/marine/commander/nano_shield_3D")
local kNanoLoopSound = PrecacheAsset("sound/NS2.fev/marine/commander/nano_loop")
local kNanoDamageSound = PrecacheAsset("sound/NS2.fev/marine/commander/nano_damage")

local kNanoshieldMaterial = PrecacheAsset("cinematics/vfx_materials/nanoshield.material")
local kNanoshieldExoViewMaterial = PrecacheAsset("cinematics/vfx_materials/nanoshield_exoview.material")
local kNanoshieldViewMaterial = PrecacheAsset("cinematics/vfx_materials/nanoshield_view.material")

-- These are functions that override existing same-named functions instead
-- of the default case of combining with them.
NanoShieldMixin.overrideFunctions =
{
    "ComputeDamageOverride"
}

NanoShieldMixin.expectedMixins =
{
    Live = "NanoShieldMixin makes only sense if this entity can take damage (has LiveMixin).",
}

NanoShieldMixin.optionalCallbacks =
{
    GetCanBeNanoShieldedOverride = "Return true or false if the entity has some specific conditions under which nano shield is allowed.",
    GetNanoShieldOffset = "Return a vector defining an offset for the nano shield effect"
}

NanoShieldMixin.networkVars =
{
    nanoShielded = "boolean",
    timeNanoShieldInit = "private time",
}

function NanoShieldMixin:__initmixin()
    
    PROFILE("NanoShieldMixin:__initmixin")
    
    if Server then
    
        self.timeNanoShieldInit = 0
        self.nanoShielded = false
        
    end

    if Client then

        self:AddFieldWatcher("nanoShielded", NanoShieldMixin.UpdateClientNanoShieldEffects)

    end
    
end

local function ClearNanoShield(self, destroySound)

    self.nanoShielded = false
    self.timeNanoShieldInit = 0    
    
    if Client then
        self:_RemoveEffect()
    end
    
    if Server and self.shieldLoopSound and destroySound then
        DestroyEntity(self.shieldLoopSound)
    end
    
    self.shieldLoopSound = nil
    
end

function NanoShieldMixin:OnDestroy()

    if self:GetIsNanoShielded() then
        ClearNanoShield(self, false)
    end
    
end

function NanoShieldMixin:OnTakeDamage(damage, attacker, doer, point)

    if self:GetIsNanoShielded() then
        StartSoundEffectAtOrigin(kNanoDamageSound, self:GetOrigin())
    end
    
end

function NanoShieldMixin:ActivateNanoShield()

    if self:GetCanBeNanoShielded() then
    
        self.timeNanoShieldInit = Shared.GetTime()
        self.nanoShielded = true
        
        if Server then
        
            assert(self.shieldLoopSound == nil)
            self.shieldLoopSound = Server.CreateEntity(SoundEffect.kMapName)
            self.shieldLoopSound:SetAsset(kNanoLoopSound)
            self.shieldLoopSound:SetParent(self)
            self.shieldLoopSound:Start()
            
            StartSoundEffectOnEntity(kNanoShieldStartSound, self)

            self:AddTimedCallback(NanoShieldMixin.CheckandClearNanoShield, kNanoShieldDuration)
            
        end
        
    end
    
end

function NanoShieldMixin:GetIsNanoShielded()
    return self.nanoShielded
end

function NanoShieldMixin:GetNanoShieldTimeRemaining()
    local percentLeft = 0

    if self.nanoShielded then
        percentLeft = Clamp( math.abs( (self.timeNanoShieldInit + kNanoShieldDuration) - Shared.GetTime() ) / kNanoShieldDuration, 0.0, 1.0 )
    end

    return percentLeft
end

function NanoShieldMixin:GetCanBeNanoShielded()

    local resultTable = { shieldedAllowed = not self.nanoShielded }
    
    if self.GetCanBeNanoShieldedOverride then
        self:GetCanBeNanoShieldedOverride(resultTable)
    end
    
    return resultTable.shieldedAllowed
    
end

function NanoShieldMixin:CheckandClearNanoShield()
    
    ClearNanoShield(self, true)
    return false

end

function NanoShieldMixin:ComputeDamageOverrideMixin(attacker, damage, damageType, time)

    if self.nanoShielded == true then
        return damage * kNanoShieldDamageReductionDamage, damageType
    end
    
    return damage
    
end

NanoShieldMixin.OnUpdate = nil
NanoShieldMixin.OnProcessMove = nil

if Client then

    -- Adds the material effect to the entity and all child entities (hat have a Model mixin)
    local function AddEffect(entity, material, viewMaterial, entities)
    
        local numChildren = entity:GetNumChildren()
        
        if HasMixin(entity, "Model") then
            local model = entity._renderModel
            if model ~= nil then
                if model:GetZone() == RenderScene.Zone_ViewModel then
                    model:AddMaterial(viewMaterial)
                else
                    model:AddMaterial(material)
                end
                table.insert(entities, entity:GetId())
            end
        end
        
        for i = 1, entity:GetNumChildren() do
            local child = entity:GetChildAtIndex(i - 1)
            AddEffect(child, material, viewMaterial, entities)
        end
    
    end
    
    local function RemoveEffect(entities, material, viewMaterial)
    
        for i =1, #entities do
            local entity = Shared.GetEntity( entities[i] )
            if entity ~= nil and HasMixin(entity, "Model") then
                local model = entity._renderModel
                if model ~= nil then
                    if model:GetZone() == RenderScene.Zone_ViewModel then
                        model:RemoveMaterial(viewMaterial)
                    else
                        model:RemoveMaterial(material)
                    end
                end                    
            end
        end
        
    end

    function NanoShieldMixin:_CreateEffect()
   
        if not self.nanoShieldMaterial then
        
            local material = Client.CreateRenderMaterial()
            material:SetMaterial(kNanoshieldMaterial)

            local viewMaterial = Client.CreateRenderMaterial()
            
            if self:isa("Exo") then
                viewMaterial:SetMaterial(kNanoshieldExoViewMaterial)
            else
                viewMaterial:SetMaterial(kNanoshieldViewMaterial)
            end    
            
            self.nanoShieldEntities = {}
            self.nanoShieldMaterial = material
            self.nanoShieldViewMaterial = viewMaterial
            AddEffect(self, material, viewMaterial, self.nanoShieldEntities)
            
        end    
        
    end

    function NanoShieldMixin:_RemoveEffect()

        if self.nanoShieldMaterial then
            RemoveEffect(self.nanoShieldEntities, self.nanoShieldMaterial, self.nanoShieldViewMaterial)
            Client.DestroyRenderMaterial(self.nanoShieldMaterial)
            Client.DestroyRenderMaterial(self.nanoShieldViewMaterial)
            self.nanoShieldMaterial = nil
            self.nanoShieldViewMaterial = nil
            self.nanoShieldEntities = nil
        end            

    end

    function NanoShieldMixin:UpdateClientNanoShieldEffects()

        if self:GetIsNanoShielded() and self:GetIsAlive() then
            self:_CreateEffect()
        else
            self:_RemoveEffect() 
        end

        return true
        
    end
    
end