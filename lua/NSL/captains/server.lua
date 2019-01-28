-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/captains/server.lua
-- - Dragon

local kCaptainsPhase = kNSLCaptainsStates.REGISTRATION
local kCaptainsPhaseChangeTime = 0
local kRegisteredPlayers = { }
local kCaptainVotes = { }
local kSelectedCaptains = { [kTeam1Index] = 0, [kTeam2Index] = 0 }
local kSelectedTeams = { [kTeam1Index] = { }, [kTeam2Index] = { } }
local kCaptainActiveSelection = 0
local kCaptainSelectionsLeft = 0
local kCaptainLastAlertMessage = 0
local kMapVotes = { }

function GetNSLCaptainsState()
	return kCaptainsPhase
end

function GetNSLCaptainsGameStartReady()
	return kCaptainsPhase == kNSLCaptainsStates.ROUND1 or kCaptainsPhase == kNSLCaptainsStates.ROUND2
end

local function SetNSLCaptainsState(newState)
	kCaptainsPhase = newState
	kCaptainsPhaseChangeTime = Shared.GetTime()
	for i = 1, #gCaptainsStateChange do
		gCaptainsStateChange[i](kCaptainsPhase)
	end
end

local function CleanupCaptainState()
	kRegisteredPlayers = { }
	kCaptainsPhaseChangeTime = Shared.GetTime()
	kSelectedCaptains = { [kTeam1Index] = 0, [kTeam2Index] = 0 }
	kSelectedTeams = { [kTeam1Index] = { }, [kTeam2Index] = { } }
	kCaptainVotes = { }
	kCaptainActiveSelection = 0
	kCaptainSelectionsLeft = 0
	kCaptainsPhase = kNSLCaptainsStates.REGISTRATION
	kCaptainLastAlertMessage = Shared.GetTime()
	kMapVotes = { }
end

local function CheckStartVotingPhase()
	if kCaptainsPhase == kNSLCaptainsStates.REGISTRATION then
		if #kRegisteredPlayers == GetNSLCaptainsPlayerLimit() * 2 then
			SetNSLCaptainsState(kNSLCaptainsStates.VOTING)
			SendAllClientsMessage("NSL_CAPTAINS_VOTING_STARTED", false, GetNSLConfigValue("CaptainsVotingDuration"))
		end
	end
end

local function CheckCanJoinTeam(gameRules, player, teamNumber)
	local client = player:GetClient()
	if GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS and client then
		if teamNumber ~= kSpectatorIndex then
			-- If we have already been selected for a team, allow us to join it
			if (teamNumber == kTeam1Index or teamNumber == kTeam2Index) and table.contains(kSelectedTeams[teamNumber], client:GetUserId()) then
				-- We are approved
				return true
			end
			if table.contains(kRegisteredPlayers, client:GetUserId()) and teamNumber == 0 then
				-- Also approved
				return true
			end
			-- NOPE
			return false
		end
	end
	return true
end

table.insert(gCanJoinTeamFunctions, CheckCanJoinTeam)

