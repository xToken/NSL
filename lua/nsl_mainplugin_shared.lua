Script.Load("lua/nsl_class.lua")

local kMaxTeamNameLength = 50
local kMaxAdminChatLength = 250

local kTeamNameUpdateMessage =
{
    team1name = string.format("string (%d)", kMaxTeamNameLength + 1),
	team2name = string.format("string (%d)", kMaxTeamNameLength + 1),
	team1score = "integer (0 to 10)",
	team2score = "integer (0 to 10)"
}

Shared.RegisterNetworkMessage("TeamNames", kTeamNameUpdateMessage)

local kAdminChatMessage =
{
    message = string.format("string (%d)", kMaxAdminChatLength + 1)
}

Shared.RegisterNetworkMessage("AdminMessage", kAdminChatMessage)

function PlayerRanking:GetTrackServer()
    return not GetServerContainsBots()
end

function PlayerRanking:GetGameMode()
    return "ns2"
end