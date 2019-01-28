-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/nsl_filehooks.lua
-- - Dragon

-- Dont run from filehook calls on main menu.
if not string.find(Script.CallStack(), "Main.lua") then
	if Server then
		ModLoader.SetupFileHook("lua/ConsistencyConfig.lua", "lua/NSL/consistencychecks/server.lua", "replace")
	end
	-- Optimizations
	ModLoader.SetupFileHook("lua/CatalystMixin.lua", "lua/NSL/optimizations/CatalystMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/CorrodeMixin.lua", "lua/NSL/optimizations/CorrodeMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/EnergizeMixin.lua", "lua/NSL/optimizations/EnergizeMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/FireMixin.lua", "lua/NSL/optimizations/FireMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/FlinchMixin.lua", "lua/NSL/optimizations/FlinchMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/GhostStructureMixin.lua", "lua/NSL/optimizations/GhostStructureMixin.lua", "replace")
	--ModLoader.SetupFileHook("lua/GorgeStructureMixin.lua", "lua/NSL/optimizations/GorgeStructureMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/IdleMixin.lua", "lua/NSL/optimizations/IdleMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/NanoShieldMixin.lua", "lua/NSL/optimizations/NanoShieldMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/ParasiteMixin.lua", "lua/NSL/optimizations/ParasiteMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/RecycleMixin.lua", "lua/NSL/optimizations/RecycleMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/ResearchMixin.lua", "lua/NSL/optimizations/ResearchMixin.lua", "replace")
	--ModLoader.SetupFileHook("lua/StormCloudMixin.lua", "lua/NSL/optimizations/StormCloudMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/TechMixin.lua", "lua/NSL/optimizations/TechMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/TeleportMixin.lua", "lua/NSL/optimizations/TeleportMixin.lua", "replace")
	ModLoader.SetupFileHook("lua/UmbraMixin.lua", "lua/NSL/optimizations/UmbraMixin.lua", "replace")
	-- END
	if Client then
		-- Not sure if this is still needed, but meh
		if jit.os ~= "Linux" then
			ModLoader.SetupFileHook("lua/ClientResources.lua", "lua/NSL/consistencychecks/client.lua", "pre")
		end
	end
end