// Making our own GetLightsForLocation (can't override the other one and light cache is a local)
// I'm not sure I prefer this over the other method I was using before...
// At least it's a single file here? Maybe? Meh...

local NSLMaps = { 	"ns2_nsl_biodome", "ns2_nsl_summit", "ns2_nsl_tram", "ns2_nsl_descent", "ns2_nsl_veil", "ns2_nsl_jambi", "ns2_nsl_eclipse", 
					"ns2_biodome", "ns2_summit", "ns2_tram", "ns2_descent", "ns2_veil", "ns2_jambi", "ns2_eclipse", 
					"ns2_turtle", "ns2_caged", "ns2_tanith" }
					
local BlockedProps = { 	"models/props/veil/veil_hologram_01.model", 
						"models/props/veil/veil_holosign_01_nanogrid.model", 
						"models/props/biodome/biodome_bamboo_crown_01_01.model",
						"models/props/biodome/biodome_bamboo_crown_01_02.model",
						"models/props/biodome/biodome_bamboo_crown_01_03.model",																	
						"models/props/biodome/biodome_bamboo_crown_01_04.model",
						"models/props/biodome/biodome_bamboo_clump_01_01_high.model",
						"models/props/biodome/biodome_bamboo_clump_01_02_high.model",
						"models/props/biodome/biodome_bamboo_clump_01_03_high.model",
						"models/props/biodome/biodome_bamboo_clump_01_04_high.model",
						"models/props/biodome/biodome_bamboo_clump_01_05_high.model",
						"models/props/biodome/biodome_bamboo_clump_01_01_low.model",
						"models/props/biodome/biodome_bamboo_clump_01_02_low.model",
						"models/props/biodome/biodome_bamboo_clump_01_03_low.model",
						"models/props/biodome/biodome_bamboo_clump_01_04_low.model",
						"models/props/biodome/biodome_bamboo_clump_01_05_low.model",
						"models/props/biodome/biodome_waterfall_01.model",
						"models/props/biodome/biodome_grass_01_01.model",
						"models/props/biodome/biodome_grass_01_02.model",
						"models/props/biodome/biodome_grass_01_03.model",
						"models/props/biodome/biodome_grass_01_04.model",
						"models/props/biodome/biodome_grass_02_tile.model" }
					
local PropCache = { }				//Caches model and physics models for destruction.
local DataCache = { }				//Caches object information for output to JSON or reloading NSL state.
local NSLLights						//If NSL setup is loaded or not.
local lightLocationCache = { }		//For GetLightsForLocation function override.
local Loaded = false				//If first run even has triggered.
local kIntensityCutoff = 10 		//Meh maybe.
local kIntensityIncrease = 10
local kDistanceIncrease = 1

Script.Load("lua/nsl_class.lua")
Script.Load("lua/dkjson.lua")

local function ClearObjects()
	if Client then
		if Client.lightList ~= nil then
			for index, light in ipairs(Client.lightList) do
				Client.DestroyRenderLight(light)
			end
			Client.lightList = { }
		end
		if PropCache ~= nil then
			for index, models in ipairs(PropCache) do
				Client.DestroyRenderModel(models[1])
				Shared.DestroyCollisionObject(models[2])
			end
			PropCache = { }
		end
    end
end

local originalSetCommanderPropState = SetCommanderPropState
function SetCommanderPropState(isComm)
	originalSetCommanderPropState(isComm)
	if PropCache ~= nil then
		for index, propPair in ipairs(PropCache) do
			local prop = propPair[1]
			if prop.commAlpha < 1 then
				prop:SetIsVisible(not isComm)
			end
		end
	end

end

local originalDestroyLevelObjects = DestroyLevelObjects
function DestroyLevelObjects()
	originalDestroyLevelObjects()
	ClearObjects()
end

