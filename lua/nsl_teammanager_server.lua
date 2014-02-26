local t1name = "Marines"
local t2name = "Aliens"
local tscores = { }
local tqueue = { }
local overridenames = false

Script.Load("lua/nsl_class.lua")

local function SyncTeamInfotoClients(client)
	if client then
		Server.SendNetworkMessage(client, "TeamNames", {team1name = t1name, team2name = t2name, team1score = tscores[t1name] or 0, team2score = tscores[t2name] or 0 }, true)
	else
		Server.SendNetworkMessage("TeamNames", {team1name = t1name, team2name = t2name, team1score = tscores[t1name] or 0, team2score = tscores[t2name] or 0 }, true)
	end
end

table.insert(gConnectFunctions, SyncTeamInfotoClients)

function GetActualTeamName(teamnum)
	//Check players on team to get an idea of their 'team'
	local teamname = ConditionalValue(teamnum == 1, t1name, t2name)
	if not teamname then
		teamname = ConditionalValue(teamnum == 1, "Marines", "Aliens")
	end
	return teamname
end

local function GetTeamNameCount(teamnum)
	local teamdata = { }
	local playerList = GetEntitiesForTeam("Player", teamnum)
	if playerList then
		for p = 1, #playerList do
			local player = playerList[p]
			local playerClient = Server.GetOwner(player)
			if playerClient then
				local ns2id = playerClient:GetUserId()
				local nsldata = GetNSLUserData(ns2id)
				if nsldata ~= nil then
					if teamdata[nsldata.NSL_Team] ~= nil then
						teamdata[nsldata.NSL_Team] = teamdata[nsldata.NSL_Team] + 1
					else
						teamdata[nsldata.NSL_Team] = 1
					end			
				end
			end
		end
	end
	return teamdata
end

local function GetPrimaryTeam(teamnum, teamdata)
	local team = ConditionalValue(teamnum == 1, "Marines", "Aliens")
	local count = 0
	if teamdata ~= nil then
		for t, c in pairs(teamdata) do
			if c > count and t ~= "No Team" and c >= 3 then
				team = t
				count = c
			end	
		end
	end
	return team
end

local function CheckMercTeamJoin(player, teamNumber)
	local client = Server.GetOwner(player)
	if client then
		local ns2id = client:GetUserId()
		local nsldata = GetNSLUserData(ns2id)
		local teamname = GetPrimaryTeam(teamNumber, GetTeamNameCount(teamNumber))
		if nsldata ~= nil and teamname ~= ConditionalValue(teamNumber == 1, "Marines", "Aliens") then
			if (teamNumber == 1 or teamNumber == 2) and teamname ~= nsldata.NSL_Team then
				if tqueue[teamNumber] == nil then
					tqueue[teamNumber] = { }
					tqueue[teamNumber][ns2id] = false //This is set to true when mercs approved.
					SendClientMessage(client, GetNSLMessages().MercApprovalNeeded)
					return false
				elseif tqueue[teamNumber][ns2id] ~= true then
					tqueue[teamNumber][ns2id] = false
					SendClientMessage(client, GetNSLMessages().MercApprovalNeeded)
					return false
				end
			end
		end
	end
	return true
end

//Detect team changes
local originalNS2GRJoinTeam
originalNS2GRJoinTeam = Class_ReplaceMethod("NS2Gamerules", "JoinTeam", 
	function(self, player, newTeamNumber, force)
		if GetNSLModEnabled() and GetNSLConfig().kMercsRequireApproval and not CheckMercTeamJoin(player, newTeamNumber) then
			return false, player
		end
		local success, player = originalNS2GRJoinTeam(self, player, newTeamNumber, force)
		if success and not overridenames and (newTeamNumber == 1 or newTeamNumber == 2) and GetNSLModEnabled() then
			//Joined team, update
			local ntname = GetPrimaryTeam(newTeamNumber, GetTeamNameCount(newTeamNumber))
			if newTeamNumber == 1 and ntname ~= t1name then
				t1name = ntname
				SyncTeamInfotoClients()
			elseif newTeamNumber == 2 and ntname ~= t2name then
				t2name = ntname
				SyncTeamInfotoClients()
			end
		end
		return success, player
	end
)

local originalNS2GREndGame
originalNS2GREndGame = Class_ReplaceMethod("NS2Gamerules", "EndGame", 
	function(self, winningteam)
		originalNS2GREndGame(self, winningteam)
		if GetNSLModEnabled() then
			local winningteamname
			if winningteam:GetTeamType() == kAlienTeamType then
				winningteamname = t2name
			elseif winningteam:GetTeamType() == kMarineTeamType then
				winningteamname = t1name
			end
			if winningteamname ~= "Marines" and winningteamname ~= "Aliens" then
				if tscores[winningteamname] == nil then
					tscores[winningteamname] = 1
				else
					tscores[winningteamname] = tscores[winningteamname] + 1
				end
			end
			//Clear merc queue
			tqueue = { }
			SyncTeamInfotoClients()
		end
	end
)

