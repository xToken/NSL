// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_mainplugin_client.lua
// - Dragon

//NSL Main Plugin

Script.Load("lua/nsl_class.lua")
Script.Load("lua/nsl_mainplugin_shared.lua")

local t1name = "Frontiersmen"
local t2name = "Kharaa"
local kChatMinWindow = 0.005
local kTeam1NameLocal
local kTeam2NameLocal
local kInsightTeamnameHack = false
local kNSLMode
local kNSLConfigUpdateFunctions = { }

local function OnNewTeamNames(message)
	kTeam1NameLocal = message.team1name
	kTeam2NameLocal = message.team2name
	Shared.ConsoleCommand( string.format([[teams "%s" "%s"]], kTeam1NameLocal, kTeam2NameLocal) )
	Shared.ConsoleCommand( string.format("scores %s %s", message.team1score, message.team2score) )
end

function ScoreboardUI_GetBlueTeamName()
    return (kTeam1NameLocal and kTeam1NameLocal) or kTeam1Name
end

function ScoreboardUI_GetRedTeamName()
    return (kTeam2NameLocal and kTeam2NameLocal) or kTeam2Name
end

function InsightUI_GetTeam1Name()
	if kInsightTeamnameHack and kTeam1NameLocal == t1name then
		return
	end
    return kTeam1NameLocal
end

function InsightUI_GetTeam2Name()
	if kInsightTeamnameHack and kTeam2NameLocal == t2name then
		return
	end
    return kTeam2NameLocal
end

Client.HookNetworkMessage("TeamNames", OnNewTeamNames)

//Fix for low damage to techpoints causing infinite flashing warnings
local originalNS2InsightUI_GetTechPointData = InsightUI_GetTechPointData
function InsightUI_GetTechPointData()
	local techPointData = originalNS2InsightUI_GetTechPointData()
	for i = 1, table.maxn(techPointData) do
        local structureRecord = techPointData[i]
        if structureRecord.HealthFraction > 0.9625 and structureRecord.HealthFraction < 1 then
			structureRecord.HealthFraction = 1.0
		end
    end
	return techPointData
end

local function AdminMessageRecieved(message)
	ChatUI_AddSystemMessage(message.message)
end

Client.HookNetworkMessage("AdminMessage", AdminMessageRecieved)

function OnNSLConfigRecieved(message)
	if message then
		kNSLMode = EnumToString(kNSLPluginConfigs, message.config)
		for i = 1, #kNSLConfigUpdateFunctions do
			kNSLConfigUpdateFunctions[i](kNSLMode)
		end
		Shared.Message("NSL Plugin currently running " .. kNSLMode .. " configuration.")
	end
end

Client.HookNetworkMessage("NSLPluginConfig", OnNSLConfigRecieved)

//Call this with a function if it needs to be updated when/if mode changes.
function RegisterNSLModeSensitiveFunction(method)
	if type(method) == "function" then
		table.insert(kNSLConfigUpdateFunctions, method)
	else
		Shared.Message("Attempted to register non-function argument for NSL Config callback")
		Shared.Message(Script.CallStack())
	end
end

function GetNSLMode()
	return kNSLMode
end

AddClientUIScriptForClass("Spectator", "GUINSLFollowingSpectatorHUD")

//Materials that reference time dont call back into lua, which causes issues.
//This sucks, but should hopefully fix those issues.
//This might be the most epic hack in all of ns2 :<

local tablebuilt = false
local TimeBypassFunctions = { }
table.insert(TimeBypassFunctions, {name = "Alien", func = "UpdateClientEffects", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "BiteLeap", func = "CreateBloodEffect", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "LerkBite", func = "CreateBloodEffect", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "DetectableMixin", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "ClientWeaponEffectsMixin", func = "UpdateAttackEffects", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "UmbraMixin", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "CloakableMixin", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "Fade", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "Player", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "ExoWeaponHolder", func = "OnUpdateRender", oldFunc = nil })

local function BuildTableEntry(tableEntry)
	tableEntry.oldFunc = Class_ReplaceMethod(tableEntry.name, tableEntry.func, 
		function(...)
			gTimeBypass = true
			tableEntry.oldFunc(...)
			gTimeBypass = false
		end
	)
end

local function BuildTimeBypassTable()
	for i, classarray in pairs(TimeBypassFunctions) do
		BuildTableEntry(classarray)
	end
	tablebuilt = true
end

function AddClassFunctionToTimeBypassTable(className, methodName)
	local cTable =  {name = className, func = methodName, oldFunc = nil }
	table.insert(TimeBypassFunctions, cTable)
	if tablebuilt then
		BuildTableEntry(cTable)
	end
end

local function OnLoadComplete()
	BuildTimeBypassTable()
end

Event.Hook("LoadComplete", OnLoadComplete)

//FFFFFFFFFFFFFFFF
local startedChatTime = 0

function ChatUI_GetStartedChatTime()
    return startedChatTime
end

local oldChatUI_EnterChatMessage = ChatUI_EnterChatMessage
function ChatUI_EnterChatMessage(teamOnly)
	local wasEnteringChat = ChatUI_EnteringChatMessage()
	oldChatUI_EnterChatMessage(teamOnly)
	if not wasEnteringChat and ChatUI_EnteringChatMessage() then
		startedChatTime = Client.GetTime()
	end
