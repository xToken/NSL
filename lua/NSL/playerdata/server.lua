-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/playerdata/server.lua
-- - Dragon

local NSL_ClientData = { }
local NSL_NS2IDLookup = { }
local G_IDTable = { }
local RefBadges = { }
local NSL_FunctionData = { }
local NSL_PlayerDataRetries = { }
local NSL_PlayerDataMaxRetries = 3
local NSL_PlayerDataTimeout = 30

--These are the only mandatory fields
--S_ID 		- Steam ID
--NICK 		- Nickname on Site
--NSL_Team	- Current Team
--NSL_League- Associated League

--These are optional, and should be checked as such by the mod
--NSL_IP 	- IP Info from site
--NSL_ID	- Users ID on Site
--NSL_TID	- Teams ID on Site
--NSL_Level - Access Level
--NSL_Rank	- Rank
--NSL_Icon 	- Assigned Icon
--Would like to USE these icons :S

function GetNSLUserData(ns2id)
	if NSL_ClientData[ns2id] == nil then
		--Check manually specified player data table from configs
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
        if playerClient and playerClient:GetUserId() == ns2id then
            return playerList[p]
		end
	end
end

local function GetPlayerMatchingGameID(gID)
	gID = tonumber(gID)
	local targetNS2ID = G_IDTable[gID]
	if targetNS2ID then
		return GetPlayerMatchingNS2Id(targetNS2ID)
	end
end

local function GetPlayerMatchingName(name)
	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
    for p = 1, #playerList do
        if string.lower(playerList[p]:GetName()) == string.lower(name) then
			return playerList[p]
		end
	end
end

function NSLGetPlayerMatching(id)
    return GetPlayerMatchingGameID(id) or GetPlayerMatchingNS2Id(id) or GetPlayerMatchingName(id)
end

local function GetRefBadgeforID(ns2id)
	local NSLBadges = GetNSLConfigValue("Badges")
	if NSLBadges and type(NSLBadges) == "table" then
		local pData = GetNSLUserData(ns2id)
		if type(pData.NSL_Level) == "number" then
			local level = pData.NSL_Level
			if level and NSLBadges[level] then
				return NSLBadges[level].badge, NSLBadges[level].name
			end
		end
	end
end

local function GetBadgeForPlayerData(data)
	return GetActiveLeague().."#"..ToString(data.NSL_TID)
end

local function UpdateClientBadge(ns2id, data)
	local refBadge, badgeName = GetRefBadgeforID(ns2id)
	local teamBadge = GetBadgeForPlayerData(data)
	local teamBadgeName = GetNSLConfigValue("BadgeTitle")
	local success
	local row = 5
	if refBadge and GiveBadge then
		success = GiveBadge(ns2id, refBadge, row)
		if success then
			SetFormalBadgeName(refBadge, badgeName)
			row = 4
		end
	end
	if teamBadge and GiveBadge then
		success = GiveBadge(ns2id, teamBadge, row)
		if success then
			SetFormalBadgeName(teamBadge, teamBadgeName .. data.NSL_Team)
		end
	end
end

local function RemovePlayerFromRetryTable(player)
	local client = Server.GetOwner(player)
	if client and client:GetUserId() then
		for i = #NSL_PlayerDataRetries, 1, -1 do
			if NSL_PlayerDataRetries[i] and NSL_PlayerDataRetries[i].id == client:GetUserId() then
				NSL_PlayerDataRetries[i] = nil
			end
		end
	end
end

local function UpdateCallbacksWithNSLData(player, nslData)
	if player then
		for i = 1, #gPlayerDataUpdatedFunctions do
			gPlayerDataUpdatedFunctions[i](player, nslData)
		end
		if player.playerInfo then
			player.playerInfo:SetupNSLData(nslData) 
		end
		SendClientServerAdminMessage(Server.GetOwner(player), "NSL_USERNAME_VERIFIED", GetNSLConfigValue("LeagueName"), nslData.NICK)
	end
end

