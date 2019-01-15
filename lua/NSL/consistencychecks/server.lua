-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/consistencychecks/server.lua
-- - Dragon

local consistencyFile = "configs/nsl_consistencyconfig.json"

local function ApplyNSLConsistencyConfig()
	
	local file = io.open(consistencyFile, "r")
	if file then
		consistencyConfig = json.decode(file:read("*all"))
		file:close()
	end

	Shared.Message("NSL - Loading ConsistencyConfig.")
		
	if consistencyConfig then

		local startTime = Shared.GetSystemTime()			
		if type(consistencyConfig.check) == "table" then
			local check = consistencyConfig.check
			for c = 1, #check do
				local numHashed = Server.AddFileHashes(check[c])
				Shared.Message("Hashed " .. numHashed .. " " .. check[c] .. " files for consistency")
			end
		end

		if type(consistencyConfig.ignore) == "table" then
			local ignore = consistencyConfig.ignore
			for c = 1, #ignore do
				local numHashed = Server.RemoveFileHashes(ignore[c])
				Shared.Message("Skipped " .. numHashed .. " " .. ignore[c] .. " files for consistency")
			end
		end

		if type(consistencyConfig.restrict) == "table" then
			local restrict = consistencyConfig.restrict
			for c = 1, #restrict do
				local numHashed = Server.AddRestrictedFileHashes(restrict[c])
				Shared.Message("Restricted to " .. numHashed .. " " .. restrict[c] .. " files for consistency")
			end
		end
		
		local endTime = Shared.GetSystemTime()
		Print("NSL - Enhanced Consistency checking took " .. ToString(endTime - startTime) .. " seconds.")
		
	end
	
end

ApplyNSLConsistencyConfig()