-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/teammanager/server.lua
-- - Dragon

local teamData = { {name = kTeam1Name, id = 0}, {name = kTeam2Name, id = 0} }
local teamScore = { }
local teamQueue = { }
local overridenames = false
local kMinPlayersToName = 3

local function UpdateCachedTeamScores()
	for t, s in pairs(GetRecentScores()) do
		teamScore[t] = s
	end
end

UpdateCachedTeamScores()

function GetActualTeamName(teamnum)
	--Check players on team to get an idea of their 'team'
	if teamData[teamnum] then
		return teamData[teamnum].name
	end
	if teamnum == 3 then
		return "Spectators"
	else
		return "Others"	
	end
end

function GetFriendlyNameFromNSLTeamName(teamName)
	assert(false)
end

function GetNSLTeamID(teamNumber)
	if teamData[teamNumber] then
		return teamData[teamNumber].id
	end
end

local function GetTeamNameCount(teamnum)
	local data = { }
	local playerList = GetEntitiesForTeam("Player", teamnum)
	if playerList then
		for p = 1, #playerList do
			local player = playerList[p]
			local playerClient = Server.GetOwner(player)
			if playerClient then
				local ns2id = playerClient:GetUserId()
				local nsldata = GetNSLUserData(ns2id)
				if nsldata then
					if data[nsldata.NSL_Team] then
						data[nsldata.NSL_Team].count = data[nsldata.NSL_Team].count + 1
					else
						data[nsldata.NSL_Team] = {count = 1, id = nsldata.NSL_TID}
					end			
				end
			end
		end
	end
	return data
end

local function GetPrimaryTeam(teamnum, data)
	local teamName = ConditionalValue(teamnum == 1, kTeam1Name, kTeam2Name)
	local teamId = 0
	local count = 0
	if data then
		for t, d in pairs(data) do
			if d.count > count and t ~= "No Team" and d.count >= kMinPlayersToName then
				teamName = t
				teamId = d.id
				count = d.count
			end
		end
	end
	return teamName, teamId
end

local function CheckMercTeamJoin(player, teamNumber)
	local client = Server.GetOwner(player)
	if client then
		local ns2id = client:GetUserId()
		local nsldata = GetNSLUserData(ns2id)
		local teamName, teamId = GetPrimaryTeam(teamNumber, GetTeamNameCount(teamNumber))
		if nsldata and teamId ~= 0 then
			if (teamNumber == 1 or teamNumber == 2) and teamId ~= nsldata.NSL_TID then
				if teamQueue[teamNumber] == nil then
					teamQueue[teamNumber] = { }
					teamQueue[teamNumber][ns2id] = false 
					--This is set to true when mercs approved.
					SendClientMessage(client, GetNSLMessage("MercApprovalNeeded"))
					return false
				elseif teamQueue[teamNumber][ns2id] ~= true then
					teamQueue[teamNumber][ns2id] = false
					SendClientMessage(client, GetNSLMessage("MercApprovalNeeded"))
					return false
				end
			end
		end
	end
	return true
end

local function UpdateCallbacksWithNewTeamData(teamData, teamScore)
	-- basic sanity check here
	teamScore[teamData[1].name] = teamScore[teamData[1].name] or 0
	teamScore[teamData[2].name] = teamScore[teamData[2].name] or 0
	for i = 1, #gTeamNamesUpdatedFunctions do
		gTeamNamesUpdatedFunctions[i](teamData, teamScore)
	end
end

function ResetNSLTeamNames()
	teamData[1].name = kTeam1Name
	teamData[2].name = kTeam2Name
	teamData[1].id = 0
	teamData[2].id = 0
	UpdateCallbacksWithNewTeamData(teamData, teamScore)
end

local function UpdatePlayerDataOnActivation(newState)
	if newState == "GATHER" or newState == "DISABLED" then
		ResetNSLTeamNames()
	end
end

table.insert(gPluginStateChange, UpdatePlayerDataOnActivation)

local function UpdateOnSuccessfulTeamJoin(player, newTeamNumber)
	for i = 1, #gTeamJoinedFunctions do
		gTeamJoinedFunctions[i](player, newTeamNumber)
	end
end

