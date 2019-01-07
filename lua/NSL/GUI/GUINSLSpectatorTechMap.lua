-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\GUINSLSpectatorTechMap.lua
-- - Dragon

class 'GUINSLSpectatorTechMap' (GUITechMap)

local teamNumberOverride

-- Cheaty override
local oldPlayerUI_GetTeamType = PlayerUI_GetTeamType
function PlayerUI_GetTeamType()
    if teamNumberOverride then
        return teamNumberOverride == 1 and kMarineTeamType or kAlienTeamType
    end
    return oldPlayerUI_GetTeamType()
end

function GUINSLSpectatorTechMap:Initialize()
    -- Default to Marines
    self.teamNumber = self.teamNumber and self.teamNumber or 1

    --Hacky override go!
    teamNumberOverride = self.teamNumber

    -- Remember the setting, we will restore this after
    local lastTechMapButton = self.techMapButton

    -- Init default GUITechMap
    GUITechMap.Initialize(self, self.teamNumber)

    -- Restore if not null
    self.techMapButton = lastTechMapButton and lastTechMapButton or self.techMapButton

    -- Hack override retreat!
    teamNumberOverride = nil

    -- Request the tech tree for this team
    Client.SendNetworkMessage("RequestTeamTechTree", {teamNumber = self.teamNumber}, true)
end

local function InitializeTeamTechTree(self, teamNum)
    -- Update team number
    self.teamNumber = teamNum

    -- Clear
    GUITechMap.Uninitialize(self)

    -- Re-Init
    self:Initialize()
end

function GUINSLSpectatorTechMap:Uninitialize()

    GUITechMap.Uninitialize(self)
	
	Client.SendNetworkMessage("RequestTeamTechTree", {teamNumber = 0}, true)

	ClearTechTree()

end

function GUINSLSpectatorTechMap:SendKeyEvent(key, down)

	local success = false
    if GetIsBinding(key, "ShowTechMap") then
        self.techMapButton = down
    end
	if key == InputKey.Num1 and self.techMapButton and down and self.teamNumber ~= 1 then
		InitializeTeamTechTree(self, 1)
		success = true
	end
	if key == InputKey.Num2 and self.techMapButton and down and self.teamNumber ~= 2 then
		InitializeTeamTechTree(self, 2)
		success = true
	end
	return success

end

function GUINSLSpectatorTechMap:Update(deltaTime)
    teamNumberOverride = self.teamNumber
    GUITechMap.Update(self, deltaTime)
    teamNumberOverride = nil
end