// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_filehooks_client.lua
// - Dragon

//NSL Client File Hooks
local runDetectionAt = math.random() * 10
local C = { }
local recursiveLimit = 3
local sleepDetections = 0
local funcNameMin = 2

//Waaaay to much is whitelisted here, really this would only pick up lazy hooks at this point, value probably doesnt justify the complexity.
local excludeFuncs = { 	"SendKeyEvent", "UpdateGhostGuides", "OnInitLocalClient", "GetGameStarted", "GetIsPlaying", "kMinTimeBeforeConcede", "PlayerUI_GetWeaponLevel",
						"gCHUDHiddenViewModel", "PlayerUI_GetCanDisplayRequestMenu", "kWorldDamageNumberAnimationSpeed", "ChatUI_EnterChatMessage", "PlayerUI_GetPlayerResources",
						"PlayerUI_GetArmorLevel", "CommanderUI_Logout", "upgradeLevelThree" , "upgradeLevelTwo", "nearestLocationName", "gPreviousPausedTime", "sortById",
						"position", "SetItemInvisible", "gTimePositionChanged", "techId", "screenPos", "CHUDStatsVisible", "iconCoordinates", "css", "gArmoryHealthHeight",
						"useColorCHUD", "gCurrentHostStructureId", "direction", "attachEntity", "intensity", "start", "player", "velocity", "kRowSize", "kRowPlayerNameOffset",
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
						"GUI:MouseObjects"
					 }
local excludeClasses = { 
						"GUIMainMenu", "GUIScoreboard", "GUIGameEnd", "GUIChat", "GUIDeathMessages", "GUIExoHUD", "GUIHoverTooltip", "GUIMarineBuyMenu",
						"GUICommanderAlerts", "GUIAlienBuyMenu", "GUIPickups", "GUIInventory", "GUIProgressBar", "GUIWaypoints", "GUIMinimapFrame",
						"GUIAlienSpectatorHUD", "GUIWorldText", "GUIWaitingForAutoTeamBalance", "GUINotifications", "GUIRequestMenu", "GUIFeedback",
						"GUISpectator", "GUIEvent", "GUIMarineHUD", "GUIMarineTeamMessage", "GUIMinimapConnection", "GUIMinimap", "GUICrosshair",
						"GUIProduction", "GUISensorBlips", "GUIUnitStatus", "GUIAlienHUD", "GUIJetpackFuel", "GUIAlienTeamMessage"
						}
