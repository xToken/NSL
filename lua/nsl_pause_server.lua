-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\nsl_pause_server.lua
-- - Dragon

--Pause
local gamestate = {
serverpauseloopenabled = false,
serverprepauseloopenabled = false,
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
gameprepausedelta = 0
}

local function GetDamageOverTimeIsEnabled(self)
    return self.damageOverTime ~= nil and self.damageOverTime > 0
end

gSharedGetTimeAdjustments = 0

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
	function(self, func, interval, early)
		local function BlockCallsIfPaused(self, deltaTime)
			if GetIsGamePaused() then
				return true
			else
				return func(self, deltaTime)
			end
		end
		originalNS2EntityAddTimedCallback(self, BlockCallsIfPaused, interval, early)
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

local originalNS2WhipOnTag
originalNS2WhipOnTag = Class_ReplaceMethod("Whip", "OnTag", 
	function(self, tagName)

		if GetIsGamePaused() then
			return
		end
		originalNS2WhipOnTag(self, tagName)		

	end
)

local originalNS2WhipUpdateOrders
originalNS2WhipUpdateOrders = Class_ReplaceMethod("Whip", "UpdateOrders", 
	function(self, deltaTime)

		if GetIsGamePaused() then
			return
		end
		originalNS2WhipUpdateOrders(self, deltaTime)		

	end
)

local originalNS2CommandStructureOnUse
originalNS2CommandStructureOnUse = Class_ReplaceMethod("CommandStructure", "OnUse", 
	function(self, player, elapsedTime, useSuccessTable)
		
		if GetIsGamePaused() or GetIsGamePausing() then
			useSuccessTable.useSuccess = useSuccessTable.useSuccess and false
		else
			originalNS2CommandStructureOnUse(self, player, elapsedTime, useSuccessTable)
		end	

	end
)

local function UpdatePausesOnGameEnd(self, winningteam)
	if GetNSLModEnabled() then
		gamestate.team1resume = false
		gamestate.team2resume = false
		--Check pause and copy?
		local alienpauses = 0
		local marinepauses = 0
		if gamestate.teampauses["Aliens"] and gamestate.teampauses["Aliens"] > 0 then
			alienpauses = gamestate.teampauses["Aliens"]
		end
		if gamestate.teampauses["Marines"] and gamestate.teampauses["Marines"] > 0 then
			marinepauses = gamestate.teampauses["Marines"]
		end
		gamestate.teampauses["Marines"] = 0
		gamestate.teampauses["Aliens"] = 0
		if alienpauses > 0 then
			gamestate.teampauses["Marines"] = alienpauses
		end
		if marinepauses > 0 then
			gamestate.teampauses["Aliens"] = marinepauses
		end
	end
end

table.insert(gGameEndFunctions, UpdatePausesOnGameEnd)

local originalNS2PlayerCopyPlayerDataFrom
originalNS2PlayerCopyPlayerDataFrom = Class_ReplaceMethod("Player", "CopyPlayerDataFrom", 
	function(self, player)
		originalNS2PlayerCopyPlayerDataFrom(self, player)
		self.gamepaused = GetIsGamePaused()
		if self.gamepaused then
			self.timepaused = GetIsGamePausedTime()
			self.timeadjustment = Shared.GetTime(true) - GetIsGamePausedTime()
		else
			self.timepaused = GetIsGamePausedTime()
			self.timeadjustment = gSharedGetTimeAdjustments
		end
	end
)

local originalNS2PlayerOnCreate
originalNS2PlayerOnCreate = Class_ReplaceMethod("Player", "OnCreate", 
	function(self)
		originalNS2PlayerOnCreate(self)
		self.gamepaused = GetIsGamePaused()
		if self.gamepaused then
			self.timepaused = GetIsGamePausedTime()
			self.timeadjustment = Shared.GetTime(true) - GetIsGamePausedTime()
		else
			self.timepaused = GetIsGamePausedTime()
			self.timeadjustment = gSharedGetTimeAdjustments
		end
	end
)

function GetCommanderLogoutAllowed()
	return not GetIsGamePaused()
end

function GetIsGamePaused()
	return gamestate.gamepaused
end

function GetIsGamePausing()
	return gamestate.gamepausedcountdown ~= 0
end

function GetIsGamePausedTime()
	return gamestate.gamepausedtime
end

local lastTimeAdjustmentUpdate = 0
local kTimeAdjustmentUpdateRate = 1

