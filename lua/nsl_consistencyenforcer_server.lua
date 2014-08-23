//Hmm lets see what kind of craziness THIS can cause...

local ConsistencyApplied = false
local defaultConsistency = 
{
	restrict = 	{ "lua/entry/*.entry" },
	check = 	{ 	
				"game_setup.xml", 
				"*.lua", 
				"*.hlsl", 
				"*.shader", 
				"*.screenfx", 
				"*.surface_shader", 
				"*.fxh",
				"*.fx", 
				"*.render_setup", 
				"*.shader_template", 
				"*.level", 
				"*.dds", 
				"*.jpg", 
				"*.png", 
				"*.cinematic", 
				"*.material", 
				"*.model", 
				"*.animation_graph", 
				"*.polygons", 
				"*.fev", 
				"*.fsb", 
				"*.entry" 
				},
	ignore = 	{ 	
				"ui/crosshairs.dds", 
				"ui/crosshairs-hit.dds", 
				"ui/exo_crosshair.dds", 
				"ui/exosuit_HUD1.dds", 
				"ui/exosuit_HUD4.dds", 
				"ui/marine_minimap_blip.dds", 
				"ui/minimap_blip.dds",
				"sound/hitsounds_client.fev",
				"sound/hitsounds_client.fsb",
				"sound/hitsounds_client.soundinfo"
				}
}

local function ApplyNSLConsistencyConfig()

	local consistencyConfig = GetNSLConfigValue("ConsistencyConfig") or defaultConsistency
		
	if consistencyConfig and not ConsistencyApplied then

		local startTime = Shared.GetSystemTime()
		//First, remove ANY established config
		Server.RemoveFileHashes("*.*")
		
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
			local check = consistencyConfig.restrict
			for c = 1, #check do
				local numHashed = Server.AddRestrictedFileHashes(check[c])
				Shared.Message("Hashed " .. numHashed .. " " .. check[c] .. " files for consistency")
			end
		end
		
		local endTime = Shared.GetSystemTime()
		Print("NSL Enhanced Consistency checking took " .. ToString(endTime - startTime) .. " seconds")
		ConsistencyApplied = true
		
	end
	
end

table.insert(gConfigLoadedFunctions, ApplyNSLConsistencyConfig)