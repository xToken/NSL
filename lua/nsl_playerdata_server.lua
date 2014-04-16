local C_CODE = "1A2D3E4C5F"
local NSL_ClientData = { }
local NSL_NS2IDLookup = { }
local G_IDTable = { }

//These are the only mandatory fields
//S_ID 		- Steam ID
//NICK 		- Nickname on Site
//NSL_Team	- Current Team

//These are optional, and should be checked as such by the mod
//NSL_IP 	- IP Info from site
//NSL_ID	- Users ID on Site
//NSL_TID	- Teams ID on Site
//NSL_Level - Access Level
//NSL_Rank	- Rank
//NSL_Icon 	- Assigned Icon
//Would like to USE these icons :S

local TeamnameToBadgeNames = { }
TeamnameToBadgeNames["clan_all-in"] = { "All-In" }
TeamnameToBadgeNames["clan_calamity_gaming"] = { "Calamity Gaming" }
TeamnameToBadgeNames["clan_dark_legion"] = { "Dark Legion" }
TeamnameToBadgeNames["clan_godar"] = { "Goðar" }
TeamnameToBadgeNames["clan_legendary_snails"] = { "Legendary Snails" }
TeamnameToBadgeNames["clan_lucky_fkers"] = { "Lucky Fkers" }
TeamnameToBadgeNames["clan_mimic"] = { "Mimic" }
TeamnameToBadgeNames["clan_saunamen"] = { "Saunamen" }
TeamnameToBadgeNames["clan_scurvy"] = { "Scurvy" }
TeamnameToBadgeNames["clan_singularity"] = { "Singularity" }
TeamnameToBadgeNames["clan_titus"] = { "Titus Gaming" }

Script.Load("lua/nsl_class.lua")

function GetNSLUserData(ns2id)
	if NSL_ClientData[ns2id] == nil then
		//Check manually specified player data table from configs
		local cPlayerData = GetNSLConfigValue("PLAYERDATA")
		local sns2id = tostring(ns2id)
		if cPlayerData and sns2id then
			for id, data in pairs(cPlayerData) do
				if id == sns2id then
					return data
				end
			end
		end
	else
		return NSL_ClientData[ns2id]
	end
	return nil
end

local function GetGameIDMatchingNS2ID(ns2id)
	ns2id = tonumber(ns2id)
	for p = 1, #G_IDTable do
		if G_IDTable[p] == ns2id then
			return p
		end
	end
end

local function GetPlayerMatchingNS2Id(ns2id)
	ns2id = tonumber(ns2id)
	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
    for p = 1, #playerList do
        local playerClient = Server.GetOwner(playerList[p])
        if playerClient and playerClient:GetUserId() == tonumber(ns2id) then
            return playerList[p]
		end
	end
end

local function GetPlayerMatchingGameID(gID)
	local targetNS2ID = G_IDTable[gID]
	if targetNS2ID ~= nil then
		return GetPlayerMatchingNS2Id(targetNS2ID)
	end
end

local function GetPlayerMatchingName(name)
	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
    for p = 1, #playerList do
        if playerList[p]:GetName() == name then
			return playerList[p]
		end
	end
end

function GetPlayerMatching(id)
    return GetPlayerMatchingGameID(gID) or GetPlayerMatchingNS2Id(id) or GetPlayerMatchingName(id)
end

local function UpdateClientBadge(ns2id, team)
	if GiveBadge then
		for badge, names in pairs(TeamnameToBadgeNames) do
			if table.contains(names, team) then
				return GiveBadge(ns2id, badge)
			end
		end
	end
end