local function OnCommandOverrideTeamnames(client, team1name, team2name)
	if client and team1name and team2name then
		local NS2ID = client:GetUserId()
		if ValidateNSLUsersAccessLevel(NS2ID) then
			overridenames = true
			t1name = team1name
			t2name = team2name
			SyncTeamInfotoClients()
		end
	end
end

Event.Hook("Console_sv_nslsetteamnames",               OnCommandOverrideTeamnames)

local function OnCommandSwitchTeamNames(client)
	if client then
		local NS2ID = client:GetUserId()
		if ValidateNSLUsersAccessLevel(NS2ID) then
			overridenames = true
			local team1name = t1name
			t1name = t2name
			t2name = team1name
			SyncTeamInfotoClients()
		end
	end
end

Event.Hook("Console_sv_nslswitchteams",               OnCommandSwitchTeamNames)

local function OnCommandSetTeamScores(client, team1score, team2score)
	team1score = tonumber(team1score)
	team2score = tonumber(team2score)
	if client then
		local NS2ID = client:GetUserId()
		if ValidateNSLUsersAccessLevel(NS2ID) then
			if team1score then
				tscores[t1name] = team1score
			end
			if team2score then
				tscores[t2name] = team2score
			end
			SyncTeamInfotoClients()
		end
	end
end

Event.Hook("Console_sv_nslsetteamscores",               OnCommandSetTeamScores)

local function ApproveMercs(teamnum, playerid)
	local enemyteam = GetEnemyTeamNumber(teamnum)
	if enemyteam == kTeamInvalid then
		return
	end
	if tqueue[enemyteam] ~= nil then
		for id, state in pairs(tqueue[enemyteam]) do
			if playerid == nil or playerid == id then
				tqueue[enemyteam][id] = true
				local nsldata = GetNSLUserData(id)
				if nsldata then
					SendAllClientsMessage(string.format(GetNSLMessages().MercApproved, nsldata.NICK, GetActualTeamName(enemyteam)))
				end
			end
		end
	end
end

local function OnCommandApproveMercs(client, target)
	local ns2id = client:GetUserId()
	local player = client:GetControllingPlayer()
	local tplayer = GetPlayerMatching(target)
	if player ~= nil then
		local tns2id
		if tplayer then
			local pclient = Server.GetOwner(tplayer)
			if pclient ~= nil then
				tns2id = pclient:GetUserId()
			end
		end
		local teamnum = player:GetTeamNumber()
		ApproveMercs(teamnum, tns2id)
	end
end

Event.Hook("Console_mercsok",                 OnCommandApproveMercs)
Event.Hook("Console_approvemercs",            OnCommandApproveMercs)
gArgumentedChatCommands["/mercsok"] = 		  OnCommandApproveMercs
gArgumentedChatCommands["mercsok"] = 		  OnCommandApproveMercs
gArgumentedChatCommands["approvemercs"] = 	  OnCommandApproveMercs

local function OnClientCommandApproveMercs(client, team, target)
	team = tonumber(team)
	local player = GetPlayerMatching(target)
	if client and team and (team == 1 or team == 2) then
		local NS2ID = client:GetUserId()
		local tns2id
		if player then
			local pclient = Server.GetOwner(player)
			if pclient ~= nil then
				tns2id = pclient:GetUserId()
			end
		end
		if ValidateNSLUsersAccessLevel(NS2ID) then
			ApproveMercs(team, tns2id)
		end
	end
end

Event.Hook("Console_sv_nslapprovemercs",               OnClientCommandApproveMercs)

local function ClearMercs(teamnum)
	local enemyteam = GetEnemyTeamNumber(teamnum)
	if enemyteam == kTeamInvalid then
		return
	end
	if tqueue[enemyteam] ~= nil then
		tqueue[enemyteam] = { }
		SendTeamMessage(teamnum, GetNSLMessages().MercsReset)
	end
end

local function OnCommandClearMercs(client)
	local ns2id = client:GetUserId()
	local player = client:GetControllingPlayer()
	if player ~= nil then
		local teamnum = player:GetTeamNumber()
		ClearMercs(teamnum)
	end
end

Event.Hook("Console_clearmercs",                 OnCommandClearMercs)
gChatCommands["rejectmercs"] = OnCommandClearMercs
gChatCommands["clearmercs"] = OnCommandClearMercs

local function OnClientCommandClearMercs(client, team)
	team = tonumber(team)
	if client and team and (team == 1 or team == 2) then
		local NS2ID = client:GetUserId()
		if ValidateNSLUsersAccessLevel(NS2ID) then
			ClearMercs(team)
		end
	end
end

Event.Hook("Console_sv_nslclearmercs",               OnClientCommandClearMercs)