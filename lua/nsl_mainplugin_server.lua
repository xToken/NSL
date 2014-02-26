//NSL Main Plugin
//This will hopefully (once more is available from ENSL site and also in NS2's engine) function somewhat like the old ensl plugin for ns1.
//Short term - this just checks the ensl database on user connect to get more information about clients.  Also enables friendly fire and sets some slightly better networking values.
//Long term - this will force clients to be on their team ingame, and also automatically allow for approval/rejection of mercs.

//Functions for chat commands
gChatCommands = { }
//Chat functions which could use additional arguments
gArgumentedChatCommands = { }
//Functions on connect
gConnectFunctions = { }
//Team Allowance Checks
gCanJoinTeamFunctions = { }
local kReserveSlotEnabled = false

Script.Load("lua/nsl_class.lua")
Script.Load("lua/nsl_mainplugin_shared.lua")
Script.Load("lua/nsl_playerdata_server.lua")
Script.Load("lua/nsl_teammanager_server.lua")

local function OnClientConnected(client)
	if GetNSLModEnabled() then
		if GetNSLConfig().kInterp ~= 100 then
			Shared.ConsoleCommand(string.format("interp %f", (GetNSLConfig().kInterp/1000)))
		end
		if GetNSLConfig().kClientRate ~= 20 then
			//Shared.ConsoleCommand(string.format("cr %f", GetNSLConfig().kClientRate))
		end
		if GetNSLConfig().kMoveRate ~= 30 then
			Shared.ConsoleCommand(string.format("mr %f", GetNSLConfig().kMoveRate))
		end
		for i = 1, #gConnectFunctions do
			gConnectFunctions[i](client)
		end
	end
end

Event.Hook("ClientConnect", OnClientConnected)

local originalNS2GameRulesGetCanJoinTeamNumber
originalNS2GameRulesGetCanJoinTeamNumber = Class_ReplaceMethod("NS2Gamerules", "GetCanJoinTeamNumber", 
	function(self, teamNumber)
		if GetNSLModEnabled() then
			for i = 1, #gCanJoinTeamFunctions do
				if not gCanJoinTeamFunctions[i](self, teamNumber) then
					return false
				end
			end
		end
		return originalNS2GameRulesGetCanJoinTeamNumber(self, teamNumber)
	end
)

function ValidateNSLUsersAccessLevel(ns2id)
	if ns2id then
		return table.contains(GetNSLRefs(), ns2id)
	end
	return false
end

local originalNS2GRGetFriendlyFire
//Override friendly fire function checks
originalNS2GRGetFriendlyFire = Class_ReplaceMethod("NS2Gamerules", "GetFriendlyFire", 
	function(self)
		return GetFFEnabled() and GetNSLModEnabled()
	end
)

//Override friendly fire function checks
function GetFriendlyFire()
	return GetFFEnabled() and GetNSLModEnabled()
end

//Block MapCycle
function MapCycle_CycleMap()
end

//Set friendly fire percentage
kFriendlyFireScalar = GetNSLConfig().kFriendlyFireDamagePercentage

//Simple functions to make sending messages easier.
function SendAllClientsMessage(message)
	Server.SendNetworkMessage("Chat", BuildChatMessage(false, "NSL", -1, kTeamReadyRoom, kNeutralTeamType, message), true)
end

function SendClientMessage(client, message)
	Server.SendNetworkMessage(client, "Chat", BuildChatMessage(false, "NSL", -1, kTeamReadyRoom, kNeutralTeamType, message), true)
end

function SendTeamMessage(teamnum, message)

	local chatmessage = BuildChatMessage(false, "NSL", -1, kTeamReadyRoom, kNeutralTeamType, message)
	if tonumber(teamnum) ~= nil then
		local playerRecords = GetEntitiesForTeam("Player", teamnum)
		for _, player in ipairs(playerRecords) do
			
			local client = Server.GetOwner(player)
			if client ~= nil then
				Server.SendNetworkMessage(client, "Chat", chatmessage, true)
			end
		
		end
	end
