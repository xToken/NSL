-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/messages/server.lua
-- - Dragon

Script.Load("lua/dkjson.lua")

local kNSLMessageIDs = { }
local kNSLMessageDefaults = { }
local kNSLParsedFile = { }

local function BuildNSLMessageTable()

    local fileName = "lang/enUS.json"
    local counter = 1
    local openedFile = GetFileExists(fileName) and io.open(fileName, "r")
    if openedFile then
        local parsedFile, _, errStr = json.decode(openedFile:read("*all"))
        io.close(openedFile)
        for k, v in pairs(parsedFile) do
            kNSLMessageIDs[k] = counter
            kNSLMessageDefaults[k] = v
            counter = counter + 1
        end
		kNSLParsedFile = parsedFile
    end
    
end

BuildNSLMessageTable()

function GetNSLMessageID(messageName)
    return kNSLMessageIDs[messageName] or 0
end

function GetNSLMessageDefaultText(messageName)
    return kNSLMessageDefaults[messageName] and string.format(kNSLMessageDefaults[messageName], "") or ""
end

-- Send msg id mapping to clients on connect :<
local function OnNSLClientConnected(client)
	local NS2ID = client:GetUserId()
	local counter = 1
	for k, v in pairs(kNSLParsedFile) do
		Server.SendNetworkMessage(client, "NSLSystemMessageDefinition", {messageid = counter, messagename = k}, true)
		counter = counter + 1
	end
end

table.insert(gConnectFunctions, OnNSLClientConnected)