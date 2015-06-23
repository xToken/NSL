// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\GUINSLSpectatorTechMap.lua
// - Dragon

Script.Load("lua/GUIScript.lua")
Script.Load("lua/MarineTechMap.lua")
Script.Load("lua/AlienTechMap.lua")

local kTechStatus = enum({'Available', 'Allowed', 'NotAvailable'})

local kTechMaps =
{
    [kMarineTeamType] = kMarineTechMap,
    [kAlienTeamType] = kAlienTechMap
}
local kLines =
{
    [kMarineTeamType] = kMarineLines,
    [kAlienTeamType] = kAlienLines
}
local kLineColors =
{
    [kMarineTeamType] = Color(0, 0.8, 1, 0.5),
    [kAlienTeamType] = Color(1, 0.4, 0, 0.5),
}

local kGrey = Color(0.18, 0.18, 0.18, 1)
local kAllowedColor = Color(0.6, 0.6, 0.6, 1)

local kTechMapIconColors =
{
    [kMarineTeamType] = { [kTechStatus.Available] = Color(0.8, 1, 1, 1), [kTechStatus.Allowed] = kAllowedColor,  [kTechStatus.NotAvailable] = kGrey },
    [kAlienTeamType] =  { [kTechStatus.Available] = Color(1, 0.9, 0.4, 1),  [kTechStatus.Allowed] = kAllowedColor,  [kTechStatus.NotAvailable] = kGrey }

}

local kStartOffset =
{
    [kMarineTeamType] = kMarineTechMapYStart,
    [kAlienTeamType] = kAlienTechMapYStart
}

local kIconSize = GUIScale(Vector(56, 56, 0))
local kHalfIconSize = kIconSize * 0.5
local kBackgroundSize = Vector(15 * kIconSize.x, 15 * kIconSize.y, 0)
local kIconTextur = "ui/buildmenu.dds"

local kProgressMeterSize = Vector(kIconSize.x, GUIScale(10), 0)

class 'GUINSLSpectatorTechMap' (GUIScript)

local function CreateTechIcon(self, techId, position, teamType, modFunction, text)

    local icon = GetGUIManager():CreateGraphicItem()
    icon:SetSize(kIconSize)
    icon:SetTexture(kIconTextur)    
    icon:SetPosition(Vector(position.x * kIconSize.x, position.y * kIconSize.y, 0))
    icon:SetColor(kIconColors[teamType])
    icon:SetTexturePixelCoordinates(unpack(GetTextureCoordinatesForIcon(techId)))
    icon:SetLayer(1)
    
    self.background:AddChild(icon)
    
    local textItem
    
    if text then
    
        textItem = GetGUIManager():CreateTextItem()
        textItem:SetFontSize(GUIScale(15))
        textItem:SetText(text)    
        textItem:SetAnchor(GUIItem.Right, GUIItem.Bottom)
        textItem:SetTextAlignmentX(GUIItem.Align_Max)
        textItem:SetTextAlignmentY(GUIItem.Align_Max)
        textItem:SetLayer(2)
        
        icon:AddChild(textItem)
    
    end
    
    return { Icon = icon, TechId = techId, ModFunction = modFunction, Text = textItem }

end

local function CreateLine(self, startPoint, endPoint, teamType)

    local lineStartPoint = Vector(startPoint.x * kIconSize.x, startPoint.y * kIconSize.y, 0) + kHalfIconSize
    local lineEndPoint = Vector(endPoint.x * kIconSize.x, endPoint.y * kIconSize.y, 0) + kHalfIconSize
    
    local delta = lineStartPoint - lineEndPoint
    local direction = GetNormalizedVector(delta)
    local length = math.sqrt(delta.x ^ 2 + delta.y ^ 2)    
    local rotation = math.atan2(direction.x, direction.y)
    
    if rotation < 0 then
        rotation = rotation + math.pi * 2
    end

    rotation = rotation + math.pi * 0.5
    local rotationVec = Vector(0, 0, rotation)
    
    local line = GetGUIManager():CreateGraphicItem()
    line:SetSize(Vector(length, 2, 0))
    line:SetPosition(lineStartPoint)
    line:SetRotationOffset(Vector(-length, 0, 0))
    line:SetRotation(rotationVec)
    line:SetColor(kLineColors[teamType])
    line:SetLayer(0) 
    
    self.background:AddChild(line)
    
    return line

end

local function CreateProgressMeter(icon)

    local progressMeterBackGround = GetGUIManager():CreateGraphicItem()
    progressMeterBackGround:SetSize(kProgressMeterSize)
    progressMeterBackGround:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    progressMeterBackGround:SetPosition(Vector(0, -kProgressMeterSize.y, 0))
    progressMeterBackGround:SetColor(Color(0, 0, 0, 1))

    local progressMeter = GetGUIManager():CreateGraphicItem()
    progressMeter:SetPosition( Vector(1, 1, 0))
    
    icon:AddChild(progressMeterBackGround)
    progressMeterBackGround:AddChild(progressMeter)
    
    return progressMeter, progressMeterBackGround

end

local function CleanupGUIItems(self)

	if self.background then
        GUI.DestroyItem(self.background)
        self.background = nil
    end
    
    self.techIcons = { }
    self.lines = { }
	
end

local function CreateGUIItems(self)

	self.background = GetGUIManager():CreateGraphicItem()
    self.background:SetSize(kBackgroundSize)
    self.background:SetPosition(-kBackgroundSize * 0.5)
    self.background:SetAnchor(GUIItem.Middle, GUIItem.Center)
    self.background:SetIsVisible(true)
    self.background:SetColor(Color(0.0,0.0,0.0,0.4))
    self.background:SetLayer(kGUILayerScoreboard)
	
	self.techIcons = { }
    self.lines = { }

