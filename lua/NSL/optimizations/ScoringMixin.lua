-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/optimizations/ScoringMixin.lua
-- - Dragon

local function SharedUpdate(self, deltaTime)
    
    if not self.commanderTime then
        self.commanderTime = 0
    end
    
    if not self.playTime then
        self.playTime = 0
    end
    
    if not self.marineTime then
        self.marineTime = 0
    end
    
    if not self.alienTime then
        self.alienTime = 0
    end    
    
    if self:GetIsPlaying() then
    
        if self:isa("Commander") then
            self.commanderTime = self.commanderTime + deltaTime
        end
        
        self.playTime = self.playTime + deltaTime
        
        if self:GetTeamType() == kMarineTeamType then
            self.marineTime = self.marineTime + deltaTime
        end
        
        if self:GetTeamType() == kAlienTeamType then
            self.alienTime = self.alienTime + deltaTime
        end
    
    end

    return true

end

function ScoringMixin:__initmixin()
    
    PROFILE("ScoringMixin:__initmixin")
    
    self.score = 0
    -- Some types of points are added continuously. These are tracked here.
    self.continuousScores = { }
    
    self.serverJoinTime = Shared.GetTime()

    self.playerLevel = -1
    self.totalXP = -1
    self.playerSkill = -1
    self.adagradSum = 0
    
    self.weightedEntranceTimes = {}
    self.weightedEntranceTimes[kTeam1Index] = {}
    self.weightedEntranceTimes[kTeam2Index] = {}
    
    self.weightedExitTimes = {}
    self.weightedExitTimes[kTeam1Index] = {}
    self.weightedExitTimes[kTeam2Index] = {}

    if Server then
        self:AddTimedCallback(SharedUpdate, 1)
    end
    
end

function ScoringMixin:OnProcessMove(input)
    -- This is kinda dumb, but meh.  NS2+ hooks the sharedupdate, but we dont want it to get actually called here.  We will call it from the timedcallback
    if false then
        SharedUpdate(self, input.time)
    end
end