--This runs every tick to procedurally update any timerelevant fields of any relevant ents to insure they remain in the appropriate state.
local function UpdateEntStates(deltatime)
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	local updateTime = false
	lastTimeAdjustmentUpdate = lastTimeAdjustmentUpdate + deltatime
	if lastTimeAdjustmentUpdate > (1 / kTimeAdjustmentUpdateRate) then
		lastTimeAdjustmentUpdate = lastTimeAdjustmentUpdate - (1 / kTimeAdjustmentUpdateRate)
		updateTime = true
	end
	for _, player in ientitylist(playerRecords) do
		if player ~= nil then
			if updateTime then
				player.timeadjustment = gSharedGetTimeAdjustments
			end
			player.gamepaused = gamestate.gamepaused
			player.timepaused = gamestate.gamepausedtime
		end
	end
	local gamerules = GetGamerules()
	if gamerules then
		gamerules.timeToSendAllPings = gamerules.timeToSendAllPings - deltatime
		gamerules.timeToSendIndividualPings = gamerules.timeToSendIndividualPings - deltatime
		gamerules.timeToSendHealth = gamerules.timeToSendHealth - deltatime
		gamerules.timeToSendTechPoints = gamerules.timeToSendTechPoints - deltatime
		gamerules:UpdatePings()
		gamerules:UpdateHealth()
		gamerules:UpdateTechPoints()
	end
end

--This runs when game resumes, should restore any ents whos states were saved initially.
local function ResumeEntStates()
	
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		if player ~= nil then
			player.gamepaused = gamestate.gamepaused
			player.timeadjustment = gSharedGetTimeAdjustments
			player.timepaused = gamestate.gamepausedtime
		end
	end
	--Resume the annoying noise
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

--This runs when the pause enables, saves the times/states of any ents that cannot be procedurally correctly.
local function SaveEntStates()

	--Stopppp the duck turrets
	local Sentries = Shared.GetEntitiesWithClassname("Sentry")
	for _, Sentry in ientitylist(Sentries) do
		Sentry.attacking = false
	end

	--Stop the bacon from spammmming.
	local Obs = Shared.GetEntitiesWithClassname("Observatory")
	for _, Ob in ientitylist(Obs) do
		if Ob.distressBeaconTime ~= nil and Ob.distressBeaconSound ~= nil then
			Ob.distressBeaconSound:Stop()
			--Dont wanna listen to that noise over and over and over and over and over ..
		end
	end
	
	--Cancel out whip attacks
	local Whips = Shared.GetEntitiesWithClassname("Whip")
	for _, Whip in ientitylist(Whips) do
		Whip.attacking = false
		Whip.slapping = false
		Whip.bombarding = false
		Whip.attackStartTime = nil
		Whip.targetId = Entity.invalidId
		Whip.waitingForEndAttack = false
	end
	
	--Block movement instantly so that its not updated each frame needlessly
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		if player ~= nil then
			if ValidateTeamNumber(player:GetTeamNumber()) then
				player:PrimaryAttackEnd()
				local weapon = player:GetActiveWeapon()
				if weapon ~= nil then
					weapon.reloading = false
				end
				player:SetCameraShake(0)
				if(player.secondaryAttackLastFrame ~= nil and player.secondaryAttackLastFrame) then
					player:SecondaryAttackEnd()
				end
			end
			player.gamepaused = true
			player.timepaused = Shared.GetTime()
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

	if gamestate.serverpauseloopenabled then
		gamestate.gamepauseddelta = gamestate.gamepauseddelta + deltatime
		if GetIsGamePaused() then
			--Going to check and reblock player movement every second or so - trying every frame, might as well.
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
					SendAllClientsMessage(string.format(GetNSLMessage("PauseResumeWarningMessage"), ((GetNSLConfigValue("PausedMaxDuration") - gamestate.gamepauseddelta))), true)
				end
				gamestate.gamepausedmessagetime = 0
			end
			UpdateEntStates(deltatime)
			if GetNSLConfigValue("PausedMaxDuration") ~= 0 and gamestate.gamepauseddelta >= GetNSLConfigValue("PausedMaxDuration") and gamestate.gamepausedcountdown == 0 then
				gamestate.serverprepauseloopenabled = true
				gamestate.gamepausedcountdown = GetNSLConfigValue("PauseEndDelay")
			end
			--No more scoreboard updates, uses PlayerInfo ent.
		else
			ResumeEntStates()
			gamestate.serverpauseloopenabled = false
			if gamestate.gamepausingteam ~= 0 then
				local pausesremaining = (GetNSLConfigValue("PauseMaxPauses") - (gamestate.teampauses[GetActualTeamName(gamestate.gamepausingteam)] or 0))
				SendAllClientsMessage(string.format(GetNSLMessage("PauseResumeMessage"), GetActualTeamName(gamestate.gamepausingteam), pausesremaining))
			end
			gamestate.gamepausedtime = 0
			gamestate.gamepausingteam = 0
			gamestate.gamepauseddelta = 0
		end
	end
	if gamestate.serverprepauseloopenabled then
		gamestate.gameprepausedelta = gamestate.gameprepausedelta + deltatime
		if gamestate.gameprepausedelta >= 1 then
			gamestate.gamepausedcountdown = (gamestate.gamepausedcountdown - 1)
			if gamestate.gamepausedcountdown > 0 then
				SendAllClientsMessage(string.format(GetNSLMessage("PauseWarningMessage"), ConditionalValue(GetIsGamePaused(), "resume", "pause"), (gamestate.gamepausedcountdown)), true)
			else
				if not GetIsGamePaused() then
					SaveEntStates()
					gamestate.serverpauseloopenabled = true
					SendAllClientsMessage(GetNSLMessage("PausePausedMessage"))
					gamestate.gamepausedtime = Shared.GetTime()
				else
					--Since other event already running, just let the final trigger run there (will be next frame).
				end
				gamestate.serverprepauseloopenabled = false
				gamestate.gamepaused = not GetIsGamePaused()
				gamestate.gamepausedcountdown = 0
			end
			gamestate.gameprepausedelta = gamestate.gameprepausedelta - 1
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
					gamestate.serverprepauseloopenabled = true
					SendAllClientsMessage(string.format(GetNSLMessage("PausePlayerMessage"), player:GetName()), true)
				else
					SendClientMessage(client, GetNSLMessage("PauseTooManyPausesMessage"))
				end
			end
		end
	end
	
