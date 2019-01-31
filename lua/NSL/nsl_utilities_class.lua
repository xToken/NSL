-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/nsl_utilities_class.lua
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