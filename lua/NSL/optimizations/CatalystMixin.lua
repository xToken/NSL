-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/CatalystMixin.lua
-- - Dragon

CatalystMixin = CreateMixin(CatalystMixin)
CatalystMixin.type = "Catalyst"

CatalystMixin.kDefaultDuration = 10
CatalystMixin.kCatalystSpeedUp = 0.7

CatalystMixin.kEffectIntervall = 1.5
CatalystMixin.kEffectName = "catalyst"

CatalystMixin.kHealPercentage = .03
CatalystMixin.kHealInterval = 2
CatalystMixin.kHealCheckInterval = 0.25
CatalystMixin.kHealEffectInterval = 1
CatalystMixin.kMaxHealTargets = 3

CatalystMixin.optionalCallbacks = {

    OnCatalyst = "Called when catalyst is triggered.",
    OnCatalystEnd = "Called at catalyst time out."

}

CatalystMixin.networkVars = {
    isCatalysted = "boolean"
}

function CatalystMixin:__initmixin()
    
    PROFILE("CatalystMixin:__initmixin")
    
    self.maxCatalystStacks = CatalystMixin.kDefaultCatalystStacks

    if Client then

        self.isCatalystedClient = false
        self:AddFieldWatcher("isCatalysted", CatalystMixin.TriggerClientSideEffects)

    elseif Server then

        self.isCatalysted = false
        self.timeUntilCatalystEnd = 0

    end

end

function CatalystMixin:GetCatalystScalar()

    if self.isCatalysted then
        return 1
    end

    return 0

end

function CatalystMixin:GetIsCatalysted()
    return self.isCatalysted
end

local function NeedsHealing(ent)
    return ent.AmountDamaged and ent:AmountDamaged() > 0
end

function CatalystMixin:GetCanCatalyst()
    local canBeMatured = ( HasMixin(self, "Maturity") and not self:GetIsMature() )
    local canEvolveFaster = self:isa("Embryo")
    local canBeHealed = self.GetCanCatalyzeHeal and self:GetCanCatalyzeHeal() and NeedsHealing(self)

    local requiresInfestation = not self:isa("Player") and ConditionalValue(self:isa("Whip"), false, LookupTechData(self:GetTechId(), kTechDataRequiresInfestation))
    local canStopStarving = requiresInfestation and not self:GetGameEffectMask(kGameEffect.OnInfestation)
    local canPreventImmaturity = self.maturityStarvation == true

    return canBeMatured or canEvolveFaster or canBeHealed or canStopStarving or canPreventImmaturity
end

if Client then

    function CatalystMixin:UpdateCatalystClientEffects(deltaTime)

        local now = Shared.GetTime()

        local player = Client.GetLocalPlayer()

        if player and player == self and not player:GetIsThirdPerson() then
            return
        end

        local showEffect = not GetAreEnemies(self, player) or ( not self:isa("Player") and (not HasMixin(self, "Cloakable") or not self:GetIsCloaked()) )

        if showEffect then
            self:TriggerEffects(CatalystMixin.kEffectName)
        end

        return self.isCatalysted

    end

end

function CatalystMixin:TriggerClientSideEffects()

    if self.isCatalysted then

        if self.OnCatalyst then
            self:OnCatalyst()
        end
        self:AddTimedCallback(CatalystMixin.UpdateCatalystClientEffects, CatalystMixin.kEffectIntervall)

    else

        if self.OnCatalystEnd then
            self:OnCatalystEnd()
        end

    end

    return true
end

CatalystMixin.OnProcessMove = nil
CatalystMixin.OnUpdate = nil

function CatalystMixin:UpdateCatalystEffects()

    if self.shouldHeal then
        self:AddHealth(self:GetMaxHealth() * CatalystMixin.kHealPercentage)
    end

    if self.timeCatalystEnds < Shared.GetTime() then
        self.isCatalysted = false
        self.shouldHeal = false
        if self.OnCatalystEnd then
            self:OnCatalystEnd()
        end
    end
    return self.isCatalysted

end

function CatalystMixin:TriggerCatalyst(duration, shouldHeal)

    if Server and self:GetCanCatalyst() then
        local wasCatalyzed = self.isCatalysted
        self.timeUntilCatalystEnd = ConditionalValue(duration ~= nil, duration, CatalystMixin.kDefaultDuration)
        self.timeCatalystEnds = Shared.GetTime() + self.timeUntilCatalystEnd
        self.isCatalysted = true
        self.shouldHeal = shouldHeal or false
        if not wasCatalyzed then
            self:AddTimedCallback(CatalystMixin.UpdateCatalystEffects, self.timeUntilCatalystEnd)
        end
        if self.OnCatalyst then
            self:OnCatalyst()
        end
    end

end

function CatalystMixin:CopyPlayerDataFrom(player)

    if player.isCatalysted then
        self:TriggerCatalyst(math.max(player.timeCatalystEnds - Shared.GetTime(), 1))
    end

end