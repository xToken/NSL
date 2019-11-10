-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\GUINSLSpectatorTechMap.lua
-- - Dragon

class 'GUINSLSpawnSelectionMenu' (GUIScript)

local kBackgroundColor = Color(0.0, 0.0, 0.0, 0.7)
local kTitleColor = Color(0.08, 0.16, 0.26, 1)
local kTitleTextColor = Color(0.28, 0.36, 0.46, 1)
local kOptionColor = Color(0.7, 0.7, 0.7, 1)
local kOptionSelectedColor = Color(1, 1, 1, 1)
local kOptionChoosen = Color(0, 1, 0, 1)

local kOptionOffset = Vector(0, 15, 0)
local kTitleVoteOffset = Vector(0, 8, 0)
local kSpawnBackgroundSize = Vector(200, 175, 0)
local kTitleBackgroundSize = Vector(198, 20, 0)
local kSpawnTextFont = Fonts.kAgencyFB_Small

local kSelectionDelay = 1

function GetRelevantTechPoints()
    
    local gameInfo = GetGameInfoEntity()
    local selectedIndex = 10
    if gameInfo:GetSpawnSelectionEnabled() then
        local allowableSpawns = { }
        local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
        for _, currentTechPoint in ipairs(techPoints) do
            if currentTechPoint:GetTeamNumberAllowed() == 0 or currentTechPoint:GetTeamNumberAllowed() == 2 then
                table.insert(allowableSpawns, currentTechPoint:GetLocationName())
                if currentTechPoint:GetId() == gameInfo:GetSpawnSelection() then
                    selectedIndex = #allowableSpawns
                end
            end
        end

        return true, allowableSpawns, selectedIndex

    end
    return false, { }, selectedIndex

end

local function UpdateUISize(self)

    self.background:SetSize(GUIScale(kSpawnBackgroundSize))
    self.background:SetPosition(-GUIScale(kSpawnBackgroundSize))

    self.titleBackground:SetSize(GUIScale(kTitleBackgroundSize))
    self.titleBackground:SetPosition(Vector(2, 2, 0))

    self.titleText:SetPosition(GUIScale(kTitleVoteOffset))
    self.titleText:SetScale(GetScaledVector())

    for i = 1, 10 do

        local vec = kOptionOffset
        vec = vec * i
        vec.y = vec.y + 15
        self["spawnLocation"..i]:SetPosition(GUIScale(vec))
        self["spawnLocation"..i]:SetScale(GetScaledVector())

    end
    
end

local function UpdateChoiceOptions(self)

    for i = 1, 9 do
        self["spawnLocation"..i]:SetText(self.spawnLocations[i] or "")
    end
    self.spawnLocation10:SetText("Random Spawn")
    UpdateUISize(self)
end

function GUINSLSpawnSelectionMenu:Initialize()

    self.background = GUIManager:CreateGraphicItem()
    self.background:SetIsVisible(false)
    self.background:SetColor(kBackgroundColor)
    self.background:SetAnchor(GUIItem.Right, GUIItem.Center)
    self.background:SetLayer(kGUILayerMainMenu)

    self.titleBackground = GUIManager:CreateGraphicItem()
    self.titleBackground:SetColor(kTitleColor)
    self.background:AddChild(self.titleBackground)
    
    self.titleText = GUIManager:CreateTextItem()
    self.titleText:SetColor(kTitleTextColor)
    self.titleText:SetText("SELECT STARTING LOCATION")
    self.titleText:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.titleText:SetTextAlignmentX(GUIItem.Align_Center)
    self.titleText:SetTextAlignmentY(GUIItem.Align_Center)
    self.titleBackground:AddChild(self.titleText)
    
    self.spawnLocations = { }
    self.enabled = false
    self.selectedIndex = 10
    self.enabled, self.spawnLocations, self.selectedIndex = GetRelevantTechPoints()
    self.opened = false
    self.lastSelected = 0
    self.updateCheck = true
    self.lastUpdateCheck = Shared.GetTime()
    self.selectedId = -1

    for i = 1, 9 do
    
        self["spawnLocation"..i] = GUIManager:CreateTextItem()
        self["spawnLocation"..i]:SetColor(kOptionColor)
        self["spawnLocation"..i]:SetAnchor(GUIItem.Middle, GUIItem.Top)
        self["spawnLocation"..i]:SetTextAlignmentX(GUIItem.Align_Center)
        self["spawnLocation"..i]:SetTextAlignmentY(GUIItem.Align_Center)
        self.background:AddChild(self["spawnLocation"..i])

    end

    self.spawnLocation10 = GUIManager:CreateTextItem()
    self.spawnLocation10:SetColor(kOptionColor)
    self.spawnLocation10:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.spawnLocation10:SetTextAlignmentX(GUIItem.Align_Center)
    self.spawnLocation10:SetTextAlignmentY(GUIItem.Align_Center)
    self.background:AddChild(self.spawnLocation10)

    UpdateChoiceOptions(self)
    
    UpdateUISize(self)

    if HelpScreen_AddObserver then
        HelpScreen_AddObserver(self)
    end
    
