//
// lua\GUINSLFollowingSpectatorHUD.lua
//

class 'GUINSLFollowingSpectatorHUD' (GUIScript)

local kFontScale = GUIScale(Vector(1, 1, 0))
local kTextFontName = "fonts/AgencyFB_large.fnt"
local kFontColor = Color(1, 1, 1, 1)
local kPlayerNameOffset = GUIScale(Vector(0, -85, 0))

local function GetNameofPlayerBeingFollowed()
	local player = Client.GetLocalPlayer()
	if player:isa("Spectator") and player:GetIsFollowing() then
		local tID = player:GetFollowTargetId()
		if tID ~= Entity.invalidId then
			local target = Shared.GetEntity(tID)
			if target and target.GetName then
				return target:GetName()
			end
		end
	end
end

function GUINSLFollowingSpectatorHUD:Initialize()

    self.nameText = GUIManager:CreateTextItem()
    self.nameText:SetFontName(kTextFontName)
    self.nameText:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
    self.nameText:SetTextAlignmentX(GUIItem.Align_Center)
    self.nameText:SetTextAlignmentY(GUIItem.Align_Center)
    self.nameText:SetColor(kFontColor)
    self.nameText:SetPosition(kPlayerNameOffset)
    
end

function GUINSLFollowingSpectatorHUD:Uninitialize()

    assert(self.nameText)
    
    GUI.DestroyItem(self.nameText)
    self.nameText = nil

end

function GUINSLFollowingSpectatorHUD:Update(deltaTime)

	local pName = GetNameofPlayerBeingFollowed()
    self.nameText:SetIsVisible(pName ~= nil)

    if self.lastname ~= pName and pName ~= nil then
		local followText = StringReformat(Locale.ResolveString("FOLLOWING_NAME"), { name = pName })
        self.nameText:SetText(followText)
        self.lastname = pName
    end
    
end