-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/nsl_client.lua
-- - Dragon

-- Load shared defs
Script.Load("lua/NSL/nsl_shared.lua")

-- Load client defs
Script.Load("lua/NSL/eventhooks/client.lua")
Script.Load("lua/NSL/heartbeat/client.lua")
Script.Load("lua/NSL/pause/client.lua")
Script.Load("lua/NSL/spectator_techtree/client.lua")
Script.Load("lua/NSL/teammanager/client.lua")

local kNSLChatSoundWarning = PrecacheAsset("sound/NS2.fev/common/invalid")

-- Load custom GUI scripts if needed
AddClientUIScriptForClass("Spectator", "NSL/GUI/GUINSLFollowingSpectatorHUD")
AddClientUIScriptForTeam(kSpectatorIndex, "NSL/GUI/GUINSLSpectatorTechMap")

--if I name this chatMessages, it matches vanilla.  Anything that then joins upvalues to the chatMessages in vanilla wont get broken by my hook.
local chatMessages = { }
local kNSLDefaultMessageColor = Color(1, 1, 1, 1)
local kNSLMessageHexColor = 0x800080

local oldChatUI_GetMessages = ChatUI_GetMessages
function ChatUI_GetMessages()
	local cM = oldChatUI_GetMessages()
	if table.maxn(chatMessages) > 0 then
        table.copy(chatMessages, cM, true)
        chatMessages = { }
    end
	return cM
end

local function AdminMessageRecieved(message)
	local player = Client.GetLocalPlayer()    
	if message and player then
	
        table.insert(chatMessages, HexStringToNumber(message.color))
        table.insert(chatMessages, message.header)
		table.insert(chatMessages, kNSLDefaultMessageColor)
        table.insert(chatMessages, message.message)
		
		--No idea what this crap is for...
        table.insert(chatMessages, false)
        table.insert(chatMessages, false)
        table.insert(chatMessages, 0)
        table.insert(chatMessages, 0)

        if message.changesound then 
            StartSoundEffect(kNSLChatSoundWarning)
        else
            StartSoundEffect(player:GetChatSound())
        end
		Shared.Message(message.header .. " " .. message.message)
        
	end
end

Client.HookNetworkMessage("NSLSystemMessage", AdminMessageRecieved)