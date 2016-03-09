-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\nsl_teammanager_server.lua
-- - Dragon

local t1name = "Frontiersmen"
local t2name = "Kharaa"
local tscores = { }
local tqueue = { }
local overridenames = false
local kMinPlayersToName = 3

local function UpdateCachedTeamScores()
	for t, s in pairs(GetRecentScores()) do
		tscores[t] = s
	end
end

UpdateCachedTeamScores()

local function SyncTeamInfotoClients(client)
	if client then
		Server.SendNetworkMessage(client, "TeamNames", {team1name = t1name, team2name = t2name, team1score = tscores[t1name] or 0, team2score = tscores[t2name] or 0 }, true)
	else
		Server.SendNetworkMessage("TeamNames", {team1name = t1name, team2name = t2name, team1score = tscores[t1name] or 0, team2score = tscores[t2name] or 0 }, true)
	end
end

table.insert(gConnectFunctions, SyncTeamInfotoClients)

function GetActualTeamName(teamnum)
	--Check players on team to get an idea of their 'team'
	if teamnum == 1 then
		teamname = t1name or "Frontiersmen"
	elseif teamnum == 2 then
		teamname = t2name or "Kharaa"
	elseif teamnum == 3 then
		teamname = "Spectators"
	else
		teamname = "Others"	
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
	local team = ConditionalValue(teamnum == 1, "Frontiersmen", "Kharaa")
	local count = 0
	if teamdata ~= nil then
		for t, c in pairs(teamdata) do
			if c > count and t ~= "No Team" and c >= kMinPlayersToName then
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
		if nsldata ~= nil and teamname ~= ConditionalValue(teamNumber == 1, "Frontiersmen", "Kharaa") then
			if (teamNumber == 1 or teamNumber == 2) and teamname ~= nsldata.NSL_Team then
				if tqueue[teamNumber] == nil then
					tqueue[teamNumber] = { }
					tqueue[teamNumber][ns2id] = false 
					--This is set to true when mercs approved.
					SendClientMessage(client, GetNSLMessage("MercApprovalNeeded"))
					return false
				elseif tqueue[teamNumber][ns2id] ~= true then
					tqueue[teamNumber][ns2id] = false
					SendClientMessage(client, GetNSLMessage("MercApprovalNeeded"))
					return false
				end
			end
		end
	end
	return true
end

local function UpdateCallbacksWithNewTeamNames(team1name, team2name)
	SyncTeamInfotoClients()
	for i = 1, #gTeamNamesUpdatedFunctions do
		gTeamNamesUpdatedFunctions[i](team1name, team2name)
	end
end

function ResetNSLTeamNames()
	t1name = "Frontiersmen"
	t2name = "Kharaa"
	UpdateCallbacksWithNewTeamNames(t2name, t1name)
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
				local ntname = GetPrimaryTeam(newTeamNumber, GetTeamNameCount(newTeamNumber))
				if newTeamNumber == 1 and ntname ~= t1name then
					t1name = ntname
					UpdateCallbacksWithNewTeamNames(t1name, t2name)
				elseif newTeamNumber == 2 and ntname ~= t2name then
					t2name = ntname
					UpdateCallbacksWithNewTeamNames(t1name, t2name)
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
				winningteamname = t2name
			elseif winningteam:GetTeamType() == kMarineTeamType then
				winningteamname = t1name
			end
			if winningteamname ~= "Frontiersmen" and winningteamname ~= "Kharaa" then
				if tscores[winningteamname] == nil then
					tscores[winningteamname] = 1
				else
					tscores[winningteamname] = tscores[winningteamname] + 1
				end
			end
		end
		--Clear merc queue
		tqueue = { }
		UpdateNSLScores(t1name, tscores[t1name] or 0, t2name, tscores[t2name] or 0)
		SyncTeamInfotoClients()
	end
end

table.insert(gGameEndFunctions, UpdateTeamDataOnGameEnd)

local function OnCommandOverrideTeamnames(client, team1name, team2name)
	if client and team1name and team2name then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			overridenames = true
			t1name = team1name
			t2name = team2name
			UpdateCallbacksWithNewTeamNames(t1name, t2name)
		end
	end
end

Event.Hook("Console_sv_nslsetteamnames",               OnCommandOverrideTeamnames)

local function OnCommandSwitchTeamNames(client)
	if client then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			overridenames = true
			local team1name = t1name
			t1name = t2name
			t2name = team1name
			UpdateCallbacksWithNewTeamNames(t1name, t2name)
		end
	end
end

Event.Hook("Console_sv_nslswitchteams",               OnCommandSwitchTeamNames)

local function OnCommandSetTeamScores(client, team1score, team2score)
	team1score = tonumber(team1score)
	team2score = tonumber(team2score)
	if client then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
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
		if GetIsNSLRef(NS2ID) then
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
		SendTeamMessage(teamnum, GetNSLMessage("MercsReset"))
	end
end

local function OnCommandClearMercs(client)
	if not client then return end
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
		if GetIsNSLRef(NS2ID) then
			ClearMercs(team)
		end
	end
end

Event.Hook("Console_sv_nslclearmercs",               OnClientCommandClearMercs)

local function OnClientCommandMercHelp(client)
	if client then
		local NS2ID = client:GetUserId()
		if GetIsNSLRef(NS2ID) then
			--Print Ref only merc commands
			ServerAdminPrint(client, "sv_nslapprovemercs" .. ": " .. "<team, opt. player> - Forces approval of teams mercs, '1' approving for marines which allows alien mercs.")
			ServerAdminPrint(client, "sv_nslclearmercs" .. ": " .. "<team> - 1,2 - Clears approval of teams mercs, '1' clearing any alien mercs.")
		end
		ServerAdminPrint(client, "rejectmercs" .. ": " .. "Chat command, will clear any merc approvals for your team.")
		ServerAdminPrint(client, "clearmercs" .. ": " .. "Chat or console command, will also clear any merc approvals for your team.")
		ServerAdminPrint(client, "/mercsok" .. ": " .. "Chat command, will approve opposing teams merc(s).")
		ServerAdminPrint(client, "mercsok" .. ": " .. "Chat or console command, will approve opposing teams merc(s).")
		ServerAdminPrint(client, "approvemercs" .. ": " .. "Chat command, will approve opposing teams merc(s).")
		ServerAdminPrint(client, "NOTE!" .. ": " .. "Approving a merc optionally requires details to identify the target player.")
		ServerAdminPrint(client, "NOTE!" .. ": " .. "Mercs can be approved based on name, ns2id or game ID, all of which are listed in sv_nslinfo.")
		ServerAdminPrint(client, "NOTE!" .. ": " .. "/mercsok Dragon as an example.")
	end
end

Event.Hook("Console_sv_nslmerchelp",               OnClientCommandMercHelp)