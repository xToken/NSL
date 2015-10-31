// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_playerdata_server.lua
// - Dragon

local NSL_ClientData = { }
local NSL_NS2IDLookup = { }
local G_IDTable = { }
local RefBadges = { }

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
TeamnameToBadgeNames["all-in"] = { "all-in" }
TeamnameToBadgeNames["calamity_gaming"] = { "calamitygaming" }
TeamnameToBadgeNames["dark_legion"] = { "darklegion" }
TeamnameToBadgeNames["godar"] = { "godar" }
TeamnameToBadgeNames["legendary_snails"] = { "legendarysnails" }
TeamnameToBadgeNames["lucky_fkers"] = { "luckyfkers" }
TeamnameToBadgeNames["mimic"] = { "mimic" }
TeamnameToBadgeNames["saunamen"] = { "saunamen" }
TeamnameToBadgeNames["scurvy"] = { "scurvy" }
TeamnameToBadgeNames["singularity"] = { "singularity" }
TeamnameToBadgeNames["titus"] = { "titusgaming" }

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

local function GetRefBadgeforID(ns2id)
	local NSLBadges = GetNSLConfigValue("Badges")
	if NSLBadges and type(NSLBadges) == "table" then
		local level = 0 -- The default level for players, which will have no badge
		local pData = GetNSLUserData(ns2id)
		if pData and pData.NSL_Level then
			if pData.NSL_Level <= level then
				return
			end
			level = pData.NSL_Level
			return NSLBadges[tostring(level)]
		end
	end
end

local function GetTeamBadgeForTeamName(teamName)
	if teamName and teamName ~= "" then
		teamName = string.lower(teamName)
		for badge, names in pairs(TeamnameToBadgeNames) do
			if table.contains(names, teamName) then
				return badge
			end
		end
	end
end

local function UpdateClientBadge(ns2id)
	local refBadge = GetRefBadgeforID(ns2id)
	local teamBadge = GetTeamBadgeForTeamName(NSL_ClientData[ns2id].NSL_Team)
	if GiveBadge then
		//Yay for badges+ mod.
		//Give badge if ref, and ref badge configured.
		local succes, row
		row = 1
		if refBadge then
			success = GiveBadge(ns2id, refBadge, row)
			row = row + 1
		end
		if teamBadge then
			Shared.Message(ToString(kBadges))
			success = success and GiveBadge(ns2id, teamBadge, row)
		end
	else
		//Assume legacy badge process :S
		local player = GetPlayerMatchingNS2Id(ns2id)
		if player and refBadge then
			local client = Server.GetOwner(player)
			if client then
				local newmsg = { clientId = client:GetId() }
				
				//Set all badges to false first.
				for _, badge in ipairs(gRefBadges) do
					newmsg[ "has_" .. badge.name .. "_badge" ] = false
				end
				//Set current NSL badge to true.
				newmsg["has_" .. refBadge .. "_badge"] = true
				
				Server.SendNetworkMessage("RefBadges", newmsg, true)
				
				// Send this client info for all existing clients.
				for clientId, msg in pairs(RefBadges) do
					Server.SendNetworkMessage( client, "RefBadges", msg, true )
				end
				
				// Store it ourselves as well for future clients
				RefBadges[ newmsg.clientId ] = newmsg
			end
		end
	end
end

local function OnClientConnectENSLResponse(response)
	if response then
		local responsetable = json.decode(response)
		if responsetable == nil or responsetable.id == nil then
			//Message to user to register on ENSL site?
			//Possible DB issue?
		else
			local ns2id = NSL_NS2IDLookup[responsetable.steam.id]
			if ns2id ~= nil then
				local player = GetPlayerMatchingNS2Id(ns2id)
				local clientData = {
					S_ID = responsetable.steam.id or "",
					NICK = responsetable.username or "Invalid",
					NSL_Team = responsetable.team and responsetable.team.name or "No Team",
					NSL_ID = responsetable.id or "",
					NSL_TID = responsetable.team and responsetable.team.id or "",
				}
				
				if responsetable.admin then
					clientData.NSL_Level = 4
					clientData.NSL_Rank = "Admin"
				elseif responsetable.referee then
					clientData.NSL_Level = 3
					clientData.NSL_Rank = "Ref"
				elseif responsetable.caster then
					clientData.NSL_Level = 2
					clientData.NSL_Rank = "Caster"
				elseif responsetable.moderator then
					clientData.NSL_Level = 1
					clientData.NSL_Rank = "Mod"
				else
					clientData.NSL_Level = 0
					clientData.NSL_Rank = nil
				end
				
				NSL_ClientData[ns2id] = clientData;
				
				if player then
					ServerAdminPrint(Server.GetOwner(player), string.format("NSL Username verified as %s", NSL_ClientData[ns2id].NICK))
				end
				UpdateClientBadge(ns2id)
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
					NSL_Team = responsetable.TeamName or "No Team",
					NSL_ID = responsetable.UserID or "",
					NSL_TID = responsetable.TeamID or "",
					NSL_Level = responsetable.IsAdmin and 1 or 0,
					NSL_Rank = nil,
					NSL_Icon = nil}
					if player then
						ServerAdminPrint(Server.GetOwner(player), string.format("AusNS2 Username verified as %s", NSL_ClientData[ns2id].NICK))
					end
					UpdateClientBadge(ns2id)
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
					Shared.SendHTTPRequest(string.format("%s%s.steamid", QueryURL, NS2ID), "GET", OnClientConnectENSLResponse)
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
			return string.format("IGN : %s, sID : %s, NS2ID : %s, gID : %s, HCap : %.0f%%, League Information Unavailable or Unregistered User.", player:GetName(), sID, pNS2ID, gID, (1 - player:GetHandicap() ) * 100)
		else
			return string.format("IGN : %s, sID : %s, NS2ID : %s, gID : %s, HCap : %.0f%%, LNick : %s, LTeam : %s, LID : %s", player:GetName(), NSLData.S_ID, pNS2ID, gID, (1 - player:GetHandicap() ) * 100, NSLData.NICK, NSLData.NSL_Team, NSLData.NSL_ID or 0)
		end				
	end
	return ""
end

local function OnClientCommandViewNSLInfo(client, team)
	if client then
		local NS2ID = client:GetUserId()
		local playerList = GetPlayerList(team)				
		if playerList then
			ServerAdminPrint(client, "IGN = In-Game Name, sID = SteamID, gID = GameID, HCap = Handicap, LNick = League Nickname, LTeam = League Team, LID = League ID")
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
	if not client then return end
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
	if not client then return end
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
	if not client then return end
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