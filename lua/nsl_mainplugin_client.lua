-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\nsl_mainplugin_client.lua
-- - Dragon

--NSL Main Plugin

Script.Load("lua/nsl_class.lua")
Script.Load("lua/nsl_mainplugin_shared.lua")

local t1name = "Frontiersmen"
local t2name = "Kharaa"
local kChatMinWindow = 0.005
local kNSLTeamDecalSize = 256
local kNSLTeamDecalColumns = 8
local kNSLTeamDecalRows = 8
local kTeam1NameLocal
local kTeam2NameLocal
local kInsightTeamnameHack = false
local kNSLDecals = { }
local kNSLMode
local kNSLConfigUpdateFunctions = { }
local teamConfigUpdateURL = "https://raw.githubusercontent.com/xToken/NSL/master/configs/nsl_teamconfig.json"
local teamConfigLocalFile = "configs/nsl_teamconfig.json"
local kNSLModel = PrecacheAsset("models/teamlogos/nsllogos.model")
local kNSLCachedDecals = { }
local kNSLTeamConfig = { }
local kTeamWinScreensEnabled = false
local kNSLChatSoundWarning = PrecacheAsset("sound/NS2.fev/common/invalid")
PrecacheAsset("materials/teamlogos/teamlogos.surface_shader")

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

--Fix for low damage to techpoints causing infinite flashing warnings
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

--if I name this chatMessages, it matches vanilla.  Anything that then joins upvalues to the chatMessages in vanilla wont get broken by my hook then.
local chatMessages = { }
local kNSLDefaultMessageColor = Color(1, 1, 1, 1)
local kNSLMessageHexColor = 0x800080

local oldChatUI_GetMessages = ChatUI_GetMessages
function ChatUI_GetMessages()
	local cM = oldChatUI_GetMessages()
	if table.maxn(chatMessages) > 0 then
        table.copy(chatMessages, cM, true)
        chatMessages = { }
    end
	return cM
end

local function AdminMessageRecieved(message)
	local player = Client.GetLocalPlayer()    
	if message and player then
	
        table.insert(chatMessages, HexStringToNumber(message.color))
        table.insert(chatMessages, message.header)
		table.insert(chatMessages, kNSLDefaultMessageColor)
        table.insert(chatMessages, message.message)
		
		--No idea what this crap is for...
        table.insert(chatMessages, false)
        table.insert(chatMessages, false)
        table.insert(chatMessages, 0)
        table.insert(chatMessages, 0)

        if message.changesound then 
            StartSoundEffect(kNSLChatSoundWarning)
        else
            StartSoundEffect(player:GetChatSound())
        end
		Shared.Message(message.header .. " " .. message.message)
        
	end
end

Client.HookNetworkMessage("NSLSystemMessage", AdminMessageRecieved)

function GetNSLTeamName(teamName)
	if teamName and teamName ~= "" then
		teamName = string.lower(teamName)
		if kNSLTeamConfig and kNSLTeamConfig.TeamNames then
			for nslname, names in pairs(kNSLTeamConfig.TeamNames) do
				if table.contains(names, teamName) then
					return nslname
				end
			end
		end
	end
	return teamName
end

local function GetNSLTeamDecalLocation(nslTeamName)
	if kNSLTeamConfig and kNSLTeamConfig.TeamLogos and kNSLTeamConfig.TeamLogos[nslTeamName] then
		return kNSLTeamConfig.TeamLogos[nslTeamName]
	end
end

local function OnLoadLocalConfig(configFile)
	local config = { }
	local file = io.open(configFile, "r")
	if file then
		config = json.decode(file:read("*all"))
		file:close()
	end
	return config
end