end

--Trigger pause from somewhere else
function TriggerDisconnectNSLPause(name, pausingTeam, pauseDelay, forcePause)
	
	if GetGamerules():GetGameStarted() and GetNSLModEnabled() and GetNSLConfigValue("PauseEnabled") then
		if not GetIsGamePaused() and gamestate.gamepausedcountdown == 0 and pausingTeam and ValidateTeamNumber(pausingTeam) then
			local validpause = false
			if (gamestate.teampauses[GetActualTeamName(pausingTeam)] or 0) < GetNSLConfigValue("PauseMaxPauses") then
				gamestate.teampauses[GetActualTeamName(pausingTeam)] = (gamestate.teampauses[GetActualTeamName(pausingTeam)] or 0) + 1
				validpause = true
			end
			if validpause or forcePause then
				gamestate.team1resume = false
				gamestate.team2resume = false
				gamestate.gamepausedcountdown = pauseDelay
				gamestate.gamepausingteam = pausingTeam
				gamestate.serverprepauseloopenabled = true
				SendAllClientsMessage(string.format(GetNSLMessage("PauseDisconnectedMessage"), name))
			else
				SendClientMessage(client, GetNSLMessage("PauseTooManyPausesMessage"))
			end
		end
	end
end

Event.Hook("Console_gpause",               OnCommandPause)
gChatCommands["pause"] = OnCommandPause
gChatCommands["!pause"] = OnCommandPause

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
					gamestate.serverprepauseloopenabled = true
					gamestate.gamepausedcountdown = GetNSLConfigValue("PauseEndDelay")
				end
			end
		end
	end
	
end

Event.Hook("Console_unpause",               OnCommandUnPause)
gChatCommands["unpause"] = OnCommandUnPause
gChatCommands["!unpause"] = OnCommandUnPause
gChatCommands["resume"] = OnCommandUnPause
gChatCommands["!resume"] = OnCommandUnPause

local function OnCommandAdminPause(client)
	
	if client and GetNSLModEnabled() and GetNSLConfigValue("PauseEnabled") then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			if GetGamerules():GetGameStarted() then
				if gamestate.gamepausedcountdown == 0 then
					gamestate.serverprepauseloopenabled = true
					gamestate.team1resume = false
					gamestate.team2resume = false
					gamestate.gamepausedcountdown = ConditionalValue(GetIsGamePaused(), GetNSLConfigValue("PauseEndDelay"), GetNSLConfigValue("PauseStartDelay"))
				else
					gamestate.serverprepauseloopenabled = false
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