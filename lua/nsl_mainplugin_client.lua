//NSL Main Plugin

Script.Load("lua/nsl_class.lua")
Script.Load("lua/nsl_mainplugin_shared.lua")

local kTeam1NameLocal
local kTeam2NameLocal

local function OnNewTeamNames(message)
	kTeam1NameLocal = message.team1name
	kTeam2NameLocal = message.team2name
	local GUIS = ClientUI.GetScript("GUIScoreboard")
	if GUIS then
		GUIS.teams[2].TeamName = kTeam1NameLocal
		GUIS.teams[3].TeamName = kTeam2NameLocal
	end
	Shared.ConsoleCommand( string.format([[teams "%s" "%s"]], kTeam1NameLocal, kTeam2NameLocal) )
	Shared.ConsoleCommand( string.format("scores %s %s", message.team1score, message.team2score) )
end

function ScoreboardUI_GetBlueTeamName()
    return (kTeam1NameLocal and kTeam1NameLocal) or kTeam1Name
end

function ScoreboardUI_GetRedTeamName()
    return (kTeam2NameLocal and kTeam2NameLocal) or kTeam2Name
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

AddClientUIScriptForClass("Spectator", "GUINSLFollowingSpectatorHUD")

//Materials that reference time dont call back into lua, which causes issues.
//This sucks, but should hopefully fix those issues.
//This might be the most epic hack in all of ns2 :<

local TimeBypassFunctions = { }
table.insert(TimeBypassFunctions, {name = "Alien", func = "UpdateClientEffects", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "BiteLeap", func = "CreateBloodEffect", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "LerkBite", func = "CreateBloodEffect", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "DetectableMixin", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "ClientWeaponEffectsMixin", func = "UpdateAttackEffects", oldFunc = nil })

for i, classarray in pairs(TimeBypassFunctions) do
	classarray.oldFunc = Class_ReplaceMethod(classarray.name, classarray.func, 
		function(...)
			gTimeBypass = true
			classarray.oldFunc(...)
			gTimeBypass = false
		end
	)
end

//WOWOWOWOWOWOW
local oldGUIManagerSendCharacterEvent = GUIManager.SendCharacterEvent
function GUIManager:SendCharacterEvent(character)
	//Separate callback :/
	oldGUIManagerSendCharacterEvent(self, character)
	local localPlayer = Client.GetLocalPlayer()
	if localPlayer and localPlayer.gamepaused and ChatUI_EnteringChatMessage() then
		ReplaceLocals(ChatUI_EnterChatMessage, { startedChatTime = (Shared.GetTime() - 0.01) })
	end
end

local RefBadges = { }

local function RefBadgeRecieved(msg)
	//Print("received RefBadges msg for client id = "..msg.clientId.." msg = "..ToString(msg) )
	RefBadges[ msg.clientId ] = msg
end

Client.HookNetworkMessage("RefBadges", RefBadgeRecieved)

local oldBadges_GetBadgeTextures = Badges_GetBadgeTextures
function Badges_GetBadgeTextures( clientId, usecase )
	local textures = { }
	local badges = RefBadges[ clientId ]
	textures = oldBadges_GetBadgeTextures(clientId, usecase)
    if badges then
		local textureKey = (usecase == "scoreboard" and "scoreboardTexture" or "unitStatusTexture")
		for _,info in ipairs(gRefBadges) do
			if badges[ "has_" .. info.name .. "_badge" ] == true then
				table.insert( textures, info[textureKey] )
			end
		end
	end
	return textures
end