--Detect team changes
local originalNS2GRJoinTeam
originalNS2GRJoinTeam = Class_ReplaceMethod("NS2Gamerules", "JoinTeam", 
	function(self, player, newTeamNumber, force)
		if GetNSLModEnabled() and GetNSLConfigValue("MercsRequireApproval") and not CheckMercTeamJoin(player, newTeamNumber) then
			return false, player
		end
		local success, player = originalNS2GRJoinTeam(self, player, newTeamNumber, force)
		if success then
			if not overridenames and (newTeamNumber == 1 or newTeamNumber == 2) and GetNSLModEnabled() and GetNSLConfigValue("OverrideTeamNames") then
				--Joined team, update
				local teamName, teamId = GetPrimaryTeam(newTeamNumber, GetTeamNameCount(newTeamNumber))
				if newTeamNumber == 1 and teamName ~= teamData[1].name then
					teamData[1].name = teamName
					teamData[1].id = teamId
					UpdateCallbacksWithNewTeamData(teamData, teamScore)
				elseif newTeamNumber == 2 and teamName ~= teamData[2].name then
					teamData[2].name = teamName
					teamData[2].id = teamId
					UpdateCallbacksWithNewTeamData(teamData, teamScore)
				end
			end
			UpdateOnSuccessfulTeamJoin(player, newTeamNumber)
		end
		return success, player
	end
)

local function UpdateTeamDataOnGameEnd(self, winningteam)
	if GetNSLModEnabled() then
		if winningteam then
			local winningteamname
			if winningteam:GetTeamType() == kAlienTeamType then
				winningteamname = teamData[2].name
			elseif winningteam:GetTeamType() == kMarineTeamType then
				winningteamname = teamData[1].name
			end
			if winningteamname ~= kTeam1Name and winningteamname ~= kTeam2Name then
				if teamScore[winningteamname] == nil then
					teamScore[winningteamname] = 1
				else
					teamScore[winningteamname] = teamScore[winningteamname] + 1
				end
			end
		end
		--Clear merc queue
		teamQueue = { }
		UpdateCallbacksWithNewTeamData(teamData, teamScore)
	end
end

table.insert(gGameEndFunctions, UpdateTeamDataOnGameEnd)

local function OnCommandOverrideTeamnames(client, team1name, team2name)
	if client and team1name and team2name then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			overridenames = true
			teamData[1].name = team1name
			teamData[2].name = team2name
			UpdateCallbacksWithNewTeamData(teamData, teamScore)
		end
	end
end

Event.Hook("Console_sv_nslsetteamnames", OnCommandOverrideTeamnames)
RegisterNSLHelpMessageForCommand("sv_nslsetteamnames: <team1name, team2name> Will set the team names manually, also will prevent automatic team name updates.", true)

local function OnCommandSwitchTeamNames(client)
	if client then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			overridenames = true
			local team1name = teamData[1].name
			teamData[1].name = teamData[2].name
			teamData[2].name = team1name
			UpdateCallbacksWithNewTeamData(teamData, teamScore)
		end
	end
end

Event.Hook("Console_sv_nslswitchteams", OnCommandSwitchTeamNames)
RegisterNSLHelpMessageForCommand("sv_nslswitchteams: Will switch team names (best used if setting team names manually).", true)

local function OnCommandSetTeamScores(client, team1score, team2score)
	team1score = tonumber(team1score)
	team2score = tonumber(team2score)
	if client then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			if team1score then
				teamScore[teamData[1].name] = team1score
			end
			if team2score then
				teamScore[teamData[2].name] = team2score
			end
			UpdateCallbacksWithNewTeamData(teamData, teamScore)
		end
	end
end

Event.Hook("Console_sv_nslsetteamscores", OnCommandSetTeamScores)
RegisterNSLHelpMessageForCommand("sv_nslsetteamscores: <t1score, t2score> Will set the team scores manually.", true)

local function OnCommandSetTeamIDs(client, team1id, team2id)
	team1id = tonumber(team1id)
	team2id = tonumber(team2id)
	if client then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			if team1id then
				teamData[1].id = team1id
			end
			if team2id then
				teamData[2].id = team2id
			end
			UpdateCallbacksWithNewTeamData(teamData, teamScore)
		end
	end
end

Event.Hook("Console_sv_nslsetteamids", OnCommandSetTeamIDs)
RegisterNSLHelpMessageForCommand("sv_nslsetteamids: <t1id, t2id> Will set the team ids manually.", true)

local function ApproveMercs(teamnum, playerid)
	local enemyteam = GetEnemyTeamNumber(teamnum)
	if enemyteam == kTeamInvalid then
		return
	end
	if teamQueue[enemyteam] then
		for id, state in pairs(teamQueue[enemyteam]) do
			if playerid == nil or playerid == id then
				teamQueue[enemyteam][id] = true
				local nsldata = GetNSLUserData(id)
				if nsldata then
					SendAllClientsMessage(string.format(GetNSLMessage("MercApproved"), nsldata.NICK, GetActualTeamName(enemyteam)))
				end
			end
		end
	end
