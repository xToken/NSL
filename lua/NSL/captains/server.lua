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
local kCaptainLastSelection = 0
local kCaptainLastAlertMessage = 0
local kCaptainsAssignTeamsAt = 0
local kCaptainsBasicMapVote = false
local kWinningMap
local kMapVoteTracking = { }
local kVotedMaps = { }
local kMapVotes = { }
local kMapVotingEnded = false

function GetNSLCaptainsState()
	return kCaptainsPhase
end

function GetNSLCaptainsGameStartReady()
	return (kCaptainsPhase == kNSLCaptainsStates.ROUND1 or kCaptainsPhase == kNSLCaptainsStates.ROUND2) and kCaptainsAssignTeamsAt == 0
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
	kCaptainsAssignTeamsAt = 0
	kCaptainLastSelection = 0
	kCaptainsPhase = kNSLCaptainsStates.REGISTRATION
	kCaptainLastAlertMessage = Shared.GetTime()
	kMapVotes = { }
	kVotedMaps = { }
	kMapVoteTracking = { }
	kWinningMap = nil
	kMapVotingEnded = false
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

RegisterNSLConsoleCommand("joingame", OnCommandJoinGame, "CMD_JOINAME", true)
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

RegisterNSLConsoleCommand("leavegame", OnCommandLeaveGame, "CMD_LEAVEGAME", true)
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
				SetNSLCaptainsState(kNSLCaptainsStates.SELECTING)
				SendClientMessage(Server.GetOwner(team1captain), "NSL_CAPTAIN_SWITCH_CAPTAIN_SELECTION", false, 1)
				SendClientMessage(Server.GetOwner(team2captain), "NSL_CAPTAINS_SELECTED", false)
				table.insert(kSelectedTeams[kTeam1Index], kSelectedCaptains[kTeam1Index])
				gamerules:JoinTeam(team1captain, 1)
				table.insert(kSelectedTeams[kTeam2Index], kSelectedCaptains[kTeam2Index])
				gamerules:JoinTeam(team2captain, 2)
				SendAllClientsMessage("NSL_CAPTAINS_SELECTION", false, team1captain:GetName(), team2captain:GetName())
				kCaptainVotes = { }
				kCaptainActiveSelection = 1
				kCaptainSelectionsLeft = 1
				kCaptainLastSelection = Shared.GetTime()
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
			if #kCaptainVotes[ns2id] >= 2 then
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

RegisterNSLConsoleCommand("votecaptain", OnCommandVoteCaptain, "CMD_VOTECAPTAIN", true)
RegisterNSLHelpMessageForCommand("CMD_VOTECAPTAIN", false)
gArgumentedChatCommands["votecaptain"] = OnCommandVoteCaptain

local function OnCommandSelectPlayer(client, player)
	local target = NSLGetPlayerMatching(player)
	local captain = client:GetControllingPlayer()
	local gamerules = GetGamerules()
	if client and GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS and target and kCaptainsPhase == kNSLCaptainsStates.SELECTING then
		local playerClient = target:GetClient()
		local ns2id = client:GetUserId()
		if (kSelectedCaptains[kTeam1Index] == ns2id or kSelectedCaptains[kTeam2Index] == ns2id) and playerClient then
			-- Only captains can select
			local targetns2id = playerClient:GetUserId()
			local targetTeam = kSelectedCaptains[kTeam1Index] == ns2id and kTeam1Index or kTeam2Index
			if kCaptainActiveSelection == targetTeam and table.contains(kRegisteredPlayers, targetns2id) and 
				not table.contains(kSelectedTeams[kTeam1Index], targetns2id) and not table.contains(kSelectedTeams[kTeam2Index], targetns2id) then
				SendAllClientsMessage("NSL_CAPTAIN_SELECTED_PLAYER", false, target:GetName(), captain:GetName())
				table.insert(kSelectedTeams[targetTeam], targetns2id)
				gamerules:JoinTeam(target, targetTeam)
				-- check if all players are selected
				if #kSelectedTeams[kTeam1Index] + #kSelectedTeams[kTeam2Index] >= #kRegisteredPlayers then
					-- Everyone has been picked!
					kCaptainActiveSelection = 0
					kCaptainSelectionsLeft = 0
					kCaptainLastSelection = Shared.GetTime()
					SetNSLCaptainsState(kNSLCaptainsStates.ROUND1)
					SendAllClientsMessage("NSL_CAPTAIN_ALL_PLAYERS_SELECTED", false)
				else
					local lastCaptainSelecting = kCaptainActiveSelection
					kCaptainActiveSelection = kCaptainActiveSelection == kTeam1Index and kTeam2Index or kTeam1Index
					kCaptainLastSelection = Shared.GetTime()
					if lastCaptainSelecting ~= kCaptainActiveSelection then
						-- New captain can select now
						local otherCaptain = NSLGetPlayerMatching(kSelectedCaptains[kCaptainActiveSelection])
						if otherCaptain then
							SendClientMessage(Server.GetOwner(otherCaptain),"NSL_CAPTAIN_SWITCH_CAPTAIN_SELECTION", false, 1)
						end
					else
						-- same captain can select again
						--SendAllClientsMessage("NSL_CAPTAIN_SELECT_ADDITIONAL", false, 1)
					end
				end
			end
		end
	end
