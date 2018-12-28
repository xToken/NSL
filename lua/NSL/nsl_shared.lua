-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/nsl_shared.lua
-- - Dragon

-- NSL shared references
kNSLPluginConfigs =  enum( {'DISABLED', 'GATHER', 'PCW', 'OFFICIAL'} )
kNSLPluginConfigString = { }
kNSLPluginConfigString["DISABLED"] = kNSLPluginConfigs.DISABLED
kNSLPluginConfigString["GATHER"] = kNSLPluginConfigs.GATHER
kNSLPluginConfigString["PCW"] = kNSLPluginConfigs.PCW
kNSLPluginConfigString["OFFICIAL"] = kNSLPluginConfigs.OFFICIAL

-- For reference
kNSLPluginBuild = 103

-- Shared defs
Script.Load("lua/NSL/nsl_utilities.lua")

Script.Load("lua/NSL/handicap/shared.lua")
Script.Load("lua/NSL/gameinfo/shared.lua")
Script.Load("lua/NSL/pause/shared.lua")
Script.Load("lua/NSL/playerdata/shared.lua")
Script.Load("lua/NSL/spectator_techtree/shared.lua")
Script.Load("lua/NSL/teamdecals/shared.lua")

-- NSL Network Messages below
local kMaxAdminChatLength = 250
local kMaxFunctionMessageLength = 80

local kAdminChatMessage =
{
	header = string.format("string (%d)", kMaxAdminChatLength + 1),
    message = string.format("string (%d)", kMaxAdminChatLength + 1),
	color = string.format("string (%d)", 7),
	changesound = "boolean" -- bool for now. later maybe filenames, or ints and keep an index somewhere
}

Shared.RegisterNetworkMessage("NSLSystemMessage", kAdminChatMessage)

local kTechTreeRequest = 
{
	teamNumber =  string.format("integer (-1 to %d)", kSpectatorIndex)
}

Shared.RegisterNetworkMessage("RequestTeamTechTree", kTechTreeRequest)

local kFunctionTrigger = 
{
	detectionType = string.format("string (%d)", kMaxFunctionMessageLength + 1),
	detectionValue = string.format("string (%d)", kMaxFunctionMessageLength + 1),
}

Shared.RegisterNetworkMessage("ClientFunctionReport", kFunctionTrigger)