end

function GUINSLSpectatorTechMap:Initialize()
    self.showtechMap = false
    self.techMapButton = false	
end

local function InitializeTeamTechTree(self, teamNum)

	CleanupGUIItems(self)
	
	CreateGUIItems(self)
	
	self.teamSelected = teamNum
	
	local techMap = kTechMaps[self.teamSelected]
    local offset = kStartOffset[self.teamSelected]
    for i = 1, #techMap do

        local entry = techMap[i]
    
        if entry[1] and entry[1] ~= kTechId.None then

            local position = Vector(entry[2], entry[3] + offset, 0)
            table.insert(self.techIcons, CreateTechIcon(self, entry[1], position, self.teamSelected, entry[4], entry[5]))
        
        end
    
    end
	
    local lines = kLines[self.teamSelected]
    for i = 1, #lines do
    
        local line = lines[i]
        local startPoint = Vector(line[1], line[2] + offset, 0)
        local endPoint = Vector(line[3], line[4] + offset, 0)
        table.insert(self.lines, CreateLine(self, startPoint, endPoint, self.teamSelected))
    
    end
	
	Client.SendNetworkMessage("RequestTeamTechTree", {teamNumber = self.teamSelected}, true)
	
end

function GUINSLSpectatorTechMap:Uninitialize()
    CleanupGUIItems(self)
	
	Client.SendNetworkMessage("RequestTeamTechTree", {teamNumber = 0}, true)
	ClearTechTree()
	self.teamSelected = 0
	
end

function GUINSLSpectatorTechMap:SendKeyEvent(key, down)

	local success = false
    if GetIsBinding(key, "ShowTechMap") then
        self.techMapButton = down
    end
	if key == InputKey.Num1 and self.techMapButton and down then
		InitializeTeamTechTree(self, 1)
		success = true
	end
	if key == InputKey.Num2 and self.techMapButton and down then
		InitializeTeamTechTree(self, 2)
		success = true
	end
	return success

end

function GUINSLSpectatorTechMap:GetIsVisible()
    return self.background ~= nil and self.background:GetIsVisible()
end

function GUINSLSpectatorTechMap:Update(deltaTime)

    self.hoverTechId = nil
    
    local showMap = self.techMapButton and (self.teamSelected == 1 or self.teamSelected == 2)
	
	if self.background then
		self.background:SetIsVisible(showMap)
	end

    if showMap then		
    
        local animation = 0.65 + 0.35 * (1 + math.sin(Shared.GetTime() * 5)) * 0.5
    
        local baseColor = kIconColors[self.teamSelected]
        self.researchingColor = Color(
            baseColor.r * animation,
            baseColor.g * animation,
            baseColor.b * animation, 1)
    
        local techTree = GetTechTree()
        local useColors = kTechMapIconColors[self.teamSelected]
        local mouseX, mouseY = Client.GetCursorPosScreen()
        
        if techTree then
    
            for i = 1, #self.techIcons do
            
                local techIcon = self.techIcons[i]
                local techId = techIcon.TechId
                local techNode = techTree:GetTechNode(techId)
                local status = kTechStatus.NotAvailable
                local researchProgress = 0

                if techNode then
                
                    researchProgress = techNode:GetResearchProgress()
                
                    if techNode:GetHasTech() then                
                        status = kTechStatus.Available                    
                    elseif techNode:GetAvailable() then
                        status = kTechStatus.Allowed
                    end
                    
                    if techNode:GetIsPassive() or techNode:GetIsMenu() then
                        status = kTechStatus.Available
                    elseif techNode:GetIsUpgrade() and techNode:GetAvailable() then    
                        status = kTechStatus.Available
                    elseif techNode:GetIsResearch() then

                        if techNode:GetResearched() and techTree:GetHasTech(techId) then
                            status = kTechStatus.Available
                        elseif techNode:GetAvailable() then
                        
                            status = kTechStatus.Allowed
                            
                        elseif techNode:GetResearching() then
                        
                            status = kTechStatus.Allowed
                            
                        end

                    elseif (techNode:GetIsBuy() or techNode:GetIsActivation()) and techNode:GetAvailable() then
                        status = kTechStatus.Available
                    end
                    
                end
                
                local progressing = false                
                if researchProgress ~= 0 and researchProgress ~= 1 then                
                    progressing = true
                    status = kTechStatus.Available                
                end
                
                local useColor = useColors[status]
                
                if progressing then
                    
                    if not techIcon.ProgressMeter then
                        techIcon.ProgressMeter, techIcon.ProgressMeterBackground = CreateProgressMeter(techIcon.Icon)
                    end
                    
                    techIcon.ProgressMeterBackground:SetIsVisible(true)
                    techIcon.ProgressMeter:SetSize(Vector((kProgressMeterSize.x - 2) * researchProgress, kProgressMeterSize.y - 2, 0))
                    
                    useColor = self.researchingColor
                    
                elseif techIcon.ProgressMeterBackground then
                    techIcon.ProgressMeterBackground:SetIsVisible(false)
                end
                
                if techIcon.ModFunction then
                    techIcon.ModFunction(techIcon.Icon, techIcon.TechId, techIcon.Text)
                end
                
                techIcon.Icon:SetColor(useColor)
                
                if not self.hoveTechId and GUIItemContainsPoint(techIcon.Icon, mouseX, mouseY) then
                    self.hoverTechId = techIcon.TechId
                end
            
            end
        
        end
    
    end

end

function GUINSLSpectatorTechMap:GetTooltipData()

    if self.hoverTechId then
        return PlayerUI_GetTooltipDataFromTechId(self.hoverTechId)
    end    

    return nil

end