local function OnClientConnectENSLResponse(response)
	if response then
		local responsetable = { }
		local startpos = 0
		for st,se in function() return string.find(response, "\r", startpos, true) end do
			table.insert(responsetable, string.sub(response, startpos, st - 1))
			startpos = se + 1
		end
		if responsetable[1] == "#FAIL#" then
			//Message to user to register on ENSL site?
			//Possible DB issue?
		elseif responsetable[3] ~= nil then
			local ns2id = NSL_NS2IDLookup[responsetable[3]]
			if ns2id ~= nil then
				//GRISSI why...
				if responsetable[6] == "Goar" then
					responsetable[6] = "Godar"
				end
				local player = GetPlayerMatchingNS2Id(ns2id)
				NSL_ClientData[ns2id] = {
				S_ID = responsetable[3] or "",
				NICK = responsetable[4] or "Invalid",
				NSL_IP = responsetable[5] or "0.0.0.0",
				NSL_Team = responsetable[6] or "No Team",
				NSL_ID = responsetable[7] or "",
				NSL_TID = responsetable[8] or "",
				NSL_Level = responsetable[9] or "0",
				NSL_Rank = responsetable[10] or nil,
				NSL_Icon = responsetable[11] or ""}
				if player then
					ServerAdminPrint(Server.GetOwner(player), string.format("NSL Username verified as %s", NSL_ClientData[ns2id].NICK))
				end
				if responsetable[10]~= nil then
					if string.find(responsetable[10], "Admin") then
						NSL_ClientData[ns2id].NSL_Level = 2
					elseif string.find(responsetable[10], "Referee") then
						NSL_ClientData[ns2id].NSL_Level = 1
					end
				end
				UpdateClientBadge(ns2id, NSL_ClientData[ns2id].NSL_Team)
			end
		end
	end
end

local function OnClientConnectAUSNS2Response(response)
	if response then
		local responsetable = json.decode(response)
		if responsetable == nil or responsetable.UserID == nil then
			//Message to user to register on AUSNS2 site?
			//Possible DB issue?
		else
			local steamId = string.gsub(responsetable.SteamID, "STEAM_", "")
			if steamId ~= nil then
				local ns2id = NSL_NS2IDLookup[steamId]
				if ns2id ~= nil then
					local player = GetPlayerMatchingNS2Id(ns2id)
					NSL_ClientData[ns2id] = {
					S_ID = responsetable.SteamID or "",
					NICK = responsetable.UserName or "Invalid",
					NSL_IP = nil,
					NSL_Team = responsetable.TeamName or "No Team",
					NSL_ID = responsetable.UserID or "",
					NSL_TID = responsetable.TeamID or "",
					NSL_Level = responsetable.IsAdmin and ToString(responsetable.IsAdmin) or "0",
					NSL_Rank = nil,
					NSL_Icon = nil}
					if player then
						ServerAdminPrint(Server.GetOwner(player), string.format("AusNS2 Username verified as %s", NSL_ClientData[ns2id].NICK))
					end
					UpdateClientBadge(ns2id, NSL_ClientData[ns2id].NSL_Team)
				end				
			end
		end
	end
end

local function OnClientConnected(client)
	local NS2ID = client:GetUserId()
	if GetNSLModEnabled() then
		if GetNSLUserData(NS2ID) == nil then
			//Doesnt have data, query
			local QueryURL = GetNSLConfigValue("PlayerDataURL")
			if QueryURL then
				//PlayerDataFormat
				local steamId = "0:" .. (NS2ID % 2) .. ":" .. math.floor(NS2ID / 2)
				NSL_NS2IDLookup[steamId] = NS2ID
				if GetNSLConfigValue("PlayerDataFormat") == "ENSL" then
					Shared.SendHTTPRequest(string.format("%s%s?ch=%s", QueryURL, steamId, C_CODE), "GET", OnClientConnectENSLResponse)
				end
				if GetNSLConfigValue("PlayerDataFormat") == "AUSNS" then
					Shared.SendHTTPRequest(string.format("%s%s", QueryURL, steamId), "GET", OnClientConnectAUSNS2Response)
				end
			end
		end
	end
	if not table.contains(G_IDTable, NS2ID) then
		table.insert(G_IDTable, NS2ID)
	end
end

table.insert(gConnectFunctions, OnClientConnected)

local function UpdatePlayerDataOnActivation(newState)
	if newState == "PCW" or newState == "OFFICIAL" then
		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		for p = 1, #playerList do
			local playerClient = Server.GetOwner(playerList[p])
			if playerClient then
				OnClientConnected(playerClient)
			end
		end
	end
end

table.insert(gPluginStateChange, UpdatePlayerDataOnActivation)

local function GetPlayerList(query)
	if query == nil then
		return EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	elseif query:lower() == "marines" then
		return GetEntitiesForTeam("Player", kTeam1Index)
	elseif query:lower() == "aliens" then
		return GetEntitiesForTeam("Player", kTeam2Index)
	elseif query:lower() == "specs" or query:lower() == "spectators" then
		return GetEntitiesForTeam("Player", kSpectatorIndex)
	elseif query:lower() == "other" or query:lower() == "others" then
		return GetEntitiesForTeam("Player", kTeamReadyRoom)
	else
		return EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	end
