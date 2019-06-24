-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/nsl_shared.lua
-- - Dragon

-- NSL shared references
kNSLPluginConfigs =  enum( {'DISABLED', 'GATHER', 'PCW', 'OFFICIAL', 'CAPTAINS'} )
kNSLCaptainsStates = enum( {'REGISTRATION', 'VOTING', 'SELECTING', 'ROUND1', 'ROUND2', 'MAPVOTE'})

-- For reference
kNSLPluginBuild = 128

-- Shared defs
Script.Load("lua/NSL/nsl_utilities.lua")

Script.Load("lua/NSL/handicap/shared.lua")
--Script.Load("lua/NSL/heartbeat/shared.lua") -- Vanilla added 15sec timeout with B327
Script.Load("lua/NSL/gameinfo/shared.lua")
--Script.Load("lua/NSL/optimizations/shared.lua") -- Vanilla added entity update changes with B328 making this obsolete
Script.Load("lua/NSL/pause/shared.lua")
Script.Load("lua/NSL/playerdata/shared.lua")
Script.Load("lua/NSL/spectator_techtree/shared.lua")
Script.Load("lua/NSL/teamdecals/shared.lua")

-- NSL Network Messages below
local kMaxFunctionMessageLength = 80
local kNSLMessageIDMax = 255
local kMaxAdminChatLength = 250
local kNSLMessageAltMax = 25

local kNSLSystemMessage =
{
	header = "integer (0 to 2)",
	messageid = string.format("integer (0 to %d)", kNSLMessageIDMax),
    messageparam1 = string.format("string (%d)", kNSLMessageAltMax + 1),
    messageparam2 = string.format("string (%d)", kNSLMessageAltMax + 1),
    messageparam3 = string.format("string (%d)", kNSLMessageAltMax + 1),
	color = string.format("string (%d)", 7),
	changesound = "boolean" -- bool for now. later maybe filenames, or ints and keep an index somewhere
}

Shared.RegisterNetworkMessage("NSLSystemMessage", kNSLSystemMessage)

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

local kNSLServerAdminChatMessage =
{
	messageid = string.format("integer (0 to %d)", kNSLMessageIDMax),
    messageparam1 = string.format("string (%d)", kNSLMessageAltMax + 1),
    messageparam2 = string.format("string (%d)", kNSLMessageAltMax + 1),
    messageparam3 = string.format("string (%d)", kNSLMessageAltMax + 1),
}

Shared.RegisterNetworkMessage("NSLServerAdminPrint", kNSLServerAdminChatMessage)

local kAdminChatMessage =
{
	header = string.format("string (%d)", kMaxAdminChatLength + 1),
    message = string.format("string (%d)", kMaxAdminChatLength + 1),
	color = string.format("string (%d)", 7),
	changesound = "boolean" -- bool for now. later maybe filenames, or ints and keep an index somewhere
}

Shared.RegisterNetworkMessage("NSLAdminChat", kAdminChatMessage)

local kNSLPlayerInfoMessage =
{
	clientId = "entityid",
    gameId = "integer (0 to 4095)",
}

Shared.RegisterNetworkMessage("NSLPlayerInfoMessage", kNSLPlayerInfoMessage)