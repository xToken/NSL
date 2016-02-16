-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua\nsl_consistencybypass_server.lua
-- - Dragon

--We set a value, then load the old file :D
Server.SetConfigSetting("consistency_enabled", false)
Script.Load("lua/ConsistencyConfig.lua")
Server.SetConfigSetting("consistency_enabled", true)