end

local function ChatUICreation(scriptName, script)

	if scriptName == "GUIChat" then

		function GUIChat:SendCharacterEvent(character)
			local enteringChatMessage = ChatUI_EnteringChatMessage()
			
			if (Client.GetTime() - ChatUI_GetStartedChatTime()) > kChatMinWindow and enteringChatMessage then
			
				local currentText = self.inputItem:GetWideText()
				if currentText:length() < kMaxChatLength then
				
					self.inputItem:SetWideText(currentText .. character)
					return true
					
				end
				
			end
			
			return false
		end
	
	end
	
	if scriptName == "GUIGameEnd" then
	
		local oldGUIGameEndSetGameEnded = GUIGameEnd.SetGameEnded
		function GUIGameEnd:SetGameEnded(playerWon, playerDraw, playerTeamType)
			kInsightTeamnameHack = true
			oldGUIGameEndSetGameEnded(self, playerWon, playerDraw, playerTeamType)
			kInsightTeamnameHack = false
		end
		
	end
	
	if scriptName == "GUIScoreboard" then
		
		local oldGUIScoreboardUpdateTeam = GUIScoreboard.UpdateTeam
		function GUIScoreboard:UpdateTeam(updateTeam)
			oldGUIScoreboardUpdateTeam(self, updateTeam)
			local teamNameGUIItem = updateTeam["GUIs"]["TeamName"]
			local teamNum = updateTeam["TeamNumber"]
			local teamScores = updateTeam["GetScores"]()
			local numPlayers = table.count(teamScores)
			local playersOnTeamText = string.format("%d %s", numPlayers, numPlayers == 1 and Locale.ResolveString("SB_PLAYER") or Locale.ResolveString("SB_PLAYERS") )
			if teamNum == 1 and kTeam1NameLocal ~= t1name then
				teamNameGUIItem:SetText( string.format("%s (%s)", kTeam1NameLocal, playersOnTeamText) )
			elseif teamNum == 2 and kTeam2NameLocal ~= t2name then
				teamNameGUIItem:SetText( string.format("%s (%s)", kTeam2NameLocal, playersOnTeamText) )
			end
			
		end
		
	end
	
end

ClientUI.AddScriptCreationEventListener(ChatUICreation)

local kPausedUpdateScripts = { "GUIScoreboard", "GUIChat", "GUIMinimapFrame", "GUIInsight_PlayerFrames", "GUITechMap", "GUIInsight_Overhead", "GUIMainMenu",
								"GUIInsight_PenTool", "GUIInsight_PlayerHealthbars", "GUIInsight_Graphs", "GUINSLSpectatorTechMap", "GUINSLFollowingSpectatorHUD" }
local kPausedScoreboardUpdateRate = 0.5
local scoreboardUpdate = 0.5

function AddGUIScriptToPausedUpdates(GUIClassName)
    table.insert(kPausedUpdateScripts, GUIClassName)
end

local originalGUIManagerUpdate
originalGUIManagerUpdate = Class_ReplaceMethod("GUIManager", "Update", 
	function(self, deltaTime)
		local player = Client.GetLocalPlayer()
		if player and player.gamepaused then
			for s = #self.scripts, 1, -1 do
				local script = self.scripts[s]
				if script and table.contains(kPausedUpdateScripts, script.classname) then
					script.lastUpdateTime = script.lastUpdateTime - deltaTime
				end
			end
			scoreboardUpdate = math.max(0, scoreboardUpdate - deltaTime)
			if scoreboardUpdate == 0 then
				Scoreboard_ReloadPlayerData()
				scoreboardUpdate = kPausedScoreboardUpdateRate
			end
		end
		originalGUIManagerUpdate(self, deltaTime)
	end
)

local RefBadges = { }

local function RefBadgeRecieved(msg)
	//Print("received RefBadges msg for client id = "..msg.clientId.." msg = "..ToString(msg) )
	RefBadges[ msg.clientId ] = msg
end

Client.HookNetworkMessage("RefBadges", RefBadgeRecieved)

local oldBadges_GetBadgeTextures = Badges_GetBadgeTextures
function Badges_GetBadgeTextures( clientId, usecase )
	local textures, badgeNames
	local badges = RefBadges[ clientId ]
	textures, badgeNames = oldBadges_GetBadgeTextures(clientId, usecase)
    if badges then
		//These seem to get cached somewhere now, so check the table to be sure....
		local textureKey = (usecase == "scoreboard" and "scoreboardTexture" or "unitStatusTexture")
		for _, info in ipairs(gRefBadges) do
			if not table.contains(badgeNames, info.name) and badges[ "has_" .. info.name .. "_badge" ] == true then
				table.insert( textures, info[textureKey] )
				table.insert( badgeNames, info.name )
				break
				//Can only have 1 nsl badge, sorry dudes
			end
		end
	end
	return textures, badgeNames
end

local oldGetBadgeFormalName = GetBadgeFormalName
function GetBadgeFormalName(name)
	local fname = oldGetBadgeFormalName(name)
	if fname == "Custom Badge" then
		for _, info in ipairs(gRefBadges) do
			if info.name == name then
				return info.fname
			end
		end
	end
	return fname
end

//Leeeets see how much this breaks :D
AddClientUIScriptForTeam(kSpectatorIndex, "GUINSLSpectatorTechMap")