local function OnCommandJoinGame(client)
	local gamerules = GetGamerules()
	if gamerules and client and GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS then
		-- Do stuff
		local player = client:GetControllingPlayer()
		local playername = player:GetName()
		if kCaptainsPhase == kNSLCaptainsStates.REGISTRATION then
			--ALready registered?
			if not table.contains(kRegisteredPlayers, client:GetUserId()) then
				-- Check if we can register
				if #kRegisteredPlayers < GetNSLCaptainsPlayerLimit() * 2 then
					-- Registered, give them the good news
					table.insert(kRegisteredPlayers, client:GetUserId())
					SendAllClientsMessage("NSL_CAPTAINS_PLAYER_REGISTERED", false, playername, GetNSLCaptainsPlayerLimit() * 2 - #kRegisteredPlayers)
					gamerules:JoinTeam(player, kTeamReadyRoom)
					-- Trigger scans to start picking process
					CheckStartVotingPhase()
				else
					-- Too many players already :<
					SendClientMessage(client, "NSL_CAPTAINS_TOO_MANY_PLAYERS_REGISTERED", false)
				end
			else
				SendClientMessage(client, "NSL_CAPTAINS_ALREADY_REGISTERED", false)
			end
		end
	end
end

Event.Hook("Console_joingame", OnCommandJoinGame)
RegisterNSLHelpMessageForCommand("CMD_JOINGAME", false)
gChatCommands["joingame"] = OnCommandJoinGame
gChatCommands["!join"] = OnCommandJoinGame

local function OnCommandLeaveGame(client)
	local gamerules = GetGamerules()
	if gamerules and client and GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS then
		local player = client:GetControllingPlayer()
		if table.contains(kRegisteredPlayers, client:GetUserId()) then
			table.removevalue(kRegisteredPlayers, client:GetUserId())
			-- SendAllClientsMessage("TournamentModeTeamReady", false, playername, "unreadied", GetActualTeamName(teamnum))
			-- Abort any picking/pregame, if this is a captain just reset
			if player then
				gamerules:JoinTeam(player, kSpectatorIndex)
			end
		end
	end
end

Event.Hook("Console_leavegame", OnCommandLeaveGame)
RegisterNSLHelpMessageForCommand("CMD_LEAVEGAME", false)
gChatCommands["leavegame"] = OnCommandLeaveGame
gChatCommands["!leave"] = OnCommandLeaveGame

local function CaptainsModeOnDisconnect(client)
	--Depending on who and when, do stuff
	--OnCommandLeaveGame(client)
end

table.insert(gDisconnectFunctions, CaptainsModeOnDisconnect)

local function OnClientConnected(client)
	if client and GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS then
		local ns2id = client:GetUserId()
		local gamerules = GetGamerules()
		local player = client:GetControllingPlayer()
		if table.contains(kSelectedTeams[kTeam1Index], ns2id) then
			-- rejoin team 1
			gamerules:JoinTeam(player, kTeam1Index)
		end
		if table.contains(kSelectedTeams[kTeam2Index], ns2id) then
			-- rejoin team 1
			gamerules:JoinTeam(player, kTeam2Index)
		end
		if not table.contains(kRegisteredPlayers, ns2id) then
			-- In captains mode, move joiners instantly to spec.  From there they 'register' to join
			gamerules:JoinTeam(player, kSpectatorIndex)
			if kCaptainsPhase == kNSLCaptainsStates.REGISTRATION then
				SendClientMessage(client, "NSL_CAPTAINS_MODE_WELCOME_REGISTER", false)
			else
				SendClientMessage(client, "NSL_CAPTAINS_MODE_WELCOME_INPROGRESS", false)
			end
		end
	end
end

table.insert(gConnectFunctions, OnClientConnected)

local function CollateCaptainVotes(finalize)
	local captainVotes = { }
	local possibleCaptains = { }
	local castedVotes = 0
	for k, v in pairs(kCaptainVotes) do
		for i = 1, #v do
			captainVotes[v[i]] = (captainVotes[v[i]] and captainVotes[v[i]] or 0) + 1
			table.insertunique(possibleCaptains, v[i])
			castedVotes = castedVotes + 1
		end
	end
	if castedVotes >= GetNSLCaptainsPlayerLimit() * 2 * 2 then
		-- Everyone has voted twice, go!
		finalize = true
	end
	table.sort(possibleCaptains, function(a, b) return captainVotes[a] > captainVotes[b] end)
	if finalize and #possibleCaptains >= 2 then
		local captain1, captain2
		captain1 = possibleCaptains[1]
		captain2 = possibleCaptains[2]
		if captain1 and captain2 then
			-- We can proceed
			if math.random(0, 1) < 0.5 then
				kSelectedCaptains[kTeam1Index] = captain1
				kSelectedCaptains[kTeam2Index] = captain2
			else
				kSelectedCaptains[kTeam2Index] = captain1
				kSelectedCaptains[kTeam1Index] = captain2
			end
			-- Announce
			local team1captain, team2captain
			local gamerules = GetGamerules()
			team1captain = NSLGetPlayerMatching(kSelectedCaptains[kTeam1Index])
			team2captain = NSLGetPlayerMatching(kSelectedCaptains[kTeam2Index])
			if team1captain and team2captain then
				SetNSLCaptainsState(kNSLCaptainsStates.SELECTION)
				gamerules:JoinTeam(team1captain, 1)
				table.insert(kSelectedTeams[kTeam1Index], kSelectedCaptains[kTeam1Index])
				table.insert(kSelectedTeams[kTeam2Index], kSelectedCaptains[kTeam2Index])
				gamerules:JoinTeam(team2captain, 2)
				SendAllClientsMessage("NSL_CAPTAINS_SELECTION", false, team1captain:GetName(), team2captain:GetName())
				kCaptainVotes = { }
				kCaptainActiveSelection = 1
				kCaptainSelectionsLeft = 1
			end
		end
	end
end

local function OnCommandVoteCaptain(client, captain)
	local target = NSLGetPlayerMatching(captain)
	if client and GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS and target and kCaptainsPhase == kNSLCaptainsStates.VOTING then
		local captainClient = target:GetClient()
		local ns2id = client:GetUserId()
		if table.contains(kRegisteredPlayers, ns2id) then
			-- Only registered players can vote!
			if not kCaptainVotes[ns2id] then
				kCaptainVotes[ns2id] = { }
			end
			if #kCaptainVotes[ns2id] > 2 then
				-- Cannot vote for more captains!
				return
			end
			if captainClient then
				table.insert(kCaptainVotes[ns2id], captainClient:GetUserId())
				SendClientMessage(client, "NSL_CAPTAINS_VOTED_FOR_CAPTAIN", false, target:GetName(), 2 - #kCaptainVotes[ns2id])
				CollateCaptainVotes()
			end
		end
	end
end

Event.Hook("Console_votecaptain", OnCommandVoteCaptain)
RegisterNSLHelpMessageForCommand("CMD_VOTECAPTAIN", false)
gArgumentedChatCommands["votecaptain"] = OnCommandVoteCaptain

local function OnCommandSelectPlayer(client, player)
	local target = NSLGetPlayerMatching(player)
	local captain = client:GetControllingPlayer()
	local gamerules = GetGamerules()
	if client and GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS and target and kCaptainsPhase == kNSLCaptainsStates.SELECTION then
		local playerClient = target:GetClient()
		local ns2id = client:GetUserId()
		if (kSelectedCaptains[kTeam1Index] == ns2id or kSelectedCaptains[kTeam2Index] == ns2id) and playerClient then
			-- Only captains can select
			local targetns2id = playerClient:GetUserId()
			local targetTeam = kSelectedCaptains[kTeam1Index] == ns2id and kTeam1Index or kTeam2Index
			if kCaptainActiveSelection == targetTeam and kCaptainSelectionsLeft > 0 and table.contains(kRegisteredPlayers, targetns2id) and 
				not table.contains(kSelectedTeams[kTeam2Index], targetns2id) and not table.contains(kSelectedTeams[kTeam2Index], targetns2id) then
				SendAllClientsMessage("NSL_CAPTAIN_SELECTED_PLAYER", false, target:GetName(), captain:GetName())
				table.insert(kSelectedTeams[targetTeam], targetns2id)
				gamerules:JoinTeam(target, targetTeam)
				local lastCaptainSelecting = kCaptainActiveSelection
				kCaptainActiveSelection = kCaptainSelectionsLeft > 0 and kCaptainActiveSelection or kCaptainActiveSelection == kTeam1Index and kTeam2Index or kTeam1Index
				kCaptainSelectionsLeft = kCaptainSelectionsLeft > 0 and kCaptainSelectionsLeft - 1 or 2
				if lastCaptainSelecting ~= kCaptainActiveSelection then
					-- New captain can select now
					local otherCaptain = NSLGetPlayerMatching(kSelectedCaptains[kCaptainActiveSelection])
					if otherCaptain then
						SendAllClientsMessage("NSL_CAPTAIN_SWITCH_CAPTAIN_SELECTION", false, otherCaptain:GetName(), kCaptainSelectionsLeft)
					end
				else
					-- same captain can select again
					SendAllClientsMessage("NSL_CAPTAIN_SELECT_ADDITIONAL", false, captain:GetName(), kCaptainSelectionsLeft)
				end
			end
		end
	end
end

Event.Hook("Console_selectplayer", OnCommandSelectPlayer)
RegisterNSLHelpMessageForCommand("CMD_SELECTPLAYER", false)
gArgumentedChatCommands["selectplayer"] = OnCommandSelectPlayer

local mapCycle
local function ValidateMap(mapName)
	if not mapCycle then
		mapCycle = MapCycle_GetMapCycle()
	end
	mapName = string.lower(mapName)
	for m = 1, #mapCycle.maps do
		if mapName == (type(mapCycle.maps[m]) == "table" and string.lower(mapCycle.maps[m].map) or string.lower(mapCycle.maps[m])) then
			return true
		end
	end
	return false
end

local function OnCommandSelectMap(client, map)
	local gamerules = GetGamerules()
	local mapName = string.lower(map)
	if client and GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS and kCaptainsPhase == kNSLCaptainsStates.MAPVOTE and ValidateMap(mapName) then
		local ns2id = client:GetUserId()
		local player = client:GetControllingPlayer()
		local updatedVote = false
		if kMapVotes[ns2id] then
			-- We already voted, subtract old vote and add new
			kMapVotes[kMapVotes[ns2id]] = math.max(kMapVotes[kMapVotes[ns2id]] - 1, 0)
			SendAllClientsMessage("NSL_CAPTAIN_VOTED_FOR_MAP_CHANGED", false, player:GetName(), kMapVotes[ns2id], mapName)
			updatedVote = true
		end
		kMapVotes[ns2id] = mapName
		kMapVotes[mapName] = kMapVotes[mapName] and kMapVotes[mapName] + 1 or 1
		if not updatedVote then
			SendAllClientsMessage("NSL_CAPTAIN_VOTED_FOR_MAP", false, player:GetName(), mapName)
		end
	end
end

Event.Hook("Console_selectmap", OnCommandSelectMap)
RegisterNSLHelpMessageForCommand("CMD_SELECTMAP", false)
gArgumentedChatCommands["selectmap"] = OnCommandSelectMap

-- Callback from ns2gamerules when we are in pregame mode, and not ready to start
function MonitorCaptainsPreGameCountDown()
	local alertTime = kCaptainLastAlertMessage + GetNSLConfigValue("CaptainsAlertDelay") < Shared.GetTime()
	if kCaptainsPhase == kNSLCaptainsStates.REGISTRATION then
		if alertTime then
			SendAllClientsMessage("NSL_CAPTAINS_MODE_REGISTRATION_PERIODIC", false, #kRegisteredPlayers, GetNSLCaptainsPlayerLimit() * 2)
			kCaptainLastAlertMessage = Shared.GetTime()
		end
	elseif kCaptainsPhase == kNSLCaptainsStates.VOTING then
		if kCaptainsPhaseChangeTime + GetNSLConfigValue("CaptainsVotingTimeAllowed") < Shared.GetTime() then
			CollateCaptainVotes(true)
		elseif alertTime then
			for k, _ in ipairs(kRegisteredPlayers) do
				local player = NSLGetPlayerMatching(k)
				if player then
					local playerClient = Server.GetOwner(player)
					if playerClient then
						SendClientMessage(playerClient, "NSL_CAPTAINS_MODE_VOTING_PERIODIC", false, 2 - (#kCaptainVotes[ns2id] or 0))
					end
				end
			end
			kCaptainLastAlertMessage = Shared.GetTime()
		end
	elseif kCaptainsPhase == kNSLCaptainsStates.SELECTION then
		if kCaptainsPhaseChangeTime + GetNSLConfigValue("CaptainsSelectionTimeAllowed") < Shared.GetTime() then

		elseif alertTime then

			kCaptainLastAlertMessage = Shared.GetTime()
		end
	elseif kCaptainsPhase == kNSLCaptainsStates.MAPVOTE then
		if kCaptainsPhaseChangeTime + GetNSLConfigValue("CaptainsMapVoteTimeAllowed") < Shared.GetTime() then

		elseif alertTime then

			kCaptainLastAlertMessage = Shared.GetTime()
		end
	end
end