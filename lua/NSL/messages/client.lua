-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/messages/client.lua
-- - Dragon

Script.Load("lua/dkjson.lua")

local kNSLChatSoundWarning = PrecacheAsset("sound/NS2.fev/common/invalid")
local kNSLLanguageIDLookup = { }
local kNSLStringReference = { }
local configFileName = "NSLClientConfig.json"
local kNSLOpponentChatMute = false

local function SaveNSLClientConfig()
    SaveConfigFile(configFileName, { opponentChatMute = kNSLOpponentChatMute })
end

local function LoadNSLClientConfig()
    local defaultConfig = { opponentChatMute = false }
    WriteDefaultConfigFile(configFileName, defaultConfig)
    local config = LoadConfigFile(configFileName) or defaultConfig
    kNSLOpponentChatMute = config.opponentChatMute or false
end

LoadNSLClientConfig()

local function BuildNSLLanguageTable()

    local fileName = "lang/enUS.json"
    local openedFile = GetFileExists(fileName) and io.open(fileName, "r")
    --Shared.Message("NSL - Loading enUS Language")
    kNSLStringReference["enUS"] = { }
    if openedFile then
        local parsedFile, _, errStr = json.decode(openedFile:read("*all"))
        io.close(openedFile)
        for k, v in pairs(parsedFile) do
            text = v["text"]
            idx = v["id"]
            kNSLLanguageIDLookup[idx] = k
            kNSLStringReference["enUS"][k] = text
        end
    end

	-- local langFiles = { }

    -- Shared.GetMatchingFileNames("lang/*.json", false, langFiles )

    -- table.removevalue(langFiles, "lang/enUS.json")

    -- if #langFiles > 0 then
    --     for i = 1, #langFiles do
    --         local fileName = langFiles[i]
    --         local localeName = string.gsub(string.gsub(fileName, "lang/", ""), ".json", "")
    --         --Shared.Message(string.format("NSL - Loading %s Language", localeName))
    --         local openedFile = GetFileExists(fileName) and io.open(fileName, "r")
    --         if openedFile then
    --             local parsedFile, _, errStr = json.decode(openedFile:read("*all"))
    --             io.close(openedFile)
    --             kNSLStringReference[localeName] = parsedFile
    --         end
            
    --     end
    -- end
    
end

BuildNSLLanguageTable()

local function FormatAndReturnNSLMessageByID(msgId, mp1, mp2, mp3)
    return string.format(ReturnNSLMessageByID(msgId), mp1, mp2, mp3)
end

function ReturnNSLMessageByID(msgId)
    -- determine users locale
    local msgName = kNSLLanguageIDLookup[msgId]
    -- do we have translations for this message?
    return ReturnNSLMessage(msgName)
end

function ReturnNSLMessage(msgName)
    -- determine users locale
    local locale = Client.GetOptionString( "locale", "enUS" )
    -- do we have translations for this message?
    if kNSLStringReference[locale] and kNSLStringReference[locale][msgName] then
        return kNSLStringReference[locale][msgName]
    else
        return kNSLStringReference["enUS"][msgName]
    end
end

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

local function SystemMessageRecieved(message)
    local player = Client.GetLocalPlayer()
    local gameInfo = GetGameInfoEntity()
    if message and player and gameInfo then
    
        local msg = FormatAndReturnNSLMessageByID(message.messageid, message.messageparam1, message.messageparam2, message.messageparam3)
        local header
        if message.header == 2 then
            -- Player name
            header = string.format("(%s)(%s):", gameInfo:GetLeagueName(), player:GetName())
        elseif message.header == 1 then
            -- Team name
            header = string.format("(%s)(%s):", gameInfo:GetLeagueName(), player:GetTeamNumber() == 1 and gameInfo:GetTeam1Name() or gameInfo:GetTeam2Name())
        else
            header = string.format("(%s):", gameInfo:GetLeagueName())
        end
        table.insert(chatMessages, HexStringToNumber(message.color))
        table.insert(chatMessages, header)
        table.insert(chatMessages, kNSLDefaultMessageColor)
        table.insert(chatMessages, msg)
        
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
        Shared.Message(header .. " " .. msg)
        
    end
end

Client.HookNetworkMessage("NSLSystemMessage", SystemMessageRecieved)

local function OnNSLServerAdminPrint(message)
    Shared.Message(FormatAndReturnNSLMessageByID(message.messageid, message.messageparam1, message.messageparam2, message.messageparam3))
end
Client.HookNetworkMessage("NSLServerAdminPrint", OnNSLServerAdminPrint)

local function AdminChatMessageRecieved(message)
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

        StartSoundEffect(player:GetChatSound())
        Shared.Message(message.header .. " " .. message.message)
        
    end
end

Client.HookNetworkMessage("NSLAdminChat", AdminChatMessageRecieved)

local oldOnMessageChat

-- Validate against the NSL global opponents chat mute option
local function OnMessageChat(message)
    local player = Client.GetLocalPlayer()
    if player and kNSLOpponentChatMute then
        if player:GetTeamNumber() ~= message.teamNumber and (message.teamNumber == 1 or message.teamNumber == 2) then
            -- We dont want to see this chat message
            return
        end
    end
    return oldOnMessageChat(message)
end

local d = debug.getregistry()
for k, v in pairs(d) do
    if type(v) == "function" then
        local vF = debug.getinfo(v)
        if vF.short_src == "lua/Chat.lua" then
            oldOnMessageChat = v
            --table.remove(d, i) -- This doesnt seem to actually unregister anything?..
            break
        end
    end
end

if oldOnMessageChat then

    Client.HookNetworkMessage("Chat", OnMessageChat)
    -- This causes a warning message, but our hook still gets inserted... need to find better solution.

end

local function OnCommandToggleOpponentMute()
    kNSLOpponentChatMute = not kNSLOpponentChatMute
    SaveNSLClientConfig()
    Shared.Message(string.format("NSL: Opponents Chat is now %s.", kNSLOpponentChatMute and "hidden" or "visible"))
end

Event.Hook("Console_toggleopponentmute", OnCommandToggleOpponentMute)
Event.Hook("Console_tom", OnCommandToggleOpponentMute)