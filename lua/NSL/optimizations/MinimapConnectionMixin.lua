-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/UmbraMixin.lua
-- - Dragon

Script.Load("lua/MapConnector.lua")

MinimapConnectionMixin = CreateMixin( MinimapConnectionMixin )
MinimapConnectionMixin.type = "MinimapConnection"

MinimapConnectionMixin.expectedMixins =
{
    Team = "For team number."
}

MinimapConnectionMixin.expectedCallbacks =
{
    GetConnectionStartPoint = "For map connector.",
    GetConnectionEndPoint = "For map connector."
}

local kUpdateRate = 0.5

function MinimapConnectionMixin:__initmixin()
    if Server then
        self:AddTimedCallback(MinimapConnectionMixin.OnTimedUpdate, kUpdateRate)
    end
end

if Server then

    function MinimapConnectionMixin:OnTimedUpdate(deltaTime)

        local endPoint = self:GetConnectionEndPoint()
        local startPoint = self:GetConnectionStartPoint()
        
        if (not endPoint or not startPoint) and self.connectorId then
        
            local connector = Shared.GetEntity(self.connectorId)
            if connector then
                DestroyEntity(connector)
            end
            
            self.connectorId = nil
        
        elseif endPoint and startPoint and not self.connectorId then
            self.connectorId = CreateEntity(MapConnector.kMapName, startPoint, self:GetTeamNumber()):GetId()
        end
        
        if endPoint and startPoint and self.connectorId then
        
            local connector = Shared.GetEntity(self.connectorId)
            assert(connector)
            connector:SetOrigin(startPoint)
            connector:SetEndPoint(endPoint)
        
        end

        return true
    
    end
    
    function MinimapConnectionMixin:OnDestroy()
    
        if self.connectorId then
        
            local connector = Shared.GetEntity(self.connectorId)
            if connector then
                DestroyEntity(connector)
            end
            
            self.connectorId = nil
        
        end
    
    end

end