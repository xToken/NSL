-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/pause/shared.lua
-- - Dragon

gTimeBypass = false
gPreviousPausedTime = 0
local kClientPaused
local kClientView = { yaw = 0, pitch = 0 }
local kJetpackJumpWindow = 0.001

local function ValidateTeamNumber(teamnum)
	return teamnum ~= 3
end

local function SaveClientViewAngles(player)
	if Client then
		if not kClientPaused then
			kClientPaused = true
			kClientView.yaw = debug.getupvaluex(Client.SetYaw, "_cameraYaw")
			kClientView.pitch = debug.getupvaluex(Client.SetPitch, "_cameraPitch")
			return true
		else
			Client.SetYaw(kClientView.yaw)
			Client.SetPitch(kClientView.pitch)
		end
	end
	return false
end

local function RestoreClientViewAngles()
	if Client and kClientPaused then
		Client.SetYaw(kClientView.yaw)
		Client.SetPitch(kClientView.pitch)
		kClientPaused = false
		kClientView = { yaw = 0, pitch = 0 }
	end
end

--Blocks input.
local originalNS2PlayerOnProcessIntermediate
originalNS2PlayerOnProcessIntermediate = Class_ReplaceMethod("Player", "OnProcessIntermediate", 
	function(self, input)

		if self.gamepaused and ValidateTeamNumber(self:GetTeamNumber()) then
			if SaveClientViewAngles(self) then
				--Run this if this returns true, to update the view angles one last time.
				originalNS2PlayerOnProcessIntermediate(self, input)
			end
			return
		else
			originalNS2PlayerOnProcessIntermediate(self, input)
			RestoreClientViewAngles()
		end
		
	end
)

--FJDKOSFHJDKSHFKJDSHFKJSDHFKJSDHFKJSDLFHDSIJRFYU*W#$IHATENS2
local oldFollowMoveMixinUpdateMove = FollowMoveMixin.UpdateMove
function FollowMoveMixin:UpdateMove(input)
	if self.gamepaused and ValidateTeamNumber(self:GetTeamNumber()) then
		return
	else
		oldFollowMoveMixinUpdateMove(self, input)
	end
end

--Blocks input.
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

--Blocks buying things.
local originalNS2PlayerProcessBuyAction
originalNS2PlayerProcessBuyAction = Class_ReplaceMethod("Player", "ProcessBuyAction", 
	function(self, upgrades)

		if self.gamepaused and ValidateTeamNumber(self:GetTeamNumber()) then
			return false
		else
			return originalNS2PlayerProcessBuyAction(self, upgrades)
		end
		
	end
)

--Blocks input.
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

--Maybe time rounding issues?
local originalNS2JetpackMarineGetCanJump
originalNS2JetpackMarineGetCanJump = Class_ReplaceMethod("JetpackMarine", "GetCanJump", 
	function(self)
		local jetpackChangeTime = Shared.GetTime() - self.timeJetpackingChanged
		return not self:GetIsWebbed() and ( self:GetIsOnGround() or (jetpackChangeTime < kJetpackJumpWindow and self.startedFromGround) or self:GetIsOnLadder() )
	end
)

--Eliminates gravity to prevent stutter if midair.
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

--Fix for healing effects not working after pause.
local oldLiveMixinAddHealth = LiveMixin.AddHealth
function LiveMixin:AddHealth(...)
	gTimeBypass = true
	local healed = oldLiveMixinAddHealth(self, ...)
	gTimeBypass = false
	return healed
end

local oldLiveMixinSetArmor = LiveMixin.SetArmor
function LiveMixin:SetArmor(...)
	gTimeBypass = true
	oldLiveMixinSetArmor(self, ...)
	gTimeBypass = false
end

--Pause Projectiles (some/most)
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

--Fix for chat messages being rate limited during pause.
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
    --Add tokens to bucket first.
    AddTokens(self)
    --Check if we are able to remove the requested number of tokens from the bucket.
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

local UpdateAnimationState = debug.getupvaluex(BaseModelMixin.ProcessMoveOnModel, "UpdateAnimationState")
ReplaceLocals(UpdateAnimationState, { Shared_GetTime = Shared.GetTime })
ReplaceLocals(UpdateAnimationState, { Shared_GetPreviousTime = Shared.GetPreviousTime })

--Sample of 'time' accuracy
--Server  : 19.716058198363
--Predict : 19.71484375
--Client  : 19.71484375
--Sample of 'float' accuracy
--Server  : 21.63121445477
--Predict : 21.631214141846
--Client  : 21.631214141846
--Time paused set on pause, used for smooth prediction on the client during pause.
--Time adjustment set on resume, used for adjusting all time based on the delta.
--Ideally I could network these at different precisions to save bw, but I dont know the efficiency of time vs float so....
--Considering how important these are for EVERYTHING, a little extra bandwidth on ent creation seems to be plenty acceptable.
Class_Reload( "Player", {timeadjustment = "float", timepaused = "float", gamepaused = "boolean"} )