local function UpdateValuesForObject(object, loading)
	if loading then
		object.angles = Angles(object.angles.pitch, object.angles.yaw, object.angles.roll)
		object.origin = Vector(object.origin.x, object.origin.y, object.origin.z)
		if object.color then
			object.color = Color(object.color.r, object.color.g, object.color.b, object.color.a)
		end
		if object.scale then
			object.scale = Vector(object.scale.x, object.scale.y, object.scale.z)
		end
		if object.color_dir_forward then
			object.color_dir_forward = Color(object.color_dir_forward.r, object.color_dir_forward.g, object.color_dir_forward.b, object.color_dir_forward.a)
			object.color_dir_backward = Color(object.color_dir_backward.r, object.color_dir_backward.g, object.color_dir_backward.b, object.color_dir_backward.a)
			object.color_dir_up = Color(object.color_dir_up.r, object.color_dir_up.g, object.color_dir_up.b, object.color_dir_up.a)
			object.color_dir_down = Color(object.color_dir_down.r, object.color_dir_down.g, object.color_dir_down.b, object.color_dir_down.a)
			object.color_dir_left = Color(object.color_dir_left.r, object.color_dir_left.g, object.color_dir_left.b, object.color_dir_left.a)
			object.color_dir_right = Color(object.color_dir_right.r, object.color_dir_right.g, object.color_dir_right.b, object.color_dir_right.a)
		end
	else
		object.angles = { pitch = object.angles.pitch, yaw = object.angles.yaw, roll = object.angles.roll }
		object.origin = { x = object.origin.x, y = object.origin.y, z = object.origin.z }
		if object.color then
			object.color = { r = object.color.r, g = object.color.g, b = object.color.b, a = object.color.a }
		end
		if object.scale then
			object.scale = { x = object.scale.x, y = object.scale.y, z = object.scale.z }
		end
		if object.color_dir_forward then
			object.color_dir_forward = { r = object.color_dir_forward.r, g = object.color_dir_forward.g, b = object.color_dir_forward.b, a = object.color_dir_forward.a }
			object.color_dir_backward = { r = object.color_dir_backward.r, g = object.color_dir_backward.g, b = object.color_dir_backward.b, a = object.color_dir_backward.a }
			object.color_dir_up = { r = object.color_dir_up.r, g = object.color_dir_up.g, b = object.color_dir_up.b, a = object.color_dir_up.a }
			object.color_dir_down = { r = object.color_dir_down.r, g = object.color_dir_down.g, b = object.color_dir_down.b, a = object.color_dir_down.a }
			object.color_dir_left = { r = object.color_dir_left.r, g = object.color_dir_left.g, b = object.color_dir_left.b, a = object.color_dir_left.a }
			object.color_dir_right = { r = object.color_dir_right.r, g = object.color_dir_right.g, b = object.color_dir_right.b, a = object.color_dir_right.a }
		end
	end
	return object
end

local function LoadLightData(filename)
	local LoadData
	local file = io.open("lights/" .. filename .. ".json", "r")
	if file then
		LoadData = json.decode(file:read("*all"))
		file:close()
	else
		Shared.Message("Missing " .. filename .. " light data file.")
	end
	return LoadData
end

local function OnCommandLoadLights()
	if Client then
		local LoadData
		if NSLLights then
			local defaultfilename = string.gsub(Shared.GetMapName(), "_nsl", "")
			LoadData = LoadLightData(defaultfilename)
		else
			local nslfilename = "ns2_nsl_" .. string.gsub(string.gsub(Shared.GetMapName(), "ns2_", ""), "nsl_", "")
			LoadData = LoadLightData(nslfilename)
			/*if not LoadData then
				//Attempt to autogen NSL lights using intensity cutoff.
				local defaultfilename = string.gsub(Shared.GetMapName(), "_nsl", "")
				LoadTempData = LoadLightData(defaultfilename)
				if LoadTempData then
					local lightsremoved = 0
					local propsremoved = 0
					LoadData = { }
					for i, object in pairs(LoadTempData) do
						if object.className == "prop_static" then
							propsremoved = propsremoved + 1
						elseif object.values.intensity < kIntensityCutoff then
							lightsremoved = lightsremoved + 1
						else
							object.values.intensity = object.values.intensity + kIntensityIncrease
							object.values.distance = object.values.distance + kDistanceIncrease
							object.values.casts_shadows = false
							table.insert(LoadData, LoadTempData[i])
						end
					end
					Shared.Message(string.format("Lights adjusted, %s lights removed, %s props removed, %s objects remaining from %s.", lightsremoved, propsremoved, #LoadData, #LoadTempData))
				end
			end*/
		end
		if LoadData then
			ClearObjects()
			//Load valid, PURGE ALL THE LIGHTS
			for i, object in pairs(LoadData) do
				object.values = UpdateValuesForObject(object.values, true)
				LoadMapEntity(object.className, object.groupName, object.values)
			end
			lightLocationCache = { }
			//Re-init powernodes?
			local powerPoints = Shared.GetEntitiesWithClassname("PowerPoint")
			for index, powerPoint in ientitylist(powerPoints) do
				powerPoint.lightHandler = nil
			end
			NSLLights = not NSLLights
		end
	end
