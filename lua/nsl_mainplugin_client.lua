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