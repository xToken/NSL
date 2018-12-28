-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\eventhooks\client.lua
-- - Dragon

--Functions for when NSL mod state changes on client
gNSLConfigUpdateFunctions = { }
--Functions for when team names/scores are updated on client
gTeamNamesUpdatedFunctions = { }

local function OnNSLConfigUpdated(gameInfo)
	Shared.Message("NSL Plugin currently running " .. EnumToString(kNSLPluginConfigs, gameInfo.nslconfig) .. " configuration.")
end

table.insert(gNSLConfigUpdateFunctions, OnNSLConfigUpdated)