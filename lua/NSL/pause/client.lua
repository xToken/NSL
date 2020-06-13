-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/pause/client.lua
-- - Dragon

-- Materials that reference time dont call back into lua, which causes issues.
-- This sucks, but should hopefully fix those issues.
-- This might be the most epic hack in all of ns2 :<
local tablebuilt = false
local TimeBypassFunctions = { }
table.insert(TimeBypassFunctions, {name = "Alien", func = "UpdateClientEffects", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "BiteLeap", func = "CreateBloodEffect", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "LerkBite", func = "CreateBloodEffect", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "DetectableMixin", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "ClientWeaponEffectsMixin", func = "UpdateAttackEffects", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "UmbraMixin", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "CloakableMixin", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "Fade", func = "OnUpdateRender", oldFunc = nil })
table.insert(TimeBypassFunctions, {name = "ExoWeaponHolder", func = "OnUpdateRender", oldFunc = nil })

local function BuildTableEntry(tableEntry)
	tableEntry.oldFunc = Class_ReplaceMethod(tableEntry.name, tableEntry.func, 
		function(...)
			gTimeBypass = true
			tableEntry.oldFunc(...)
			gTimeBypass = false
		end
	)
end

local function BuildTimeBypassTable()
	for i, classarray in pairs(TimeBypassFunctions) do
		BuildTableEntry(classarray)
	end
	tablebuilt = true
end

function AddClassFunctionToTimeBypassTable(className, methodName)
	local cTable =  {name = className, func = methodName, oldFunc = nil }
	table.insert(TimeBypassFunctions, cTable)
	if tablebuilt then
		BuildTableEntry(cTable)
	end
end

local function OnLoadComplete()
	BuildTimeBypassTable()
end

Event.Hook("LoadComplete", OnLoadComplete)

-- Allow chats to still work during pauses
local startedChatTime = 0
local kChatMinWindow = 0.005

function ChatUI_GetStartedChatTime()
    return startedChatTime
end

local oldChatUI_EnterChatMessage = ChatUI_EnterChatMessage
function ChatUI_EnterChatMessage(teamOnly)
	local wasEnteringChat = ChatUI_EnteringChatMessage()
	oldChatUI_EnterChatMessage(teamOnly)
	if not wasEnteringChat and ChatUI_EnteringChatMessage() then
		startedChatTime = Client.GetTime()
	end
end

local function ChatUICreation(scriptName, script)

	if scriptName == "GUIChat" then

		function GUIChat:SendCharacterEvent(character)
			local enteringChatMessage = ChatUI_EnteringChatMessage()
			
			if (Client.GetTime() - ChatUI_GetStartedChatTime()) > kChatMinWindow and enteringChatMessage then
			
				local currentText = self.inputItem:GetWideText()
				if currentText:length() < kMaxChatLength then
				
					self.inputItem:SetWideText(currentText .. character)
					return true
					
				end
				
			end
			
			return false
		end
	
	end
	
end

ClientUI.AddScriptCreationEventListener(ChatUICreation)

-- List of GUI scripts that still update normally during pauses
local kPausedUpdateScripts = { "GUIScoreboard", "GUIChat", "GUIMinimapFrame", "GUIInsight_PlayerFrames", "GUITechMap", "GUIInsight_Overhead", "GUIMainMenu",
								"GUIInsight_PenTool", "GUIInsight_PlayerHealthbars", "GUIInsight_Graphs", "GUINSLSpectatorTechMap", "GUINSLFollowingSpectatorHUD",
								"GUIEggDisplay" }
local kPausedScoreboardUpdateRate = 0.5
local scoreboardUpdate = 0.5

function AddGUIScriptToPausedUpdates(GUIClassName)
    table.insert(kPausedUpdateScripts, GUIClassName)
end

local originalGUIManagerUpdate
originalGUIManagerUpdate = Class_ReplaceMethod("GUIManager", "Update", 
	function(self, deltaTime)
		local player = Client.GetLocalPlayer()
		if player and player.gamepaused then
			if Shared.GetBuildNumber() >= 328 then
				local numScripts = self.scripts:GetCount()
				for s = numScripts, 1, -1 do
					local script = self.scripts:GetValueAtIndex(s)
					if script and table.contains(kPausedUpdateScripts, script.classname) then
						script.lastUpdateTime = script.lastUpdateTime - deltaTime
						script.nextUpdateTime = script.nextUpdateTime - deltaTime
					end
				end
			else
				for s = #self.scripts, 1, -1 do
					local script = self.scripts[s]
					if script and table.contains(kPausedUpdateScripts, script.classname) then
						script.lastUpdateTime = script.lastUpdateTime - deltaTime
					end
				end
			end
			scoreboardUpdate = math.max(0, scoreboardUpdate - deltaTime)
			if scoreboardUpdate == 0 then
				Scoreboard_ReloadPlayerData()
				scoreboardUpdate = kPausedScoreboardUpdateRate
			end
		end
		originalGUIManagerUpdate(self, deltaTime)
	end
)

local BaseGUIManagerHook
local HookTable = debug.getregistry()["Event.HookTable"]
if HookTable then
	for i, e in ipairs(HookTable["UpdateClient"]) do
		if string.find(ToString(e), "lua/GUI/BaseGUIManager.lua") then
			BaseGUIManagerHook = e
			table.remove(HookTable["UpdateClient"], i)
		end
	end
end

if BaseGUIManagerHook and type(BaseGUIManagerHook) == "function" then
	--Print("Sucessfully hooked new GUI system!")
	Event.Hook("UpdateClient", function(deltaTime)
		gTimeBypass = true
		BaseGUIManagerHook(deltaTime)
		gTimeBypass = false
	end, "BaseGUIManager")
end