end

local function OnCommandApproveMercs(client, target)
	if not client then return end
	local ns2id = client:GetUserId()
	local player = client:GetControllingPlayer()
	local tplayer = GetPlayerMatching(target)
	if player then
		local tns2id
		if tplayer then
			local pclient = Server.GetOwner(tplayer)
			if pclient then
				tns2id = pclient:GetUserId()
			end
		end
		local teamnum = player:GetTeamNumber()
		ApproveMercs(teamnum, tns2id)
	end
end

Event.Hook("Console_mercsok", OnCommandApproveMercs)
Event.Hook("Console_approvemercs", OnCommandApproveMercs)
gArgumentedChatCommands["/mercsok"] = OnCommandApproveMercs
gArgumentedChatCommands["mercsok"] = OnCommandApproveMercs
gArgumentedChatCommands["approvemercs"] = OnCommandApproveMercs

local function OnClientCommandApproveMercs(client, team, target)
	team = tonumber(team)
	local player = GetPlayerMatching(target)
	if client and team and (team == 1 or team == 2) then
		local NS2ID = client:GetUserId()
		local tns2id
		if player then
			local pclient = Server.GetOwner(player)
			if pclient then
				tns2id = pclient:GetUserId()
			end
		end
		if GetIsNSLRef(NS2ID) then
			ApproveMercs(team, tns2id)
		end
	end
end

Event.Hook("Console_sv_nslapprovemercs", OnClientCommandApproveMercs)
RegisterNSLHelpMessageForCommand("sv_nslapprovemercs: <team, opt. player> - Forces approval of teams mercs, '1' approving for marines which allows alien mercs.", true)

local function ClearMercs(teamnum)
	local enemyteam = GetEnemyTeamNumber(teamnum)
	if enemyteam == kTeamInvalid then
		return
	end
	if teamQueue[enemyteam] then
		teamQueue[enemyteam] = { }
		SendTeamMessage(teamnum, GetNSLMessage("MercsReset"))
	end
end

local function OnCommandClearMercs(client)
	if not client then return end
	local ns2id = client:GetUserId()
	local player = client:GetControllingPlayer()
	if player then
		local teamnum = player:GetTeamNumber()
		ClearMercs(teamnum)
	end
end

Event.Hook("Console_clearmercs", OnCommandClearMercs)
gChatCommands["rejectmercs"] = OnCommandClearMercs
gChatCommands["clearmercs"] = OnCommandClearMercs

local function OnClientCommandClearMercs(client, team)
	team = tonumber(team)
	if client and team and (team == 1 or team == 2) then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			ClearMercs(team)
		end
	end
end

Event.Hook("Console_sv_nslclearmercs", OnClientCommandClearMercs)
RegisterNSLHelpMessageForCommand("sv_nslclearmercs: <team> - 1,2 - Clears approval of teams mercs, '1' clearing any alien mercs.", true)

local function OnClientCommandMercHelp(client)
	if client then
		ServerAdminPrint(client, "rejectmercs" .. ": " .. "Chat command, will clear any merc approvals for your team.")
		ServerAdminPrint(client, "clearmercs" .. ": " .. "Chat or console command, will also clear any merc approvals for your team.")
		ServerAdminPrint(client, "/mercsok" .. ": " .. "Chat command, will approve opposing teams merc(s).")
		ServerAdminPrint(client, "mercsok" .. ": " .. "Chat or console command, will approve opposing teams merc(s).")
		ServerAdminPrint(client, "approvemercs" .. ": " .. "Chat command, will approve opposing teams merc(s).")
		ServerAdminPrint(client, "NOTE!" .. ": " .. "Approving a merc optionally accepts details to identify the target player.")
		ServerAdminPrint(client, "NOTE!" .. ": " .. "Mercs can be approved based on name, ns2id or game ID, all of which are listed in sv_nslinfo.")
		ServerAdminPrint(client, "NOTE!" .. ": " .. "/mercsok Dragon as an example.")
	end
end

Event.Hook("Console_sv_nslmerchelp", OnClientCommandMercHelp)
RegisterNSLHelpMessageForCommand("sv_nslmerchelp: Displays specific help information pertaining to approving and clearing mercs.", false)