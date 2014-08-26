//First Person Spectator Block
local kDeltatimeBetweenAction = 0.3
	
local function IsTeamSpectator(self)
	return self:isa("TeamSpectator") or self:isa("AlienSpectator") or self:isa("MarineSpectator")
end

local function NextSpectatorMode(self, mode)

	if mode == nil then
		mode = self.specMode
	end
	
	local numModes = 0
	for name, _ in pairs(kSpectatorMode) do
	
		if type(name) ~= "number" then
			numModes = numModes + 1
		end
		
	end

	local nextMode = (mode % numModes) + 1
	// FirstPerson is only used directly through SetSpectatorMode(), never in this function.
	if nextMode == kSpectatorMode.FirstPerson and not GetNSLConfigValue("FirstPersonSpectate") and GetNSLModEnabled() then
		if IsTeamSpectator(self) then
			return kSpectatorMode.Following
		else
			return kSpectatorMode.FreeLook
		end
    else
		return nextMode
	end
	
end

local function UpdateSpectatorMode(self, input)

	assert(Server)
	
	self.timeFromLastAction = self.timeFromLastAction + input.time
	if self.timeFromLastAction > kDeltatimeBetweenAction then
	
		if bit.band(input.commands, Move.Jump) ~= 0 then
		
			self:SetSpectatorMode(NextSpectatorMode(self))
			self.timeFromLastAction = 0
			
		elseif bit.band(input.commands, Move.Weapon1) ~= 0 then
		
			self:SetSpectatorMode(kSpectatorMode.FreeLook)
			self.timeFromLastAction = 0
			
		elseif bit.band(input.commands, Move.Weapon2) ~= 0 then
		
			self:SetSpectatorMode(kSpectatorMode.Overhead)
			self.timeFromLastAction = 0
			
		elseif bit.band(input.commands, Move.Weapon3) ~= 0 then
		
			if not GetNSLConfigValue("FirstPersonSpectate") and GetNSLModEnabled() then
				self:SetSpectatorMode(kSpectatorMode.Following)
			else
				self:SetSpectatorMode(kSpectatorMode.FirstPerson)
			end
			
			self.timeFromLastAction = 0
			
		elseif bit.band(input.commands, Move.Weapon5) ~= 0 then
			
			self:SetSpectatorMode(kSpectatorMode.Following)
			self.timeFromLastAction = 0
			
		end
		
	end
	
end

ReplaceLocals(GetOriginalSpecOnProcessMove(), {UpdateSpectatorMode = UpdateSpectatorMode})

function FollowingSpectatorMode:FindTarget(spectator)
    if spectator.selectedId ~= Entity.invalidId then
        spectator.followedTargetId = spectator.selectedId    
    end
end

local oldNS2SpectatorOnInitialized
oldNS2SpectatorOnInitialized = Class_ReplaceMethod("Spectator", "OnInitialized", 
	function(self)
		Player.OnInitialized(self)
    
		self.selectedId = Entity.invalidId
		
		if Server then
		
			self.timeFromLastAction = 0
			self:SetIsVisible(false)
			self:SetIsAlive(false)
			// Start us off by looking for a target to follow.
			if not GetNSLConfigValue("FirstPersonSpectate") and GetNSLModEnabled() then
				self:SetSpectatorMode(kSpectatorMode.Following)
			else
				self:SetSpectatorMode(kSpectatorMode.FirstPerson)
			end
			
		elseif Client then
		
			if self:GetIsLocalPlayer() and self:GetTeamNumber() == kSpectatorIndex then
				self:ShowMap(true, false, true)
			end
			
		end
		
		// Remove physics
		self:DestroyController()
		
		// Other players never see a spectator.
		self:SetPropagate(Entity.Propagate_Never)
	end
)

local function OnClientCommandNSLFPS(client)
	if client then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			local player = client:GetControllingPlayer()
			if player ~= nil and player:isa("Spectator") and player:GetTeamNumber() == kSpectatorIndex then
				player:SetSpectatorMode(kSpectatorMode.FirstPerson)
			end
		end
	end
end

Event.Hook("Console_sv_nslfirstpersonspectate",               OnClientCommandNSLFPS)