-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/messages/server.lua
-- - Dragon

Script.Load("lua/dkjson.lua")

local kNSLMessageIDs = { }

local function BuildNSLMessageTable()

    local fileName = "lang/enUS.json"
    local counter = 1
    local openedFile = GetFileExists(fileName) and io.open(fileName, "r")
    if openedFile then
        local parsedFile, _, errStr = json.decode(openedFile:read("*all"))
        io.close(openedFile)
        for k, v in pairs(parsedFile) do
            kNSLMessageIDs[k] = counter
            counter = counter + 1
        end
    end
    
end

BuildNSLMessageTable()

function GetNSLMessageID(messageName)
    return kNSLMessageIDs[messageName] or 0
end