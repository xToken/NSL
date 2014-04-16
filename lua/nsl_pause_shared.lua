Script.Load("lua/nsl_class.lua")

gTimeBypass = false

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

		if self.gamepaused then
			return
		else
			originalNS2PlayerOnProcessMove(self, input)
		end
		
	end
)

//Blocks input.
local originalNS2SpectatorOnProcessMove
originalNS2SpectatorOnProcessMove = Class_ReplaceMethod("Spectator", "OnProcessMove", 
	function(self, input)

		if self.gamepaused then
			if ValidateTeamNumber(self:GetTeamNumber()) then
				return
			else
				gTimeBypass = true
				originalNS2SpectatorOnProcessMove(self, input)
				gTimeBypass = false
			end
		else
			originalNS2SpectatorOnProcessMove(self, input)
		end
		
	end
)

//Gah
function GetOriginalSpecOnProcessMove()
	return originalNS2SpectatorOnProcessMove
end

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
//Keep running running running running....
local oldSetPlayerPoseParameters = SetPlayerPoseParameters
function SetPlayerPoseParameters(player, viewModel, headAngles)
	if player.gamepaused and ValidateTeamNumber(player:GetTeamNumber()) then
		//bleh
		local coords = player:GetCoords()
		local pitch = -Math.Wrap(Math.Degrees(headAngles.pitch), -180, 180)

		local bodyYaw = 0
		if player.bodyYaw then
			bodyYaw = Math.Wrap(Math.Degrees(player.bodyYaw), -180, 180)
		end
		
		local bodyYawRun = 0
		if player.bodyYawRun then
			bodyYawRun = Math.Wrap(Math.Degrees(player.bodyYawRun), -180, 180)
		end
		
		local headCoords = headAngles:GetCoords()
		
		local velocity = player:GetVelocityFromPolar()
		// Not all players will contrain their movement to the X/Z plane only.
		if player.GetMoveSpeedIs2D and player:GetMoveSpeedIs2D() then
			velocity.y = 0
		end
		
		local x = Math.DotProduct(headCoords.xAxis, velocity)
		local z = Math.DotProduct(headCoords.zAxis, velocity)
		
		local moveYaw
		
		if player.OverrideGetMoveYaw then
			moveYaw = player:OverrideGetMoveYaw()
		end
		
		if not moveYaw then
			moveYaw = Math.Wrap(Math.Degrees( math.atan2(z,x) ), -180, 180)
		end

		player:SetPoseParam("move_yaw", moveYaw)
		player:SetPoseParam("move_speed", 0)
		player:SetPoseParam("body_pitch", pitch)
		player:SetPoseParam("body_yaw", bodyYaw)
		player:SetPoseParam("body_yaw_run", bodyYawRun)		
		player:SetPoseParam("crouch", 0)
		player:SetPoseParam("land_intensity", 0)
		
		if viewModel then
		
			viewModel:SetPoseParam("body_pitch", pitch)
			viewModel:SetPoseParam("move_yaw", moveYaw)
			viewModel:SetPoseParam("move_speed", 0)
			viewModel:SetPoseParam("crouch", 0)
			viewModel:SetPoseParam("body_yaw", bodyYaw)
			viewModel:SetPoseParam("body_yaw_run", bodyYawRun)
			viewModel:SetPoseParam("land_intensity", 0)
			
		end
	else
		oldSetPlayerPoseParameters(player, viewModel, headAngles)
	end
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

Class_Reload( "Player", {timeadjustment = "time", timepaused = "time", gamepaused = "compensated boolean"} )