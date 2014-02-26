local E_URL = "http://www.ensl.org/plugin/user/"
local C_CODE = "1A2D3E4C5F"
local NSL_ClientData = { }
local NSL_NS2IDLookup = { }
//S_ID
//NICK
//NSL_IP
//NSL_Team
//NSL_ID
//NSL_TID
//NSL_Level
//NSL_Rank
//NSL_Icon

Script.Load("lua/nsl_class.lua")

function GetNSLUserData(ns2id)
	return NSL_ClientData[ns2id]
end

local function GetPlayerMatchingNS2Id(ns2id)
	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
    for p = 1, #playerList do
        local playerClient = Server.GetOwner(playerList[p])
        if playerClient and playerClient:GetUserId() == tonumber(ns2id) then
            return playerList[p]
		end
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
    return GetPlayerMatchingNS2Id(id) or GetPlayerMatchingName(id)
end

local function OnClientConnectNSLResponse(response)
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
			local player = GetPlayerMatchingNS2Id(ns2id)
			NSL_ClientData[ns2id] = {
			S_ID = responsetable[3] or "",
			NICK = responsetable[4] or "Invalid",
			NSL_IP = responsetable[5] or "0.0.0.0",
			NSL_Team = responsetable[6] or "No Team",
			NSL_ID = responsetable[7] or "",
			NSL_TID = responsetable[8] or "",
			NSL_Level = responsetable[9] or "",
			NSL_Rank = responsetable[10] or "",
			NSL_Icon = responsetable[11] or ""}
			if player then
				ServerAdminPrint(Server.GetOwner(player), string.format("NSL Username verified as %s", NSL_ClientData[ns2id].NICK))
			end
		end
	end
end

local function OnClientConnected(client)
	if GetNSLModEnabled() then
		local NS2ID = client:GetUserId()
		if NSL_ClientData[NS2ID] == nil then
			local steamId = "0:" .. (NS2ID % 2) .. ":" .. math.floor(NS2ID / 2)
			NSL_NS2IDLookup[steamId] = NS2ID
			Shared.SendHTTPRequest(string.format("%s%s?ch=%s", E_URL, steamId, C_CODE), "GET", OnClientConnectNSLResponse)
		end
	end
end

table.insert(gConnectFunctions, OnClientConnected)

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
		if NSL_ClientData[pNS2ID] == nil then
			local sID = "0:" .. (pNS2ID % 2) .. ":" .. math.floor(pNS2ID / 2)
			return string.format("In-Game Name : %s, SteamID : %s, NS2ID : %s, NSL Information Unavailable or Unregistered User.", player:GetName(), sID, pNS2ID)
		else
			return string.format("In-Game Name : %s, SteamID : %s, NS2ID : %s, NSL Username : %s, NSL Team : %s, NSL UserID : %s", player:GetName(), NSL_ClientData[pNS2ID].S_ID, pNS2ID, NSL_ClientData[pNS2ID].NICK, NSL_ClientData[pNS2ID].NSL_Team, NSL_ClientData[pNS2ID].NSL_ID)
		end				
	end
	return ""
end

local function OnClientCommandViewENSLInfo(client, team)
	if client then
		local NS2ID = client:GetUserId()
		local playerList = GetPlayerList(team)				
		if playerList then
			for p = 1, #playerList do
				ServerAdminPrint(client, GetPlayerString(playerList[p]))
			end
		end
	end
end

Event.Hook("Console_sv_nslinfo",               OnClientCommandViewENSLInfo)

local function UpdateNSLMode(client, mode)
	if string.lower(mode) == "pcw" then
		SetNSLMode("PCW")
	elseif string.lower(mode) == "official" then
		SetNSLMode("OFFICIAL")
	elseif string.lower(mode) == "disabled" then
		SetNSLMode("DISABLED")
	end
	ServerAdminPrint(client, string.format("NSL Plugin now running in %s config.", GetNSLMode()))
end

local function OnClientSVCommandSetMode(client, mode)
	local NS2ID = client:GetUserId()
	if not ValidateNSLUsersAccessLevel(NS2ID) and mode ~= nil then
		UpdateNSLMode(client, mode)
	end
end

local function OnClientCommandSetMode(client, mode)
	local NS2ID = client:GetUserId()
	if ValidateNSLUsersAccessLevel(NS2ID) and mode ~= nil then
		UpdateNSLMode(client, mode)
	else
		ServerAdminPrint(client, string.format("NSL Plugin currently running in %s config.", GetNSLMode()))
	end
end

Event.Hook("Console_sv_nslcfg",               OnClientCommandSetMode)
CreateServerAdminCommand("Console_sv_nslcfg", OnClientSVCommandSetMode, "<state> - disabled,pcw,official - Changes the configuration mode of the NSL plugin.")

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
	if ValidateNSLUsersAccessLevel(NS2ID) then
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
	if ValidateNSLUsersAccessLevel(NS2ID) and team then
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
	if ValidateNSLUsersAccessLevel(NS2ID) and player then
		local ns2data = GetNSLUserData(NS2ID)
		local message = string.format("(%s)(%s) %s:", player:GetName(), ns2data.NSL_Rank or "Ref", ns2data.NICK or NS2ID)
        for i, p in ipairs({...}) do
            message = message .. " " .. p
        end
		OnCommandChat(client, player, message)
	end
end

Event.Hook("Console_sv_nslpsay",               OnClientCommandPlayerChat)