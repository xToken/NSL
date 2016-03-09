-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\nsl_filehooks.lua
-- - Dragon

if Server then
	--This is odd, but hey.
	ModLoader.SetupFileHook( "lua/ConsistencyConfig.lua", "lua/nsl_consistencybypass_server.lua", "replace" )
elseif Client then
	ModLoader.SetupFileHook( "lua/ClientResources.lua", "lua/nsl_filehooks_client.lua", "pre" )
end