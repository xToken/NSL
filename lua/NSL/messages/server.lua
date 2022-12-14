-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/messages/server.lua
-- - Dragon

Script.Load("lua/dkjson.lua")

local kNSLMessageIDs = { }
local kNSLMessageDefaults = { }

local function BuildNSLMessageTable()

    local fileName = "lang/enUS.json"
    local openedFile = GetFileExists(fileName) and io.open(fileName, "r")
    if openedFile then
        local parsedFile, _, errStr = json.decode(openedFile:read("*all"))
        io.close(openedFile)
        for k, v in pairs(parsedFile) do
            text = v["text"]
            idx = v["id"]
            kNSLMessageIDs[k] = idx
            kNSLMessageDefaults[k] = text
        end
    end
    
end

BuildNSLMessageTable()

function GetNSLMessageID(messageName)
    return kNSLMessageIDs[messageName] or 0
end

function GetNSLMessageDefaultText(messageName)
    return kNSLMessageDefaults[messageName] and string.format(kNSLMessageDefaults[messageName], "") or ""
end