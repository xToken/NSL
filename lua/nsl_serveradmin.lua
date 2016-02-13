// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_serveradmin.lua
// - Dragon

//NSL Server Admin Hooks

local function GetUpValue(origfunc, name)

	local index = 1
	local foundValue = nil
	while true do
	
		local n, v = debug.getupvalue(origfunc, index)
		if not n then
			break
		end
		
		-- Find the highest index matching the name.
		if n == name then
			foundValue = v
		end
		
		index = index + 1
		
	end
	
	return foundValue
	
end

function ReplaceLocals(originalFunction, replacedLocals)

    local numReplaced = 0
    for name, value in pairs(replacedLocals) do
    
        local index = 1
        local foundIndex = nil
        while true do
        
            local n, v = debug.getupvalue(originalFunction, index)
            if not n then
                break
            end
            
            -- Find the highest index matching the name.
            if n == name then
                foundIndex = index
            end
            
            index = index + 1
            
        end
        
        if foundIndex then
        
            debug.setupvalue(originalFunction, foundIndex, value)
            numReplaced = numReplaced + 1
            
        end
        
    end
    
    return numReplaced
    
end

local oldGetClientCanRunCommand = GetClientCanRunCommand
function GetClientCanRunCommand(client, commandName, printWarning)

	if not client then return end
	local NS2ID = client:GetUserId()
	local canRun = false
	if GetNSLLeagueAdminsAccess() and GetNSLModEnabled() and GetIsNSLRef(NS2ID) then
		canRun = GetCanRunCommandviaNSL(NS2ID, commandName)
	end
	if not canRun then
		return oldGetClientCanRunCommand(client, commandName, printWarning)
	end
	return canRun
	
end