end

// Save original lights on map load
local function OnFirstUpdateClient()
	if not Loaded then
		NSLLights = (string.find(Shared.GetMapName(), "_nsl") ~= nil)
		Loaded = true
		if table.contains(NSLMaps, Shared.GetMapName()) then
			Shared.Message([[NSL Mod loaded which includes Mendasp's Spectator Lights mod. Type "sv_nsllights" in console to switch between normal and NSL lights.]])
			if Client.GetOptionBoolean("lowLights", false) ~= NSLLights then
				OnCommandLoadLights()
			end
		end
	end
end

Event.Hook("UpdateClient", OnFirstUpdateClient)

//Catch loading of lights, cache in table.  This will contain the NSL version of lights.
local originalLoadMapEntity = LoadMapEntity
function LoadMapEntity(className, groupName, values)
	local success = originalLoadMapEntity(className, groupName, values)
	//Testing Code :S
	//values = UpdateValuesForObject(values, false)
	//table.insert(DataCache, { className = className, groupName = groupName, values = values })
	//For doing map dumps.
	if success then
		if (className == "light_spot" or className == "light_point" or className == "light_ambient" or (className == "prop_static" and table.contains(BlockedProps, values.model))) and not Loaded then
			values = UpdateValuesForObject(values, false)
			table.insert(DataCache, { className = className, groupName = groupName, values = values })
		end
		if className == "prop_static" and table.contains(BlockedProps, values.model) then
			table.insert(PropCache, Client.propList[#Client.propList])
			table.remove(Client.propList, #Client.propList)
		end
	end
	return success
end

//Dont want to used cached lights if changed.
function GetLightsForLocation(locationName)

    if locationName == nil or locationName == "" then
        return {}
    end
    if lightLocationCache[locationName] then
        return lightLocationCache[locationName]   
    end
	
    local lightList = {}
    local locations = GetLocationEntitiesNamed(locationName)
    if table.count(locations) > 0 then
        for index, location in ipairs(locations) do
            for index, renderLight in ipairs(Client.lightList) do
                if renderLight then
                    local lightOrigin = renderLight:GetCoords().origin
                    if location:GetIsPointInside(lightOrigin) then
                        table.insert(lightList, renderLight)
                    end
                end
            end
        end
    end
	
    // Log("Total lights %s, lights in %s = %s", #Client.lightList, locationName, #lightList)
    lightLocationCache[locationName] = lightList
    return lightList
   
end

// Loading and saving lights
local function OnCommandSaveLights()
	if Client and Shared.GetCheatsEnabled() then
		local filename = Shared.GetMapName()
        local lightsFile = io.open("config://" .. filename .. ".json", "w+")
		lightsFile:write("[")
		for i, object in ipairs(DataCache) do
			lightsFile:write(json.encode(object))
			if i < #DataCache then
				lightsFile:write(",\n")
			end
		end
		lightsFile:write("]")
		io.close(lightsFile)
		Shared.Message("Saved lights to " .. filename .. ".json")
	end
end

function OnCommandLowLights()
	if Client and table.contains(NSLMaps, Shared.GetMapName()) then
		OnCommandLoadLights()
		Client.SetOptionBoolean("lowLights", NSLLights)
		Shared.Message("NSL lights mode " .. ConditionalValue(NSLLights, "enabled", "disabled") .. ".  " .. ConditionalValue(NSLLights, "NSL", "Original") .. " lighting loaded.")
	end
end

Event.Hook("Console_savelights", OnCommandSaveLights)
Event.Hook("Console_sv_nsllights", OnCommandLowLights)