local function OnConfigResponse(response, league)
	local responseTable
	if response then
		responseTable = json.decode(response)
		if not responseTable or not responseTable.Version or not responseTable.EndOfTable then
			Shared.Message("NSL - Failed getting team config from GitHub, using local copy.")
			responseTable = OnLoadLocalConfig(teamConfigLocalFile)
		end
		for i, config in ipairs(responseTable.Configs) do
			if config.LeagueName and config.LeagueName == league then
				kNSLTeamConfig = config
			end
		end
	end
	return responseTable
end

function OnNSLConfigRecieved(message)
	if message then
		kNSLMode = EnumToString(kNSLPluginConfigs, message.config)
		for i = 1, #kNSLConfigUpdateFunctions do
			kNSLConfigUpdateFunctions[i](kNSLMode)
		end
		Shared.Message("NSL Plugin currently running " .. kNSLMode .. " configuration.")
		if kNSLMode ~= "DISABLED" and (not kNSLTeamConfig or not kNSLTeamConfig.TeamNames) then
			Shared.SendHTTPRequest(teamConfigUpdateURL, "GET", function(response) OnConfigResponse(response, message.league) end)
		end
	end
end

Client.HookNetworkMessage("NSLPluginConfig", OnNSLConfigRecieved)

--Call this with a function if it needs to be updated when/if mode changes.
function RegisterNSLModeSensitiveFunction(method)
	if type(method) == "function" then
		table.insert(kNSLConfigUpdateFunctions, method)
	else
		Shared.Message("NSL - Attempted to register non-function argument for NSL Config callback")
		Shared.Message(Script.CallStack())
	end
end

function GetNSLMode()
	return kNSLMode
end

AddClientUIScriptForClass("Spectator", "GUINSLFollowingSpectatorHUD")

--Materials that reference time dont call back into lua, which causes issues.
--This sucks, but should hopefully fix those issues.
--This might be the most epic hack in all of ns2 :< 

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

--FFFFFFFFFFFFFFFF
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
	
	if scriptName == "GUIGameEnd" then
		--LAZY
		local kEndStates = enum({ 'AlienPlayerWin', 'MarinePlayerWin', 'AlienPlayerLose', 'MarinePlayerLose', 'AlienPlayerDraw', 'MarinePlayerDraw' })
		local kMessageText = { [kEndStates.AlienPlayerWin] = "ALIEN_VICTORY",
							   [kEndStates.MarinePlayerWin] = "MARINE_VICTORY",
							   [kEndStates.AlienPlayerLose] = "ALIEN_DEFEAT",
							   [kEndStates.MarinePlayerLose] = "MARINE_DEFEAT",
							   [kEndStates.AlienPlayerDraw] = "DRAW_GAME",
							   [kEndStates.MarinePlayerDraw] = "DRAW_GAME" }
		
		local oldGUIGameEndSetGameEnded = GUIGameEnd.SetGameEnded
		function GUIGameEnd:SetGameEnded(playerWon, playerDraw, playerTeamType)
			oldGUIGameEndSetGameEnded(self, playerWon, playerDraw, playerTeamType)
			if kTeamWinScreensEnabled then
				local playerIsMarine = playerTeamType == kMarineTeamType
				local endState
				if playerWon then
					endState = playerIsMarine and kEndStates.MarinePlayerWin or kEndStates.AlienPlayerWin
				elseif playerDraw then
					endState = playerIsMarine and kEndStates.MarinePlayerDraw or kEndStates.AlienPlayerDraw
				else
					endState = playerIsMarine and kEndStates.MarinePlayerLose or kEndStates.AlienPlayerLose
				end
				local messageString = Locale.ResolveString(kMessageText[endState])
				local winningTeamName = nil
				if endState == kEndStates.MarinePlayerWin then
					winningTeamName = InsightUI_GetTeam1Name()
				elseif endState == kEndStates.AlienPlayerWin then
					winningTeamName = InsightUI_GetTeam2Name()     
				end
				if winningTeamName then
					messageString = string.format("%s Wins!", winningTeamName)
				end
				local decalLocation = GetNSLTeamDecalLocation(GetNSLTeamName(winningTeamName))
				if decalLocation then
					local xOffset = ((decalLocation - 1) % kNSLTeamDecalColumns) * kNSLTeamDecalSize
					local yOffset = math.floor((decalLocation - 1) / kNSLTeamDecalColumns) * kNSLTeamDecalSize
					self.endIcon:SetTexture(teamDDS)
					self.endIcon:SetTexturePixelCoordinates(xOffset, yOffset, xOffset + kNSLTeamDecalSize, yOffset + kNSLTeamDecalSize)
					self.messageText:SetPosition(Vector(0, 0, 0) * GUIScale(1))
					self.messageText:SetText(messageString)
				end
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
	--Print("received RefBadges msg for client id = "..msg.clientId.." msg = "..ToString(msg) )
	RefBadges[ msg.clientId ] = msg
