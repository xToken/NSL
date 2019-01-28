-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/UmbraMixin.lua
-- - Dragon

UmbraMixin = CreateMixin( UmbraMixin )
UmbraMixin.type = "Umbra"

UmbraMixin.kSegment1Cinematic = PrecacheAsset("cinematics/alien/crag/umbraTrail1.cinematic")
UmbraMixin.kSegment2Cinematic = PrecacheAsset("cinematics/alien/crag/umbraTrail2.cinematic")
UmbraMixin.kViewModelCinematic = PrecacheAsset("cinematics/alien/crag/umbra_1p.cinematic")

local kMaterialName = PrecacheAsset("cinematics/vfx_materials/umbra.material")
local kViewMaterialName = PrecacheAsset("cinematics/vfx_materials/umbra_view.material")

PrecacheAsset("cinematics/vfx_materials/umbra.surface_shader")
PrecacheAsset("cinematics/vfx_materials/umbra_view.surface_shader")
PrecacheAsset("cinematics/vfx_materials/2em_1mask_1norm_scroll_refract_tint.surface_shader")

local kEffectInterval = 0.1
local kStaticEffectInterval = .34

UmbraMixin.expectedMixins =
{
}

UmbraMixin.networkVars =
{
    -- as an override for the gameeffect mask
    dragsUmbra = "boolean",
}

local kUmbraModifier = {}
kUmbraModifier["Shotgun"] = kUmbraShotgunModifier
kUmbraModifier["Rifle"] = kUmbraBulletModifier
kUmbraModifier["HeavyMachineGun"] = kUmbraBulletModifier
kUmbraModifier["Pistol"] = kUmbraBulletModifier
kUmbraModifier["Sentry"] = kUmbraBulletModifier
kUmbraModifier["Minigun"] = kUmbraMinigunModifier
kUmbraModifier["Railgun"] = kUmbraRailgunModifier

function UmbraMixin:__initmixin()
    
    PROFILE("UmbraMixin:__initmixin")
    
    self.dragsUmbra = false
    umbraBulletCount = 0
    self.timeUmbraExpires = 0
    
    if Client then
        self.timeLastUmbraEffect = 0
        self.umbraIntensity = 0
        self:AddFieldWatcher("dragsUmbra", UmbraMixin.TriggerClientSideUmbraEffects)
    end
    
end

function UmbraMixin:GetHasUmbra()
    return self.dragsUmbra
end

if Server then

    function UmbraMixin:SetOnFire()
        self.dragsUmbra = false
        self.timeUmbraExpires = 0
    end

    function UmbraMixin:CheckAndClearUmbraFlag()
        self.dragsUmbra = self.timeUmbraExpires > Shared.GetTime()
        return false
    end

    function UmbraMixin:SetHasUmbra(state, umbraTime, force)
    
        if HasMixin(self, "Live") and not self:GetIsAlive() then
            return
        end
        
        if HasMixin(self, "Fire") and self:GetIsOnFire() then
            return
        end
    
        self.dragsUmbra = state
        
        if not umbraTime then
            umbraTime = 0
        end
        
        if self.dragsUmbra then        
            self.timeUmbraExpires = Shared.GetTime() + umbraTime
            self:AddTimedCallback(UmbraMixin.CheckAndClearUmbraFlag, umbraTime)
        end
        
    end
    
end

function UmbraMixin:TriggerClientSideUmbraEffects()
    if self:GetHasUmbra() then
        self:AddTimedCallback(UmbraMixin.UpdateClientSideUmbraEffects, kEffectInterval)
    end
    return true
end

function UmbraMixin:UpdateClientSideUmbraEffects(deltaTime)

    if self:GetHasUmbra() then
    
        local effectInterval = kStaticEffectInterval
        if self.lastOrigin ~= self:GetOrigin() then
            effectInterval = kEffectInterval
            self.lastOrigin = self:GetOrigin()
        end

        if self.timeLastUmbraEffect + effectInterval < Shared.GetTime() then
        
            local coords = self:GetCoords()
            
            if HasMixin(self, "Target") then
                coords.origin = self:GetEngagementPoint()
            end
        
            self:TriggerEffects("umbra_drag", { effecthostcoords = coords } )
            self.timeLastUmbraEffect = Shared.GetTime()
        end
        
        self.umbraIntensity = 1
        
    else
    
        self.umbraIntensity = math.max(0, self.umbraIntensity - deltaTime * .5)
    
    end

    return self.umbraIntensity > 0

end

function UmbraMixin:OnUpdateRender()

    local model = self:GetRenderModel()
    if model then
    
        if not self.umbraMaterial then        
            self.umbraMaterial = AddMaterial(model, kMaterialName)  
        end
        
        self.umbraMaterial:SetParameter("intensity", self.umbraIntensity)
    
    end
    
    local viewModel = self.GetViewModelEntity and self:GetViewModelEntity() and self:GetViewModelEntity():GetRenderModel()
    if viewModel then
    
        if not self.umbraViewMaterial then        
            self.umbraViewMaterial = AddMaterial(viewModel, kViewMaterialName)        
        end
        
        self.umbraViewMaterial:SetParameter("intensity", self.umbraIntensity)
    
    end

end

function UmbraMixin:ModifyDamageTaken(damageTable, attacker, doer, damageType)

    if self:GetHasUmbra() then
    
        local modifier = 1
        if doer then        
            modifier = kUmbraModifier[doer:GetClassName()] or 1        
        end
    
        damageTable.damage = damageTable.damage * modifier
        
    end
    

end