end

local function GetPlayerString(player)
	local playerClient = Server.GetOwner(player)
	if playerClient then
		local pNS2ID = playerClient:GetUserId()
		local NSLData = GetNSLUserData(pNS2ID)
		local gID = GetGameIDMatchingNS2ID(pNS2ID)
		if NSLData == nil then
			local sID = "0:" .. (pNS2ID % 2) .. ":" .. math.floor(pNS2ID / 2)
			return string.format("IGN : %s, sID : %s, NS2ID : %s, gID : %s, League Information Unavailable or Unregistered User.", player:GetName(), sID, pNS2ID, gID)
		else
			return string.format("IGN : %s, sID : %s, NS2ID : %s, gID : %s, LNick : %s, LTeam : %s, LID : %s", player:GetName(), NSLData.S_ID, pNS2ID, gID, NSLData.NICK, NSLData.NSL_Team, NSLData.NSL_ID or 0)
		end				
	end
	return ""
end

local function OnClientCommandViewNSLInfo(client, team)
	if client then
		local NS2ID = client:GetUserId()
		local playerList = GetPlayerList(team)				
		if playerList then
			ServerAdminPrint(client, "IGN = In-Game Name, sID = SteamID, gID = GameID, LNick = League Nickname, LTeam = League Team, LID = League UserID")
			for p = 1, #playerList do
				ServerAdminPrint(client, GetPlayerString(playerList[p]))
			end
		end
	end
end

Event.Hook("Console_sv_nslinfo",               OnClientCommandViewNSLInfo)

local function OnCommandChat(client, target, message)
	if target == nil then
		Server.SendNetworkMessage("AdminMessage", {message = string.sub(message, 1, 250)}, true)
	else
		if type(target) == "number" then
			local playerRecords = GetEntitiesForTeam("Player", target)
			for _, player in ipairs(playerRecords) do
				local pclient = Server.GetOwner(player)
				if pclient ~= nil then
					Server.SendNetworkMessage(pclient, "AdminMessage", {message = string.sub(message, 1, 250)}, true)
				end
			end
		elseif type(target) == "userdata" and target:isa("Player") then
			Server.SendNetworkMessage(target, "AdminMessage", {message = string.sub(message, 1, 250)}, true)
		end
	end
end

local function OnClientCommandChat(client, ...)
	local NS2ID = client:GetUserId()
	if GetIsNSLRef(NS2ID) then
		local ns2data = GetNSLUserData(NS2ID)
		local message = string.format("(All)(%s) %s:", ns2data.NSL_Rank or "Ref", ns2data.NICK or NS2ID)
        for i, p in ipairs({...}) do
            message = message .. " " .. p
        end
		OnCommandChat(client, nil, message)
	end
end

Event.Hook("Console_sv_nslsay",               OnClientCommandChat)

local function OnClientCommandTeamChat(client, team, ...)
	local NS2ID = client:GetUserId()
	team = tonumber(team)
	if GetIsNSLRef(NS2ID) and team then
		local ns2data = GetNSLUserData(NS2ID)
		local message = string.format("(%s)(%s) %s:", GetActualTeamName(team), ns2data.NSL_Rank or "Ref", ns2data.NICK or NS2ID)
        for i, p in ipairs({...}) do
            message = message .. " " .. p
        end
		OnCommandChat(client, team, message)
	end
end

Event.Hook("Console_sv_nsltsay",               OnClientCommandTeamChat)

local function OnClientCommandPlayerChat(client, target, ...)
	local NS2ID = client:GetUserId()
	local player = GetPlayerMatching(target)
	if GetIsNSLRef(NS2ID) and player then
		local ns2data = GetNSLUserData(NS2ID)
		local message = string.format("(%s)(%s) %s:", player:GetName(), ns2data.NSL_Rank or "Ref", ns2data.NICK or NS2ID)
        for i, p in ipairs({...}) do
            message = message .. " " .. p
        end
		OnCommandChat(client, player, message)
	end
end

Event.Hook("Console_sv_nslpsay",               OnClientCommandPlayerChat)