end

function ProcessSayCommand(player, command)

	if GetNSLModEnabled() then
		local client = Server.GetOwner(player)
		for validCommand, func in pairs(gChatCommands) do
			if string.lower(validCommand) == string.lower(command) then
				func(client)
			end
		end
		for validCommand, func in pairs(gArgumentedChatCommands) do
			if string.lower(string.sub(command, 1, string.len(validCommand))) == string.lower(validCommand) then
				func(client, string.sub(command, string.len(validCommand) + 2))
			end
		end
	end

end

local function OnClientCommandENSLHelp(client)
	if client then
		local NS2ID = client:GetUserId()
		if ValidateNSLUsersAccessLevel(NS2ID) then
			ServerAdminPrint(client, "sv_nslinfo" .. ": " .. "<team> - marines,aliens,specs,other,all - Will return the player details from the ENSL site.")
			ServerAdminPrint(client, "sv_nslsay" .. ": " .. "<message> - Will send a message to all connected players that displays in yellow.")
			ServerAdminPrint(client, "sv_nsltsay" .. ": " .. "<team, message> - Will send a message to all players on the team provided that displays in yellow.")
			ServerAdminPrint(client, "sv_nslpsay" .. ": " .. "<player, message> - Will send a message to the provided player that displays in yellow.")
			ServerAdminPrint(client, "sv_nslcfg" .. ": " .. "<state> - disabled,pcw,official - Changes the configuration mode of the NSL plugin.")
			ServerAdminPrint(client, "sv_nslapprovemercs" .. ": " .. "<team, optional player> - Forces approval of teams mercs, '1' approving for marines which allows alien mercs.")
			ServerAdminPrint(client, "sv_nslclearmercs" .. ": " .. "<team> - 1,2 - Clears approval of teams mercs, '1' clearing any alien mercs.")
			ServerAdminPrint(client, "sv_nslpause" .. ": " .. "Will pause/unpause game using standard delays.  Does not consume teams allowed pauses.")
			ServerAdminPrint(client, "sv_nslforcestart" .. ": " .. "Will force the countdown to start regardless of teams ready status, still requires commanders.")
			ServerAdminPrint(client, "sv_nslcancelstart" .. ": " .. "Will cancel a game start countdown currently in progress.")
			ServerAdminPrint(client, "sv_nslsetteamnames" .. ": " .. "<team1name, team2name> Will set the team names manually, will prevent automatic team name updates.")
			ServerAdminPrint(client, "sv_nslswitchteams" .. ": " .. "Will switch team names (best used if setting team names manually).")
			ServerAdminPrint(client, "sv_nslsetteamscores" .. ": " .. "<t1score, t2score> Will set the team scores manually, set team names first.")
		end
	end
end

Event.Hook("Console_sv_nslhelp",               OnClientCommandENSLHelp)

local function OnCommandEnableFF(client)
	SetFFState(not GetFFEnabled())
	ServerAdminPrint(client, "Friendly Fire " .. ConditionalValue(GetFFEnabled(), "enabled.", "disabled."))
end

CreateServerAdminCommand("Console_sv_nslfriendlyfire", OnCommandEnableFF, "Toggles friendly fire on or off.")

local function SetupRefReserveSlot()
	local setting = Server.GetConfigSetting("reserved_slots")
	local refs = GetNSLRefs()
	local validids = { }
	
    if not setting then
        Server.SetConfigSetting("reserved_slots", { amount = 0, ids = { } })
        setting = Server.GetConfigSetting("reserved_slots")
    end
	
	for i = 1, #refs do
		local valid
		for name, ns2id in pairs(setting.ids) do
			if refs[i] == ns2id then
				validids[ns2id] = true
				valid = true
				break
			end
		end
		if not valid then
			validids[refs[i]] = true
			setting.ids["NSLRef"] = refs[i]
		end
	end
	
	for name, ns2id in pairs(setting.ids) do
		if (not kReserveSlotEnabled or not validids[ns2id]) and name == "NSLRef" then
			setting.ids[name] = nil
		end
	end
	
	setting.amount = ConditionalValue(kReserveSlotEnabled, 1, 0)
	
	local tags = { }
	Server.GetTags(tags)
	for t = 1, #tags do
	
		if string.find(tags[t], "R_S") then
			Server.RemoveTag(tags[t])
		end
		
	end
	
	if kReserveSlotEnabled then
		Server.AddTag("R_S" .. setting.amount)
		Server.SaveConfigSettings()
	end
	
