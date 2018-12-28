-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/consistencychecks/client.lua
-- - Dragon

--NSL Client File Hooks
local runDetectionAt = math.random() * 10
local C = { }
local recursiveLimit = 3
local sleepDetections = 0
local funcNameMin = 2

--Waaaay to much is whitelisted here, really this would only pick up lazy hooks at this point, value probably doesnt justify the complexity.
local excludeFuncs = { 	"SendKeyEvent", "UpdateGhostGuides", "OnInitLocalClient", "GetGameStarted", "GetIsPlaying", "kMinTimeBeforeConcede", "PlayerUI_GetWeaponLevel",
						"gCHUDHiddenViewModel", "PlayerUI_GetCanDisplayRequestMenu", "kWorldDamageNumberAnimationSpeed", "ChatUI_EnterChatMessage", "PlayerUI_GetPlayerResources",
						"PlayerUI_GetArmorLevel", "CommanderUI_Logout", "upgradeLevelThree" , "upgradeLevelTwo", "nearestLocationName", "gPreviousPausedTime", "sortById",
						"position", "SetItemInvisible", "gTimePositionChanged", "techId", "screenPos", "CHUDStatsVisible", "iconCoordinates", "css", "gArmoryHealthHeight",
						"useColorCHUD", "gCurrentHostStructureId", "direction", "attachEntity", "intensity", "start", "player", "veloctiy", "kRowSize", "kRowPlayerNameOffset",
						"kTableContainerOffset", "kCommanderMessageVerticalOffset", "color", "defaultValue", "oldValue", "animStartTime"
						}
local excludeClassFuncs = { 
						"Commander:UpdateMisc", "Commander:OnDestroy", "ExoWeaponHolder:OnUpdateRender", "PlayerMapBlip:GetMapBlipColor", "ActiveControls:NumMembers",
						"Locale:ResolveString", "AlienCommander:UpdateMisc", "AlienCommander:OnDestroy", "MapBlip:GetMapBlipColor", "ClientUI:EvaluateUIVisibility",
						"MarineCommander:UpdateMisc", "MarineCommander:OnDestroy", "HiveVisionExtra_screenEffect", "screenEffects:darkVision", "HiveVision_screenEffect",
						"Script:Load", "ActiveControls:Position", "AlienTeamInfo:OnUpdate", "CystGhostModel:Update", "addedBlip:Time", "addedBlip:Item", "kWorkerIcon:Width", "kWorkerIcon:Height", 
						"kEggsIcon:Width", "kEggsIcon:Height", "kResourceTowerIcon:Width", "kResourceTowerIcon:Height", "kPersonalResourceIcon:Width", "kPersonalResourceIcon:Height",
						"kTeamResourceIcon:Width", "kTeamResourceIcon:Height", "Player:kShowGiveDamageTime", "startDetails:Position", "startDetails:InfoColor", "startDetails:IconSize",
						"startDetails:ShadowColor", "startDetails:IconColor", "startDetails:InfoScale", "Fade:OnUpdateRender", "Gorge:UpdateClientEffects", "LerkBite:CreateBloodEffect",
						"Lerk:UpdateClientEffects", "BiteLeap:CreateBloodEffect", "ClientWeaponEffectsMixin:UpdateAttackEffects", "Skulk:UpdateClientEffects", "XenocideLeap:CreateBloodEffect",
						"Embryo:UpdateClientEffects", "Alien:UpdateClientEffects", "UmbraMixin:OnUpdateRender", "DetectableMixin:OnUpdateRender", "CloakableMixin:OnUpdateRender",
						"option:sort", "option:currentValue", "option:tooltip", "option:label", "option:inputClass", "option:valueType", "option:name", "option:defaultValue",
						"GUI:MouseObjects", "HelpScreen:Display", "HelpScreen:Hide", "Shine:AddStartupMessage"
					 }