local function OnClientConnectENSLResponse(response)
	if response then
		local responsetable = json.decode(response)
		if responsetable == nil or responsetable.steam == nil or responsetable.steam.id == nil then
			--Message to user to register on ENSL site?
			--Possible DB issue?
		else
			local ns2id = NSL_NS2IDLookup[responsetable.steam.id]
			if ns2id then
				local player = GetPlayerMatchingNS2Id(ns2id)
				local clientData = {
					S_ID = responsetable.steam.id or "",
					NICK = string.UTF8SanitizeForNS2(responsetable.username or "Invalid"),
					NSL_Team = string.UTF8SanitizeForNS2(responsetable.team and responsetable.team.name or "No Team"),
					NSL_ID = responsetable.id or "",
					NSL_TID = responsetable.team and responsetable.team.id or "",
					NSL_League = "ENSL"
				}
				if responsetable.admin then
					clientData.NSL_Level = 4
					clientData.NSL_Rank = "Admin"
				elseif responsetable.referee then
					clientData.NSL_Level = 3
					clientData.NSL_Rank = "Ref"
				elseif responsetable.caster then
					clientData.NSL_Level = 1
					clientData.NSL_Rank = "Caster"
				elseif responsetable.moderator then
					clientData.NSL_Level = 2
					clientData.NSL_Rank = "Mod"
				else
					clientData.NSL_Level = 0
					clientData.NSL_Rank = nil
				end

				--Check config refs here
				local cRefs = GetNSLConfigValue("REFS")
				if cRefs and table.contains(cRefs, ns2id) then
					--A manually configured 'Ref' - give them ref level
					clientData.NSL_Level = 3
					clientData.NSL_Rank = "Ref"
				end
				
				NSL_ClientData[ns2id] = clientData
				UpdateCallbacksWithNSLData(player, clientData)
				RemovePlayerFromRetryTable(player)
				UpdateClientBadge(ns2id, NSL_ClientData[ns2id])
			end
		end
	end
end

local function OnClientConnectAUSNS2Response(response)
	if response then
		local responsetable = json.decode(response)
		if responsetable == nil or responsetable.UserID == nil then
			--Message to user to register on AUSNS2 site?
			--Possible DB issue?
		else
			local steamId = string.gsub(responsetable.SteamID, "STEAM_", "")
			if steamId then
				local ns2id = NSL_NS2IDLookup[steamId]
				if ns2id then
					local player = GetPlayerMatchingNS2Id(ns2id)
					NSL_ClientData[ns2id] = {
					S_ID = responsetable.SteamID or "",
					NICK = string.UTF8SanitizeForNS2(responsetable.UserName or "Invalid"),
					NSL_Team = string.UTF8SanitizeForNS2(responsetable.TeamName or "No Team"),
					NSL_ID = responsetable.UserID or "",
					NSL_TID = responsetable.TeamID or "",
					NSL_Level = responsetable.IsAdmin and 1 or 0,
					NSL_Rank = responsetable.IsAdmin and "Admin" or nil,
					NSL_Icon = nil,
					NSL_League = "AUSNS2"}
					
					UpdateCallbacksWithNSLData(player, NSL_ClientData[ns2id])
					RemovePlayerFromRetryTable(player)
					UpdateClientBadge(ns2id, NSL_ClientData[ns2id])
				end				
			end
		end
	end
end

local function HandleStaticLeagueConfig(ns2id)
	if ns2id then
		--Check config refs here
		local cRefs = GetNSLConfigValue("REFS")
		if cRefs and table.contains(cRefs, ns2id) then
			--A manually configured 'Ref' - give them powerz
			local player = GetPlayerMatchingNS2Id(ns2id)
			local clientData = {
				S_ID = "",
				NICK = player:GetName(),
				NSL_Team = "",
				NSL_ID = "",
				NSL_TID = "",
				NSL_League = "NA"
			}
			clientData.NSL_Level = 1
			clientData.NSL_Rank = "Admin"

			NSL_ClientData[ns2id] = clientData
			UpdateCallbacksWithNSLData(player, clientData)
			RemovePlayerFromRetryTable(player)
			UpdateClientBadge(ns2id, NSL_ClientData[ns2id])
		end
	end
end

function UpdateNSLPlayerData(RefTable)
	if not GetNSLUserData(RefTable.id) then
		--Check for retry
		if RefTable.attemps < NSL_PlayerDataMaxRetries then
			--Doesnt have data, query
			local QueryURL = GetNSLConfigValue("PlayerDataURL")
			if QueryURL then
				--PlayerDataFormat
				local steamId = "0:" .. (RefTable.id % 2) .. ":" .. math.floor(RefTable.id / 2)
				NSL_NS2IDLookup[steamId] = RefTable.id
				RefTable.attemps = RefTable.attemps + 1
				RefTable.time = NSL_PlayerDataTimeout
				if GetNSLConfigValue("PlayerDataFormat") == "ENSL" then
					Shared.SendHTTPRequest(string.format("%s%s.steamid", QueryURL, RefTable.id), "GET", OnClientConnectENSLResponse)
				end
				if GetNSLConfigValue("PlayerDataFormat") == "AUSNS" then
					Shared.SendHTTPRequest(string.format("%s%s", QueryURL, steamId), "GET", OnClientConnectAUSNS2Response)
				end
				if GetNSLConfigValue("PlayerDataFormat") == "N/A" then
					HandleStaticLeagueConfig(RefTable.id)
				end
			else
				--Configs might not be loaded yet - push out time
				RefTable.time = NSL_PlayerDataTimeout
			end
		else
			Shared.Message(string.format("NSL - Failed to get valid response from %s site for ns2id %s.", 
														GetNSLConfigValue("LeagueName"), tostring(RefTable.id)))
			RefTable = nil
		end
	else
		--Already have data.
		local player = GetPlayerMatchingNS2Id(RefTable.id)
		if player then
			UpdateCallbacksWithNSLData(player, GetNSLUserData(RefTable.id))
		end
		RefTable = nil
	end