end

function GUINSLSpawnSelectionMenu:OnHelpScreenVisChange(state)
    
    self.hiddenByHelpScreen = state
    self:UpdateVisibility()
    
end

function GUINSLSpawnSelectionMenu:Uninitialize()
       
    GUI.DestroyItem(self.titleText)
    self.titleText = nil
    
    GUI.DestroyItem(self.titleBackground)
    self.titleBackground = nil

    for i = 1, 10 do
        GUI.DestroyItem(self["spawnLocation"..i])
        self["spawnLocation"..i] = nil
    end
    
    GUI.DestroyItem(self.background)
    self.background = nil
    
    if HelpScreen_RemoveObserver then
        HelpScreen_RemoveObserver(self)
    end

    MouseTracker_SetIsVisible(false)
    
end

function GUINSLSpawnSelectionMenu:SetIsVisible(state)
    
    self.opened = state
    self:UpdateVisibility()
    
end

function GUINSLSpawnSelectionMenu:UpdateVisibility()

    local visible = self.opened and not self.hiddenByHelpScreen and self.enabled
    
    self.background:SetIsVisible(visible)
    MouseTracker_SetIsVisible(visible, "ui/Cursor_MenuDefault.dds", true)
    
end

function GUINSLSpawnSelectionMenu:OnResolutionChanged(oldX, oldY, newX, newY)
    UpdateUISize(self)
end

function GUINSLSpawnSelectionMenu:Update(deltaTime)

    PROFILE("GUINSLSpawnSelectionMenu:Update")

    if self.background:GetIsVisible() and not self.hidden then
        
        for i = 1, 10 do

            if i == self.selectedIndex then
                self["spawnLocation"..i]:SetColor(kOptionChoosen)
            elseif GUIItemContainsPoint(self["spawnLocation"..i], Client.GetCursorPosScreen()) then
                self["spawnLocation"..i]:SetColor(kOptionSelectedColor)
            else
                self["spawnLocation"..i]:SetColor(kOptionColor)
            end
            
        end
        
    end

    if GetGameInfoEntity():GetGameStarted() and self.background:GetIsVisible() then
        self:SetIsVisible(false)
    end

    if not GetGameInfoEntity():GetGameStarted() and not self.background:GetIsVisible() then
        self:SetIsVisible(true)
        self.updateCheck = true
        self.lastUpdateCheck = Shared.GetTime()
    end

    if self.lastUpdateCheck + 1 < Shared.GetTime() then
        if self.updateCheck then
            UpdateChoiceOptions(self)
            self.updateCheck = false
        end
        if self.selectedId ~= GetGameInfoEntity():GetSpawnSelection() then
            UpdateChoiceOptions(self)
        end
        self.lastUpdateCheck = Shared.GetTime()
    end
    
end

local function SpawnItemSelected(self, index)

    if index ~= self.selectedIndex then

        local pressedItem = self["spawnLocation"..index]

        local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
        for _, currentTechPoint in ipairs(techPoints) do
            if currentTechPoint:GetLocationName() == self.spawnLocations[index] then
                Client.SendNetworkMessage("NSLSelectSpawn", { techPointId = currentTechPoint:GetId() }, true)
                self.selectedIndex = index
            end
        end

        if index == 10 then
            Client.SendNetworkMessage("NSLSelectSpawn", { techPointId = -1 }, true)
            self.selectedIndex = index
        end

    end
    
end

function GUINSLSpawnSelectionMenu:SendKeyEvent(key, down)

    if self.background:GetIsVisible() and not self.hidden then
            
        if key == InputKey.MouseButton0 then
        
            for i = 1, 10 do
                local item = self["spawnLocation"..i]
                if item:GetIsVisible() and GUIItemContainsPoint(item, Client.GetCursorPosScreen()) and self.lastSelected + kSelectionDelay < Shared.GetTime() then
                    self.lastSelected = Shared.GetTime()
                    SpawnItemSelected(self, i)
                    return false
                    
                end
                
            end

        end
        
    end
    
    return false
    
end