end

Client.HookNetworkMessage("RefBadges", RefBadgeRecieved)

local oldBadges_GetBadgeTextures = Badges_GetBadgeTextures
function Badges_GetBadgeTextures( clientId, usecase )
	local textures, badgeNames
	local badges = RefBadges[ clientId ]
	textures, badgeNames = oldBadges_GetBadgeTextures(clientId, usecase)
    if badges then
		--These seem to get cached somewhere now, so check the table to be sure....
		local textureKey = (usecase == "scoreboard" and "scoreboardTexture" or "unitStatusTexture")
		for _, info in ipairs(gRefBadges) do
			if not table.contains(badgeNames, info.name) and badges[ "has_" .. info.name .. "_badge" ] == true then
				table.insert( textures, info[textureKey] )
				table.insert( badgeNames, info.name )
				break
				--Can only have 1 nsl badge, sorry dudes
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

--Leeeets see how much this breaks :D
AddClientUIScriptForTeam(kSpectatorIndex, "GUINSLSpectatorTechMap")

local function InitNSLDecal(decal, origin, yaw, pitch, roll)
	if decal then
		local renderModel = Client.CreateRenderModel(RenderScene.Zone_Default)
		renderModel:SetModel(kNSLModel)
		if not kNSLCachedDecals[decal] then
			kNSLCachedDecals[decal] = PrecacheAsset(string.format("materials/teamlogos/%s/%s.material", decal, decal))
		end
		local renderMaterial = Client.CreateRenderMaterial()
		renderMaterial:SetMaterial(kNSLCachedDecals[decal])  
		renderModel:AddMaterial(renderMaterial)
		local coords = Angles(pitch, yaw, roll):GetCoords(origin)
		coords:Scale(4)
		renderModel:SetCoords(coords)
		table.insert(kNSLDecals, {model = renderModel, material = renderMaterial, origin = origin, decal = decal})
	end
end

local function OnNewNSLDecal(message)
	if message then
		InitNSLDecal(message.decalName, message.origin, message.yaw, message.pitch, message.roll)
	end
end

Client.HookNetworkMessage("NSLDecal", OnNewNSLDecal)

local kOriginVec = Vector(0, 0, 0)
local function OnClearNSLDecal(message)
	if message then
		for i = #kNSLDecals, 1, -1 do
			if kNSLDecals[i] and (kNSLDecals[i].origin == message.origin or message.origin == kOriginVec) then
				local rm = kNSLDecals[i].model
				local rmat = kNSLDecals[i].material
				rm:RemoveMaterial(rmat)
				Client.DestroyRenderMaterial(rmat)
				Client.DestroyRenderModel(rm)
				kNSLDecals[i] = nil
			end
		end
	end
end

Client.HookNetworkMessage("NSLClearDecals", OnClearNSLDecal)

local function OnReplacedPlayer(message)
	--AWWWW YEA LETS GO HORRIBLE CODE TIME
	local player = Client.GetLocalPlayer()
	if player then
	end
end

Client.HookNetworkMessage("NSLReplacePlayer", OnReplacedPlayer)