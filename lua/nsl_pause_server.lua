//Pause

Script.Load("lua/nsl_class.lua")

local gamestate = {
serverupdateenabled = false,
serverdelayedupdateenabled = false,
gamepaused = false,
gamepausedtime = 0,
gamepausedcountdown = 0,
gamepausedmessagetime = 0,
gamepausingteam = 0,
gamepausedscoreupdate = 0,
teampauses = { },
team1resume = false, 
team2resume = false,
gamepauseddelta = 0,
gamedelaydelta = 0
}

gSharedGetTimeAdjustments = 0

local function GetDamageOverTimeIsEnabled(self)
    return self.damageOverTime ~= nil and self.damageOverTime > 0
end

local UpdatingClasses = {	
"ScriptActor",
"Clog",
"DeathTrigger",
"Gamerules",
"ObjectiveInfo",
"ParticleEffect",
"Pheromone",
"PredictedProjectile",
"Ragdoll",
"SoundEffect",
"SpawnBlocker",
"SporeCloud",
"TeamInfo",
"TeamJoin",
"TimedEmitter",
"Tunnel",
"TunnelProp",
"ViewModel",
"Web"
}

local ClassUpdatesBlock = { }
table.insert(ClassUpdatesBlock, {name = "CatalystMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "CloakableMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "ClogFallMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "CombatMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "ConstructMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "CorrodeMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "EffectsMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "EnergizeMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "EnergyMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "FireMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "FlinchMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "GhostStructureMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "IdleMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "LOSMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "MaturityMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "NanoShieldMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "OrdersMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "ParasiteMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "PredictedProjectileShooterMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "RagdollMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "RecycleMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "ResearchMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "StompMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "StormCloudMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "StunMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "TargettingMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "TechMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "TeleportMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "TunnelUserMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "UmbraMixin", OnProcessMove = nil })
table.insert(ClassUpdatesBlock, {name = "VortexAbleMixin", OnProcessMove = nil })
local ProcessTechTreeActionBlock = { }
table.insert(ProcessTechTreeActionBlock, {name = "Commander", ProcessTechTreeAction = nil })
table.insert(ProcessTechTreeActionBlock, {name = "AlienCommander", ProcessTechTreeAction = nil })
table.insert(ProcessTechTreeActionBlock, {name = "MarineCommander", ProcessTechTreeAction = nil })

local function ValidateTeamNumber(teamnum)
	return teamnum == 1 or teamnum == 2
end

for i, classarray in pairs(ClassUpdatesBlock) do
	classarray.OnProcessMove = Class_ReplaceMethod(classarray.name, "OnProcessMove", 
		function(self, input)
			if GetIsGamePaused() then
				return
			end
			return classarray.OnProcessMove(self, input)
		end
	)
end

for i, classarray in pairs(ProcessTechTreeActionBlock) do
	classarray.ProcessTechTreeAction = Class_ReplaceMethod(classarray.name, "ProcessTechTreeAction", 
		function(...)
			if GetIsGamePaused() then
				return false
			end
			return classarray.ProcessTechTreeAction(...)
		end
	)
end

local originalNS2EntityAddTimedCallback
originalNS2EntityAddTimedCallback = Class_ReplaceMethod("Entity", "AddTimedCallback", 
	function(self, func, interval)
		local function BlockCallsIfPaused(self)
			if GetIsGamePaused() then
				return true
			else
				return func(self)
			end
		end
		originalNS2EntityAddTimedCallback(self, BlockCallsIfPaused, interval)
	end
)

local originalNS2PathingMixinMoveToTarget
originalNS2PathingMixinMoveToTarget = Class_ReplaceMethod("PathingMixin", "MoveToTarget", 
	function(...)

		if GetIsGamePaused() then
			return false
		end
		return originalNS2PathingMixinMoveToTarget(...)
		
	end
)

local originalNS2AiAttacksMixinOnTag
originalNS2AiAttacksMixinOnTag = Class_ReplaceMethod("AiAttacksMixin", "OnTag", 
	function(self, tagName)

		if GetIsGamePaused() then
			return
		end
		originalNS2AiAttacksMixinOnTag(self, tagName)		

	end
)

local originalNS2PlayerCopyPlayerDataFrom
originalNS2PlayerCopyPlayerDataFrom = Class_ReplaceMethod("Player", "CopyPlayerDataFrom", 
	function(self, player)
		self.timeadjustment = player.timeadjustment
		originalNS2PlayerCopyPlayerDataFrom(self, player)
	end
)

local originalNS2PlayerOnCreate
originalNS2PlayerOnCreate = Class_ReplaceMethod("Player", "OnCreate", 
	function(self)
		originalNS2PlayerOnCreate(self)
		self.timeadjustment = gSharedGetTimeAdjustments
	end
)

local originalNS2GameRulesEndGame
originalNS2GameRulesEndGame = Class_ReplaceMethod("NS2Gamerules", "EndGame", 
	function(self, winningTeam)
		gamestate.team1resume = false
		gamestate.team2resume = false
		return originalNS2GameRulesEndGame(self, winningTeam)
	end
)

local function PauseBlockTeamJoins(self, teamNumber)
	if GetIsGamePaused() and (teamNumber ~= 1 and teamNumber ~= 2) then
		// send message telling people that they cant do that.
		return false
	end
	return true
end

table.insert(gCanJoinTeamFunctions, PauseBlockTeamJoins)

function GetCommanderLogoutAllowed()
	return not GetIsGamePaused()
end

function GetIsGamePaused()
	return gamestate.gamepaused
end

//This runs every tick to procedurally update any timerelevant fields of any relevant ents to insure they remain in the appropriate state.
local function UpdateEntStates(deltatime)
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		if player ~= nil then
			if ValidateTeamNumber(player:GetTeamNumber()) and not player.gamepaused then
				player.followMoveEnabled = false
			end
			player.timeadjustment = gSharedGetTimeAdjustments
			player.gamepaused = gamestate.gamepaused
		end
	end
end

//This runs when game resumes, should restore any ents whos states were saved initially.
local function ResumeEntStates()
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		if player ~= nil then
			if ValidateTeamNumber(player:GetTeamNumber()) then
				player.followMoveEnabled = true
			end
			player.timeadjustment = gSharedGetTimeAdjustments
			player.gamepaused = gamestate.gamepaused
		end
	end
	//Resume the annoying noise
	local Obs = Shared.GetEntitiesWithClassname("Observatory")
	for _, Ob in ientitylist(Obs) do
		if Ob.distressBeaconTime ~= nil and Ob.distressBeaconSound ~= nil then
			Ob.distressBeaconSound:Start()
			
			local origin = Ob:GetDistressOrigin()
			Ob.distressBeaconSound:SetOrigin(origin)
		end
	end
	
	local Ents = Shared.GetEntitiesWithClassname("Entity")
	for _, ent in ientitylist(Ents) do
		for i = 1, #UpdatingClasses do
			if ent:isa(UpdatingClasses[i]) then
				ent:SetUpdates(true)
				break
			end
		end
	end

end

// This runs when the pause enables, saves the times/states of any ents that cannot be procedurally correctly.
local function SaveEntStates()

	//Stopppp the duck turrets
	local Sentries = Shared.GetEntitiesWithClassname("Sentry")
	for _, Sentry in ientitylist(Sentries) do
		Sentry.attacking = false
	end

	//Stop the bacon from spammmming.
	local Obs = Shared.GetEntitiesWithClassname("Observatory")
	for _, Ob in ientitylist(Obs) do
		if Ob.distressBeaconTime ~= nil and Ob.distressBeaconSound ~= nil then
			Ob.distressBeaconSound:Stop()
			//Dont wanna listen to that noise over and over and over and over and over ..
		end
	end
	//Block movement instantly so that its not updated each frame needlessly
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		if player ~= nil then
			if ValidateTeamNumber(player:GetTeamNumber()) then
				player:PrimaryAttackEnd()
				local weapon = player:GetActiveWeapon()
				if weapon ~= nil then
					weapon.reloading = false
				end
				player.followMoveEnabled = false
				player:SetCameraShake(0)
				if(player.secondaryAttackLastFrame ~= nil and player.secondaryAttackLastFrame) then
					player:SecondaryAttackEnd()
				end
			end
			player.timeadjustment = gSharedGetTimeAdjustments
			player.gamepaused = true
		end
	end
	
	local Ents = Shared.GetEntitiesWithClassname("Entity")
	for _, ent in ientitylist(Ents) do
		if not ent:isa("PlayerInfoEntity") then
			ent:SetUpdates(false)
		end
	end
end

local function UpdateMoveState(deltatime)

	if gamestate.serverupdateenabled then
		gamestate.gamepauseddelta = gamestate.gamepauseddelta + deltatime
		if GetIsGamePaused() then
			//Going to check and reblock player movement every second or so - trying every frame, might as well.
			gSharedGetTimeAdjustments = gSharedGetTimeAdjustments + deltatime
			gamestate.gamepausedmessagetime = (gamestate.gamepausedmessagetime + deltatime)
			if gamestate.gamepausedmessagetime > GetNSLConfigValue("PausedReadyNotificationDelay") and gamestate.gamepausedcountdown == 0 then
				if gamestate.team2resume and not gamestate.team1resume then
					SendAllClientsMessage(string.format(GetNSLMessage("PauseTeamReadyPeriodicMessage"), GetActualTeamName(2), GetActualTeamName(1)))
				elseif gamestate.team1resume and not gamestate.team2resume then
					SendAllClientsMessage(string.format(GetNSLMessage("PauseTeamReadyPeriodicMessage"), GetActualTeamName(1), GetActualTeamName(2)))
				elseif not gamestate.team1resume and not gamestate.team2resume then
					SendAllClientsMessage(GetNSLMessage("PauseNoTeamReadyMessage"))
				end
				if GetNSLConfigValue("PausedMaxDuration") ~= 0 then
					SendAllClientsMessage(string.format(GetNSLMessage("PauseResumeWarningMessage"), ((GetNSLConfigValue("PausedMaxDuration") - gamestate.gamepauseddelta))))
				end
				gamestate.gamepausedmessagetime = 0
			end
			UpdateEntStates(deltatime)
			if GetNSLConfigValue("PausedMaxDuration") ~= 0 and gamestate.gamepauseddelta >= GetNSLConfigValue("PausedMaxDuration") and gamestate.gamepausedcountdown == 0 then
				gamestate.serverdelayedupdateenabled = true
				gamestate.gamepausedcountdown = GetNSLConfigValue("PauseEndDelay")
			end
			//No more scoreboard updates, uses PlayerInfo ent.
		else
			ResumeEntStates()
			gamestate.serverupdateenabled = false
			if gamestate.gamepausingteam ~= 0 then
				local pausesremaining = (GetNSLConfigValue("PauseMaxPauses") - (gamestate.teampauses[GetActualTeamName(gamestate.gamepausingteam)] or 0))
				SendAllClientsMessage(string.format(GetNSLMessage("PauseResumeMessage"), GetActualTeamName(gamestate.gamepausingteam), pausesremaining))
			end
			gamestate.gamepausedtime = 0
			gamestate.gamepausingteam = 0
			gamestate.gamepauseddelta = 0
		end
	end
	if gamestate.serverdelayedupdateenabled then
		gamestate.gamedelaydelta = gamestate.gamedelaydelta + deltatime
		if gamestate.gamedelaydelta >= 1 then
			gamestate.gamepausedcountdown = (gamestate.gamepausedcountdown - 1)
			if gamestate.gamepausedcountdown > 0 then
				SendAllClientsMessage(string.format(GetNSLMessage("PauseWarningMessage"), ConditionalValue(GetIsGamePaused(), "resume", "pause"), (gamestate.gamepausedcountdown)))
			else
				if not GetIsGamePaused() then
					SaveEntStates()
					gamestate.serverupdateenabled = true
					SendAllClientsMessage(GetNSLMessage("PausePausedMessage"))
					gamestate.gamepausedtime = Shared.GetTime()
					//Shared.Message("Game Paused.")
				else
					//Since other event already running, just let the final trigger run there (will be next frame).
					//Shared.Message("Game Resumed.")
				end
				gamestate.serverdelayedupdateenabled = false
				gamestate.gamepaused = not GetIsGamePaused()
				gamestate.gamepausedcountdown = 0
			end
			gamestate.gamedelaydelta = gamestate.gamedelaydelta - 1
		end
	end

end

Event.Hook("UpdateServer", UpdateMoveState)

local function OnCommandPause(client)
	
	if client ~= nil and GetGamerules():GetGameStarted() and GetNSLModEnabled() and GetNSLConfigValue("PauseEnabled") then
		local player = client:GetControllingPlayer()
		if player ~= nil and not GetIsGamePaused() and gamestate.gamepausedcountdown == 0 then
			local teamnumber = player:GetTeamNumber()
			if teamnumber and ValidateTeamNumber(teamnumber) then
				local validpause = false
				if (gamestate.teampauses[GetActualTeamName(teamnumber)] or 0) < GetNSLConfigValue("PauseMaxPauses") then
					gamestate.teampauses[GetActualTeamName(teamnumber)] = (gamestate.teampauses[GetActualTeamName(teamnumber)] or 0) + 1
					validpause = true
				end
				if validpause then
					gamestate.team1resume = false
					gamestate.team2resume = false
					gamestate.gamepausedcountdown = GetNSLConfigValue("PauseStartDelay")
					gamestate.gamepausingteam = teamnumber
					gamestate.serverdelayedupdateenabled = true
					SendAllClientsMessage(string.format(GetNSLMessage("PausePlayerMessage"), player:GetName()))
				else
					SendClientMessage(client, GetNSLMessage("PauseTooManyPausesMessage"))
				end
			end
		end
	end
	
end

Event.Hook("Console_gpause",               OnCommandPause)
gChatCommands["pause"] = OnCommandPause

local function OnCommandUnPause(client)
	
	if client ~= nil and GetNSLModEnabled() and GetNSLConfigValue("PauseEnabled") then
		local player = client:GetControllingPlayer()
		if player ~= nil  and GetIsGamePaused() then
			local teamnumber = player:GetTeamNumber()
			if teamnumber and ValidateTeamNumber(teamnumber) then
				if teamnumber == 1 then
					gamestate.team1resume = not gamestate.team1resume
				else
					gamestate.team2resume = not gamestate.team2resume
				end
				if gamestate.team2resume and not gamestate.team1resume then
					SendAllClientsMessage(string.format(GetNSLMessage("PauseTeamReadyMessage"), player:GetName(), GetActualTeamName(2), GetActualTeamName(1)))
				elseif gamestate.team1resume and not gamestate.team2resume then
					SendAllClientsMessage(string.format(GetNSLMessage("PauseTeamReadyMessage"), player:GetName(), GetActualTeamName(1), GetActualTeamName(2)))
				elseif not gamestate.team1resume and not gamestate.team2resume then
					SendAllClientsMessage(GetNSLMessage("PauseNoTeamReadyMessage"))
				elseif gamestate.gamepausedcountdown == 0 then
					SendAllClientsMessage(string.format(GetNSLMessage("PauseTeamReadiedMessage"), player:GetName(), GetActualTeamName(teamnumber)))
					gamestate.serverdelayedupdateenabled = true
					gamestate.gamepausedcountdown = GetNSLConfigValue("PauseEndDelay")
				end
			end
		end
	end
	
end

Event.Hook("Console_unpause",               OnCommandUnPause)
gChatCommands["unpause"] = OnCommandUnPause
gChatCommands["resume"] = OnCommandUnPause

local function OnCommandAdminPause(client)
	
	if client and GetNSLModEnabled() and GetNSLConfigValue("PauseEnabled") then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			if GetGamerules():GetGameStarted() then
				if gamestate.gamepausedcountdown == 0 then
					gamestate.serverdelayedupdateenabled = true
					gamestate.team1resume = false
					gamestate.team2resume = false
					gamestate.gamepausedcountdown = ConditionalValue(GetIsGamePaused(), GetNSLConfigValue("PauseEndDelay"), GetNSLConfigValue("PauseStartDelay"))
				else
					gamestate.serverdelayedupdateenabled = false
					SendAllClientsMessage(GetNSLMessage("PauseCancelledMessage"))
					gamestate.gamepausedcountdown = 0
				end
			
				ServerAdminPrint(client, "Game " .. ConditionalValue(not GetIsGamePaused(), "pausing.", "unpausing."))
			end
		end
	end
	
end

Event.Hook("Console_sv_nslpause",               OnCommandAdminPause)

local function OnCommandAdminSetPauses(client, teamnum, pauses)
	
	if client and GetNSLModEnabled() and GetNSLConfigValue("PauseEnabled") then
		local NS2ID = client:GetUserId()
		teamnum = tonumber(teamnum)
		pauses = tonumber(pauses)
		if GetIsNSLRef(NS2ID) and teamnum and pauses and ValidateTeamNumber(teamnum) then
			local teamname = GetActualTeamName(teamnum)
			gamestate.teampauses[teamname] = Clamp(GetNSLConfigValue("PauseMaxPauses") - pauses, 0, GetNSLConfigValue("PauseMaxPauses"))
			ServerAdminPrint(client, string.format("%s now have %s pauses remaining.", teamname, Clamp(pauses, 0, GetNSLConfigValue("PauseMaxPauses"))))
		end
	end
	
end

Event.Hook("Console_sv_nslsetpauses",               OnCommandAdminSetPauses)