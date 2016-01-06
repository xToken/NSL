// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_pause_shared.lua
// - Dragon

Script.Load("lua/nsl_class.lua")

gTimeBypass = false
gPreviousPausedTime = 0
local kJetpackJumpWindow = 0.001

local function ValidateTeamNumber(teamnum)
	return teamnum ~= 3
end

//Blocks input.
local originalNS2PlayerOnProcessIntermediate
originalNS2PlayerOnProcessIntermediate = Class_ReplaceMethod("Player", "OnProcessIntermediate", 
	function(self, input)

		if self.gamepaused and ValidateTeamNumber(self:GetTeamNumber()) then
			return
		else
			originalNS2PlayerOnProcessIntermediate(self, input)
		end
		
	end
)

//Blocks input.
local originalNS2PlayerOnProcessMove
originalNS2PlayerOnProcessMove = Class_ReplaceMethod("Player", "OnProcessMove", 
	function(self, input)

		if self.gamepaused and ValidateTeamNumber(self:GetTeamNumber()) then
			return
		else
			originalNS2PlayerOnProcessMove(self, input)
		end
		
	end
)

local oldCameraHolderMixinSetDesiredCamera = CameraHolderMixin.SetDesiredCamera
function CameraHolderMixin:SetDesiredCamera(transitionDuration, mode, position, angles, distance, yOffset, callback)
	if self.gamepaused then
		return
	end
	oldCameraHolderMixinSetDesiredCamera(self, transitionDuration, mode, position, angles, distance, yOffset, callback)
end

//Blocks input.
local originalNS2PlayerGetCanControl
originalNS2PlayerGetCanControl = Class_ReplaceMethod("Player", "GetCanControl", 
	function(self)

		if self.gamepaused and ValidateTeamNumber(self:GetTeamNumber()) then
			return false
		else
			return originalNS2PlayerGetCanControl(self)
		end
		
	end
)

//Maybe time rounding issues?
local originalNS2JetpackMarineGetCanJump
originalNS2JetpackMarineGetCanJump = Class_ReplaceMethod("JetpackMarine", "GetCanJump", 
	function(self)
		local jetpackChangeTime = Shared.GetTime() - self.timeJetpackingChanged
		return not self:GetIsWebbed() and ( self:GetIsOnGround() or (jetpackChangeTime < kJetpackJumpWindow and self.startedFromGround) or self:GetIsOnLadder() )
	end
)

//Eliminates gravity to prevent stutter if midair.
local originalNS2PlayerModifyGravityForce
originalNS2PlayerModifyGravityForce = Class_ReplaceMethod("Player", "ModifyGravityForce", 
	function(self, gravityTable)

		if self.gamepaused and ValidateTeamNumber(self:GetTeamNumber()) then
			gravityTable.gravity = 0
		else
			originalNS2PlayerModifyGravityForce(self, gravityTable)
		end
		
	end
)

//Fix for healing effects not working after pause.
local oldLiveMixinAddHealth = LiveMixin.AddHealth
function LiveMixin:AddHealth(...)
	gTimeBypass = true
	oldLiveMixinAddHealth(self, ...)
	gTimeBypass = false
end

local oldLiveMixinSetArmor = LiveMixin.SetArmor
function LiveMixin:SetArmor(...)
	gTimeBypass = true
	oldLiveMixinSetArmor(self, ...)
	gTimeBypass = false
end

//Pause Projectiles (some/most)
if Server then
    local originalNS2PredictedProjectileShooterMixinOnProcessMove = PredictedProjectileShooterMixin.OnProcessMove
	function PredictedProjectileShooterMixin.OnProcessMove(self, input)
		if self.gamepaused then
			return
		else
			originalNS2PredictedProjectileShooterMixinOnProcessMove(self, input)
		end
	end
elseif Client then
	local originalNS2PredictedProjectileShooterMixinOnProcessIntermediate = PredictedProjectileShooterMixin.OnProcessIntermediate
	function PredictedProjectileShooterMixin.OnProcessIntermediate(self, input)
		if self.gamepaused then
			return
		else
			originalNS2PredictedProjectileShooterMixinOnProcessIntermediate(self, input)
		end
	end
end

