Script.Load("lua/nsl_class.lua")

local function ValidateTeamNumber(teamnum)
	return teamnum == 1 or teamnum == 2
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
	function()
		local timeadjustment = 0
		local localPlayer
		if Server then
			timeadjustment = gSharedGetTimeAdjustments
		elseif Client then
			localPlayer = Client.GetLocalPlayer()
		elseif Predict then
			localPlayer = Predict.GetLocalPlayer()
		end
		if localPlayer ~= nil then
			timeadjustment = localPlayer.timeadjustment
		end
		return (originalNS2SharedGetTime() - (timeadjustment or 0))	
	end
)

//This seems wierd, but want to ensure smoothest experience possible, and ready room players that trigger a crouch will cause havok for themselves.
function Player:GetCrouchCameraAnimationAllowed(result)
    result.allowed = result.allowed and not self.gamepaused
end

Class_Reload( "Player", {timeadjustment = "time", gamepaused = "compensated boolean"} )