local excludeHooks = { "Console_debugcommander", "Console_cents", "Console_jm", "Console_team1", "Console_r_aa", "Console_print_bindings", "Console_hud_rate", 
						"Console_resetcommandertutorial", "Console_debugcyst", "Console_setvoicevolume", "Console_unfairadvantage", "Console_animinputs", 
						"Console_sh_alltalklocal_cl", "Console_guiinfo", "Console_drawdecal", "Console_propnames", "Console_r_glass", "Console_sh_animateui", "Console_ma",
						"Console_distance", "Console_bind", "Console_sv_nslhandicap", "Console_score1", "Console_ironhorsemode", "Console_mantis_s3", "Console_sh_clientconfigmenu",
						"Console_unl", "Console_alienvision", "Console_score2", "Console_iamthelaw", "Console_pen", "Console_filmsmoothing", "Console_name", "Console_debugnotifications",
						"Console_sh_disableweb", "Console_reset_help", "Console_sh_chatbox", "Console_r_animation", "Console_perfmon", "Console_setvv", "Console_dbg_value", 
						"Console_r_ao", "Console_say", "Console_mca", "Console_print_client_ui", "Console_sh_errorreport", "Console_mcg", "Console_reject", "Console_setmusicvolume",
						"Console_soundgeometry", "Console_chuckle", "Console_ssv", "Console_hivevision", "Console_mcr", "Console_print_client_resources", "Console_setmaplocationcolor",
						"Console_r_mode", "Console_swalkmode", "Console_savelights", "Console_connect", "Console_cjit", "Console_oneffectdebug", "Console_sh_loadplugin_cl", 
						"Console_r_shadows", "Console_locate", "Console_r_fog", "Console_team_say", "Console_iamgolden", "Console_scaremode", "Console_mantis_accept", "Console_chatwrapamount",
						"Console_mct", "Console_chattime", "Console_minimapnames", "Console_slot6", "Console_tracereticle", "Console_allbadges", "Console_dumpguiscripts", "Console_resettipvids",
						"Console_requestweld", "Console_badge", "Console_ironmode", "Console_badges", "Console_perfdbg", "Console_unbind", "Console_goldenmode", "Console_swalkmode_cameraspeed",
						"Console_swalkmode_vmspeed", "Console_trollrate", "Console_selecthallucinations", "Console_plus_export", "Console_setplusversion", "Console_r_poseparams", "Console_swapres",
						"Console_mariomode", "Console_cfindref", "Console_changegcsettingclient", "Console_trollmode", "Console_random_debug", "Console_setsensitivity", "Console_accept",
						"Console_displayannotations", "Console_outline", "Console_clear_binding", "Console_teams", "Console_sleeping", "Console_mynameisgolden", "Console_r_pq", "Console_annotate",
						"Console_scores", "Console_mantis_login", "Console_reconnect", "Console_r_gamma", "Console_hitreg_always", "Console_removeoption", "Console_iamsquad5", "Console_sethudmap",
						"Console_johnmadden", "Console_sh_viewwebinsteam", "Console_debuggui", "Console_changeminizoom", "Console_lerk_view_tilt", "Console_locateorigin", "Console_debugspeed",
						"Console_testsentry", "Console_playmusic", "Console_cleardebuglines", "Console_music", "Console_sh_votemenu", "Console_plus", "Console_location", "Console_retry",
						"Console_mapinfo", "Console_showviewangles", "Console_team2", "Console_r_bloom", "Console_map", "Console_r_atmospherics", "Console_minimap_rate", "Console_hitreg",
						"Console_sh_unloadplugin_cl", "Console_mantis_reject", "Console_sysdev", "Console_pathingfill", "Console_r_healthrings", "Console_debugtext", "Console_setsoundvolume",
						"NotifyGUIItemDestroyed", "MapPostLoad", "ProcessGameInput", "MapPreLoad", "PhysicsTrigger", "ClientConnect", "DebugState", "UpdateServer", "ClientConnected", 
						"ResolutionChanged", "WebViewCall", "PhysicsCollision", "LoadComplete", "ClientDisconnected", "DisplayChanged", "MapLoadEntity", "ClientDisconnect", 
						"ConnectRequested", "SoundDeviceListChanged", "LocalPlayerChanged", "OptionsChanged"
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
			if type(v) == "table" and not table.contains(excludeHooks, k) then
				modString = UpdateFuncString(modString, "Hooks(" .. tostring(#v) .. ")", k)
			end
		end
	end
	if modString then
		for k, v in ipairs(split(modString, ";")) do
			if not table.contains(rTable, r) then
				Client.SendNetworkMessage("ClientFunctionReport", {detectionType = v}, true)
				table.insert(rTable, v)
			end
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

local function HTTPResponseRecieved(data)
	Print(ToString(data))
end

local kTextureUploadURL
//Sadly this costs me about 80fps, probably not viable at this time.
local function TakeTextureRenderCameraSnapshot()
	
    local player = Client.GetLocalPlayer()
    if player then
		local cullingMode = RenderCamera.CullingMode_Occlusion
		local rCamera = Client.CreateRenderCamera()
		rCamera:SetRenderSetup("renderer/Deferred.render_setup")
		rCamera:SetNearPlane(0.03)		
		local adjustValue = Clamp( Client.GetOptionFloat("graphics/display/fov-adjustment",0), 0, 1 )
		local adjustRadians = math.rad((1 - adjustValue) * kMinFOVAdjustmentDegrees + adjustValue * kMaxFOVAdjustmentDegrees)
		if player:isa("Commander") or player:isa("Spectator") then
			adjustRadians = 0
		end
		if player:GetIsOverhead() or player:GetCameraFarPlane() then
			cullingMode = RenderCamera.CullingMode_Frustum
		else
			farPlane = 1000.0
		end
		rCamera:SetCoords(player:GetCameraViewCoords())
        rCamera:SetFov(GetScreenAdjustedFov( player:GetRenderFov() + adjustRadians, 4 / 3 ))
        rCamera:SetFarPlane(farPlane)
        rCamera:SetCullingMode(cullingMode)
		rCamera:SetTargetTexture("asdf", true, Client.GetScreenWidth() , Client.GetScreenHeight())
		//Shared.SendHTTPRequest(kTextureUploadURL, "POST", { GetMaterialParameter("asdf") }, HTTPResponseRecieved)
		Client.DestroyRenderCamera(rCamera)
		rCamera = nil
	end
end

local function OnUpdateClientTimers(deltaTime)

	PROFILE("OnUpdateClientTimers")
	
	runDetectionAt = math.max(runDetectionAt - deltaTime, 0)
	if runDetectionAt == 0 then
		CheckGlobalFunctionTable(_G, C, 1)
		//TakeTextureRenderCameraSnapshot()
		runDetectionAt = math.random() * 10 + 30
	end

end

Event.Hook("UpdateClient", OnUpdateClientTimers)

local function OnNSLFunctionDataReceived(message)
	if message and message.functionName then
		if _G[message.functionName] and message.newValue then
			_G[message.functionName] = ConditionalValue(tonumber(message.newValue), tonumber(message.newValue), message.newValue)
		end
	end
end

local function OnLoadComplete()
	Client.HookNetworkMessage("ClientFunctionUpdate", OnNSLFunctionDataReceived)
end

Event.Hook("LoadComplete", OnLoadComplete)