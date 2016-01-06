// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_filehooks_client.lua
// - Dragon

//NSL Client File Hooks
local runDetectionAt = math.random() * 10
local function GetUpValue(origfunc, name)

	local index = 1
	local foundValue = nil
	while true do
	
		local n, v = debug.getupvalue(origfunc, index)
		if not n then
			break
		end
		
		if n == name then
			foundValue = v
		end
		
		index = index + 1
		
	end
	
	return foundValue
	
end

local origGetMaxDistanceFor
local actualHVMValue = 63

local function CheckHiveVisionMixin()
	origGetMaxDistanceFor = GetUpValue(HiveVisionMixin.OnUpdate, "GetMaxDistanceFor")
	local player = Client.GetLocalPlayer()
	if player and origGetMaxDistanceFor then
		if origGetMaxDistanceFor(player) > actualHVMValue then
			//Report to server
			Client.SendNetworkMessage("ClientFunctionReport", {detectionType = "HiveVision"}, true)
		end
	end
end

local C = { }
local gBuilt = false
local recursiveLimit = 3
local sleepDetections = 0
local excludeFuncs = { 
						"Commander:UpdateMisc", "Commander:UpdateGhostGuides", "Commander:OnDestroy", "Commander:OnInitLocalClient", "ExoWeaponHolder:OnUpdateRender",
						"PlayerMapBlip:GetMapBlipColor", "gCHUDHiddenViewModel", "Locale:ResolveString", "PlayerUI_GetCanDisplayRequestMenu", "AlienCommander:UpdateMisc",
						"AlienCommander:UpdateGhostGuides", "AlienCommander:OnInitLocalClient", "AlienCommander:OnDestroy", "MapBlip:GetMapBlipColor", 
						"MarineCommander:UpdateMisc", "MarineCommander:UpdateGhostGuides", "MarineCommander:OnDestroy", "MarineCommander:OnInitLocalClient"
					 }
local excludeClasses = { 
						"GUIMainMenu", "GUIScoreboard", "GUIGameEnd", "GUIChat", "GUIDeathMessages", "GUIExoHUD", "GUIHoverTooltip", "GUIMarineBuyMenu",
						"GUICommanderAlerts", "GUIAlienBuyMenu", "GUIPickups", "GUIInventory", "GUIProgressBar", "GUIWaypoints", "GUIMinimapFrame",
						"GUIAlienSpectatorHUD", "GUIWorldText", "GUIWaitingForAutoTeamBalance", "GUINotifications", "GUIRequestMenu", "GUIFeedback",
						"GUISpectator", "GUIEvent", "GUIMarineHUD", "GUIMarineTeamMessage", "GUIMinimapConnection", "GUIMinimap", "GUICrosshair",
						"GUIProduction", "GUISensorBlips", "GUIUnitStatus", "GUIAlienHUD", "GUIJetpackFuel", "GUIAlienTeamMessage"
						}
local modString
	
local function CopyGTable(G, t, R)
	for k, v in pairs(G) do
		if k ~= "_G" and not t[k] then
			if type(v) == "table" then
				if R <= recursiveLimit then
					if not t[k] then
						t[k] = { }
					end
					CopyGTable(v, t[k], R + 1)
				end
			else
				t[k] = v
			end
		end
	end
end

local function UpdateMainCopyWithDiffs(G, q, t, R)
	for k, v in pairs(G) do
		if k ~= "_G" then
			if type(v) == "table" then
				if R <= recursiveLimit then
					if not t[k] then
						t[k] = { }
					end
					UpdateMainCopyWithDiffs(v, q and q[k] or nil, t[k], R + 1)
				end
			else
				if not q or not q[k] or q[k] ~= v then
					t[k] = v
				end
			end
		end
	end
end

local function UpdateFuncString(s, new, h)
	if not new then return s end
	if h then new = h .. ":" .. new end
	if not s then
		s = new
	else
		s = s .. ";" .. new
	end
	return s
end

function split(str, pat)
   local t = {}
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

local function CheckGlobalFunctionTable(G, t, R, S)
	if sleepDetections > 0 then
		sleepDetections = sleepDetections - 1
		return
	end
	for k, v in pairs(G) do
		if k ~= "_G" then
			if type(v) == "table" then
				if R <= recursiveLimit and t[k] and not table.contains(excludeClasses, k) then
					CheckGlobalFunctionTable(v, t[k], R + 1, k)
				end
			else
				if S then
					if t[k] and t[k] ~= v and not table.contains(excludeFuncs, S .. ":" .. k) then
						modString = UpdateFuncString(modString, k, S)
					end
				else
					if t[k] and t[k] ~= v and not table.contains(excludeFuncs, k) then
						modString = UpdateFuncString(modString, k, S)
					end
				end
			end
		end
	end
	if R > 1 then
		return
	end
	if modString then
		for k, v in ipairs(split(modString, ";")) do
		  Client.SendNetworkMessage("ClientFunctionReport", {detectionType = v}, true)
		end
		modString = nil
	end
	sleepDetections = 10
end

local oldScriptLoad = Script.Load
local l
function Script.Load(fileName, reload)
	if not l then l = string.lower(fileName) end
	if string.find(fileName, "PostLoadMod.lua") then
		//Stuff
		local Q = { }
		CopyGTable(_G, Q, 1)
		oldScriptLoad(fileName, reload)
		UpdateMainCopyWithDiffs(_G, Q, C, 1)
	else
		oldScriptLoad(fileName, reload)
	end
	fileName = string.lower(fileName)
	if l == fileName then
		CopyGTable(_G, C, 1)
		l = nil
	end
end

local function OnUpdateClientTimers(deltaTime)

	PROFILE("OnUpdateClientTimers")
	
	runDetectionAt = math.max(runDetectionAt - deltaTime, 0)
	if runDetectionAt == 0 then
		//First detection
		CheckHiveVisionMixin()
		CheckGlobalFunctionTable(_G, C, 1)
		runDetectionAt = math.random() * 10 + 30
	end

end

Event.Hook("UpdateClient", OnUpdateClientTimers)