end

local function OnNSLClientConnected(client)
	local NS2ID = client:GetUserId()
	if GetNSLModEnabled() and NS2ID > 0 then
		table.insert(NSL_PlayerDataRetries, {id = NS2ID, attemps = 0, time = 1})
	end
	if not table.contains(G_IDTable, NS2ID) then
		table.insert(G_IDTable, NS2ID)
	end
end

table.insert(gConnectFunctions, OnNSLClientConnected)

local function OnServerUpdated(deltaTime)
	if GetNSLModEnabled() then
		for i = #NSL_PlayerDataRetries, 1, -1 do
			if NSL_PlayerDataRetries[i] and NSL_PlayerDataRetries[i].time > 0 then
				NSL_PlayerDataRetries[i].time = math.max(0, NSL_PlayerDataRetries[i].time - deltaTime)
				if NSL_PlayerDataRetries[i].time == 0 then
					UpdateNSLPlayerData(NSL_PlayerDataRetries[i])
				end
			end
		end
	end
end

Event.Hook("UpdateServer", OnServerUpdated)

local function ForceUpdatePlayerData()
	-- Blank existing table
	NSL_ClientData = { }
	-- Re-add everyone as if they just joined
	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	for p = 1, #playerList do
		local playerClient = Server.GetOwner(playerList[p])
		if playerClient then
			OnNSLClientConnected(playerClient)
		end
	end
end
table.insert(gLeagueChangeFunctions, ForceUpdatePlayerData)

local function UpdatePlayerDataOnActivation(newState)
	if not newState == kNSLPluginConfigs.DISABLED then
		ForceUpdatePlayerData()
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

local function OnClientCommandViewNSLInfo(client, team)
	if client then
		local NS2ID = client:GetUserId()
		local playerList = GetPlayerList(team)				
		if playerList then
			SendClientServerAdminMessage(client, "NSL_PLAYER_INFO_HEADING")
			for p = 1, #playerList do
				local playerClient = Server.GetOwner(playerList[p])
				if playerClient then
					Server.SendNetworkMessage(client, "NSLPlayerInfoMessage", {clientId = playerList[p]:GetClientIndex(), gameId = GetGameIDMatchingNS2ID(playerClient:GetUserId())}, true)
				end
			end
		end
	end
end

RegisterNSLConsoleCommand("sv_nslinfo", OnClientCommandViewNSLInfo, "SV_NSLINFO", true)

local function MakeNSLMessage(message, header)
	local m = { }
	m.message = string.sub(message, 1, 250)
	m.header = header
	m.color = GetNSLConfigValue("MessageColor")
	return m
end

local function OnCommandChat(client, target, message, header)
	if target == nil then
		Server.SendNetworkMessage("NSLAdminChat", MakeNSLMessage(message, header), true)
	else
		if type(target) == "number" then
			local playerRecords = GetEntitiesForTeam("Player", target)
			for _, player in ipairs(playerRecords) do
				local pclient = Server.GetOwner(player)
				if pclient then
					Server.SendNetworkMessage(pclient, "NSLAdminChat", MakeNSLMessage(message, header), true)
				end
			end
		elseif type(target) == "userdata" and target:isa("Player") then
			Server.SendNetworkMessage(target, "NSLAdminChat", MakeNSLMessage(message, header), true)
		end
	end
end

local function OnClientCommandChat(client, ...)
	if not client then return end
	local NS2ID = client:GetUserId()
	if GetIsNSLRef(NS2ID) then
		local ns2data = GetNSLUserData(NS2ID)
		local message = ""
		local header = string.format("(All)(%s) %s:", ns2data.NSL_Rank or "Ref", ns2data.NICK or NS2ID)
        for i, p in ipairs({...}) do
            message = message .. " " .. p
        end
		OnCommandChat(client, nil, message, header)
	end
end

RegisterNSLConsoleCommand("sv_nslsay", OnClientCommandChat, "SV_NSLSAY", false,
	{{ Type = "string", TakeRestOfLine = true, Error = "Please provide message."}})

