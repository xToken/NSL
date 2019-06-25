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

local oldChatUI_EnterChatMessage = ChatUI_EnterChatMessage
function ChatUI_EnterChatMessage(teamOnly)
	gTimeBypass = true
	oldChatUI_EnterChatMessage(teamOnly)
	gTimeBypass = false
end

local function ChatUICreation(scriptName, script)

	if scriptName == "GUIChat" then

		local originalGUIChatSendCharacterEvent
		originalGUIChatSendCharacterEvent = Class_ReplaceMethod("GUIChat", "SendCharacterEvent", 
			function(self, character)
				gTimeBypass = true
				originalGUIChatSendCharacterEvent(self, character)
				gTimeBypass = false
			end
		)
	
	end
	
end

ClientUI.AddScriptCreationEventListener(ChatUICreation)

local originalGUIManagerUpdate
originalGUIManagerUpdate = Class_ReplaceMethod("GUIManager", "Update", 
	function(self, deltaTime)
		gTimeBypass = true
		originalGUIManagerUpdate(self, deltaTime)
		gTimeBypass = false
	end
)