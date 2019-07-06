-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/customspawns/shared.lua
-- - Dragon

function TechPoint:SetAllowedTeam(teamNumber)
	teamNumber = teamNumber or 3
    self.allowedTeamNumber = Clamp(teamNumber, 0, 3)
end

function TechPoint:GetTeamNumberAllowed()
    return self.allowedTeamNumber
end

Class_Reload( "TechPoint", { allowedTeamNumber = "integer (0 to 3)" } )

local kSelectSpawnMessage =
{
	techPointId = "entityid"
}

Shared.RegisterNetworkMessage("NSLSelectSpawn", kSelectSpawnMessage)