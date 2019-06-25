-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/errorreporter/server.lua
-- - Dragon

local kErrorLength = 9999
local kErrorKeyLength = 1024
local kReportedErrors = { }
local kReportedErrorsCount = 0

local function ErrorReporter(msg)
	local k = string.sub(msg, 1, kErrorKeyLength)
	kReportedErrors[k] = string.sub(msg, 1, kErrorLength)
	-- This wont always be numerically accurate, but good enough
	kReportedErrorsCount = kReportedErrorsCount + 1
end

Event.Hook("ErrorCallback", ErrorReporter)

local function OnErrorReportResponse(data)
	-- No reponse codes are coming through... another weirdness with NS2?
end

local function OnGameEndReportErrors()
	if GetNSLConfigValue("ReportErrors") and kReportedErrorsCount > 0 then
		local osver = jit and jit.os or ""
		local modData = ""
		local errData = { }
		for i = 1, Server.GetNumActiveMods() do
			modData = modData .. Server.GetActiveModId(i) .. ","
		end
		for k, v in pairs(kReportedErrors) do
			table.insert(errData, v)
		end
		postData = { OS = osver, Mods = string.sub(modData, 1, -2), Error = errData, ErrorCount = kReportedErrorsCount, Build = kNSLPluginBuild, NS2_Build = Shared.GetBuildNumber() }
		Shared.SendHTTPRequest(GetNSLConfigValue("ErrorReportURL"), "POST", { data = json.encode(postData) }, OnErrorReportResponse)
		kReportedErrors = { }
		kReportedErrorsCount = 0
	end
end

table.insert(gGameEndFunctions, OnGameEndReportErrors)