end

local function RandomlySelectPlayer()
	local remainingPlayers = { }
	for _, v in ipairs(kRegisteredPlayers) do
		if not table.contains(kSelectedTeams[kTeam1Index], v) and not table.contains(kSelectedTeams[kTeam2Index], v) then
			table.insert(remainingPlayers, v)
		end
	end
	local randomPlayer = math.random(1, #remainingPlayers)
	local targetCaptain = kSelectedCaptains[kCaptainActiveSelection]
	if randomPlayer and targetCaptain then
		local player = NSLGetPlayerMatching(remainingPlayers[randomPlayer])
		local captain = NSLGetPlayerMatching(targetCaptain)
		if player and captain then
			SendAllClientsMessage("NSL_CAPTAIN_RANDOMLY_SELECTED_PLAYER", false, captain:GetName())
			OnCommandSelectPlayer(Server.GetOwner(captain), remainingPlayers[randomPlayer])
		end
	end
end

RegisterNSLConsoleCommand("selectplayer", OnCommandSelectPlayer, "CMD_SELECTPLAYER", true)
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

local function TallyBuiltinMapVoteCount(final)
	table.sort(kVotedMaps, function(a, b) return kMapVotes[a] > kMapVotes[b] end)
	return kVotedMaps[1]
end

local function OnCommandSelectMap(client, map)
	local gamerules = GetGamerules()
	local mapName = string.lower(map)
	if client and GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS and kCaptainsPhase == kNSLCaptainsStates.MAPVOTE and ValidateMap(mapName) and kCaptainsBasicMapVote then
		local ns2id = client:GetUserId()
		local player = client:GetControllingPlayer()
		local updatedVote = false
		if kMapVoteTracking[ns2id] then
			-- We already voted, subtract old vote and add new
			kMapVotes[kMapVoteTracking[ns2id]] = math.max(kMapVotes[kMapVoteTracking[ns2id]] - 1, 0)
			SendAllClientsMessage("NSL_CAPTAIN_VOTED_FOR_MAP_CHANGED", false, player:GetName(), kMapVoteTracking[ns2id], mapName)
			updatedVote = true
		end
		kMapVoteTracking[ns2id] = mapName
		kMapVotes[mapName] = kMapVotes[mapName] and kMapVotes[mapName] + 1 or 1
		table.insertunique(kVotedMaps, mapName)
		if not updatedVote then
			SendAllClientsMessage("NSL_CAPTAIN_VOTED_FOR_MAP", false, player:GetName(), mapName)
		end
	end
end

RegisterNSLConsoleCommand("selectmap", OnCommandSelectMap, "CMD_SELECTMAP", true)
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
		if kCaptainsPhaseChangeTime + GetNSLConfigValue("CaptainsVotingDuration") < Shared.GetTime() then
			CollateCaptainVotes(true)
		elseif alertTime then
			local timeRemaining = math.floor(GetNSLConfigValue("CaptainsMapVoteTimeAllowed") - (Shared.GetTime() - kCaptainsPhaseChangeTime))
			for _, v in ipairs(kRegisteredPlayers) do
				local player = NSLGetPlayerMatching(v)
				if player then
					local playerClient = Server.GetOwner(player)
					local votesRemaining = 2 - (kCaptainVotes[v] and #kCaptainVotes[v] or 0)
					if playerClient then
						if votesRemaining > 0 then
							SendClientMessage(playerClient, "NSL_CAPTAINS_MODE_VOTING_PERIODIC_WITHVOTES", false, timeRemaining, votesRemaining)
						else
							SendClientMessage(playerClient, "NSL_CAPTAINS_MODE_VOTING_PERIODIC", false, timeRemaining)
						end
					end
				end
			end
			kCaptainLastAlertMessage = Shared.GetTime()
		end
	elseif kCaptainsPhase == kNSLCaptainsStates.SELECTING then
		if kCaptainLastSelection + GetNSLConfigValue("CaptainsSelectionTimeAllowed") < Shared.GetTime() then
			-- Manually pick randomly
			RandomlySelectPlayer()
		elseif alertTime then
			-- Periodic message?
			kCaptainLastAlertMessage = Shared.GetTime()
		end
	elseif kCaptainsPhase == kNSLCaptainsStates.ROUND1 and kCaptainsAssignTeamsAt > 0 then
		if kCaptainsAssignTeamsAt < Shared.GetTime() then
			-- Flip team assignments
			local team1players, team2players
			local gamerules = GetGamerules()
			team1players = kSelectedTeams[kTeam1Index]
			team2players = kSelectedTeams[kTeam2Index]
			kSelectedTeams[kTeam1Index] = team2players
			kSelectedTeams[kTeam2Index] = team1players
			for _, v in ipairs(kSelectedTeams[kTeam1Index]) do
				-- rejoin team 1
				local player = NSLGetPlayerMatching(v)
				if player then
					gamerules:JoinTeam(player, kTeam1Index)
				end
			end
			for _, v in ipairs(kSelectedTeams[kTeam2Index]) do
				-- rejoin team 2
				local player = NSLGetPlayerMatching(v)
				if player then
					gamerules:JoinTeam(player, kTeam2Index)
				end
			end
			SetNSLCaptainsState(kNSLCaptainsStates.ROUND2)
			kCaptainsAssignTeamsAt = 0
		end
	elseif kCaptainsPhase == kNSLCaptainsStates.MAPVOTE and kCaptainsBasicMapVote then
		if kWinningMap and kCaptainsPhaseChangeTime + GetNSLConfigValue("CaptainsMapVoteTimeAllowed") + 5 < Shared.GetTime() then
			MapCycle_ChangeMap(kWinningMap)
		elseif kCaptainsPhaseChangeTime + GetNSLConfigValue("CaptainsMapVoteTimeAllowed") < Shared.GetTime() and not kMapVotingEnded then
			kWinningMap = TallyBuiltinMapVoteCount()
			if kWinningMap then
				SendAllClientsMessage("NSL_CAPTAINS_MAP_VOTE_COMPLETED", false, kWinningMap, 5)
			else
				-- bleh
				SetNSLCaptainsState(kNSLCaptainsStates.REGISTRATION)
			end
			kMapVotingEnded = true
		elseif alertTime then
			local winningMap = TallyBuiltinMapVoteCount()
			if not winningMap then winningMap = "no map" end
			SendAllClientsMessage("NSL_CAPTAINS_MAP_VOTE_PERIODIC", false, math.floor(GetNSLConfigValue("CaptainsMapVoteTimeAllowed") - (Shared.GetTime() - kCaptainsPhaseChangeTime)), winningMap)
			kCaptainLastAlertMessage = Shared.GetTime()
		end
	end
end

local function CheckAndStartBestMapVote()
	if Shine then
		-- somehow check and start shine mapvote?
	else
		-- booo
		SendAllClientsMessage("NSL_CAPTAINS_MAP_VOTE_STARTED", false, GetNSLConfigValue("CaptainsMapVoteTimeAllowed"))
		kCaptainsBasicMapVote = true
	end
end

local function UpdateTeamDataOnGameEnd(gameRules, winningteam)
	if GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS then
		-- Check round1 end
		if kCaptainsPhase == kNSLCaptainsStates.ROUND1 then
			-- Set time for next round soft start
			kCaptainsAssignTeamsAt = Shared.GetTime() + 10
		end
		-- Check last round end
		if kCaptainsPhase == kNSLCaptainsStates.ROUND2 then
			-- time for map vote
			SetNSLCaptainsState(kNSLCaptainsStates.MAPVOTE)
			CheckAndStartBestMapVote()
		end
	end
end

table.insert(gGameEndFunctions, UpdateTeamDataOnGameEnd)

local function CaptainDebug(client, command, arg1, arg2)
	local gamerules = GetGamerules()
	if client and GetNSLModEnabled() and GetNSLMode() == kNSLPluginConfigs.CAPTAINS then
		if command == "assign" then
			-- arg1 = joining player
			local player = NSLGetPlayerMatching(arg1)
			if player then
				OnCommandJoinGame(Server.GetOwner(player))
			end
		end
		if command == "votecapt" then
			-- arg1 = voting player, arg2 = captain
			local player = NSLGetPlayerMatching(arg1)
			if player then
				OnCommandVoteCaptain(Server.GetOwner(player), arg2)
			end
		end
		if command == "select" then
			-- arg1 = teamId, arg2 = player
			local captId = kSelectedCaptains[arg1 == "1" and kTeam1Index or kTeam2Index]
			local capt = NSLGetPlayerMatching(captId)
			local player = NSLGetPlayerMatching(arg2)
			if capt and player then
				OnCommandSelectPlayer(Server.GetOwner(capt), arg2)
			end
		end
	end
end

RegisterNSLConsoleCommand("captdebug", CaptainDebug, "", false)

local oldServerClientGetUserId = ServerClient.GetUserId
function ServerClient:GetUserId()
	if self:GetIsVirtual() then
		return self:GetId()
	end
    return oldServerClientGetUserId(self)
end