local function OnClientCommandTeamChat(client, team, ...)
	if not client then return end
	local NS2ID = client:GetUserId()
	team = tonumber(team)
	if GetIsNSLRef(NS2ID) and team then
		local ns2data = GetNSLUserData(NS2ID)
		local message = ""
		local header = string.format("(%s)(%s) %s:", GetActualTeamName(team), ns2data.NSL_Rank or "Ref", ns2data.NICK or NS2ID)
        for i, p in ipairs({...}) do
            message = message .. " " .. p
        end
		OnCommandChat(client, team, message, header)
	end
end

RegisterNSLConsoleCommand("sv_nsltsay", OnClientCommandTeamChat, "SV_NSLTSAY", false,
	{{ Type = "string", Error = "Please provide target team number."},
	{ Type = "string", TakeRestOfLine = true, Error = "Please provide message."}})

local function OnClientCommandPlayerChat(client, target, ...)
	if not client then return end
	local NS2ID = client:GetUserId()
	local player = NSLGetPlayerMatching(target)
	if GetIsNSLRef(NS2ID) and player then
		local ns2data = GetNSLUserData(NS2ID)
		local message = ""
		local header = string.format("(%s)(%s) %s:", player:GetName(), ns2data.NSL_Rank or "Ref", ns2data.NICK or NS2ID)
        for i, p in ipairs({...}) do
            message = message .. " " .. p
        end
		OnCommandChat(client, player, message, header)
	end
end

RegisterNSLConsoleCommand("sv_nslpsay", OnClientCommandPlayerChat, "SV_NSLPSAY", false,
	{{ Type = "string", Error = "Please provide target player."},
	{ Type = "string", TakeRestOfLine = true, Error = "Please provide message."}})

local function OnRecievedFunction(client, message)

	if client and message then
		local NS2ID = client:GetUserId()
		if not NSL_FunctionData[NS2ID] then
			NSL_FunctionData[NS2ID] = { }
		end
		if not table.contains(NSL_FunctionData[NS2ID], message.detectionType) then
			--Reconnects or monitored fields could re-add duplicate stuff, only add if new.	
			table.insert(NSL_FunctionData[NS2ID], message.detectionType)
		end
		--Set value
		NSL_FunctionData[NS2ID][message.detectionType] = message.detectionValue
	end
	
end

Server.HookNetworkMessage("ClientFunctionReport", OnRecievedFunction)

local function OnClientCommandShowFunctionData(client, target)
	if not client then return end
	local NS2ID = client:GetUserId()
	local heading = false
	if GetIsNSLRef(NS2ID) then
		local targetPlayer = NSLGetPlayerMatching(target)
		local targetClient
		if targetPlayer then
			targetClient = Server.GetOwner(targetPlayer)
		end
		local playerList = GetPlayerList()
		if playerList then
			for p = 1, #playerList do
				local playerClient = Server.GetOwner(playerList[p])
				if playerClient then
					local pNS2ID = playerClient:GetUserId()
					if NSL_FunctionData[pNS2ID] and (not targetPlayer or (targetClient and pNS2ID == targetClient:GetUserId())) then
						if not heading then
							SendClientServerAdminMessage(client, "NSL_FUNCTION_DATA_HEADING")
							SendClientServerAdminMessage(client, "NSL_PLAYER_INFO_HEADING")
							heading = true
						end
						Server.SendNetworkMessage(client, "NSLPlayerInfoMessage", {clientId = playerList[p]:GetClientIndex(), gameId = GetGameIDMatchingNS2ID(pNS2ID)}, true)
						for k, v in ipairs(NSL_FunctionData[pNS2ID]) do
							--Check for value updates if this is a detection type that updates.. itself?
							if NSL_FunctionData[pNS2ID][v] then
								SendClientServerAdminMessage(client, "NSL_FUNCTION_DATA_REPORT_UPDATES", v, NSL_FunctionData[pNS2ID][v])
							else
								SendClientServerAdminMessage(client, "NSL_FUNCTION_DATA_REPORT", v)
							end
						end
						SendClientServerAdminMessage(client, "NSL_FUNCTION_DATA_END")
					end
				end
			end
		end
		if not heading then
			SendClientServerAdminMessage(client, "NSL_FUNCTION_DATA_NONE")
		end
	end
end

RegisterNSLConsoleCommand("sv_nslfunctiondata", OnClientCommandShowFunctionData, "SV_NSLFUNCTIONDATA", false,
	{{ Type = "string", Optional = true}})

local originalNS2PlayerGetName
originalNS2PlayerGetName = Class_ReplaceMethod("Player", "GetName", 
	function(self)
		if GetNSLConfigValue("ForceLeagueNicks") then
			if self.playerInfo then 
				if self.playerInfo:GetNSLName() ~= "" then
					return self.playerInfo:GetNSLName()
				end
			end
		end
		return self.name ~= "" and self.name or kDefaultPlayerName
	end
)