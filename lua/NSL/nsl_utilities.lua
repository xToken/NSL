-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/nsl_utilities.lua
-- - Dragon

-- Utility Funcs
local function ReplaceMethodInDerivedClasses(className, methodName, method, original)

	-- only replace the method when it matches with super class (has not been implemented by the derrived class)
	if _G[className][methodName] ~= original then
		return
	end
	
	_G[className][methodName] = method

	local classes = Script.GetDerivedClasses(className)
	
	if classes then
		for i, c in ipairs(classes) do
			ReplaceMethodInDerivedClasses(c, methodName, method, original)
		end
	end
	
end

function Class_ReplaceMethod(className, methodName, method)

	if _G[className] == nil then 
		return nil
	end
	
	local original = _G[className][methodName]
	
	if original then
		ReplaceMethodInDerivedClasses(className, methodName, method, original)
	end
	
	return original

end

-- This doesnt exist in older builds
if not debug.getupvaluex then
	local old = debug.getupvalue
    local function getupvalue(f, up, recursive)
        if type(up) ~= "string" then
            return old(f, up)
        end

        if recursive == nil then
            recursive = true
        end

        local funcs   = {}
        local i, n, v = 0
        repeat
            i = i + 1
            n, v = old(f, i)
            if recursive and type(v) == "function" then
                table.insert(funcs, v)
            end
        until
            n == nil or n == up

        -- Do a recursive search
        if n == nil then
            for _, subf in ipairs(funcs) do
                v, f, i = getupvalue(subf, up)
                if f ~= nil then
                    return v, f, i
                end
            end
        elseif n == up then
            return v, f, i
        end
    end
    debug.getupvaluex = getupvalue
end