-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/CorrodeMixin.lua
-- - Dragon

CorrodeMixin = CreateMixin( CorrodeMixin )
CorrodeMixin.type = "Corrode"

PrecacheAsset("cinematics/vfx_materials/bilebomb.surface_shader")
PrecacheAsset("cinematics/vfx_materials/bilebomb_exoview.surface_shader")

local kBilebombMaterial = PrecacheAsset("cinematics/vfx_materials/bilebomb.material")
local kBilebombExoMaterial = PrecacheAsset("cinematics/vfx_materials/bilebomb_exoview.material")

CorrodeMixin.networkVars =
{
    isCorroded = "boolean"
}

local kCorrodeShaderDuration = 4

local function CorrodeOnInfestationOrInGorgeTunnel(self)

    if self.updateInitialInfestationCorrodeState and GetIsPointOnInfestation(self:GetOrigin()) then
    
        self:SetGameEffectMask(kGameEffect.OnInfestation, true)
        self.updateInitialInfestationCorrodeState = false
        
    end

    if not self:isa("Player") and not self:isa("MAC") and not self:isa("Exosuit") then

	    if self:GetMaxArmor() > 0 and self:GetGameEffectMask(kGameEffect.OnInfestation) and self:GetCanTakeDamage() and (not HasMixin(self, "GhostStructure") or not self:GetIsGhostStructure()) then
	        
	        self:SetCorroded()
	        
	        if self:isa("PowerPoint") and self:GetArmor() > 0 then
	            self:DoDamageLighting()
	        end
	        
	        if not self:isa("PowerPoint") or self:GetArmor() > 0 then
	            -- stop damaging power nodes when armor reaches 0... gets annoying otherwise.
	            self:DeductHealth(kInfestationCorrodeDamagePerSecond, nil, nil, false, true, true)
	        end
	        
	    end

	else

	    if GetIsPointInGorgeTunnel(self:GetOrigin()) then
	        
	        -- drain armor only
	        self:DeductHealth(kGorgeArmorTunnelDamagePerSecond, nil, nil, false, true)
	        
	        self:SetCorroded()

	    end

	end

    if self.isCorroded and self.timeCorrodeStarted + kCorrodeShaderDuration < Shared.GetTime() then        
        self.isCorroded = false   
    end

    return self:GetIsAlive()

end

local function UpdateCorrodeMaterial(self)

    if self._renderModel then
    
        if self.isCorroded and not self.corrodeMaterial then

            local material = Client.CreateRenderMaterial()
            material:SetMaterial(kBilebombMaterial)
            
            if self:isa("Player") then
                material:SetParameter("highlight", 1)
            end

            local viewMaterial = Client.CreateRenderMaterial()
            if self:isa("Exo") then
                viewMaterial:SetMaterial(kBilebombExoMaterial)
            else
                viewMaterial:SetMaterial(kBilebombMaterial)
            end
            
            self.corrodeEntities = {}
            self.corrodeMaterial = material
            self.corrodeMaterialViewMaterial = viewMaterial
            AddMaterialEffect(self, material, viewMaterial, self.corrodeEntities)
        
        elseif not self.isCorroded and self.corrodeMaterial then

            RemoveMaterialEffect(self.corrodeEntities, self.corrodeMaterial, self.corrodeMaterialViewMaterial)
            Client.DestroyRenderMaterial(self.corrodeMaterial)
            Client.DestroyRenderMaterial(self.corrodeMaterialViewMaterial)
            self.corrodeMaterial = nil
            self.corrodeMaterialViewMaterial = nil
            self.corrodeEntities = nil
            
        end
        
    end

    return true
    
end

function CorrodeMixin:__initmixin()
    
    PROFILE("CorrodeMixin:__initmixin")
    
    if Server then
        
        self.isCorroded = false
        self.timeCorrodeStarted = 0
        
        if not self:isa("MAC") and (kCorrodeMarineStructureArmorOnInfestation or self:isa("Player") or self:isa("Exosuit")) then
        
            self:AddTimedCallback(CorrodeOnInfestationOrInGorgeTunnel, 1)
            self.updateInitialInfestationCorrodeState = true
            
        end
        
    end

    if Client then

    	self:AddFieldWatcher("isCorroded", UpdateCorrodeMaterial)

    end
    
end

function CorrodeMixin:OnDestroy()
    
    if Client and self.corrodeMaterial then
        Client.DestroyRenderMaterial(self.corrodeMaterial)
        self.corrodeMaterial = nil
    end    
    
end

function CorrodeMixin:OnTakeDamage(damage, attacker, doer, point, direction)

    if Server then
    
        if doer and doer.GetDamageType and doer:GetDamageType() == kDamageType.Corrode then
            self:SetCorroded()
        end
    
    end
    
end

if Server then

    function CorrodeMixin:SetCorroded()
        self.isCorroded = true
        self.timeCorrodeStarted = Shared.GetTime()
    end
    
end

CorrodeMixin.OnUpdate = nil
CorrodeMixin.OnProcessMove = nil

if Server then

    function OnCommandCorrode(client)

        if Shared.GetCheatsEnabled() then
            
            local player = client:GetControllingPlayer()
            if player.SetCorroded then
                player:SetCorroded()
            end
            
        end

    end

    Event.Hook("Console_corrode",                 OnCommandCorrode)

end