local originalNS2SharedGetPreviousTime
originalNS2SharedGetPreviousTime = Class_ReplaceMethod("Shared", "GetPreviousTime", 
	function(RealTime)
		local localPlayer
		local timeadjustment = 0
		if Server then
			if GetIsGamePaused() then
				if gPreviousPausedTime == 0 then
					gPreviousPausedTime = originalNS2SharedGetPreviousTime()
				end
				if gTimeBypass or RealTime then
					return originalNS2SharedGetPreviousTime()
				else
					return gPreviousPausedTime
				end
			else
				gPreviousPausedTime = 0
				timeadjustment = gSharedGetTimeAdjustments
			end
		elseif Client then
			localPlayer = Client.GetLocalPlayer()
		elseif Predict then
			localPlayer = Predict.GetLocalPlayer()
		end
		if localPlayer ~= nil then
			if localPlayer.gamepaused then
				if gPreviousPausedTime == 0 then
					gPreviousPausedTime = originalNS2SharedGetPreviousTime()
				end
				if gTimeBypass or RealTime then
					return originalNS2SharedGetPreviousTime()
				else
					return gPreviousPausedTime
				end
			else
				gPreviousPausedTime = 0
				timeadjustment = localPlayer.timeadjustment
			end
		end
		if gTimeBypass or RealTime then
			timeadjustment = 0
		end
		return (originalNS2SharedGetPreviousTime() - (timeadjustment or 0))	
	end
)

local originalNS2SharedGetTime
originalNS2SharedGetTime = Class_ReplaceMethod("Shared", "GetTime", 
	function(RealTime)
		local timeadjustment = 0
		local localPlayer
		if Server then
			if GetIsGamePaused() and not (gTimeBypass or RealTime) then
				return GetIsGamePausedTime()
			else
				timeadjustment = gSharedGetTimeAdjustments
			end
		elseif Client then
			localPlayer = Client.GetLocalPlayer()
		elseif Predict then
			localPlayer = Predict.GetLocalPlayer()
		end
		if localPlayer ~= nil then
			if localPlayer.gamepaused and not (gTimeBypass or RealTime) then
				return localPlayer.timepaused
			else
				timeadjustment = localPlayer.timeadjustment
			end
		end
		if gTimeBypass or RealTime then
			timeadjustment = 0
		end
		return (originalNS2SharedGetTime() - (timeadjustment or 0))	
	end
)

//Fix for chat messages being rate limited during pause.
local function AddTokens(self)

    local now = Shared.GetTime(true)
    local timeSinceLastTokenAdded = now - self.lastTimeTokensAdded
    if timeSinceLastTokenAdded >= 1 / self.tokensAddedPerSecond then
        local numberOfTokensToAdd = math.floor(timeSinceLastTokenAdded * self.tokensAddedPerSecond)
        if numberOfTokensToAdd > 0 then
            self.tokens = math.min(self.maxTokensAllowed, self.tokens + numberOfTokensToAdd)
            self.lastTimeTokensAdded = now
        end
    end
end

local function RemoveTokens(self, numberToRemove)
    // Add tokens to bucket first.
    AddTokens(self)
    // Check if we are able to remove the requested number of tokens from the bucket.
    local tokensRemoved = self.tokens >= numberToRemove
    if tokensRemoved then
        self.tokens = self.tokens - numberToRemove
    end
    return tokensRemoved
end

local function GetNumberOfTokens(self)
    AddTokens(self)
    return self.tokens 
end

ReplaceLocals(CreateTokenBucket, { GetNumberOfTokens = GetNumberOfTokens })
ReplaceLocals(CreateTokenBucket, { RemoveTokens = RemoveTokens })

local function GetUpValue(origfunc, name)

	local index = 1
	local foundValue = nil
	while true do
	
		local n, v = debug.getupvalue(origfunc, index)
		if not n then
			break
		end
		
		-- Find the highest index matching the name.
		if n == name then
			foundValue = v
		end
		
		index = index + 1
		
	end
	
	return foundValue
	
end

local UpdateAnimationState = GetUpValue(BaseModelMixin.ProcessMoveOnModel, "UpdateAnimationState")
ReplaceLocals(UpdateAnimationState, { Shared_GetTime = Shared.GetTime })
ReplaceLocals(UpdateAnimationState, { Shared_GetPreviousTime = Shared.GetPreviousTime })

Class_Reload( "Player", {timeadjustment = "time", timepaused = "time", gamepaused = "compensated boolean"} )