end

if GetNSLModEnabled() then
	//Block AFK, AutoConcede, AutoTeamBalance and other server cfg stuff
	Server.SetConfigSetting("rookie_friendly", false)
	Server.SetConfigSetting("force_even_teams_on_join", false)
	Server.SetConfigSetting("auto_team_balance", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance_check_after_time", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance_after_warning_time", nil)
	Server.SetConfigSetting("auto_kick_afk_time", nil)
	Server.SetConfigSetting("auto_kick_afk_capacity", nil)
	Server.SetConfigSetting("end_round_on_team_unbalance", nil)
	SetupRefReserveSlot()
end

local kDeltatimeBetweenAction = 0.3
	
local function IsTeamSpectator(self)
	return self:isa("TeamSpectator") or self:isa("AlienSpectator") or self:isa("MarineSpectator")
end

local function NextSpectatorMode(self, mode)

	if mode == nil then
		mode = self.specMode
	end
	
	local numModes = 0
	for name, _ in pairs(kSpectatorMode) do
	
		if type(name) ~= "number" then
			numModes = numModes + 1
		end
		
	end

	local nextMode = (mode % numModes) + 1
	// FirstPerson is only used directly through SetSpectatorMode(), never in this function.
	if nextMode == kSpectatorMode.FirstPerson then
		if IsTeamSpectator(self) then
			return kSpectatorMode.Following
		else
			return kSpectatorMode.FreeLook
		end
    else
		return nextMode
	end
	
end

local function UpdateSpectatorMode(self, input)

	assert(Server)
	
	self.timeFromLastAction = self.timeFromLastAction + input.time
	if self.timeFromLastAction > kDeltatimeBetweenAction then
	
		if bit.band(input.commands, Move.Jump) ~= 0 then
		
			self:SetSpectatorMode(NextSpectatorMode(self))
			self.timeFromLastAction = 0
			
		elseif bit.band(input.commands, Move.Weapon1) ~= 0 then
		
			self:SetSpectatorMode(kSpectatorMode.FreeLook)
			self.timeFromLastAction = 0
			
		elseif bit.band(input.commands, Move.Weapon2) ~= 0 then
		
			self:SetSpectatorMode(kSpectatorMode.Overhead)
			self.timeFromLastAction = 0
			
		elseif bit.band(input.commands, Move.Weapon3) ~= 0 then
		
			self:SetSpectatorMode(kSpectatorMode.Following)
			self.timeFromLastAction = 0
			
		end
		
	end
	
end

ReplaceLocals(Spectator.OnProcessMove, {UpdateSpectatorMode = UpdateSpectatorMode})

local oldNS2SpectatorOnInitialized = Spectator.OnInitialized
function Spectator:OnInitialized()
	oldNS2SpectatorOnInitialized(self)
	self:SetSpectatorMode(kSpectatorMode.Following)
end

function TeamSpectator:OnInitialized()
	Spectator.OnInitialized(self)
end

local function OnClientCommandNSLFPS(client)
	if client then
		local NS2ID = client:GetUserId()
		if ValidateNSLUsersAccessLevel(NS2ID) then
			local player = client:GetControllingPlayer()
			if player ~= nil and player:isa("Spectator") and player:GetTeamNumber() == kSpectatorIndex then
				player:SetSpectatorMode(kSpectatorMode.FirstPerson)
			end
		end
	end
end

Event.Hook("Console_sv_nslfirstpersonspectate",               OnClientCommandNSLFPS)