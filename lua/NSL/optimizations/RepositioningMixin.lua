-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/RepositioningMixin.lua
-- - Dragon

function RepositioningMixin:ToggleRepositioning()

    self.initialSpaceChecked = true

    if self.isRepositioning then
        return false
    end
    
    local entitiesInRange = GetEntitiesWithMixinForTeamWithinRange("Repositioning", self:GetTeamNumber(), self:GetOrigin(), self:GetRepositioningDistance())
    local baseYaw = 0

    for i, entity in ipairs(entitiesInRange) do
        
        if entity:GetCanReposition() and entity ~= self then
            
            entity.isRepositioning = true
            if entity.WakeUp then
                entity:WakeUp()
            end
            entity.timeLeftForReposition = self:GetRepositioningTime()
            
            baseYaw = entity:FindBetterPosition( GetYawFromVector(entity:GetOrigin() - self:GetOrigin()), baseYaw, 0 )
            
        end
        
    end
    
    return true
    
end