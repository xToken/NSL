-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/nsl_filehooks.lua
-- - Dragon

-- Dont run from filehook calls on main menu.
if not string.find(Script.CallStack(), "Main.lua") then
	if Server then
		ModLoader.SetupFileHook("lua/ConsistencyConfig.lua", "lua/NSL/consistencychecks/server.lua", "replace")
	end
	if Client then
		-- Not sure if this is still needed, but meh
		if jit.os ~= "Linux" then
			ModLoader.SetupFileHook("lua/ClientResources.lua", "lua/NSL/consistencychecks/client.lua", "pre")
		end
	end
end