local excludeClasses = { 
						"GUIMainMenu", "GUIScoreboard", "GUIGameEnd", "GUIChat", "GUIDeathMessages", "GUIExoHUD", "GUIHoverTooltip", "GUIMarineBuyMenu",
						"GUICommanderAlerts", "GUIAlienBuyMenu", "GUIPickups", "GUIInventory", "GUIProgressBar", "GUIWaypoints", "GUIMinimapFrame",
						"GUIAlienSpectatorHUD", "GUIWorldText", "GUIWaitingForAutoTeamBalance", "GUINotifications", "GUIRequestMenu", "GUIFeedback",
						"GUISpectator", "GUIEvent", "GUIMarineHUD", "GUIMarineTeamMessage", "GUIMinimapConnection", "GUIMinimap", "GUICrosshair",
						"GUIProduction", "GUISensorBlips", "GUIUnitStatus", "GUIAlienHUD", "GUIJetpackFuel", "GUIAlienTeamMessage"
						}
local excludeHooks = { "NotifyGUIItemDestroyed", "InventoryUpdated", "SteamPersonaChanged", "PhysicsTrigger", "ClientConnect", "DebugState", "ClientConnected", 
						"ResolutionChanged", "WebViewCall", "PhysicsCollision", "ClientDisconnected", "DisplayChanged", "ClientDisconnect", "ErrorCallback",
						"ConnectRequested", "SoundDeviceListChanged", "OptionsChanged", "InventoryNewItem", "OnLobbyMessage", "OnLobbyCreated", "OnLobbyClientEnter",
						"MapLoadEntity", "LocalPlayerChanged", "OnLobbyListResults", "MapPostLoad", "MapPreLoad", "UpdateServer"
					}
local modString
local rTable = { }
	
local function CopyGTable(G, t, R)
	for k, v in pairs(G) do
		if not t[k] then
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

local function UpdateFuncString(s, new, h)
	if not new or string.len(new) <= funcNameMin then return s end
	if h and h ~= "_G" then new = h .. ":" .. new end
	if table.contains(rTable, new) then return s end
	if not s then
		s = new
	else
		s = s .. ";" .. new
	end
	return s
end

local function split(str, pat)
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
	--This sleeps additional detection intervals because iterating the entire global table probably isn't super speedy.... Even though it doesn't actually go through the ENTIRE table
	if sleepDetections > 0 then
		sleepDetections = sleepDetections - 1
		return
	end
	for k, v in pairs(G) do
		if type(v) == "table" then
			if R <= recursiveLimit and t[k] and not table.contains(excludeClasses, k) then
				CheckGlobalFunctionTable(v, t[k], R + 1, k)
			end
		else
			--S comes from recursive calls to this function with the previous key.  This allows me to track functions of classes (S is the class)
			if S then
				if t[k] and t[k] ~= v and not table.contains(excludeClassFuncs, S .. ":" .. k) and not table.contains(excludeFuncs, k) then
					modString = UpdateFuncString(modString, k, S)
				end
			else
				if t[k] and t[k] ~= v and not table.contains(excludeClassFuncs, k) and not table.contains(excludeFuncs, k) then
					modString = UpdateFuncString(modString, k, S)
				end
			end
		end
	end
	if R > 1 then
		return
	end
	local HookTable = debug.getregistry()["Event.HookTable"]
	if HookTable then
		for k, v in pairs(HookTable) do
			if type(v) == "table" and not table.contains(excludeHooks, k) and string.sub(k, 1, 8) ~= "Console_" then
				modString = UpdateFuncString(modString, "Hooks(" .. tostring(#v) .. ")", k)
			end
		end
	end
	if modString then
		for k, v in ipairs(split(modString, ";")) do
			if not table.contains(rTable, r) then
				local s = split(v, ":")
				--Only split out numeric things.  Otherwise its a func/class func and we are just tracking its existence as being modified/latehooked.
				if #s == 2 and tonumber(s[2]) then
					Client.SendNetworkMessage("ClientFunctionReport", {detectionType = s[1], detectionValue = s[2]}, true)
				else
					Client.SendNetworkMessage("ClientFunctionReport", {detectionType = v, detectionValue = ""}, true)
				end
				table.insert(rTable, v)
			end
		end
		modString = nil
	end
	sleepDetections = 10
end

local function UpdateNSLMonitoredFields()
end

local oldScriptLoad = Script.Load
local l
function Script.Load(fileName, reload)
	if not l then l = string.lower(fileName) end
	if string.find(fileName, "PostLoadMod.lua") then
		--Stuff
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
		CheckGlobalFunctionTable(_G, C, 1)
		UpdateNSLMonitoredFields()
		runDetectionAt = math.random() * 10 + 30
	end

end

Event.Hook("UpdateClient", OnUpdateClientTimers)