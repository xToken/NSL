// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_filehooks.lua
// - Dragon

if Server then
	ModLoader.SetupFileHook( "lua/ServerAdmin.lua", "lua/nsl_serveradmin.lua", "post" )
end